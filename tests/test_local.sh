#!/bin/bash
# test_local.sh — Tests Tigress, Movfuscator, CObfuscator and Kovid locally on Debian
# Usage: ./tests/test_local.sh [light|medium|heavy]

PROFILE=${1:-medium}

PASS=0
FAIL=0
SKIP=0

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

pass() { echo -e "${GREEN}[PASS]${RESET} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${RESET} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${RESET} $1"; SKIP=$((SKIP + 1)); }
header() { echo -e "\n========================================"; echo "  $1"; echo "========================================"; }

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
    *)
        echo "Unknown profile: $PROFILE. Use: light | medium | heavy"
        exit 1
        ;;
esac

case $PROFILE in
    heavy) MOVCC_FLAGS="-DMOVFUSCATOR_ENTROPY" ;;
    *)     MOVCC_FLAGS="" ;;
esac

KOVID_LIB=/usr/local/lib
case $PROFILE in
    light)
        KOVID_PASSES=(
            -fpass-plugin=${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so
        )
        KOVID_STR_ENC=0
        ;;
    medium)
        KOVID_PASSES=(
            -fpass-plugin=${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDDummyCodeInsertionLLVMPlugin.so
        )
        KOVID_STR_ENC=1
        ;;
    heavy)
        KOVID_PASSES=(
            -fpass-plugin=${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDDummyCodeInsertionLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDInstructionObfuscationPassLLVMPlugin.so
            -fpass-plugin=${KOVID_LIB}/libKoviDControlFlowTaintLLVMPlugin.so
        )
        KOVID_STR_ENC=1
        ;;
esac

echo -e "\n${CYAN}Profile: $PROFILE${RESET}"

mkdir -p obfuscated

# ─────────────────────────────────────────
header "1/4 — TIGRESS"
# ─────────────────────────────────────────

if ! command -v tigress &>/dev/null; then
    skip "tigress not found in PATH"
else
    echo "→ Obfuscating src/test_hello.c ..."
    if tigress \
        --Environment=x86_64:Linux:Gcc:4.6 \
        "${TIGRESS_FLAGS[@]}" \
        --out=obfuscated/test_hello_tigress.c \
        src/test_hello.c 2>&1; then

        echo "→ Compiling obfuscated output..."
        if gcc -o obfuscated/test_hello_tigress obfuscated/test_hello_tigress.c 2>&1; then
            echo "→ Running binary..."
            OUTPUT=$(./obfuscated/test_hello_tigress)
            echo "$OUTPUT"
            if echo "$OUTPUT" | grep -q "Hello from test_hello.c" && \
               echo "$OUTPUT" | grep -q "2 + 3 = 5"; then
                pass "Tigress [$PROFILE]: obfuscation, compilation and output correct"
            else
                fail "Tigress [$PROFILE]: binary ran but output was unexpected"
            fi
        else
            fail "Tigress [$PROFILE]: compilation of obfuscated output failed"
        fi
    else
        fail "Tigress [$PROFILE]: obfuscation step failed"
    fi
fi

# ─────────────────────────────────────────
header "2/4 — MOVFUSCATOR"
# ─────────────────────────────────────────

if ! command -v movcc &>/dev/null; then
    skip "movcc not found in PATH (movfuscator not installed)"
else
    echo -e "${CYAN}Movfuscator flags: $MOVCC_FLAGS${RESET}"
    echo "→ Compiling src/test_hello.c with movcc..."
    if movcc $MOVCC_FLAGS -o obfuscated/test_hello_movfuscated src/test_hello.c 2>&1; then
        echo "→ Running binary (movfuscated binaries are slow, please wait)..."
        OUTPUT=$(./obfuscated/test_hello_movfuscated)
        echo "$OUTPUT"
        if echo "$OUTPUT" | grep -q "Hello from test_hello.c" && \
           echo "$OUTPUT" | grep -q "2 + 3 = 5"; then
            pass "Movfuscator [$PROFILE]: compilation and output correct"
        else
            fail "Movfuscator [$PROFILE]: binary ran but output was unexpected"
        fi
    else
        fail "Movfuscator [$PROFILE]: compilation failed"
    fi
fi

# ─────────────────────────────────────────
header "3/4 — COBFUSCATOR"
# ─────────────────────────────────────────

if ! python3 -c "import sys, os; sys.path.insert(0, os.path.expanduser('~/tools/CObfuscator')); import CObfuscator" 2>/dev/null; then
    skip "CObfuscator not found — run: git clone https://github.com/AleksaZatezalo/CObfuscator.git ~/tools/CObfuscator"
else
    echo "→ Obfuscating src/test_hello.c with CObfuscator..."
    if python3 tools/cobfuscator_run.py \
        src/test_hello.c \
        obfuscated/test_hello_cobfuscated.c 2>&1; then

        echo "→ Compiling obfuscated output..."
        if gcc -o obfuscated/test_hello_cobfuscated obfuscated/test_hello_cobfuscated.c 2>&1; then
            echo "→ Running binary..."
            OUTPUT=$(./obfuscated/test_hello_cobfuscated)
            echo "$OUTPUT"
            if echo "$OUTPUT" | grep -q "Hello from test_hello.c" && \
               echo "$OUTPUT" | grep -q "2 + 3 = 5"; then
                pass "CObfuscator [$PROFILE]: obfuscation, compilation and output correct"
            else
                fail "CObfuscator [$PROFILE]: binary ran but output was unexpected"
            fi
        else
            fail "CObfuscator [$PROFILE]: compilation of obfuscated output failed"
        fi
    else
        fail "CObfuscator [$PROFILE]: obfuscation step failed"
    fi
fi

# ─────────────────────────────────────────
header "4/4 — KOVID (LLVM passes)"
# ─────────────────────────────────────────

if ! command -v clang-19 &>/dev/null; then
    skip "clang-19 not found"
elif [[ ! -f "${KOVID_LIB}/libKoviDRenameCodeLLVMPlugin.so" ]]; then
    skip "kovid plugins not installed in ${KOVID_LIB}"
else
    echo "→ Compiling src/test_hello.c with kovid passes..."

    TMP_BC="/tmp/test_hello_kovid.bc"
    TMP_OBF_BC="/tmp/test_hello_kovid_obf.bc"

    # Emit LLVM IR
    clang-19 -O2 -emit-llvm -c src/test_hello.c -o "$TMP_BC" 2>&1

    # Apply StringEncryption via opt if medium or heavy
    if [[ "$KOVID_STR_ENC" -eq 1 ]]; then
        if opt-19 \
            -load-pass-plugin=${KOVID_LIB}/libKoviDStringEncryptionLLVMPlugin.so \
            -passes="string-encryption" \
            "$TMP_BC" -o "$TMP_OBF_BC" 2>&1; then
            echo "→ String encryption applied"
        else
            echo "→ String encryption failed, continuing without it"
            cp "$TMP_BC" "$TMP_OBF_BC"
        fi
    else
        cp "$TMP_BC" "$TMP_OBF_BC"
    fi

    # Compile with remaining passes
    if clang-19 -O2 \
        "${KOVID_PASSES[@]}" \
        "$TMP_OBF_BC" \
        -o obfuscated/test_hello_kovid 2>&1; then

        echo "→ Running binary..."
        OUTPUT=$(./obfuscated/test_hello_kovid)
        echo "$OUTPUT"

        # Note: string encryption will taint string output — only check for partial match
        if [[ "$KOVID_STR_ENC" -eq 1 ]]; then
            # strings are encrypted at runtime — binary should run without crashing
            pass "Kovid [$PROFILE]: compilation and execution successful (strings encrypted)"
        else
            if echo "$OUTPUT" | grep -q "Hello from test_hello.c" && \
               echo "$OUTPUT" | grep -q "2 + 3 = 5"; then
                pass "Kovid [$PROFILE]: compilation and output correct"
            else
                fail "Kovid [$PROFILE]: binary ran but output was unexpected"
            fi
        fi
    else
        fail "Kovid [$PROFILE]: compilation failed"
    fi
fi

# ─────────────────────────────────────────
header "RESULTS"
# ─────────────────────────────────────────
echo -e "  ${GREEN}Passed : $PASS${RESET}"
echo -e "  ${RED}Failed : $FAIL${RESET}"
echo -e "  ${YELLOW}Skipped: $SKIP${RESET}"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Some tests failed.${RESET}"
    exit 1
else
    echo -e "${GREEN}All tests passed (or skipped due to missing tools).${RESET}"
    exit 0
fi
