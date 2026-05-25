# cs2-extract

Extract and decompile assets from Counter-Strike 2's VPK archives &mdash; audio, textures, models, materials, particles, anything Source 2 ships. Two stages, both run inside podman containers so nothing is installed on the host.

```
vpks/   --(vpkedit, fedora)-->   extracted/   --(VRF, dotnet)-->   decoded/
```

## Layout

| Dir          | Stage | Contents                                                        |
| ------------ | ----- | --------------------------------------------------------------- |
| `vpks/`      | input | CS2 VPK archives (`pak01_dir.vpk` + chunks)                     |
| `extracted/` | 1     | Compiled Source 2 assets (`.vsnd_c`, `.vtex_c`, `.vmdl_c`, ...) |
| `decoded/`   | 2     | Decompiled assets (`.wav`/`.mp3`, `.png`, glTF, ...)            |
| `tools/`     | cache | VRF CLI binary, fetched once                                    |
| `.stamps/`   | cache | Per-stage timestamps so `make all` is incremental               |

## Requirements

- `podman`
- `make`
- `vpks/` populated with the CS2 archives (see below)

### Populating `vpks/`

Copy `pak01_dir.vpk` and every `pak01_NNN.vpk` chunk from your Steam install into `vpks/`. They live in:

```
<Steam library>/steamapps/common/Counter-Strike Global Offensive/game/csgo/
```

Only `pak01_dir.vpk` is referenced directly by `make unpack`; it indexes the numbered chunks, so all of them must be present alongside it.

## Usage

```sh
make all       # default goal: unpack then decode (skips stages already done)
make unpack    # vpks/      -> extracted/   (vpkedit in fedora)
make decode    # extracted/ -> decoded/     (VRF in dotnet runtime)
```

VRF picks the output format per file based on the source asset type &mdash; audio decompiles to `.wav`/`.mp3`, textures to `.png`, models to glTF, materials and particles to text, etc.

### Choosing what to extract

`make unpack` extracts the path defined by `EXTRACT_PATH` in the Makefile. The default is `sounds/vo/agents/` (bot voice lines, a convenient starting point), but it can be anything in the VPK. Override on the command line:

```sh
make clean-extracted && make EXTRACT_PATH=sounds/vo/      unpack   # all voice lines
make clean-extracted && make EXTRACT_PATH=materials/      unpack
make clean-extracted && make EXTRACT_PATH=models/weapons/ unpack
make clean-extracted && make EXTRACT_PATH=particles/      unpack
```

Always `clean-extracted` first when switching paths so the previous extraction isn't left layered underneath the new one.

### Browsing the VPK to pick a path

```sh
make tree
```

Produces two files at the repo root:

- `tree.txt` &mdash; the raw, ANSI-colored output of `vpkeditcli --file-tree`
- `tree_flat.txt` &mdash; one full path per line, produced by `flatten_tree.py`, much easier to grep

Use `tree_flat.txt` to figure out what `EXTRACT_PATH` should be, e.g. `grep -E '^materials/weapons/' tree_flat.txt | sort -u`. The target is incremental: changing only `flatten_tree.py` reruns just the flatten step, not vpkedit.

## Cleanup

| Target                 | Removes                                                |
| ---------------------- | ------------------------------------------------------ |
| `make clean-extracted` | `extracted/` (and forces re-decode)                    |
| `make clean-decoded`   | `decoded/`                                             |
| `make clean-tools`     | `tools/` (forces re-fetch of the VRF CLI)              |
| `make clean-tree`      | `tree.txt` and `tree_flat.txt`                         |
| `make clean`           | All of the above plus `.stamps/`                       |

`vpks/` is source data and is never auto-removed.

## Bumping the VRF CLI version

Edit `VRF_VERSION` in the `Makefile`, then:

```sh
make clean-tools && make decode
```
