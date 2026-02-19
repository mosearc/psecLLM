#!/bin/bash
# obfuscate_all.sh — Full obfuscation pipeline
# Usage: ./obfuscate_all.sh <source_file> [light|medium|heavy]

set -e

SOURCE="$1"
PROFILE="${2:-medium}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

if [[ -z "$SOURCE" ]]; then
    echo "Usage: $0 <source_file> [light|medium|heavy]"
    exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
    echo "Error: file not found: $SOURCE"
    exit 1
fi

case $PROFILE in
    light|medium|heavy) ;;
    *)
        echo "Error: unknown profile '$PROFILE'. Use: light | medium | heavy"
        exit 1
        ;;
esac

BASENAME=$(basename "$SOURCE")
NAME="${BASENAME%.*}"
EXT="${BASENAME##*.}"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }

# ── Tigress flag profiles ─────────────────────────────────────────────────────
# NOTE: each --Transform needs its own --Functions flag
case $PROFILE in
    light)
        TIGRESS_FLAGS=(
            --Transform=Flatten
            --FlattenDispatch=switch
            --Functions=main
        )
        ;;
    medium)
        TIGRESS_FLAGS=(
            --Transform=Flatten
            --FlattenDispatch=switch
            --Functions=main
            --Transform=EncodeArithmetic
            --Functions=main
            --Transform=Virtualize
            --VirtualizeDispatch=switch
            --Functions=main
        )
        ;;
    heavy)
        TIGRESS_FLAGS=(
            --Transform=Flatten
            --FlattenDispatch=goto
            --Functions=main
            --Transform=EncodeArithmetic
            --Functions=main
            --Transform=AddOpaque
            --Functions=main
            --Transform=Virtualize
            --VirtualizeDispatch=indirect
            --Functions=main
        )
        ;;
esac

# ── Movfuscator flags ─────────────────────────────────────────────────────────
case $PROFILE in
    heavy) MOVCC_FLAGS="-DMOVFUSCATOR_ENTROPY" ;;
    *)     MOVCC_FLAGS="" ;;
esac

echo ""
echo "========================================"
echo -e "  Obfuscation Pipeline: ${CYAN}$BASENAME${RESET}"
echo -e "  Profile: ${CYAN}$PROFILE${RESET}"
echo "========================================"

mkdir -p "${REPO_ROOT}/obfuscated"

# ── 1. TIGRESS ────────────────────────────
echo ""
echo "[1/3] Tigress"
if [[ "$EXT" != "c" ]]; then
    warn "Skipped — C files only"
elif ! command -v tigress &>/dev/null; then
    warn "Skipped — tigress not found in PATH"
else
    echo -e "  flags: ${CYAN}${TIGRESS_FLAGS[*]}${RESET}"
    tigress \
        --Environment=x86_64:Linux:Gcc:4.6 \
        "${TIGRESS_FLAGS[@]}" \
        --out="${REPO_ROOT}/obfuscated/${NAME}_tigress.c" \
        "$SOURCE"
    gcc -o "${REPO_ROOT}/obfuscated/${NAME}_tigress" \
           "${REPO_ROOT}/obfuscated/${NAME}_tigress.c"
    ok "obfuscated/${NAME}_tigress.c"
    ok "obfuscated/${NAME}_tigress  (ELF)"
fi

# ── 2. MOVFUSCATOR ────────────────────────
echo ""
echo "[2/3] Movfuscator"
if [[ "$EXT" != "c" ]]; then
    warn "Skipped — C files only"
elif ! command -v movcc &>/dev/null; then
    warn "Skipped — movcc not found in PATH"
else
    echo -e "  flags: ${CYAN}$MOVCC_FLAGS${RESET}"
    movcc $MOVCC_FLAGS -o "${REPO_ROOT}/obfuscated/${NAME}_movfuscated" "$SOURCE"
    ok "obfuscated/${NAME}_movfuscated  (ELF)"
fi

# ── 3. OBFUSK8 (GitHub Actions) ───────────
echo ""
echo "[3/3] Obfusk8 (GitHub Actions — profile: $PROFILE)"
if [[ "$EXT" != "cpp" && "$EXT" != "cxx" && "$EXT" != "cc" ]]; then
    warn "Skipped — C++ files only"
elif ! command -v gh &>/dev/null; then
    warn "Skipped — gh CLI not installed (sudo apt install gh)"
else
    if [[ "$(realpath "$SOURCE")" != "$(realpath "${REPO_ROOT}/src/$(basename "$SOURCE")")" ]]; then
        cp "$SOURCE" "${REPO_ROOT}/src/"
    fi
    cd "$REPO_ROOT"

    git add src/
    git commit -m "pipeline: obfuscate ${BASENAME} [$PROFILE]" || \
        echo "  (nothing new to commit)"
    git push origin main

    ok "Pushed — triggering GitHub Actions with profile=$PROFILE..."
    echo ""

    gh workflow run obfusk8.yml --ref main --field profile="$PROFILE"

    sleep 3
    gh run watch --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)"

    echo ""
    echo "  → Downloading artifact..."
    gh run download \
        --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
        --name "obfusk8-binaries-${PROFILE}" \
        --dir "${REPO_ROOT}/obfuscated/"

    ok "obfuscated/${NAME}_obfusk8.exe  (downloaded)"
fi

# ── SUMMARY ───────────────────────────────
echo ""
echo "========================================"
echo "  Output files:"
ls -lh "${REPO_ROOT}/obfuscated/" 2>/dev/null | grep -v "^total" | \
    awk '{print "  " $NF "  (" $5 ")"}'
echo "========================================"
echo ""
