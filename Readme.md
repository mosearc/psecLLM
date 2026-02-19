# Obfuscation Pipeline

Automated multi-tool obfuscation pipeline running across two environments.

```
Debian (local)                        GitHub Actions (windows-latest)
├── Tigress      → C obfuscation      └── Obfusk8 → C++ obfuscation
└── Movfuscator  → C obfuscation (x86)     via MSVC cl.exe
```

---

## Tools Overview

| Tool | Language | Runs on | Output |
|---|---|---|---|
| Tigress | C | Debian (local) | Obfuscated `.c` + compiled ELF |
| Movfuscator | C (x86 32-bit) | Debian (local) | ELF binary (mov-only) |
| Obfusk8 | C++ | GitHub Actions (windows-latest) | Windows PE `.exe` |

---

## Prerequisites

### Debian — Local tools

```bash
# 1. Tigress
# Download from https://tigress.wtf (free academic license)

# 2. Movfuscator — build from source
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y git gcc nasm gcc-multilib libc6-dev-i386 libgcc-s1:i386
git clone https://github.com/xoreaxeaxeax/movfuscator.git
cd movfuscator && ./build.sh && sudo ./install.sh && cd ..

# 3. GitHub CLI — for triggering and downloading Obfusk8 builds
sudo apt install -y gh
gh auth login
```

### GitHub — Remote

- A GitHub repository with this project pushed to `main`
- GitHub Actions enabled (default for all repos)

---

## Project Structure

```
obfuscation-pipeline/
├── obfuscate_all.sh               ← master pipeline script
├── src/
│   ├── test_hello.c               ← test source for Tigress + Movfuscator
│   └── test_hello.cpp             ← test source for Obfusk8
├── obfuscated/                    ← all output files land here
│   ├── test_hello_tigress.c       ← Tigress obfuscated C source
│   ├── test_hello_tigress         ← compiled ELF (runs on Debian)
│   ├── test_hello_movfuscated     ← Movfuscator ELF (runs on Debian)
│   └── test_hello_obfusk8.exe     ← Obfusk8 PE binary (runs on Windows)
├── tests/
│   └── test_local.sh              ← local test runner (Tigress + Movfuscator)
└── .github/
    └── workflows/
        └── obfusk8.yml            ← GitHub Actions workflow (Obfusk8 + MSVC)
```

---

## Obfuscation Profiles

Three profiles control the intensity of obfuscation across all tools:

| Profile | Tigress transforms | Movfuscator flags | Obfusk8 MSVC flags |
|---|---|---|---|
| `light` | Flatten (switch) | `-m32` | `/Od` — debug, fastest compile |
| `medium` | Flatten + EncodeArithmetic + Virtualize (switch) | `-m32` | `/O1` |
| `heavy` | Flatten + EncodeArithmetic + AddOpaque + Virtualize (indirect) | `-m32 -DMOVFUSCATOR_ENTROPY` | `/O2 /GL /Oy /GS-` |

### Tigress transform details

| Transform | Effect |
|---|---|
| `Flatten` | Control flow flattening — replaces structured flow with a state machine |
| `EncodeArithmetic` | Replaces arithmetic ops with complex equivalent expressions |
| `AddOpaque` | Inserts always-true/false conditions to mislead static analysis |
| `Virtualize` | Converts code into a custom virtual machine with encrypted instructions |

### Tigress dispatch modes

| Mode | Used in | Description |
|---|---|---|
| `switch` | light, medium | Standard switch-based dispatch |
| `goto` | heavy | Goto-based dispatch, harder to decompile |
| `indirect` | heavy (Virtualize) | Indirect dispatch via function pointers |

---

## Running the Pipeline

### Full pipeline (C file → Tigress + Movfuscator)

```bash
./obfuscate_all.sh src/test_hello.c              # medium (default)
./obfuscate_all.sh src/test_hello.c light
./obfuscate_all.sh src/test_hello.c heavy
```

### Full pipeline (C++ file → Obfusk8 via GitHub Actions)

```bash
./obfuscate_all.sh src/test_hello.cpp            # medium (default)
./obfuscate_all.sh src/test_hello.cpp light
./obfuscate_all.sh src/test_hello.cpp heavy
```

The script will automatically:
1. Copy the source to `src/`
2. Commit and push to GitHub
3. Trigger the `obfusk8.yml` workflow with the selected profile
4. Wait for the run to complete (`gh run watch`)
5. Download the `.exe` artifact to `obfuscated/`

---

## Testing

### Test Tigress + Movfuscator locally

```bash
# Run from repo root
bash tests/test_local.sh              # medium (default)
bash tests/test_local.sh light
bash tests/test_local.sh heavy
```

Expected output:
```
Profile: medium

========================================
  1/2 — TIGRESS
========================================
→ Obfuscating src/test_hello.c ...
→ Compiling obfuscated output...
→ Running binary...
Hello from test_hello.c
2 + 3 = 5
[PASS] Tigress [medium]: obfuscation, compilation and output correct

========================================
  2/2 — MOVFUSCATOR
========================================
→ Compiling src/test_hello.c with movcc...
→ Running binary (timeout 120s — movfuscated binaries are very slow)...
Hello from test_hello.c
2 + 3 = 5
[PASS] Movfuscator [medium]: compilation and output correct

========================================
RESULTS
========================================
  Passed : 2
  Failed : 0
  Skipped: 0
```

