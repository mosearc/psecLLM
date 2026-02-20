#!/bin/bash
# docker-build.sh — Prepares Tigress build context and builds the image
#
# Usage: ./docker-build.sh
#
# Tigress cannot be downloaded automatically (license required).
# This script copies your local Tigress install into the build context
# before running docker build.

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
TIGRESS_SRC="/usr/local/bin/tigress"
TIGRESS_DST="${REPO_ROOT}/tigress"

GREEN="\033[0;32m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}[*] psecLLM Docker build${RESET}"
echo ""

# ── Copy Tigress into build context ──────────────────────────────────────────
if [[ ! -d "$TIGRESS_SRC" ]]; then
    echo -e "${RED}[!] Tigress not found at ${TIGRESS_SRC}${RESET}"
    echo "    Install Tigress first from https://tigress.wtf"
    exit 1
fi

echo -e "${CYAN}[*] Copying Tigress from ${TIGRESS_SRC}...${RESET}"
rm -rf "$TIGRESS_DST"
cp -r "$TIGRESS_SRC" "$TIGRESS_DST"
echo -e "  ${GREEN}✓${RESET} Tigress copied to build context"

# ── Build image ───────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}[*] Building Docker image (this will take 10-15 minutes)...${RESET}"
echo -e "    Kovid LLVM passes are built from source inside the image."
echo ""

docker build -t psecllm-obfuscator "$REPO_ROOT"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf "$TIGRESS_DST"

echo ""
echo -e "${GREEN}[✓] Image built: psecllm-obfuscator${RESET}"
echo ""
echo "Run with:"
echo "  docker run -it \\"
echo "    -v ~/psecLLM:/workspace \\"
echo "    -v ~/.config/gh:/root/.config/gh \\"
echo "    psecllm-obfuscator"
echo ""
echo "Run with custom profile:"
echo "  docker run -it -e PROFILE=heavy \\"
echo "    -v ~/psecLLM:/workspace \\"
echo "    -v ~/.config/gh:/root/.config/gh \\"
echo "    psecllm-obfuscator"
