# cs2-extract

Extract Counter-Strike 2 bot voice lines, ending up with plain `.wav` / `.mp3` files. Two stages, both run inside podman containers so nothing is installed on the host.

```
vpks/   --(vpkedit, fedora)-->   vsnd/   --(VRF, dotnet)-->   audio/
```

## Layout

| Dir       | Stage | Contents                                            |
| --------- | ----- | --------------------------------------------------- |
| `vpks/`   | input | CS2 VPK archives (`pak01_dir.vpk` + chunks)         |
| `vsnd/`   | 1     | Compiled `.vsnd_c` files, per-bot subdirs           |
| `audio/`  | 2     | Decoded `.wav` / `.mp3`, mirrors `vsnd/` tree       |
| `tools/`  | cache | VRF CLI binary, fetched once                        |
| `.stamps/`| cache | Per-stage timestamps so `make all` is incremental   |

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
make unpack    # vpks/  -> vsnd/   (vpkedit in fedora)
make decode    # vsnd/  -> audio/  (VRF in dotnet runtime)
```

VRF picks the output format per file based on its internal encoding (PCM &rarr; `.wav`, MP3 &rarr; `.mp3`).

### Choosing what to extract

`make unpack` extracts the path defined by `EXTRACT_PATH` in the Makefile (default `sounds/vo/agents/`). Override on the command line for a different subtree, e.g. all bot voice lines:

```sh
make clean-vsnd && make EXTRACT_PATH=sounds/vo/ unpack
```

Always `clean-vsnd` first when switching paths so the previous extraction isn't left layered underneath the new one.

### Browsing the VPK to pick a path

```sh
make tree
```

Produces two files at the repo root:

- `tree.txt` &mdash; the raw, ANSI-colored output of `vpkeditcli --file-tree`
- `tree_flat.txt` &mdash; one full path per line, produced by `flatten_tree.py`, much easier to grep

Use `tree_flat.txt` to figure out what `EXTRACT_PATH` should be, e.g. `grep -E '^sounds/vo/' tree_flat.txt | sort -u`. The target is incremental: changing only `flatten_tree.py` reruns just the flatten step, not vpkedit.

## Cleanup

| Target             | Removes                                                |
| ------------------ | ------------------------------------------------------ |
| `make clean-vsnd`  | `vsnd/` (and forces re-decode)                         |
| `make clean-audio` | `audio/`                                               |
| `make clean-tools` | `tools/` (forces re-fetch of the VRF CLI)              |
| `make clean-tree`  | `tree.txt` and `tree_flat.txt`                         |
| `make clean`       | All of the above plus `.stamps/`                       |

`vpks/` is source data and is never auto-removed.

## Bumping the VRF CLI version

Edit `VRF_VERSION` in the `Makefile`, then:

```sh
make clean-tools && make decode
```
