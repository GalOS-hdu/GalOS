# GalOS 开发环境依赖清单

本文档详细列出 GalOS 项目所需的所有开发和测试环境依赖，以确保团队成员环境统一。

## 📋 依赖概览

| 类别 | 组件数量 | 关键版本 |
|------|----------|----------|
| Rust 工具链 | 1 个工具链 + 4 个目标平台 | nightly-2025-05-20 |
| Cargo 工具 | 3 个 | 特定版本 |
| 系统工具 | 7+ 个 | 推荐版本 |
| 交叉编译工具链 | 1+ 个 | GCC 11.2.1+ |
| 虚拟机/模拟器 | QEMU (4 架构) | **10.0+（LoongArch64 要求）** |

---

## 🔧 详细依赖清单

### 1. Rust 工具链

#### 核心工具链
- **版本**：`nightly-2025-05-20`
- **Profile**：`minimal`
- **安装方式**：通过 `rustup` 安装
- **配置文件**：`rust-toolchain.toml`

```toml
[toolchain]
profile = "minimal"
channel = "nightly-2025-05-20"
```

#### 必需组件
| 组件 | 用途 | 是否必需 |
|------|------|----------|
| `rust-src` | 提供标准库源码，用于裸机目标编译 | ✅ 必需 |
| `llvm-tools` | 提供 `rust-objdump`、`rust-objcopy` 等工具 | ✅ 必需 |
| `rustfmt` | 代码格式化 | ✅ 必需 |
| `clippy` | 静态代码分析 | ✅ 必需 |

#### 目标平台（Targets）
| 目标平台 | 架构 | 用途 |
|---------|------|------|
| `x86_64-unknown-none` | x86_64 裸机 | x86_64 架构支持 |
| `riscv64gc-unknown-none-elf` | RISC-V 64 裸机 | RISC-V 64 架构支持（主要目标） |
| `aarch64-unknown-none-softfloat` | ARM64 裸机 | AArch64 架构支持 |
| `loongarch64-unknown-none-softfloat` | LoongArch64 裸机 | 龙芯架构支持 |

**安装命令**：
```bash
rustup target add x86_64-unknown-none
rustup target add riscv64gc-unknown-none-elf
rustup target add aarch64-unknown-none-softfloat
rustup target add loongarch64-unknown-none-softfloat
```

---

### 2. Cargo 工具

以下工具通过 `cargo install` 安装，版本需严格匹配：

| 工具 | 版本 | 用途 | 安装命令 |
|------|------|------|----------|
| `cargo-axplat` | **v0.2.2** | 解析目标平台包信息 | `cargo install cargo-axplat --version 0.2.2` |
| `axconfig-gen` | **v0.2.0** | 生成平台配置文件 | `cargo install axconfig-gen --version 0.2.0` |
| `cargo-binutils` | **v0.4.0** | Cargo 二进制工具集（提供 `rust-objdump`、`rust-objcopy`） | `cargo install cargo-binutils --version 0.4.0` |

**说明**：
- 这些工具由 `arceos/scripts/make/deps.mk` 在构建时自动检查和安装
- 版本不匹配可能导致构建失败或运行时错误

---

### 3. 系统构建工具

#### 编译器工具链

| 工具 | 最低版本 | 推荐版本 | 用途 |
|------|----------|----------|------|
| **GCC** | 9.0 | 11.2.1+ | C/C++ 编译器 |
| **Clang** | 14.0 | **18.1.3+** | C/C++ 编译器（LLVM 前端） |
| **LLVM/LLD** | 14.0 | 18.1.3+ | LLVM 工具链和链接器 |

**安装（Ubuntu/Debian）**：
```bash
sudo apt install build-essential clang llvm lld
```

#### 构建系统

| 工具 | 最低版本 | 推荐版本 | 用途 |
|------|----------|----------|------|
| **Make** | GNU Make 4.0+ | 4.3+ | 构建系统 |
| **CMake** | 3.20 | **3.28.3+** | 跨平台构建工具（QEMU 编译需要） |

**安装**：
```bash
sudo apt install make cmake
```

#### 其他必需工具

| 工具 | 最低版本 | 用途 | 安装命令 |
|------|----------|------|----------|
| **Git** | 2.40 | 版本控制、子模块管理 | `sudo apt install git` |
| **curl** | 7.68+ | 下载依赖和 rootfs | `sudo apt install curl` |
| **xz-utils** | 5.2+ | 解压 rootfs 镜像 | `sudo apt install xz-utils` |
| **Python 3** | 3.10+ | 运行测试脚本 (`ci-test.py`) | `sudo apt install python3` |

