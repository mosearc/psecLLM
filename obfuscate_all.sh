#!/bin/bash
# Full pipeline:
#   - Tigress & Movfuscator run locally on Debian
#   - Obfusk8 is triggered via GitHub Actions on push
#
# Usage: ./obfuscate_all.sh <source_file>

set -e

SOURCE="$1"
REPO_DIR="$2"   # path to your git repo

if [[ -z "$SOURCE" || -z "$REPO_DIR" ]]; then
    echo "Usage: $0 <source_file> <repo_dir>"
    exit 1
fi

BASENAME=$(basename "$SOURCE")
NAME="${BASENAME%.*}"
EXT="${BASENAME##*.}"

echo "================================================"
echo " Obfuscation Pipeline: $BASENAME"
echo "================================================"

# ── 1. TIGRESS (C only) ──────────────────────────
echo ""
echo "[1/3] Tigress"
if [[ "$EXT" == "c" ]]; then
    tigress \
        --Environment=x86_64:Linux:Gcc:4.6 \
        --Transform=Virtualize \
        --Functions=main \
        --out="${REPO_DIR}/obfuscated/${NAME}_tigress.c" \
        "$SOURCE"
    echo "  ✓ Output: obfuscated/${NAME}_tigress.c"
else
    echo "  ⚠ Skipped (C files only)"
fi

# ── 2. MOVFUSCATOR (C only) ──────────────────────
echo ""
echo "[2/3] Movfuscator"
if [[ "$EXT" == "c" ]]; then
    movcc -o "${REPO_DIR}/obfuscated/${NAME}_movfuscated" "$SOURCE"
    echo "  ✓ Output: obfuscated/${NAME}_movfuscated"
else
    echo "  ⚠ Skipped (C files only)"
fi

# ── 3. OBFUSK8 — push to trigger GitHub Actions ──
echo ""
echo "[3/3] Obfusk8 (GitHub Actions)"
if [[ "$EXT" == "cpp" || "$EXT" == "cxx" || "$EXT" == "cc" ]]; then
    cp "$SOURCE" "${REPO_DIR}/src/"
    cd "$REPO_DIR"
    git add src/ obfuscated/
    git commit -m "pipeline: add ${BASENAME} for Obfusk8 obfuscation"
    git push origin main
    echo "  ✓ Pushed — GitHub Actions will compile with Obfusk8"
    echo "  → Monitor: https://github.com/mosearc/psecLLM/actions"
    echo "  → Waiting for GitHub Actions to complete..."
    gh run watch --repo mosearc/psecLLM

    echo "  → Downloading obfuscated binary..."
    gh run download --repo mosearc/psecLLM \
        --name obfusk8-binaries \
        --dir "${REPO_DIR}/obfuscated/"
    echo "  ✓ Binary saved to obfuscated/"
else
    echo "  ⚠ Skipped (C++ files only)"
fi

echo ""
echo "================================================"
echo " Local steps complete. Check GitHub Actions for Obfusk8 output."
echo "================================================"
