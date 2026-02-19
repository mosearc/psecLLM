#!/bin/bash
# test_local.sh — Tests Tigress and Movfuscator locally on Debian
# Usage: ./tests/test_local.sh [light|medium|heavy]
#
# Profiles:
#   light  — basic transforms, fastest
#   medium — flatten + encode + virtualize (default)
#   heavy  — all transforms stacked
#
# Run from repo root:
#   cd obfuscation-pipeline && bash tests/test_local.sh
#   cd obfuscation-pipeline && bash tests/test_local.sh heavy

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
            --Transform=EncodeArithmetic
            --Transform=Virtualize
            --VirtualizeDispatch=switch
            --Functions=main
        )
        ;;
    heavy)
        TIGRESS_FLAGS=(
            --Transform=Flatten
            --FlattenDispatch=goto
            --Transform=EncodeArithmetic
            --Transform=AddOpaque
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

echo -e "\n${CYAN}Profile: $PROFILE${RESET}"
echo -e "${CYAN}Tigress flags: ${TIGRESS_FLAGS[*]}${RESET}"

mkdir -p obfuscated

# ─────────────────────────────────────────
header "1/2 — TIGRESS"
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
header "2/2 — MOVFUSCATOR"
# ─────────────────────────────────────────
# Movfuscator has no meaningful flag profiles —
# it always emits mov-only x86 32-bit code.
# The only knobs are: -g (debug), strip (smaller output).

if ! command -v movcc &>/dev/null; then
    skip "movcc not found in PATH (movfuscator not installed)"
else
    MOVCC_FLAGS="-m32"
    if [[ "$PROFILE" == "heavy" ]]; then
        MOVCC_FLAGS="$MOVCC_FLAGS -DMOVFUSCATOR_ENTROPY"
    fi

    echo -e "${CYAN}Movfuscator flags: $MOVCC_FLAGS${RESET}"
    echo "→ Compiling src/test_hello.c with movcc..."

    if movcc $MOVCC_FLAGS -o obfuscated/test_hello_movfuscated src/test_hello.c 2>&1; then

        echo "→ Running binary (timeout 120s — movfuscated binaries are very slow)..."
        OUTPUT=$(timeout 120 ./obfuscated/test_hello_movfuscated)
        EXIT_CODE=$?

        if [[ $EXIT_CODE -eq 124 ]]; then
            fail "Movfuscator [$PROFILE]: binary timed out after 120s"
        else
            echo "$OUTPUT"
            if echo "$OUTPUT" | grep -q "Hello from test_hello.c" && \
               echo "$OUTPUT" | grep -q "2 + 3 = 5"; then
                pass "Movfuscator [$PROFILE]: compilation and output correct"
            else
                fail "Movfuscator [$PROFILE]: binary ran but output was unexpected"
            fi
        fi
    else
        fail "Movfuscator [$PROFILE]: compilation failed"
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
