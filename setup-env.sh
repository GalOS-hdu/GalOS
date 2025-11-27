#!/bin/bash
# GalOS Environment Setup Script
# This script helps set up the development environment for StarryOS

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  GalOS Environment Setup${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to print colored messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in Docker
if [ -f /.dockerenv ]; then
    info "Running inside Docker container"
    info "Environment is already configured!"
    echo ""
    echo -e "${GREEN}You can now:${NC}"
    echo "  1. Build: make build"
    echo "  2. Prepare rootfs: make img"
    echo "  3. Run: make run"
    exit 0
fi

# Main menu
echo "Please select your setup option:"
echo ""
echo "  1) Use Docker (Recommended)"
echo "  2) Install on Ubuntu/Debian (Native)"
echo "  3) Check current environment"
echo "  4) Exit"
echo ""
read -p "Enter your choice [1-4]: " choice

case $choice in
    1)
        info "Setting up Docker environment..."
        echo ""

        # Check if Docker is installed
        if ! command -v docker &> /dev/null; then
            error "Docker is not installed!"
            echo "Please install Docker first:"
            echo "  https://docs.docker.com/get-docker/"
            exit 1
        fi

        # Check if docker-compose is installed
        if ! command -v docker-compose &> /dev/null; then
            warning "docker-compose is not installed!"
            echo "Trying to use 'docker compose' (v2)..."
            if ! docker compose version &> /dev/null; then
                error "Docker Compose is not available!"
                echo "Please install Docker Compose:"
                echo "  https://docs.docker.com/compose/install/"
                exit 1
            fi
            COMPOSE_CMD="docker compose"
        else
            COMPOSE_CMD="docker-compose"
        fi

        success "Docker is available"

        # Build Docker image
        info "Building Docker image (this may take 20-40 minutes for first build)..."
        $COMPOSE_CMD build

        success "Docker image built successfully!"
        echo ""
        echo -e "${GREEN}Next steps:${NC}"
        echo "  1. Start container: $COMPOSE_CMD run --rm galos-dev"
        echo "  2. Inside container, run: make build && make img && make run"
        echo ""
        echo "For more information, see: docs/docker-guide.md"
        ;;

    2)
        info "Setting up native environment on Ubuntu/Debian..."
        echo ""

        warning "Note: This will install QEMU from system packages, which may NOT support LoongArch64."
        warning "For LoongArch64 support, you need to compile QEMU 10+ from source or use Docker."
        echo ""
        read -p "Continue with native setup? [y/N]: " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Setup cancelled"
            exit 0
        fi

        # Update system
        info "Updating system packages..."
        sudo apt update

        # Install system dependencies
        info "Installing system dependencies..."
        sudo apt install -y \
            build-essential cmake clang llvm lld \
            git curl xz-utils python3 \
            qemu-system

        success "System dependencies installed"

        # Install Rust
        info "Installing Rust nightly-2025-05-20..."
        if command -v rustup &> /dev/null; then
            info "rustup already installed, updating toolchain..."
            rustup toolchain install nightly-2025-05-20 \
                --profile minimal \
                --component rust-src,llvm-tools,rustfmt,clippy
            rustup default nightly-2025-05-20
        else
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
                -y --default-toolchain nightly-2025-05-20 \
                --profile minimal \
                --component rust-src,llvm-tools,rustfmt,clippy
            source $HOME/.cargo/env
        fi

        success "Rust installed"

        # Add Rust targets
        info "Adding Rust target platforms..."
        rustup target add x86_64-unknown-none
        rustup target add riscv64gc-unknown-none-elf
        rustup target add aarch64-unknown-none-softfloat
        rustup target add loongarch64-unknown-none-softfloat

        success "Rust targets added"

        # Install Cargo tools
        info "Installing Cargo tools (this may take a few minutes)..."
        cargo install cargo-axplat --version 0.2.2 || warning "cargo-axplat installation failed"
        cargo install axconfig-gen --version 0.2.0 || warning "axconfig-gen installation failed"
        cargo install cargo-binutils --version 0.4.0 || warning "cargo-binutils installation failed"

        success "Cargo tools installed"

        # Download Musl toolchain
        info "Downloading RISC-V Musl toolchain..."
        cd /tmp
        wget -q --show-progress https://github.com/arceos-org/setup-musl/releases/download/prebuilt/riscv64-linux-musl-cross.tgz

        info "Extracting Musl toolchain to /opt..."
        sudo mkdir -p /opt
        sudo tar -xzf riscv64-linux-musl-cross.tgz -C /opt/

        # Add to PATH
        if ! grep -q "/opt/riscv64-linux-musl-cross/bin" ~/.bashrc; then
            echo 'export PATH=/opt/riscv64-linux-musl-cross/bin:$PATH' >> ~/.bashrc
        fi

        success "Musl toolchain installed"

        echo ""
        success "Native environment setup complete!"
        echo ""
        echo -e "${GREEN}Next steps:${NC}"
        echo "  1. Reload shell: source ~/.bashrc"
        echo "  2. Verify: rustc --version && qemu-system-riscv64 --version"
        echo "  3. Build: make build"
        echo "  4. Prepare rootfs: make img"
        echo "  5. Run: make run"
        echo ""
        warning "Remember: System QEMU may not support LoongArch64."
        echo "  For LoongArch64 support, compile QEMU 10+ from source or use Docker."
        echo "  See: docs/environment-requirements.md"
        ;;

    3)
        info "Checking current environment..."
        echo ""

        # Check Rust
        echo -e "${BLUE}=== Rust Toolchain ===${NC}"
        if command -v rustc &> /dev/null; then
            rustc --version
            rustup show | grep -E "(active toolchain|installed targets)" || true
            success "Rust is installed"
        else
            error "Rust is not installed"
        fi
        echo ""

        # Check Cargo tools
        echo -e "${BLUE}=== Cargo Tools ===${NC}"
        if command -v cargo &> /dev/null; then
            cargo axplat --version 2>/dev/null && success "cargo-axplat OK" || warning "cargo-axplat not found"
            axconfig-gen --version 2>/dev/null && success "axconfig-gen OK" || warning "axconfig-gen not found"
            cargo install --list | grep cargo-binutils &>/dev/null && success "cargo-binutils OK" || warning "cargo-binutils not found"
        else
            error "Cargo is not installed"
        fi
        echo ""

        # Check system tools
        echo -e "${BLUE}=== System Tools ===${NC}"
        command -v gcc &> /dev/null && gcc --version | head -1 || warning "gcc not found"
        command -v clang &> /dev/null && clang --version | head -1 || warning "clang not found"
        command -v cmake &> /dev/null && cmake --version | head -1 || warning "cmake not found"
        command -v make &> /dev/null && echo "make: $(make --version | head -1)" || warning "make not found"
        command -v git &> /dev/null && git --version || warning "git not found"
        command -v python3 &> /dev/null && python3 --version || warning "python3 not found"
        echo ""

        # Check QEMU
        echo -e "${BLUE}=== QEMU ===${NC}"
        if command -v qemu-system-riscv64 &> /dev/null; then
            qemu-system-riscv64 --version | head -1
            QEMU_VERSION=$(qemu-system-riscv64 --version | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1)
            QEMU_MAJOR=$(echo $QEMU_VERSION | cut -d. -f1)
            if [ "$QEMU_MAJOR" -ge 10 ]; then
                success "QEMU version $QEMU_VERSION supports all architectures including LoongArch64"
            else
                warning "QEMU version $QEMU_VERSION may not support LoongArch64 (requires 10+)"
            fi
        else
            error "QEMU is not installed"
        fi

        command -v qemu-system-loongarch64 &> /dev/null && echo "LoongArch64: OK" || warning "LoongArch64 support not available"
        echo ""

        # Check Musl toolchain
        echo -e "${BLUE}=== Musl Toolchain ===${NC}"
        if command -v riscv64-linux-musl-gcc &> /dev/null; then
            riscv64-linux-musl-gcc --version | head -1
            success "RISC-V Musl toolchain is installed"
        else
            error "RISC-V Musl toolchain is not installed"
        fi
        echo ""

        # Summary
        echo -e "${BLUE}=== Summary ===${NC}"
        ALL_OK=true

        command -v rustc &> /dev/null || ALL_OK=false
        command -v cargo &> /dev/null || ALL_OK=false
        command -v qemu-system-riscv64 &> /dev/null || ALL_OK=false
        command -v riscv64-linux-musl-gcc &> /dev/null || ALL_OK=false

        if [ "$ALL_OK" = true ]; then
            success "Environment looks good! You can start building StarryOS."
            echo ""
            echo "Run: make build && make img && make run"
        else
            warning "Some dependencies are missing. Please run option 1 or 2 to set up the environment."
        fi
        ;;

    4)
        info "Exiting..."
        exit 0
        ;;

    *)
        error "Invalid choice"
        exit 1
        ;;
esac
