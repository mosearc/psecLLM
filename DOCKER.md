# psecLLM — Docker Setup

Portable obfuscation pipeline container running Tigress, Movfuscator, CObfuscator
and Kovid on any machine without manual dependency installation.

> Obfusk8 is **not** included in the container — it requires Windows + MSVC and
> runs on GitHub Actions. The container includes the GitHub CLI (`gh`) so you can
> still trigger and download Obfusk8 builds from inside the container.

---

## What's Inside the Image

| Tool | Version | Source |
|---|---|---|
| Tigress | 4.0.11 | Copied from your local install at build time |
| Movfuscator | latest | Built from source (github.com/xoreaxeaxeax/movfuscator) |
| CObfuscator | latest | Cloned from source (github.com/AleksaZatezalo/CObfuscator) |
| Kovid LLVM passes | latest | Built from source (github.com/djolertrk/kovid-obfuscation-passes) |
| LLVM / Clang | 19 | apt.llvm.org |
| GitHub CLI | latest | cli.github.com |
| Python | 3.11 | Debian bookworm |
| Base OS | Debian bookworm-slim | — |

---

## Prerequisites

On the **host machine** (the machine you are building the image on):

```bash
# Docker
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # log out and back in after this

# Verify
docker --version
```

Tigress must already be installed locally at `/usr/local/bin/tigress`.
If not, register and download from https://tigress.wtf first.

---

## Directory Structure (Docker-related files)

```
psecLLM/
├── Dockerfile                 ← image definition
├── docker-entrypoint.sh       ← runs tests on startup, then opens shell
├── docker-build.sh            ← helper script to build the image
└── .dockerignore              ← excludes .git, obfuscated/, cache files
```

---

## Building the Image

The build script handles everything including copying Tigress into the
build context (it cleans up after itself):

```bash
cd ~/psecLLM
chmod +x docker-build.sh
./docker-build.sh
```

Expected output:
```
[*] psecLLM Docker build

[*] Copying Tigress from /usr/local/bin/tigress...
  ✓ Tigress copied to build context

[*] Building Docker image (this will take 10-15 minutes)...
    Kovid LLVM passes are built from source inside the image.

...

[✓] Image built: psecllm-obfuscator
```

> ⚠️ The build takes 10–15 minutes because Kovid is compiled from source
> inside the image (LLVM plugin compilation is slow). This only happens once.

---

## Running the Container

### Basic run (medium profile)

```bash
docker run -it \
  -v ~/psecLLM:/workspace \
  -v ~/.config/gh:/root/.config/gh \
  psecllm-obfuscator
```

### Run with a specific profile

```bash
docker run -it \
  -e PROFILE=light \
  -v ~/psecLLM:/workspace \
  -v ~/.config/gh:/root/.config/gh \
  psecllm-obfuscator

docker run -it \
  -e PROFILE=heavy \
  -v ~/psecLLM:/workspace \
  -v ~/.config/gh:/root/.config/gh \
  psecllm-obfuscator
```

### What happens on startup

```
================================================
   psecLLM Obfuscation Pipeline
================================================

[*] Checking installed tools...
  ✓ tigress
  ✓ movcc
  ✓ clang-19
  ✓ opt-19
  ✓ gh
  ✓ CObfuscator
  ✓ kovid: RenameCode
  ✓ kovid: DummyCodeInsertion
  ✓ kovid: RemoveMetadataAndUnusedCode
  ✓ kovid: InstructionObfuscationPass
  ✓ kovid: StringEncryption
  ✓ kovid: ControlFlowTaint

[*] Running test suite (profile: medium)...

  ... test output ...

[✓] All tests passed. Dropping into shell.

root@container:/workspace#
```

The container drops into a bash shell after the tests — whether they pass or fail —
so you can debug or run the pipeline manually.

---

## Using the Pipeline Inside the Container

The repo is mounted at `/workspace` so all commands are identical to running
locally. Any output files written to `obfuscated/` are immediately visible
on your host at `~/psecLLM/obfuscated/`.

