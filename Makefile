# CS2 bot voice line extraction pipeline.
#
#   vpks/      -- input  : CS2 VPK archives (pak01_dir.vpk + chunks)
#   vsnd/      -- stage1 : compiled .vsnd_c files, organized per bot
#   audio/     -- stage2 : decoded .wav / .mp3
#   tools/     -- cached VRF CLI binary
#   .stamps/   -- per-stage timestamps so `make all` is incremental
#
# Stages:
#   make unpack  -- vpks/  -> vsnd/    (vpkedit, in fedora container)
#   make decode  -- vsnd/  -> audio/   (VRF, in dotnet runtime container)
#   make all     -- both (default goal)

VPKS_DIR   := ${PWD}/vpks
VSND_DIR   := ${PWD}/vsnd
AUDIO_DIR  := ${PWD}/audio
TOOLS_DIR  := ${PWD}/tools
STAMPS_DIR := ${PWD}/.stamps

VPK_INDEX := ${VPKS_DIR}/pak01_dir.vpk

# Path inside the VPK to extract. Trailing slash means "directory".
# Override on the command line, e.g. `make EXTRACT_PATH=sounds/vo/ unpack`.
# Changing this requires `make clean-vsnd` so paths don't pile up in vsnd/.
EXTRACT_PATH := sounds/vo/agents/

TREE_FILE      := ${PWD}/tree.txt
TREE_FLAT_FILE := ${PWD}/tree_flat.txt
FLATTEN_SCRIPT := ${PWD}/flatten_tree.py

VRF_VERSION  := 19.1
VRF_URL      := https://github.com/ValveResourceFormat/ValveResourceFormat/releases/download/$(VRF_VERSION)/cli-linux-x64.zip
VRF_BIN      := Source2Viewer-CLI

DECODE_THREADS ?= 4

FEDORA_IMAGE := fedora:latest
DOTNET_IMAGE := mcr.microsoft.com/dotnet/runtime:10.0
FETCH_IMAGE  := debian:stable-slim
PYTHON_IMAGE := python:3-slim

# Shared install snippet for the two recipes that need vpkedit inside fedora.
# Recursive (=) assignment keeps $$ literal until the recipe expands it.
VPKEDIT_INSTALL = dnf install -y -q --nogpgcheck --repofrompath terra,https://repos.fyralabs.com/terra$$(rpm -E %fedora) terra-release; dnf install -y -q vpkedit

.PHONY: all
all: decode

.PHONY: unpack
unpack: ${STAMPS_DIR}/unpacked

${STAMPS_DIR}/unpacked: ${VPK_INDEX} | ${VSND_DIR} ${STAMPS_DIR}
	podman run \
		--rm \
		-v ${VPKS_DIR}:/vpks:ro,Z \
		-v ${VSND_DIR}:/vsnd:Z \
		${FEDORA_IMAGE} \
		bash -c 'set -e; $(VPKEDIT_INSTALL); vpkeditcli /vpks/pak01_dir.vpk --extract ${EXTRACT_PATH} --output /vsnd'
	@touch $@

.PHONY: decode
decode: ${STAMPS_DIR}/decoded

${STAMPS_DIR}/decoded: ${STAMPS_DIR}/unpacked ${TOOLS_DIR}/${VRF_BIN} | ${AUDIO_DIR}
	podman run \
		--rm \
		-v ${VSND_DIR}:/vsnd:ro,Z \
		-v ${AUDIO_DIR}:/audio:Z \
		-v ${TOOLS_DIR}:/tools:ro,Z \
		${DOTNET_IMAGE} \
		/tools/${VRF_BIN} \
			--input /vsnd \
			--output /audio \
			--decompile \
			--recursive \
			--threads ${DECODE_THREADS}
	@touch $@

${TOOLS_DIR}/${VRF_BIN}: | ${TOOLS_DIR}
	podman run \
		--rm \
		-v ${TOOLS_DIR}:/tools:Z \
		${FETCH_IMAGE} \
		bash -c 'set -e; apt-get update -qq; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends curl unzip ca-certificates >/dev/null; curl -fsSL -o /tmp/vrf.zip "${VRF_URL}"; unzip -oq /tmp/vrf.zip -d /tools; chmod +x "/tools/${VRF_BIN}"'
	@touch $@

${VSND_DIR} ${AUDIO_DIR} ${TOOLS_DIR} ${STAMPS_DIR}:
	mkdir -p $@

.PHONY: tree
tree: ${TREE_FLAT_FILE}

${TREE_FILE}: ${VPK_INDEX}
	podman run \
		--rm \
		-v ${VPKS_DIR}:/vpks:ro,Z \
		-v ${PWD}:/work:Z \
		${FEDORA_IMAGE} \
		bash -c 'set -e; $(VPKEDIT_INSTALL); vpkeditcli /vpks/pak01_dir.vpk --file-tree > /work/tree.txt'

${TREE_FLAT_FILE}: ${TREE_FILE} ${FLATTEN_SCRIPT}
	podman run \
		--rm \
		-v ${PWD}:/work:Z \
		${PYTHON_IMAGE} \
		python3 /work/flatten_tree.py /work/tree.txt /work/tree_flat.txt

.PHONY: clean-vsnd
clean-vsnd:
	rm -rf ${VSND_DIR} ${STAMPS_DIR}/unpacked ${STAMPS_DIR}/decoded

.PHONY: clean-audio
clean-audio:
	rm -rf ${AUDIO_DIR} ${STAMPS_DIR}/decoded

.PHONY: clean-tools
clean-tools:
	rm -rf ${TOOLS_DIR}

.PHONY: clean-tree
clean-tree:
	rm -f ${TREE_FILE} ${TREE_FLAT_FILE}

.PHONY: clean
clean: clean-vsnd clean-audio clean-tools clean-tree
	rm -rf ${STAMPS_DIR}
