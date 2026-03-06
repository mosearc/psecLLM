#!/bin/bash
# docker-entrypoint.sh
# Auto-runs the test suite on startup, then drops into a shell

set -e

GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}================================================${RESET}"
echo -e "${CYAN}   psecLLM Obfuscation Pipeline${RESET}"
echo -e "${CYAN}================================================${RESET}"
echo ""

# ── Verify tools ──────────────────────────────────────────────────────────────
echo -e "${CYAN}[*] Checking installed tools...${RESET}"

check() {
    if command -v "$1" &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} $1"
    else
        echo -e "  ${YELLOW}⚠${RESET} $1 not found"
    fi
}

check tigress
check movcc
check clang-19
check opt-19
check gh
python3 -c "import sys; sys.path.insert(0, '/opt/CObfuscator'); import CObfuscator; print('  \033[0;32m✓\033[0m CObfuscator')" 2>/dev/null \
    || echo -e "  ${YELLOW}⚠${RESET} CObfuscator not found"

for plugin in RenameCode DummyCodeInsertion RemoveMetadataAndUnusedCode \
              InstructionObfuscationPass StringEncryption ControlFlowTaint; do
    if [[ -f "/usr/local/lib/libKoviD${plugin}LLVMPlugin.so" ]]; then
        echo -e "  ${GREEN}✓${RESET} kovid: ${plugin}"
    else
        echo -e "  ${YELLOW}⚠${RESET} kovid: ${plugin} missing"
    fi
done

echo ""

# ── Check workspace ───────────────────────────────────────────────────────────
if [[ ! -f /workspace/tests/test_local.sh ]]; then
    echo -e "${YELLOW}[!] /workspace does not look like a psecLLM repo.${RESET}"
    echo -e "    Mount your repo: docker run -v ~/psecLLM:/workspace ..."
    echo ""
    exec bash
fi

# ── Fix CObfuscator path in wrapper ──────────────────────────────────────────
# Point cobfuscator_run.py to /opt/CObfuscator inside the container
sed -i "s|os.path.expanduser('~/tools/CObfuscator')|'/opt/CObfuscator'|g" \
    /workspace/tools/cobfuscator_run.py 2>/dev/null || true

# ── Run test suite ────────────────────────────────────────────────────────────
PROFILE="${PROFILE:-medium}"
echo -e "${CYAN}[*] Running test suite (profile: ${PROFILE})...${RESET}"
echo ""

cd /workspace

if bash tests/test_local.sh "$PROFILE"; then
    echo ""
    echo -e "${GREEN}[✓] All tests passed. Dropping into shell.${RESET}"
else
    echo ""
    echo -e "${YELLOW}[!] Some tests failed. Dropping into shell for debugging.${RESET}"
fi

echo ""
exec bash
