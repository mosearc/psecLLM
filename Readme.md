# psecLLM — Obfuscation Pipeline

Automated multi-tool obfuscation pipeline running across two environments.

```
Debian (local)                                  GitHub Actions (windows-latest)
├── Tigress        → C source obfuscation        └── Obfusk8 → C++ via MSVC cl.exe
├── Movfuscator    → C x86 mov-only obfuscation
├── CObfuscator    → C source obfuscation (Python)
└── Kovid          → C/C++ LLVM IR passes
```

---

## Tools Overview

| Tool | Language | Runs on | Obfuscation level | Output |
|---|---|---|---|---|
| Tigress | C | Debian (local) | Source-level | Obfuscated `.c` + ELF |
| Movfuscator | C (x86 32-bit) | Debian (local) | Instruction-level | ELF (mov-only) |
| CObfuscator | C | Debian (local) | Source-level | Obfuscated `.c` + ELF |
| Kovid | C / C++ | Debian (local) | IR-level (LLVM) | ELF |
| Obfusk8 | C++ | GitHub Actions (windows-latest) | Compile-time VM | Windows PE `.exe` |

---

## Directory Structure

```
psecLLM/
├── obfuscate_all.sh               ← master pipeline script
├── src/
│   ├── test_hello.c               ← test source for Tigress, Movfuscator, CObfuscator, Kovid
│   └── test_hello.cpp             ← test source for Obfusk8
├── obfuscated/                    ← all output files land here
│   ├── test_hello_tigress.c
│   ├── test_hello_tigress
│   ├── test_hello_movfuscated
│   ├── test_hello_cobfuscated.c
│   ├── test_hello_cobfuscated
│   ├── test_hello_kovid
│   └── test_hello_obfusk8.exe
├── tools/
│   └── cobfuscator_run.py         ← CLI wrapper for CObfuscator Python class
├── tests/
│   └── test_local.sh              ← local test runner
└── .github/
    └── workflows/
        └── obfusk8.yml            ← GitHub Actions workflow (Obfusk8 + MSVC)
```

External tools (outside the repo):

```
~/tools/
├── CObfuscator/
│   └── CObfuscator.py
└── kovid-obfuscation-passes/
    └── build_plugin/lib/*.so

/usr/local/lib/                    ← installed Kovid plugins
    ├── libKoviDRenameCodeLLVMPlugin.so
    ├── libKoviDDummyCodeInsertionLLVMPlugin.so
    ├── libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so
    ├── libKoviDInstructionObfuscationPassLLVMPlugin.so
    ├── libKoviDStringEncryptionLLVMPlugin.so
    └── libKoviDControlFlowTaintLLVMPlugin.so
```

---

## Prerequisites

### Tigress

```bash
# Download from https://tigress.wtf (free academic license)
# Extract and follow the website installation
```

### Movfuscator

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y git gcc nasm gcc-multilib libc6-dev-i386 libgcc-s1:i386
git clone https://github.com/xoreaxeaxeax/movfuscator.git
cd movfuscator && ./build.sh && sudo ./install.sh && cd ..
```

### CObfuscator

```bash
git clone https://github.com/AleksaZatezalo/CObfuscator.git ~/tools/CObfuscator
```

### Kovid (LLVM obfuscation passes)

```bash
# 1. LLVM 19 repo
echo "deb [signed-by=/etc/apt/keyrings/llvm.gpg] http://apt.llvm.org/bookworm/ llvm-toolchain-bookworm-19 main" | sudo tee /etc/apt/sources.list.d/llvm.list
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/llvm.gpg > /dev/null
sudo apt update

# 2. LLVM/Clang packages
sudo apt install -y llvm-19-dev clang-19 libclang-19-dev lld-19 \
    pkg-config libgc-dev libssl-dev zlib1g-dev libcjson-dev \
    libunwind-dev liblldb-19-dev ninja-build python3.11-dev cmake

# 3. GCC plugin support
sudo apt install -y gcc-12-plugin-dev g++-12

# 4. lit
sudo apt install -y python3-pip
pip3 install lit --break-system-packages
sudo ln -s ~/.local/bin/lit /usr/bin/llvm-lit

