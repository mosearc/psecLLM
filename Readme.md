# Obfuscation Pipeline

Automated obfuscation using three tools across two environments.

| Tool | Language | Runs on |
|---|---|---|
| Tigress | C | Debian (local) |
| Movfuscator | C (x86) | Debian (local) |
| Obfusk8 | C++ | GitHub Actions (windows-latest) |

## Setup

### 1. Install local tools (Debian)

```bash
# Tigress — download from https://tigress.wtf and add to PATH
# Movfuscator
sudo apt install -y git gcc nasm
git clone https://github.com/xoreaxeaxeax/movfuscator.git
cd movfuscator && ./build.sh && sudo ./install.sh && cd ..

# GitHub CLI
sudo apt install -y gh
gh auth login
```

### 2. Push this repo to GitHub

```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

### 3. Make scripts executable

```bash
chmod +x obfuscate_all.sh tests/test_local.sh
```

---

## Testing

### Test Tigress + Movfuscator locally

```bash
bash tests/test_local.sh
```

Expected output:
```
========================================
  1/2 — TIGRESS
========================================
→ Obfuscating src/test_hello.c ...
→ Compiling obfuscated output...
→ Running binary...
Hello from test_hello.c
2 + 3 = 5
[PASS] Tigress: obfuscation, compilation and output correct

========================================
  2/2 — MOVFUSCATOR
========================================
→ Compiling src/test_hello.c with movcc...
→ Running binary...
Hello from test_hello.c
2 + 3 = 5
[PASS] Movfuscator: compilation and output correct

========================================
RESULTS
========================================
  Passed: 2
  Failed: 0
  Skipped: 0
```

### Test Obfusk8 via GitHub Actions

Push the included C++ test file:

```bash
./obfuscate_all.sh src/test_hello.cpp
```

This will:
1. Push `src/test_hello.cpp` to GitHub
2. Trigger the `obfusk8.yml` workflow on `windows-latest`
3. MSVC compiles the file with Obfusk8 headers included
4. The workflow runs the binary as a smoke test
5. The `.exe` artifact is downloaded back to `obfuscated/`

You can also monitor runs at:
```
https://github.com/YOUR_USERNAME/YOUR_REPO/actions
```

Or via CLI:
```bash
gh run list --repo YOUR_USERNAME/YOUR_REPO
gh run view --log   # view latest run logs
```

---

## Running the Full Pipeline

```bash
# For a C file (Tigress + Movfuscator)
./obfuscate_all.sh src/test_hello.c

# For a C++ file (Obfusk8 via GitHub Actions)
./obfuscate_all.sh src/test_hello.cpp
```

## Project Structure

```
obfuscation-pipeline/
├── src/
│   ├── test_hello.c       ← test file for Tigress + Movfuscator
│   └── test_hello.cpp     ← test file for Obfusk8
├── obfuscated/            ← all output files land here
├── tests/
│   └── test_local.sh      ← local test runner (Tigress + Movfuscator)
├── .github/
│   └── workflows/
│       └── obfusk8.yml    ← GitHub Actions workflow (Obfusk8)
└── obfuscate_all.sh       ← master pipeline script
```
