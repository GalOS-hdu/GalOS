# StarryOS Docker 开发环境指南

本指南介绍如何使用 Docker 容器化环境进行 StarryOS 的开发和测试。

## 目录

1. [环境依赖清单](#环境依赖清单)
2. [Docker 方案架构](#docker-方案架构)
3. [快速开始](#快速开始)
4. [使用方法](#使用方法)
5. [高级配置](#高级配置)
6. [常见问题](#常见问题)

---

## 环境依赖清单

### 统一版本要求

Docker 镜像已包含以下所有依赖，确保团队开发环境一致：

| 组件 | 版本 | 说明 |
|------|------|------|
| **Rust 工具链** | `nightly-2025-05-20` | 精确版本，包含 rust-src、llvm-tools、rustfmt、clippy |
| **Rust 目标平台** | - | x86_64-unknown-none, riscv64gc-unknown-none-elf, aarch64-unknown-none-softfloat, loongarch64-unknown-none-softfloat |
| **cargo-axplat** | v0.2.2 | 平台包信息解析工具 |
| **axconfig-gen** | v0.2.0 | 平台配置文件生成工具 |
| **cargo-binutils** | v0.4.0 | Cargo 二进制工具集 |
| **QEMU** | v10.2.0 | **重要**：支持 LoongArch64，从源码编译 |
| **riscv64-linux-musl-cross** | GCC 11.2.1 | RISC-V 64 交叉编译工具链 |
| **CMake** | v3.28.3+ | 构建系统 |
| **Clang/LLVM** | v18.1.3+ | 编译器工具链 |
| **Python** | v3.10+ | 用于测试脚本 |
| **Git** | v2.40+ | 版本控制 |

### QEMU 版本说明

**关键点**：StarryOS 在 LoongArch64 架构上需要 **QEMU 10.0+**，而大多数 Linux 发行版默认 QEMU 版本较低：

- Ubuntu 24.04: QEMU 8.2.2 ❌
- Debian 12: QEMU 7.2 ❌

因此，Docker 镜像从源码编译了 QEMU 10.2.0，支持所有目标架构。

---

## Docker 方案架构

### 多阶段构建设计

```
┌─────────────────────────────────────────┐
│  Stage 1: QEMU Builder                  │
│  - 从源码编译 QEMU 10.2.0               │
│  - 仅构建所需架构的 system emulator     │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Stage 2: Musl Toolchain Downloader     │
│  - 下载预编译的 Musl 工具链             │
│  - 解压到 /opt/musl-toolchains          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Stage 3: Final Development Image       │
│  - 基于 Ubuntu 24.04                     │
│  - 复制 QEMU 和 Musl 工具链             │
│  - 安装 Rust nightly-2025-05-20        │
│  - 安装 Cargo 工具                      │
│  - 创建非 root 用户                     │
└─────────────────────────────────────────┘
```

### 目录结构

```
StarryOS/
├── Dockerfile                 # 主构建文件
├── docker-compose.yml         # Docker Compose 配置
├── .dockerignore             # Docker 忽略文件
├── docs/
│   └── docker-guide.md       # 本文档
└── ...
```

---

## 快速开始

### 前置要求

- **Docker**: >= 20.10
- **Docker Compose**: >= 2.0 (可选，推荐)
- **磁盘空间**: 至少 10GB 可用空间
- **内存**: 建议 8GB+

### 1. 构建镜像

#### 方法一：使用 Docker Compose（推荐）

```bash
# 在 StarryOS 项目根目录下
docker-compose build
```

#### 方法二：使用 Docker 命令

```bash
docker build -t starryos-dev:latest .
```

**注意**：首次构建需要 20-40 分钟（编译 QEMU）。

### 2. 启动开发环境

#### 方法一：使用 Docker Compose

```bash
# 启动并进入容器
docker-compose run --rm starryos-dev

# 或者后台运行
docker-compose up -d starryos-dev
docker-compose exec starryos-dev bash
```

#### 方法二：使用 Docker 命令

```bash
docker run -it --rm \
  -v $(pwd):/workspace/StarryOS \
  -v starryos-cargo-cache:/usr/local/cargo/registry \
  -w /workspace/StarryOS \
  starryos-dev:latest
```

### 3. 验证环境

进入容器后，运行：

```bash
# 检查 Rust 版本
rustc --version
# 输出: rustc 1.89.0-nightly (60dabef95 2025-05-19)

# 检查 QEMU 版本
qemu-system-riscv64 --version
# 输出: QEMU emulator version 10.2.0

qemu-system-loongarch64 --version
# 输出: QEMU emulator version 10.2.0

# 检查 Musl 工具链
riscv64-linux-musl-gcc --version
# 输出: riscv64-linux-musl-gcc (GCC) 11.2.1

# 检查 Rust 目标平台
rustup target list --installed
```

---

## 使用方法

### 开发工作流

#### 1. 克隆项目并启动容器

```bash
# 在宿主机上
git clone --recursive https://github.com/Starry-OS/StarryOS.git
cd StarryOS

# 启动容器
docker-compose run --rm starryos-dev
```

#### 2. 在容器内构建项目

```bash
# 默认架构 (riscv64)
make build

# 指定架构
make ARCH=riscv64 build
make ARCH=loongarch64 build
make ARCH=x86_64 build
make ARCH=aarch64 build
```

#### 3. 准备 rootfs

```bash
make img
# 或指定架构
make img ARCH=riscv64
```

#### 4. 运行 StarryOS

```bash
# RISC-V 64
make run ARCH=riscv64
# 或使用快捷命令
make rv

# LoongArch 64
make run ARCH=loongarch64
# 或使用快捷命令
make la

# x86_64
make run ARCH=x86_64

# AArch64
make run ARCH=aarch64
```

#### 5. 运行测试

```bash
# CI 测试
python3 scripts/ci-test.py riscv64
python3 scripts/ci-test.py loongarch64
```

### CI/CD 集成

#### 使用 Docker Compose Profile

```bash
# 运行 CI 测试
docker-compose --profile ci run --rm starryos-ci
```

#### GitHub Actions 示例

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [riscv64, loongarch64, x86_64, aarch64]

    steps:
    - uses: actions/checkout@v4
      with:
        submodules: recursive

    - name: Build Docker image
      run: docker-compose build

    - name: Run build
      run: |
        docker-compose run --rm starryos-dev \
          bash -c "make ARCH=${{ matrix.arch }} build"

    - name: Prepare rootfs
      run: |
        docker-compose run --rm starryos-dev \
          bash -c "make ARCH=${{ matrix.arch }} img"

    - name: Run tests
      run: |
        docker-compose run --rm starryos-dev \
          bash -c "python3 scripts/ci-test.py ${{ matrix.arch }}"
```

---

## 高级配置

### KVM 加速

如果宿主机支持 KVM，可以启用硬件加速：

```yaml
# docker-compose.yml 中取消注释：
privileged: true
devices:
  - /dev/kvm:/dev/kvm
```

或使用 Docker 命令：

```bash
docker run -it --rm \
  --device /dev/kvm \
  --privileged \
  -v $(pwd):/workspace/StarryOS \
  starryos-dev:latest
```

### 自定义用户 UID/GID

匹配宿主机用户，避免文件权限问题：

```bash
docker build \
  --build-arg USER_UID=$(id -u) \
  --build-arg USER_GID=$(id -g) \
  -t starryos-dev:latest .
```

或在 `docker-compose.yml` 中修改：

```yaml
args:
  USER_UID: 1000  # 修改为你的 UID
  USER_GID: 1000  # 修改为你的 GID
```

### 使用不同的 QEMU 版本

```bash
docker build \
  --build-arg QEMU_VERSION=10.1.0 \
  -t starryos-dev:qemu10.1 .
```

### 资源限制

在 `docker-compose.yml` 中配置：

```yaml
deploy:
  resources:
    limits:
      cpus: '8'
      memory: 16G
    reservations:
      cpus: '4'
      memory: 8G
```

### 挂载额外的 Musl 工具链

如果需要其他架构的工具链：

```bash
docker run -it --rm \
  -v $(pwd):/workspace/StarryOS \
  -v /path/to/aarch64-linux-musl-cross:/opt/musl-toolchains/aarch64-linux-musl-cross \
  starryos-dev:latest
```

---

## 常见问题

### 1. 构建镜像时间过长

**原因**：需要从源码编译 QEMU。

**解决方案**：
- 使用多核并行编译（已在 Dockerfile 中配置 `make -j$(nproc)`）
- 首次构建后镜像会被缓存，后续构建更快
- 考虑使用预构建镜像（如果团队有私有镜像仓库）

### 2. 磁盘空间不足

**原因**：Docker 构建过程会产生大量中间层。

**解决方案**：
```bash
# 清理未使用的镜像和容器
docker system prune -a

# 清理构建缓存
docker builder prune
```

### 3. 容器内无法访问 /dev/kvm

**原因**：宿主机不支持 KVM 或 Docker 没有权限。

**解决方案**：
- 检查宿主机是否支持虚拟化：`lscpu | grep Virtualization`
- 确保 Docker 以特权模式运行（参见 [KVM 加速](#kvm-加速)）
- 如果不需要加速，在 Makefile 中设置 `ACCEL=n`

### 4. 文件权限问题

**原因**：容器内外用户 UID/GID 不匹配。

**解决方案**：
- 构建镜像时指定 UID/GID（参见 [自定义用户 UID/GID](#自定义用户-uidgid)）
- 或在容器内使用 `sudo chown` 修改权限

### 5. Rust 工具链版本不一致

**原因**：未使用 Docker 镜像中的 Rust。

**解决方案**：
- 确保在容器内运行构建命令
- 验证 Rust 版本：`rustc --version` 应显示 `nightly-2025-05-20`

### 6. QEMU 启动失败

**问题**：`qemu-system-xxx: command not found`

**解决方案**：
- 验证 PATH：`echo $PATH` 应包含 `/opt/qemu/bin`
- 重新构建镜像确保 QEMU 正确安装

### 7. LoongArch64 编译或运行失败

**原因**：QEMU 版本低于 10.0。

**解决方案**：
- 确认使用 Docker 镜像中的 QEMU：`qemu-system-loongarch64 --version`
- 应显示 `10.2.0` 或更高版本

### 8. 网络配置问题

**问题**：容器内无法访问网络或 QEMU 网络不通。

**解决方案**：
- 检查 Docker 网络模式：`docker-compose.yml` 中默认使用 `bridge`
- 对于 TAP 网络，可能需要特权模式和额外配置

---

## 维护和更新

### 更新依赖版本

1. 修改 `Dockerfile` 中的 `ARG` 参数
2. 重新构建镜像：

```bash
docker-compose build --no-cache
```

### 更新 Rust 工具链

如果项目升级到新的 Rust 版本（例如 `nightly-2025-06-15`）：

1. 修改 `rust-toolchain.toml`
2. 修改 `Dockerfile` 中的 `RUST_VERSION`
3. 重新构建镜像

### 团队镜像分发

#### 方案一：导出/导入镜像

```bash
# 导出镜像
docker save starryos-dev:latest | gzip > starryos-dev.tar.gz

# 在其他机器上导入
gunzip -c starryos-dev.tar.gz | docker load
```

#### 方案二：使用私有镜像仓库

```bash
# 标记镜像
docker tag starryos-dev:latest registry.example.com/starryos-dev:latest

# 推送到私有仓库
docker push registry.example.com/starryos-dev:latest

# 团队成员拉取
docker pull registry.example.com/starryos-dev:latest
```

---

## 性能优化建议

### 1. 使用持久化卷

Docker Compose 配置已包含 Cargo 缓存卷，加速依赖下载：

```yaml
volumes:
  - cargo-cache:/usr/local/cargo/registry
  - cargo-git-cache:/usr/local/cargo/git
```

### 2. 使用 BuildKit

启用 Docker BuildKit 加速构建：

```bash
export DOCKER_BUILDKIT=1
docker-compose build
```

### 3. 多阶段构建优化

Dockerfile 已使用多阶段构建，最小化最终镜像大小（约 5-6GB）。

---

## 总结

使用 Docker 容器化方案，团队可以获得：

✅ **统一开发环境**：所有依赖版本锁定，避免"在我机器上能跑"问题
✅ **简化配置**：无需手动安装 QEMU、Rust、Musl 工具链
✅ **支持 LoongArch64**：内置 QEMU 10+，满足 LoongArch64 需求
✅ **跨平台兼容**：Docker 支持 Linux、macOS、Windows
✅ **CI/CD 友好**：容器化测试环境，易于集成到 CI 管道

如有问题，请参考 [常见问题](#常见问题) 或联系团队维护者。
