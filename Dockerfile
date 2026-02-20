# psecLLM Obfuscation Pipeline
# Debian Bookworm base — matches production environment
FROM debian:bookworm-slim

LABEL description="psecLLM obfuscation pipeline: Tigress + Movfuscator + CObfuscator + Kovid"

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    # build essentials
    git wget curl gnupg cmake ninja-build \
    build-essential gcc g++ nasm \
    # 32-bit support for Movfuscator
    gcc-multilib \
    # Movfuscator runtime deps
    libc6-dev-i386 libgcc-s1:i386 \
    # Python
    python3 python3-pip python3.11-dev \
    # GCC plugin support for Kovid
    gcc-12-plugin-dev g++-12 \
    # misc
    pkg-config libssl-dev zlib1g-dev libgc-dev \
    libcjson-dev libunwind-dev \
    && rm -rf /var/lib/apt/lists/*

# ── 32-bit architecture (Movfuscator) ─────────────────────────────────────────
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y libc6:i386 libgcc-s1:i386 \
    && rm -rf /var/lib/apt/lists/*

# ── LLVM 19 (Kovid) ───────────────────────────────────────────────────────────
RUN mkdir -p /etc/apt/keyrings \
    && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key \
       | gpg --dearmor \
       | tee /etc/apt/keyrings/llvm.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/llvm.gpg] http://apt.llvm.org/bookworm/ llvm-toolchain-bookworm-19 main" \
       > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y \
        llvm-19-dev clang-19 libclang-19-dev \
        lld-19 liblldb-19-dev \
    && rm -rf /var/lib/apt/lists/*

# ── lit (Kovid test runner) ───────────────────────────────────────────────────
RUN pip3 install lit --break-system-packages \
    && ln -sf /root/.local/bin/lit /usr/bin/llvm-lit

# ── Movfuscator ───────────────────────────────────────────────────────────────
RUN git clone https://github.com/xoreaxeaxeax/movfuscator.git /tmp/movfuscator \
    && cd /tmp/movfuscator \
    && ./build.sh \
    && ./install.sh \
    && rm -rf /tmp/movfuscator

# ── CObfuscator ───────────────────────────────────────────────────────────────
RUN git clone https://github.com/AleksaZatezalo/CObfuscator.git /opt/CObfuscator

# ── Kovid — build from source ─────────────────────────────────────────────────
RUN git clone https://github.com/djolertrk/kovid-obfuscation-passes.git /tmp/kovid \
    && mkdir /tmp/kovid/build_plugin \
    && cd /tmp/kovid/build_plugin \
    && cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_DIR=/usr/lib/llvm-19/lib/cmake/llvm \
        -GNinja \
    && ninja \
    && cp lib/*.so /usr/local/lib/ \
    && cp bin/kovid-deobfuscator /usr/local/bin/ \
    && ldconfig \
    && rm -rf /tmp/kovid

# ── Tigress ───────────────────────────────────────────────────────────────────
# Tigress cannot be downloaded automatically (requires license registration).
# Copy your local install into the image at build time.
# Run: docker build --build-arg TIGRESS_SRC=/usr/local/bin/tigress ...
# Or just COPY if tigress is in the build context.
COPY tigress/ /usr/local/bin/tigress/
ENV TIGRESS_HOME=/usr/local/bin/tigress
ENV PATH="${TIGRESS_HOME}:${PATH}"

# ── GitHub CLI ────────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | tee /etc/apt/keyrings/githubcli.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# ── Workspace ─────────────────────────────────────────────────────────────────
WORKDIR /workspace

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
