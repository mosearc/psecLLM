#!/bin/bash
# docker-build.sh — Prepares Tigress build context and builds the image
#
# Usage: ./docker-build.sh
#
# Tigress cannot be downloaded automatically (license required).
# This script resolves the real Tigress package directory (following symlinks),
# copies it into the build context, then cleans up after the build.

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
TIGRESS_DST="${REPO_ROOT}/tigress"

GREEN="\033[0;32m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}[*] psecLLM Docker build${RESET}"
echo ""

# ── Resolve real Tigress location ─────────────────────────────────────────────
# Handle three cases:
#   1. /usr/local/bin/tigress is a symlink → resolve and find parent package dir
#   2. TIGRESS_HOME is set → use it directly
#   3. tigresspkg directory exists → use it directly

if [[ -n "$TIGRESS_HOME" && -d "$TIGRESS_HOME" ]]; then
    TIGRESS_SRC="$TIGRESS_HOME"
    echo -e "${CYAN}[*] Using TIGRESS_HOME: ${TIGRESS_SRC}${RESET}"

elif [[ -L "/usr/local/bin/tigress" ]]; then
    # Resolve symlink and go up to the versioned package dir
    TIGRESS_REAL=$(readlink -f /usr/local/bin/tigress)
    TIGRESS_SRC=$(dirname "$TIGRESS_REAL")
    echo -e "${CYAN}[*] Resolved Tigress symlink: /usr/local/bin/tigress → ${TIGRESS_REAL}${RESET}"
    echo -e "${CYAN}[*] Using package directory: ${TIGRESS_SRC}${RESET}"

elif [[ -d "/usr/local/bin/tigresspkg" ]]; then
    # Find the versioned subdirectory
    TIGRESS_SRC=$(find /usr/local/bin/tigresspkg -maxdepth 1 -mindepth 1 -type d | head -1)
    echo -e "${CYAN}[*] Found tigresspkg at: ${TIGRESS_SRC}${RESET}"

elif [[ -f "/usr/local/bin/tigress" ]]; then
    TIGRESS_SRC="/usr/local/bin"
    echo -e "${CYAN}[*] Using /usr/local/bin/tigress as single binary${RESET}"

else
    echo -e "${RED}[!] Tigress not found. Install from https://tigress.wtf first.${RESET}"
    exit 1
fi

# ── Copy Tigress into build context ──────────────────────────────────────────
echo -e "${CYAN}[*] Copying Tigress into build context...${RESET}"
rm -rf "$TIGRESS_DST"
cp -r "$TIGRESS_SRC" "$TIGRESS_DST"
echo -e "  ${GREEN}✓${RESET} Copied to ${TIGRESS_DST}"

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
