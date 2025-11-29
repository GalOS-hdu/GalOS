# GalOS Development Environment
# Multi-stage build for optimized image size

# Stage 1: Build QEMU from source (needed for LoongArch64)
FROM ubuntu:24.04 AS qemu-builder

ARG QEMU_VERSION=10.1.2

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    ninja-build \
    python3 \
    python3-pip \
    pkg-config \
    libglib2.0-dev \
    libpixman-1-dev \
    libslirp-dev \
    libfdt-dev \
    git \
    flex \
    bison \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download and build QEMU
WORKDIR /tmp/qemu-build
RUN wget https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz && \
    tar xf qemu-${QEMU_VERSION}.tar.xz && \
    cd qemu-${QEMU_VERSION} && \
    ./configure \
        --prefix=/opt/qemu \
        --target-list=x86_64-softmmu,riscv64-softmmu,aarch64-softmmu,loongarch64-softmmu \
        --enable-kvm \
        --enable-slirp \
        --disable-docs && \
    make -j$(nproc) && \
    make install

# Stage 2: Download and prepare Musl toolchain
FROM ubuntu:24.04 AS musl-downloader

ARG MUSL_TOOLCHAIN_VERSION=20241227
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/musl
# Download RISC-V 64 Musl toolchain
RUN wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/riscv64-linux-musl-cross.tgz && \
    mkdir -p /opt/musl-toolchains && \
    tar -xzf riscv64-linux-musl-cross.tgz -C /opt/musl-toolchains/

# Stage 3: Final development environment
FROM ubuntu:24.04

LABEL maintainer="GalOS Team"
LABEL description="GalOS Development Environment with Rust, QEMU 10+, and Musl toolchains"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/opt/qemu/bin:/opt/musl-toolchains/riscv64-linux-musl-cross/bin:$CARGO_HOME/bin:$PATH

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    cmake \
    clang \
    llvm \
    lld \
    # Version control
    git \
    # Network tools
    curl \
    wget \
    # Compression tools
    xz-utils \
    # Python
    python3 \
    python3-pip \
    # QEMU runtime dependencies
    libglib2.0-0 \
    libpixman-1-0 \
    libfdt1 \
    libslirp0 \
    # Additional utilities
    sudo \
    vim \
    tmux \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Copy QEMU from builder stage
COPY --from=qemu-builder /opt/qemu /opt/qemu

# Copy Musl toolchains from downloader stage
COPY --from=musl-downloader /opt/musl-toolchains /opt/musl-toolchains

# Install Rust using rustup
ARG RUST_VERSION=nightly-2025-05-20
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain ${RUST_VERSION} \
    --profile minimal \
    --component rust-src,llvm-tools,rustfmt,clippy

# Add Rust target platforms
RUN rustup target add \
    x86_64-unknown-none \
    riscv64gc-unknown-none-elf \
    aarch64-unknown-none-softfloat \
    loongarch64-unknown-none-softfloat

# Install required Cargo tools
RUN cargo install cargo-axplat --version 0.2.2 && \
    cargo install axconfig-gen --version 0.2.0 && \
    cargo install cargo-binutils --version 0.4.0

# Create a non-root user for development
ARG USERNAME=starry
ARG USER_UID=1001
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1) && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME 2>/dev/null || usermod -l $USERNAME -d /home/$USERNAME -m $(getent passwd $USER_UID | cut -d: -f1) && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up workspace and cargo permissions
RUN mkdir -p /workspace && \
    chown -R $USERNAME:$USERNAME /workspace /usr/local/cargo /usr/local/rustup

# Verify installations
RUN echo "===== Environment Info =====" && \
    echo "Rust: $(rustc --version)" && \
    echo "Cargo: $(cargo --version)" && \
    echo "QEMU: $(qemu-system-riscv64 --version | head -1)" && \
    echo "QEMU LoongArch: $(qemu-system-loongarch64 --version | head -1)" && \
    echo "Musl GCC: $(riscv64-linux-musl-gcc --version | head -1)" && \
    echo "CMake: $(cmake --version | head -1)" && \
    echo "Clang: $(clang --version | head -1)" && \
    echo "============================"

# Switch to non-root user
USER $USERNAME
WORKDIR /workspace

# Set environment variables for the user
ENV PATH=/opt/qemu/bin:/opt/musl-toolchains/riscv64-linux-musl-cross/bin:$CARGO_HOME/bin:$PATH

CMD ["/bin/bash"]