> ⚠️ Movfuscator binaries are extremely slow to run — every operation is compiled
> to `mov`-only x86 instructions. Expect 30–90 seconds for the test binary to complete.
> The test has a 120 second timeout.

### Test Obfusk8 via GitHub Actions

```bash
# Trigger manually
gh workflow run obfusk8.yml --ref main --field profile=light
gh run watch
```

Expected Actions output:
```
✓ Set up job
✓ Checkout repository
✓ Cache Obfusk8 headers
✓ Clone Obfusk8 headers
✓ Verify Obfusk8 structure
✓ Set up MSVC environment
✓ Resolve compiler flags from profile
✓ Find and compile all C++ sources with Obfusk8
✓ Run obfuscated binaries (smoke test)
✓ Upload obfuscated binaries
```

Smoke test output (visible in Actions log):
```
[RUN] test_hello_obfusk8.exe
Hello from test_hello.cpp
2 + 3 = 5
[OK] test_hello_obfusk8.exe
```

### Download Obfusk8 artifact after a run

```bash
gh run download --name obfusk8-binaries-light  --dir ./obfuscated/
gh run download --name obfusk8-binaries-medium --dir ./obfuscated/
gh run download --name obfusk8-binaries-heavy  --dir ./obfuscated/
```

---

## GitHub Actions — Manual Triggers

```bash
# Trigger with a specific profile
gh workflow run obfusk8.yml --field profile=light
gh workflow run obfusk8.yml --field profile=medium
gh workflow run obfusk8.yml --field profile=heavy

# Watch the run live
gh run watch

# List recent runs
gh run list --workflow=obfusk8.yml --limit 10

# View full log of latest run
gh run view --log

# View log of a specific run
gh run view <RUN_ID> --log

# Cancel a run
gh run cancel <RUN_ID>

# Cancel the latest run
gh run cancel $(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
```

---

## GitHub Actions — Workflow Details

**File:** `.github/workflows/obfusk8.yml`

**Triggers:**
- Push to `src/**.cpp`, `src/**.cxx`, `src/**.cc`
- Manual `workflow_dispatch` with profile selector

**Steps:**
1. Checkout repository
2. Cache Obfusk8 headers (keyed on workflow file hash — avoids re-cloning)
3. Clone `https://github.com/x86byte/Obfusk8.git` to `C:\Obfusk8` if not cached
4. Verify `Obfusk8Core.hpp` is locatable
5. Set up MSVC via `microsoft/setup-msbuild@v2`
6. Resolve MSVC flags from profile into `$GITHUB_ENV`
7. Compile all `src/*.cpp` files with `cl.exe` + all Obfusk8 include paths
8. Run each compiled `.exe` via PowerShell and verify output contains `"Hello from"`
9. Upload all `.exe` files as artifact (retained 30 days)

**Include paths passed to cl.exe:**
```
C:\Obfusk8\Obfusk8\Instrumentation\materialization\state
C:\Obfusk8\Obfusk8\Instrumentation\materialization\transform
C:\Obfusk8\Obfusk8\Instrumentation\materialization
C:\Obfusk8\Obfusk8\Instrumentation
C:\Obfusk8\Obfusk8
C:\Obfusk8
```

**vcvars64.bat fallback chain:**
```
C:\Program Files\Microsoft Visual Studio\2022\Enterprise\...
C:\Program Files\Microsoft Visual Studio\2022\Community\...
C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\...
```

---

## Known Issues & Notes

| Issue | Cause | Fix applied |
|---|---|---|
| Movfuscator linker fails (`cannot find -lgcc`) | 64-bit Debian missing 32-bit libs | Install `gcc-multilib libc6-dev-i386 libgcc-s1:i386` |
| Movfuscator binary hangs | mov-only x86 is extremely slow | Use `puts` instead of `printf`, 120s timeout in test |
| `((PASS++))` kills script with `set -e` | bash treats `((0))` as false | Use `PASS=$((PASS + 1))` |
| Obfusk8 smoke test exits with code 2838+ | MSVC CRT propagates `printf` return value | Smoke test checks output content, not exit code |
| `exit(0)` causes compile error with MSVC | Conflicts with MSVC headers | Use `return 0` from `main` instead |

---

## Adding Your Own Source Files

### C file (Tigress + Movfuscator)

```bash
cp /path/to/yourfile.c src/
./obfuscate_all.sh src/yourfile.c medium
```

Outputs:
- `obfuscated/yourfile_tigress.c` — obfuscated C source
- `obfuscated/yourfile_tigress` — compiled ELF
- `obfuscated/yourfile_movfuscated` — mov-only ELF

### C++ file (Obfusk8)

Make sure your file uses `return 0` (not `exit(0)`) and include Obfusk8 headers with the correct relative path:

```cpp
// Optional — only if you want the full VM obfuscation engine
// #include "Obfusk8/Instrumentation/materialization/state/Obfusk8Core.hpp"

#include <cstdio>

int main(void) {
    // your code
    return 0;
}
```

Then:
```bash
cp /path/to/yourfile.cpp src/
./obfuscate_all.sh src/yourfile.cpp light
```

Output downloaded to: `obfuscated/yourfile_obfusk8.exe`