```bash
# Inside the container

# Obfuscate a C file
./obfuscate_all.sh src/test_hello.c medium

# Obfuscate a C++ file (triggers GitHub Actions for Obfusk8)
./obfuscate_all.sh src/test_hello.cpp light

# Run tests manually
bash tests/test_local.sh
bash tests/test_local.sh heavy

# Trigger Obfusk8 on GitHub Actions
gh workflow run obfusk8.yml --ref main --field profile=medium
gh run watch
gh run download --name obfusk8-binaries-medium --dir ./obfuscated/
```

---

## GitHub CLI Authentication Inside the Container

The `-v ~/.config/gh:/root/.config/gh` mount forwards your existing `gh` login
into the container. If you haven't authenticated yet on the host:

```bash
# On the host machine first
gh auth login

# Then run the container — authentication is automatically available inside
```

If you need to re-authenticate from inside the container:

```bash
# Inside the container
gh auth login
# Follow the prompts — the token is saved to /root/.config/gh
# which is mounted back to ~/.config/gh on your host
```

---

## Transferring the Image to Another Machine

### Option A — Docker Hub (easiest)

```bash
# On source machine
docker tag psecllm-obfuscator yourdockerhubuser/psecllm-obfuscator
docker push yourdockerhubuser/psecllm-obfuscator

# On target machine
docker pull yourdockerhubuser/psecllm-obfuscator
docker run -it \
  -v ~/psecLLM:/workspace \
  -v ~/.config/gh:/root/.config/gh \
  yourdockerhubuser/psecllm-obfuscator
```

### Option B — Export/import as tar (air-gapped machines)

```bash
# On source machine
docker save psecllm-obfuscator | gzip > psecllm-obfuscator.tar.gz
# Transfer the file to target machine (scp, USB, etc.)

# On target machine
docker load < psecllm-obfuscator.tar.gz
docker run -it \
  -v ~/psecLLM:/workspace \
  -v ~/.config/gh:/root/.config/gh \
  psecllm-obfuscator
```

### Option C — Rebuild on target machine

```bash
# On target machine — clone the repo and rebuild
git clone https://github.com/mosearc/psecLLM.git
cd psecLLM
./docker-build.sh   # requires Tigress installed at /usr/local/bin/tigress
```

---

## Useful Docker Commands

```bash
# List images
docker images | grep psecllm

# Remove image (to force a full rebuild)
docker rmi psecllm-obfuscator

# Rebuild from scratch (no cache)
docker build --no-cache -t psecllm-obfuscator .

# Run without auto-test (just open a shell)
docker run -it \
  -v ~/psecLLM:/workspace \
  -v ~/.config/gh:/root/.config/gh \
  --entrypoint bash \
  psecllm-obfuscator

# Run a single command and exit
docker run --rm \
  -v ~/psecLLM:/workspace \
  psecllm-obfuscator \
  bash tests/test_local.sh light

# Check image size
docker image inspect psecllm-obfuscator --format='{{.Size}}' | numfmt --to=iec
```

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| `COPY tigress/ failed` | Tigress not found at `/usr/local/bin/tigress` | Install Tigress first from https://tigress.wtf |
| `permission denied` on docker commands | User not in docker group | `sudo usermod -aG docker $USER` then log out/in |
| `gh: not logged in` inside container | No `~/.config/gh` on host | Run `gh auth login` on host first |
| Kovid build fails during `docker build` | LLVM 19 repo unreachable | Check network, retry build |
| `/workspace does not look like a psecLLM repo` | Forgot `-v` mount | Add `-v ~/psecLLM:/workspace` to docker run |
| Tests skip all tools | Wrong working directory | Container runs from `/workspace` — make sure repo is mounted there |
| Image is very large (~4–5 GB) | LLVM dev packages + build artifacts | Expected — LLVM is large. Use Option B (tar export) to transfer |
