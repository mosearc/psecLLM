# Obfuscation Pipeline

Automated obfuscation using three tools across two environments.

| Tool | Language | Runs on | Profile support |
|---|---|---|---|
| Tigress | C | Debian (local) | ✅ light / medium / heavy |
| Movfuscator | C (x86) | Debian (local) | ✅ light / medium / heavy |
| Obfusk8 | C++ | GitHub Actions (windows-latest) | ✅ light / medium / heavy |

---

## Setup

### 1. Install local tools (Debian)

```bash
# Tigress — download from https://tigress.wtf, extract and add to PATH:
export TIGRESS_HOME=/path/to/tigress
export PATH=$TIGRESS_HOME:$PATH

# Movfuscator
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y git gcc nasm gcc-multilib libc6-dev-i386 libgcc-s1:i386
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

## Profiles

| Profile | Tigress transforms | Movfuscator | Obfusk8 MSVC flags |
|---|---|---|---|
| `light` | Flatten | -m32 | /Od (debug, fastest compile) |
| `medium` | Flatten + EncodeArithmetic + Virtualize | -m32 | /O1 |
| `heavy` | Flatten + EncodeArithmetic + AddOpaque + Virtualize (indirect) | -m32 -DMOVFUSCATOR_ENTROPY | /O2 /GL /Oy /GS- |

---

## Usage

### Run the full pipeline

```bash
# C file — Tigress + Movfuscator locally
./obfuscate_all.sh src/test_hello.c           # medium (default)
./obfuscate_all.sh src/test_hello.c light
./obfuscate_all.sh src/test_hello.c heavy

# C++ file — Obfusk8 via GitHub Actions
./obfuscate_all.sh src/test_hello.cpp
./obfuscate_all.sh src/test_hello.cpp heavy
```

### Test locally (Tigress + Movfuscator only)

```bash
bash tests/test_local.sh           # medium (default)
bash tests/test_local.sh light
bash tests/test_local.sh heavy
```

### Trigger Obfusk8 manually with a profile

```bash
gh workflow run obfusk8.yml --field profile=heavy
gh run watch
```

### Download the latest Obfusk8 artifact

```bash
gh run download --name obfusk8-binaries-medium --dir ./obfuscated/
```

---

## Project Structure

```
obfuscation-pipeline/
├── src/
│   ├── test_hello.c       ← test file for Tigress + Movfuscator
│   └── test_hello.cpp     ← test file for Obfusk8
├── obfuscated/            ← all output files land here
│   ├── test_hello_tigress.c
│   ├── test_hello_tigress          (ELF — runs on Debian)
│   ├── test_hello_movfuscated      (ELF — runs on Debian)
│   └── test_hello_obfusk8.exe      (PE  — runs on Windows)
├── tests/
│   └── test_local.sh      ← local test runner (Tigress + Movfuscator)
├── .github/
│   └── workflows/
│       └── obfusk8.yml    ← GitHub Actions workflow (Obfusk8)
└── obfuscate_all.sh       ← master pipeline script
```
