#!/bin/bash
# test_local.sh — Tests Tigress and Movfuscator locally on Debian
# Usage: ./tests/test_local.sh
#
# Expects to be run from the repo root:
#   cd obfuscation-pipeline && bash tests/test_local.sh

set -e

PASS=0
FAIL=0
SKIP=0

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

pass() { echo -e "${GREEN}[PASS]${RESET} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${RESET} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${RESET} $1"; SKIP=$((SKIP + 1)); }
header() { echo -e "\n========================================"; echo "  $1"; echo "========================================"; }

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
        --Transform=Virtualize \
        --Functions=main \
        --out=obfuscated/test_hello_tigress.c \
        src/test_hello.c 2>&1; then

        echo "→ Compiling obfuscated output..."
        if gcc -o obfuscated/test_hello_tigress obfuscated/test_hello_tigress.c 2>&1; then

            echo "→ Running binary..."
            OUTPUT=$(./obfuscated/test_hello_tigress)
            echo "$OUTPUT"

            if echo "$OUTPUT" | grep -q "Hello from test_hello.c" && \
               echo "$OUTPUT" | grep -q "2 + 3 = 5"; then
                pass "Tigress: obfuscation, compilation and output correct"
            else
                fail "Tigress: binary ran but output was unexpected"
            fi
        else
            fail "Tigress: compilation of obfuscated output failed"
        fi
    else
        fail "Tigress: obfuscation step failed"
    fi
fi

# ─────────────────────────────────────────
header "2/2 — MOVFUSCATOR"
# ─────────────────────────────────────────

if ! command -v movcc &>/dev/null; then
    skip "movcc not found in PATH (movfuscator not installed)"
else
    echo "→ Compiling src/test_hello.c with movcc..."
    if movcc -o obfuscated/test_hello_movfuscated src/test_hello.c 2>&1; then

        echo "→ Running binary..."
        OUTPUT=$(./obfuscated/test_hello_movfuscated)
        echo "$OUTPUT"

        if echo "$OUTPUT" | grep -q "Hello from test_hello.c" && \
           echo "$OUTPUT" | grep -q "2 + 3 = 5"; then
            pass "Movfuscator: compilation and output correct"
        else
            fail "Movfuscator: binary ran but output was unexpected"
        fi
    else
        fail "Movfuscator: compilation failed"
    fi
fi

# ─────────────────────────────────────────
header "RESULTS"
# ─────────────────────────────────────────
echo -e "  ${GREEN}Passed: $PASS${RESET}"
echo -e "  ${RED}Failed: $FAIL${RESET}"
echo -e "  ${YELLOW}Skipped: $SKIP${RESET}"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Some tests failed.${RESET}"
    exit 1
else
    echo -e "${GREEN}All tests passed (or skipped due to missing tools).${RESET}"
    exit 0
fi