---

### 4. 交叉编译工具链（Musl）

GalOS 使用 Musl C 库进行交叉编译，需要安装以下工具链：

#### RISC-V 64 Musl 工具链（必需）

| 属性 | 值 |
|------|-----|
| **工具链名称** | `riscv64-linux-musl-cross` |
| **GCC 版本** | **11.2.1** |
| **C 库** | Musl |
| **下载地址** | [arceos-org/setup-musl/releases](https://github.com/arceos-org/setup-musl/releases/tag/prebuilt) |
| **安装路径** | `/opt/riscv64-linux-musl-cross` 或自定义 |
| **环境变量** | `export PATH=/opt/riscv64-linux-musl-cross/bin:$PATH` |

**安装步骤**：
```bash
# 1. 下载工具链
cd /tmp
wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/riscv64-linux-musl-cross.tgz

# 2. 解压到安装目录
sudo mkdir -p /opt
sudo tar -xzf riscv64-linux-musl-cross.tgz -C /opt/

# 3. 添加到 PATH
echo 'export PATH=/opt/riscv64-linux-musl-cross/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# 4. 验证安装
riscv64-linux-musl-gcc --version
```

#### 其他架构工具链（可选）

如果需要为其他架构编译 C 应用，可以安装对应的 Musl 工具链：

| 架构 | 工具链名称 | 是否必需 |
|------|-----------|----------|
| LoongArch64 | `loongarch64-linux-musl-cross` | 可选 |
| AArch64 | `aarch64-linux-musl-cross` | 可选 |
| x86_64 | `x86_64-linux-musl-cross` | 可选 |

---

### 5. QEMU 虚拟机（关键依赖）

#### ⚠️ 版本要求（非常重要）

| 架构 | 最低 QEMU 版本 | 推荐版本 | 说明 |
|------|----------------|----------|------|
| **LoongArch64** | **10.0** | **10.2.0+** | ❗ **严格要求**，低版本不支持 |
| RISC-V 64 | 6.0 | 8.2.0+ | 推荐使用较新版本 |
| x86_64 | 6.0 | 8.2.0+ | 推荐使用较新版本 |
| AArch64 | 6.0 | 8.2.0+ | 推荐使用较新版本 |

#### 所需 QEMU 组件

| 组件 | 用途 |
|------|------|
| `qemu-system-x86_64` | x86_64 架构模拟 |
| `qemu-system-riscv64` | RISC-V 64 架构模拟 |
| `qemu-system-aarch64` | AArch64 架构模拟 |
| `qemu-system-loongarch64` | LoongArch64 架构模拟 |

#### 📦 安装方式

##### 方式一：系统包管理器（仅适用于非 LoongArch64）

**Ubuntu 24.04（QEMU 8.2.2）**：
```bash
sudo apt update
sudo apt install qemu-system
```

⚠️ **限制**：Ubuntu 24.04 默认 QEMU 版本为 8.2.2，**不支持 LoongArch64**。

##### 方式二：从源码编译（推荐，支持所有架构）

```bash
# 1. 安装编译依赖
sudo apt update
sudo apt install -y \
    build-essential \
    ninja-build \
    python3 \
    python3-pip \
    pkg-config \
    libglib2.0-dev \
    libpixman-1-dev \
    flex \
    bison \
    wget

# 2. 下载 QEMU 源码
cd /tmp
wget https://download.qemu.org/qemu-10.2.0.tar.xz
tar xf qemu-10.2.0.tar.xz
cd qemu-10.2.0

# 3. 配置构建（仅构建所需架构）
./configure \
    --prefix=/opt/qemu \
    --target-list=x86_64-softmmu,riscv64-softmmu,aarch64-softmmu,loongarch64-softmmu \
    --enable-kvm \
    --enable-slirp \
    --disable-docs

# 4. 编译并安装
make -j$(nproc)
sudo make install

# 5. 添加到 PATH
echo 'export PATH=/opt/qemu/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# 6. 验证安装
qemu-system-riscv64 --version
qemu-system-loongarch64 --version
```

**说明**：
- `--target-list` 指定仅构建所需架构，减少编译时间
- `--enable-kvm` 启用 KVM 硬件加速（Linux 宿主机）
- `--prefix=/opt/qemu` 安装到自定义路径，避免与系统 QEMU 冲突

##### 方式三：使用 Docker（最简单，推荐）

使用项目提供的 `Dockerfile`，已包含 QEMU 10.2.0：

```bash
docker-compose build
docker-compose run --rm galos-dev
```

参见 [Docker 开发环境指南](./docker-guide.md)。

---

### 6. Rootfs 文件系统

GalOS 需要一个包含 BusyBox 的根文件系统镜像。

| 属性 | 值 |
|------|-----|
| **格式** | `.img` (ext4 文件系统) |
| **来源** | [Starry-OS/rootfs Releases](https://github.com/Starry-OS/rootfs/releases) |
| **镜像版本** | 20250917 |
| **下载方式** | `make img` 自动下载 |

**手动下载**：
```bash
# RISC-V 64
curl -L https://github.com/Starry-OS/rootfs/releases/download/20250917/rootfs-riscv64.img.xz -O
xz -d rootfs-riscv64.img.xz

# LoongArch64
curl -L https://github.com/Starry-OS/rootfs/releases/download/20250917/rootfs-loongarch64.img.xz -O
xz -d rootfs-loongarch64.img.xz
```

---

## 🚀 环境验证清单

安装完所有依赖后，运行以下命令验证环境：

### 1. Rust 工具链
```bash
rustc --version
# 期望输出: rustc 1.89.0-nightly (60dabef95 2025-05-19)

cargo --version
# 期望输出: cargo 1.89.0-nightly (...)

rustup show
# 期望输出包含 nightly-2025-05-20 和所有目标平台
```

### 2. Rust 目标平台
```bash
rustup target list --installed
# 期望输出：
# aarch64-unknown-none-softfloat
# loongarch64-unknown-none-softfloat
# riscv64gc-unknown-none-elf
# x86_64-unknown-linux-gnu
# x86_64-unknown-none
```

### 3. Cargo 工具
```bash
cargo axplat --version
# 期望输出: cargo-axplat 0.2.2

axconfig-gen --version
# 期望输出: axconfig-gen 0.2.0

cargo install --list | grep cargo-binutils
# 期望输出: cargo-binutils v0.4.0
```

### 4. 系统工具
```bash
gcc --version
clang --version
cmake --version
make --version
git --version
python3 --version
curl --version
xz --version
```

### 5. Musl 工具链
```bash
riscv64-linux-musl-gcc --version
# 期望输出: riscv64-linux-musl-gcc (GCC) 11.2.1 20211120
```

### 6. QEMU
```bash
qemu-system-riscv64 --version
# 期望输出: QEMU emulator version 10.2.0 (或更高)

qemu-system-loongarch64 --version
# 期望输出: QEMU emulator version 10.0.0 (或更高)

qemu-system-x86_64 --version
qemu-system-aarch64 --version
```

---

## 📊 不同操作系统的兼容性

| 操作系统 | 原生支持 | Docker 支持 | 推荐方式 | 说明 |
|---------|---------|------------|---------|------|
| **Ubuntu 24.04** | ⚠️ 部分 | ✅ 完全 | Docker | 系统 QEMU 版本不支持 LoongArch64 |
| **Ubuntu 22.04** | ⚠️ 部分 | ✅ 完全 | Docker | 需从源码编译 QEMU |
| **Debian 12** | ⚠️ 部分 | ✅ 完全 | Docker | 需从源码编译 QEMU |
| **Arch Linux** | ✅ 完全 | ✅ 完全 | 原生/Docker | 滚动更新，QEMU 版本较新 |
| **Fedora 40+** | ✅ 完全 | ✅ 完全 | 原生/Docker | QEMU 10+ 可用 |
| **macOS** | ❌ 不支持 | ✅ 完全 | Docker | 需 Docker Desktop |
| **Windows** | ❌ 不支持 | ✅ 完全 | Docker | 需 WSL2 + Docker Desktop |

**推荐**：所有平台使用 Docker，确保环境一致性。

---

## 🛠️ 快速环境配置脚本

### Ubuntu/Debian 原生环境（不包含 QEMU 10+）

```bash
#!/bin/bash
set -e

echo "===== Installing system dependencies ====="
sudo apt update
sudo apt install -y \
    build-essential cmake clang llvm lld \
    git curl xz-utils python3 \
    qemu-system

echo "===== Installing Rust ====="
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    -y --default-toolchain nightly-2025-05-20 \
    --profile minimal \
    --component rust-src,llvm-tools,rustfmt,clippy

source $HOME/.cargo/env

echo "===== Adding Rust targets ====="
rustup target add x86_64-unknown-none
rustup target add riscv64gc-unknown-none-elf
rustup target add aarch64-unknown-none-softfloat
rustup target add loongarch64-unknown-none-softfloat

echo "===== Installing Cargo tools ====="
cargo install cargo-axplat --version 0.2.2
cargo install axconfig-gen --version 0.2.0
cargo install cargo-binutils --version 0.4.0

echo "===== Downloading Musl toolchain ====="
cd /tmp
wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/riscv64-linux-musl-cross.tgz
sudo mkdir -p /opt
sudo tar -xzf riscv64-linux-musl-cross.tgz -C /opt/

echo 'export PATH=/opt/riscv64-linux-musl-cross/bin:$PATH' >> ~/.bashrc

echo "===== Environment setup complete ====="
echo "⚠️  WARNING: System QEMU may not support LoongArch64."
echo "    To support LoongArch64, compile QEMU 10+ from source or use Docker."
echo ""
echo "Next steps:"
echo "1. Run: source ~/.bashrc"
echo "2. Verify: rustc --version && qemu-system-riscv64 --version"
echo "3. Clone project: git clone --recursive https://github.com/Starry-OS/GalOS.git"
```

### 使用 Docker（推荐）

```bash
#!/bin/bash
set -e

echo "===== Cloning GalOS project ====="
git clone --recursive https://github.com/Starry-OS/GalOS.git
cd GalOS

echo "===== Building Docker image ====="
docker-compose build

echo "===== Starting development environment ====="
docker-compose run --rm galos-dev

echo "===== Inside container, run: ====="
echo "  make build         # Build GalOS"
echo "  make img           # Download rootfs"
echo "  make run           # Run on QEMU"
```

---

## 📝 环境配置文件

### `.bashrc` / `.zshrc` 配置

```bash
# Rust
export RUSTUP_HOME=$HOME/.rustup
export CARGO_HOME=$HOME/.cargo
export PATH=$CARGO_HOME/bin:$PATH

# Musl Toolchain
export PATH=/opt/riscv64-linux-musl-cross/bin:$PATH

# QEMU (if compiled from source)
export PATH=/opt/qemu/bin:$PATH

# GalOS build options (optional)
export ARCH=riscv64
export LOG=warn
export BACKTRACE=y
```

---

## 🔄 版本更新策略

### Rust 工具链更新

当项目需要更新 Rust 版本：

1. 更新 `rust-toolchain.toml`
2. 通知团队成员运行 `rustup update`（或重新构建 Docker 镜像）
3. 更新 CI/CD 配置

### 依赖工具更新

- **Cargo 工具**：更新 `arceos/scripts/make/deps.mk`
- **QEMU**：更新 `Dockerfile` 中的 `QEMU_VERSION`
- **Musl 工具链**：更新下载链接和版本说明

---

## 🆘 故障排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| `rustc` 版本不正确 | 未安装正确版本 | 运行 `cd GalOS && rustup show` |
| 找不到 `cargo-axplat` | 未安装或未添加到 PATH | `cargo install cargo-axplat --version 0.2.2` |
| QEMU LoongArch64 启动失败 | QEMU 版本低于 10.0 | 从源码编译 QEMU 10+ 或使用 Docker |
| `riscv64-linux-musl-gcc` 找不到 | Musl 工具链未安装或 PATH 未配置 | 检查安装步骤和 PATH 设置 |
| 构建失败，报错 `linker not found` | Musl 工具链或 LLVM 工具链未正确安装 | 验证 `rust-lld` 和 Musl GCC 可用性 |

---

## 📚 参考资源

- [Rust 官方安装指南](https://www.rust-lang.org/tools/install)
- [QEMU 官方下载](https://www.qemu.org/download/)
- [GalOS Docker 指南](./docker-guide.md)
- [ArceOS Musl 工具链](https://github.com/arceos-org/setup-musl)
- [GalOS 项目主页](https://github.com/Starry-OS/GalOS)

---

**最后更新**：2025-11-26
**维护者**：GalOS Team