# 5. Clone and build
git clone https://github.com/djolertrk/kovid-obfuscation-passes.git ~/tools/kovid-obfuscation-passes
mkdir ~/tools/kovid-obfuscation-passes/build_plugin
cd ~/tools/kovid-obfuscation-passes/build_plugin
cmake .. -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/usr/lib/llvm-19/lib/cmake/llvm -GNinja
ninja

# 6. Install plugins manually (GCC plugin is skipped — only LLVM plugins needed)
sudo cp ~/tools/kovid-obfuscation-passes/build_plugin/lib/*.so /usr/local/lib/
sudo cp ~/tools/kovid-obfuscation-passes/build_plugin/bin/kovid-deobfuscator /usr/local/bin/
sudo ldconfig

# 7. Verify
ls /usr/local/lib/libKoviD*.so
```

### Obfusk8 (GitHub Actions — no local setup needed)

- A GitHub repository with this project pushed to `main`
- GitHub CLI authenticated: `sudo apt install -y gh && gh auth login`

---

## Obfuscation Profiles

| Profile | Tigress | Movfuscator | CObfuscator | Kovid | Obfusk8 |
|---|---|---|---|---|---|
| `light` | Flatten (switch) | default | all transforms | RenameCode + RemoveMetadata | `/Od` |
| `medium` | + EncodeArithmetic + Virtualize (switch) | default | all transforms | + DummyCode + StringEncryption | `/O1` |
| `heavy` | + AddOpaque + Virtualize (indirect) | + ENTROPY | all transforms | + InstructionObfuscation + ControlFlowTaint | `/O2 /GL /Oy /GS-` |

### Kovid pass details

| Pass | Plugin | Effect |
|---|---|---|
| RenameCode | `libKoviDRenameCodeLLVMPlugin.so` | Encrypts function/symbol names |
| RemoveMetadata | `libKoviDRemoveMetadataAndUnusedCodeLLVMPlugin.so` | Strips debug info and dead code |
| DummyCodeInsertion | `libKoviDDummyCodeInsertionLLVMPlugin.so` | Inserts junk instructions |
| StringEncryption | `libKoviDStringEncryptionLLVMPlugin.so` | Encrypts string literals at compile time (via `opt-19`) |
| InstructionObfuscation | `libKoviDInstructionObfuscationPassLLVMPlugin.so` | Replaces arithmetic with MBA equivalents |
| ControlFlowTaint | `libKoviDControlFlowTaintLLVMPlugin.so` | Flattening + opaque predicates + state injection |

> ⚠️ StringEncryption intentionally corrupts string output at runtime — when active
> (`medium`/`heavy`), the test only verifies the binary runs without crashing.

---

## Running the Pipeline

### C file → Tigress + Movfuscator + CObfuscator + Kovid

```bash
./obfuscate_all.sh src/test_hello.c              # medium (default)
./obfuscate_all.sh src/test_hello.c light
./obfuscate_all.sh src/test_hello.c heavy
```

### C++ file → Kovid + Obfusk8 (GitHub Actions)

```bash
./obfuscate_all.sh src/test_hello.cpp            # medium (default)
./obfuscate_all.sh src/test_hello.cpp light
./obfuscate_all.sh src/test_hello.cpp heavy
```

---

## Testing

### Run local tests (Tigress + Movfuscator + CObfuscator + Kovid)

```bash
# Run from repo root
bash tests/test_local.sh              # medium (default)
bash tests/test_local.sh light
bash tests/test_local.sh heavy
```

### Trigger Obfusk8 manually

```bash
gh workflow run obfusk8.yml --ref main --field profile=light
gh run watch
```

### Download Obfusk8 artifact

```bash
gh run download --name obfusk8-binaries-light  --dir ./obfuscated/
gh run download --name obfusk8-binaries-medium --dir ./obfuscated/
gh run download --name obfusk8-binaries-heavy  --dir ./obfuscated/
```

---

## GitHub Actions — Useful Commands

```bash
# Trigger
gh workflow run obfusk8.yml --field profile=light
gh workflow run obfusk8.yml --field profile=medium
gh workflow run obfusk8.yml --field profile=heavy

# Monitor
gh run watch
gh run list --workflow=obfusk8.yml --limit 10
gh run view --log

# Cancel
gh run cancel <RUN_ID>
gh run cancel $(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
```

---

## GitHub Actions — Workflow Details

**File:** `.github/workflows/obfusk8.yml`

**Triggers:** push to `src/**.cpp` or manual `workflow_dispatch` with profile selector.

**Steps:**
1. Checkout repository
2. Cache/clone Obfusk8 headers to `C:\Obfusk8`
3. Verify `Obfusk8Core.hpp` is locatable
4. Set up MSVC via `microsoft/setup-msbuild@v2`
5. Resolve MSVC flags from profile
6. Compile all `src/*.cpp` with `cl.exe` + all Obfusk8 include paths
7. Run each `.exe` — verify output and exit code 0
8. Upload `.exe` artifacts (retained 30 days)

**Obfusk8 include paths:**
```
C:\Obfusk8\Obfusk8\Instrumentation\materialization\state
C:\Obfusk8\Obfusk8\Instrumentation\materialization\transform
C:\Obfusk8\Obfusk8\Instrumentation\materialization
C:\Obfusk8\Obfusk8\Instrumentation
C:\Obfusk8\Obfusk8
C:\Obfusk8
```

---

## Obfusk8 — Using the `_main` Wrapper

The current `test_hello.cpp` uses the full `_main` VM wrapper:

```cpp
#include "Obfusk8/Instrumentation/materialization/state/Obfusk8Core.hpp"

_main({
    printf("Hello from test_hello.cpp\n");
    printf("2 + 3 = %d\n", 2 + 3);
})
```

> ⚠️ `_main` instantiates the full VM engine at compile time — expect 20–30 minutes
> on GitHub Actions regardless of profile. Use `light` (`/Od`) for the fastest compile.

For lighter use without `_main`, individual features can be used independently:

```cpp
#include <cstdio>
// String encryption only — no VM engine, fast compile
// auto s = OBFUSCATE_STRING("secret");

int main(void) {
    printf("Hello\n");
    return 0;
}
```

---

## Adding Your Own Source Files

### C file

```bash
cp /path/to/yourfile.c src/
./obfuscate_all.sh src/yourfile.c medium
```

Outputs in `obfuscated/`:
- `yourfile_tigress.c` + `yourfile_tigress` (ELF)
- `yourfile_movfuscated` (ELF)
- `yourfile_cobfuscated.c` + `yourfile_cobfuscated` (ELF)
- `yourfile_kovid` (ELF)

### C++ file

```bash
cp /path/to/yourfile.cpp src/
./obfuscate_all.sh src/yourfile.cpp medium
```

Outputs in `obfuscated/`:
- `yourfile_kovid` (ELF — local)
- `yourfile_obfusk8.exe` (PE — downloaded from GitHub Actions)

---

## Known Issues & Notes

| Issue | Cause | Fix |
|---|---|---|
| Movfuscator linker fails (`cannot find -lgcc`) | 64-bit Debian missing 32-bit libs | Install `gcc-multilib libc6-dev-i386 libgcc-s1:i386` |
| Movfuscator binary very slow | mov-only x86 — every op is many instructions | Use `puts` instead of `printf`, no timeout |
| `((PASS++))` kills script with `set -e` | bash treats `((0))` as false | Use `PASS=$((PASS + 1))` |
| Tigress `ERR-NOT-ENOUGH-FUNCS-SPECIFIED` | `--Functions` must follow each `--Transform` | Each transform has its own `--Functions=main` |
| Obfusk8 smoke test wrong exit code | MSVC CRT propagates `printf` return value | Use `return 0` not `exit(0)` |
| `_main` compile takes 20–30 minutes | Full VM engine instantiated at compile time | Use `light` profile, or omit `_main` for testing |
| Kovid string output corrupted | `StringEncryption` pass encrypts strings at compile time | Expected — test only checks binary runs without crashing |
| `ninja install` fails on GCC plugin | `libKoviDRenameCodeGCCPlugin.so` not built | Copy LLVM plugins manually with `cp *.so /usr/local/lib/` |
