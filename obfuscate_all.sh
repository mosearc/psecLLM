#!/bin/bash
# obfuscate_all.sh — Full obfuscation pipeline
# Usage: ./obfuscate_all.sh <source_file> [light|medium|heavy]

set -e

SOURCE="$1"
PROFILE="${2:-medium}"
LOCAL_ONLY=0
for arg in "$@"; do
    [[ "$arg" == "--local-only" ]] && LOCAL_ONLY=1
done
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

# ── Kovid pass profiles ───────────────────────────────────────────────────────
KOVID_LIB=/usr/local/lib
case $PROFILE in
    light)
        KOVID_PASSES=(
            -fpass-plugin=${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so
        )
        KOVID_OPT_PASSES="rename-code,remove-metadata"
        ;;
    medium)
        KOVID_PASSES=(
            -fpass-plugin=${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDDummyCodeInsertionLLVMPlugin.so
        )
        KOVID_OPT_PASSES="rename-code,remove-metadata,dummy-code,string-encryption"
        ;;
    heavy)
        KOVID_PASSES=(
            -fpass-plugin=${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDDummyCodeInsertionLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDInstructionObfuscationPassLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDControlFlowTaintLLVMPlugin.so
        )
        KOVID_OPT_PASSES="rename-code,remove-metadata,dummy-code,string-encryption,instruction-obfuscation,control-flow-taint"
        ;;
esac

echo ""
echo "========================================"
echo -e "  Obfuscation Pipeline: ${CYAN}$BASENAME${RESET}"
echo -e "  Profile: ${CYAN}$PROFILE${RESET}"
echo "========================================"

mkdir -p "${REPO_ROOT}/obfuscated"

# ── 1. TIGRESS ────────────────────────────
echo ""
echo "[1/5] Tigress"
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
echo "[2/5] Movfuscator"
if [[ "$EXT" != "c" ]]; then
    warn "Skipped — C files only"
elif ! command -v movcc &>/dev/null; then
    warn "Skipped — movcc not found in PATH"
else
    echo -e "  flags: ${CYAN}$MOVCC_FLAGS${RESET}"
    movcc $MOVCC_FLAGS -o "${REPO_ROOT}/obfuscated/${NAME}_movfuscated" "$SOURCE"
    ok "obfuscated/${NAME}_movfuscated  (ELF)"
fi

# ── 3. COBFUSCATOR ───────────────────────
echo ""
echo "[3/5] CObfuscator"
if [[ "$EXT" != "c" ]]; then
    warn "Skipped — C files only"
elif ! python3 -c "import sys, os; sys.path.insert(0, os.path.expanduser('~/tools/CObfuscator')); import CObfuscator" 2>/dev/null; then
    warn "Skipped — CObfuscator not found (git clone https://github.com/AleksaZatezalo/CObfuscator.git ~/tools/CObfuscator)"
else
    python3 "${REPO_ROOT}/tools/cobfuscator_run.py" \
        "$SOURCE" \
        "${REPO_ROOT}/obfuscated/${NAME}_cobfuscated.c"
    gcc -o "${REPO_ROOT}/obfuscated/${NAME}_cobfuscated" \
           "${REPO_ROOT}/obfuscated/${NAME}_cobfuscated.c"
    ok "obfuscated/${NAME}_cobfuscated.c"
    ok "obfuscated/${NAME}_cobfuscated  (ELF)"
fi

# ── 4. KOVID ─────────────────────────────
echo ""
echo "[4/5] Kovid (LLVM passes)"
if [[ "$EXT" != "c" && "$EXT" != "cpp" && "$EXT" != "cxx" && "$EXT" != "cc" ]]; then
    warn "Skipped — C/C++ files only"
elif grep -q "Obfusk8" "$SOURCE" 2>/dev/null; then
    warn "Skipped — file includes Obfusk8 headers (Windows/MSVC only, incompatible with clang-19)"
elif ! command -v clang-19 &>/dev/null; then
    warn "Skipped — clang-19 not found"
elif [[ ! -f "${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so" ]]; then
    warn "Skipped — kovid plugins not installed in ${KOVID_LIB}"
else
    echo -e "  passes: ${CYAN}${KOVID_OPT_PASSES}${RESET}"

    # StringEncryption requires the opt IR pipeline — run it separately then link
    TMP_BC="/tmp/${NAME}_kovid.bc"
    TMP_OBF_BC="/tmp/${NAME}_kovid_obf.bc"

    # Step 1: emit LLVM IR
    clang-19 -O2 -emit-llvm -c "$SOURCE" -o "$TMP_BC"

    # Step 2: apply StringEncryption via opt if medium or heavy
    if [[ "$PROFILE" == "medium" || "$PROFILE" == "heavy" ]]; then
        opt-19 \
            -load-pass-plugin=${KOVID_LIB}/libKoviDStringEncryptionLLVMPlugin.so \
            -passes="string-encryption" \
            "$TMP_BC" -o "$TMP_OBF_BC"
    else
        cp "$TMP_BC" "$TMP_OBF_BC"
    fi

    # Step 3: compile with remaining fpass-plugin passes
    clang-19 -O2 \
        "${KOVID_PASSES[@]}" \
        "$TMP_OBF_BC" \
        -o "${REPO_ROOT}/obfuscated/${NAME}_kovid"

    ok "obfuscated/${NAME}_kovid  (ELF)"
fi

# ── 5. OBFUSK8 (GitHub Actions) ───────────
echo ""
echo "[5/5] Obfusk8 (GitHub Actions — profile: $PROFILE)"
if [[ "$LOCAL_ONLY" -eq 1 ]]; then
    warn "Skipped — local-only mode (push trigger will fire Obfusk8 automatically)"
elif [[ "$EXT" != "cpp" && "$EXT" != "cxx" && "$EXT" != "cc" ]]; then
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
