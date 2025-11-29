# GalOS Docker CI 问题排查与修复记录

本文档记录了 GalOS 项目在配置和修复 Docker CI 过程中遇到的所有问题及其解决方案。

## 目录
- [GitHub Actions Workflow 概述](#github-actions-workflow-概述)
- [CI 错误1: docker-compose 命令未找到](#ci-错误1-docker-compose-命令未找到)
- [CI 错误2: GID 冲突](#ci-错误2-gid-冲突)
- [CI 错误3: 代理连接错误](#ci-错误3-代理连接错误)
- [CI 错误4: 权限拒绝错误](#ci-错误4-权限拒绝错误)
- [CI 错误5: 多架构工具链缺失](#ci-错误5-多架构工具链缺失)
- [CI 错误6: 磁盘空间不足](#ci-错误6-磁盘空间不足)
- [CI 错误7: LoongArch64 启动失败](#ci-错误7-loongarch64-启动失败)
- [总结](#总结)

---

## GitHub Actions Workflow 概述

### Workflow 行为说明

当代码 push 到 git 仓库时，`.github/workflows/docker-ci.yml` 会自动触发以下流程：

1. **触发条件**：
   - Push 到 `main` 或 `dev` 分支
   - 创建针对 `main` 或 `dev` 分支的 Pull Request

2. **并发控制**：
   - 使用 `concurrency` 配置
   - 当新的 workflow 触发时，取消同一分支上正在运行的旧 workflow

3. **多架构矩阵测试**：
   ```yaml
   matrix:
     arch: [riscv64, loongarch64, x86_64, aarch64]
   ```
   为每个架构并行运行独立的测试任务

4. **主要步骤**：
   - 检出代码（包括子模块）
   - 清理磁盘空间（释放约 14GB）
   - 设置 Docker Buildx
   - 构建 Docker 镜像
   - 为特定架构编译 GalOS
   - 准备 rootfs
   - 运行 CI 测试脚本

### GitHub 模板分析

项目包含以下模板文件：

**Issue 模板**：
- **Bug Report** (`.github/ISSUE_TEMPLATE/bug_report.md`)
  - 环境信息（架构、构建模式等）
  - 复现步骤
  - 预期行为 vs 实际行为
  - 错误日志

- **Feature Request** (`.github/ISSUE_TEMPLATE/feature_request.md`)
  - 问题描述
  - 期望的解决方案
  - 替代方案考虑

**Pull Request 模板** (`.github/pull_request_template.md`)：
- 变更类型标识（功能/修复/重构等）
- 变更描述
- 测试方法
- 检查清单

---

## CI 错误1: docker-compose 命令未找到

### 错误现象
```
Build Docker image
Run docker-compose build
/home/runner/work/_temp/xxx.sh: line 1: docker-compose: command not found
Error: Process completed with exit code 127.
```

### 根本原因
GitHub Actions 的 Ubuntu runners 默认使用 **Docker Compose V2**，命令为 `docker compose`（空格），而不是旧版本的 `docker-compose`（连字符）。

### 解决方案
将所有 `docker-compose` 命令改为 `docker compose`。

**修改文件**：`.github/workflows/docker-ci.yml`

**修改位置**（共6处）：
- Build Docker image (第63行)
- Build GalOS for ${{ matrix.arch }} (第67行)
- Prepare rootfs for ${{ matrix.arch }} (第72行)
- Run CI tests for ${{ matrix.arch }} (第77行)
- Build Docker image (docker-build-only job, 第128行)
- Verify environment (第132行)

**示例**：
```yaml
# 修改前
- name: Build Docker image
  run: |
    docker-compose build

# 修改后
- name: Build Docker image
  run: |
    docker compose build
```

**提交信息**：
```
fix(ci): use Docker Compose V2 syntax

Replace docker-compose with docker compose for GitHub Actions compatibility.
GitHub Actions Ubuntu runners use Docker Compose V2 by default.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## CI 错误2: GID 冲突

### 错误现象
```
failed to solve: process "/bin/sh -c groupadd --gid $USER_GID $USERNAME && ..."
did not complete successfully: exit code: 4
groupadd: GID '1000' already exists
```

### 根本原因
`docker-compose.yml` 中设置的 `USER_GID=1000` 与 Ubuntu 24.04 基础镜像中已存在的 GID 冲突。

### 解决方案
在 Dockerfile 中使用条件逻辑处理已存在的 UID/GID。

**修改文件**：`Dockerfile`

**修改内容**（第158-160行）：
```dockerfile
# 修改前
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 修改后
RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1) && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME 2>/dev/null || usermod -l $USERNAME -d /home/$USERNAME -m $(getent passwd $USER_UID | cut -d: -f1) && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
```

**工作原理**：
- `2>/dev/null ||`：如果命令失败（GID/UID已存在），则执行后续命令
- `groupmod -n`：重命名已存在的组
- `usermod -l`：重命名已存在的用户

---

## CI 错误3: 代理连接错误

### 错误现象
```
curl: (7) Failed to connect to 127.0.0.1 port 7897 after 0 ms: Couldn't connect to server
```

### 根本原因
`docker-compose.yml` 中硬编码了本地代理地址 `http://127.0.0.1:7897`，但 GitHub Actions 环境中没有运行代理服务。

### 解决方案
使用环境变量默认值，允许在本地和 CI 环境使用不同配置。

**修改文件**：
1. `docker-compose.yml`
2. `.env`（新建，用于本地开发）
3. `.env.example`（新建，作为模板）
4. `.gitignore`（添加 .env）

**docker-compose.yml 修改**（第37-53行）：
```yaml
# 修改前
environment:
  - HTTP_PROXY=http://127.0.0.1:7897
  - HTTPS_PROXY=http://127.0.0.1:7897
  - http_proxy=http://127.0.0.1:7897
  - https_proxy=http://127.0.0.1:7897

# 修改后
environment:
  - HTTP_PROXY=${HTTP_PROXY:-}
  - HTTPS_PROXY=${HTTPS_PROXY:-}
  - http_proxy=${http_proxy:-}
  - https_proxy=${https_proxy:-}
  - NO_PROXY=${NO_PROXY:-localhost,127.0.0.1,::1}
  - no_proxy=${no_proxy:-localhost,127.0.0.1,::1}
```

**新建 .env 文件**（本地使用，已加入 .gitignore）：
```bash
# Docker Compose Environment Variables
# Proxy configuration for local development

HTTP_PROXY=http://127.0.0.1:7897
HTTPS_PROXY=http://127.0.0.1:7897
http_proxy=http://127.0.0.1:7897
https_proxy=http://127.0.0.1:7897
```

**新建 .env.example 文件**（模板）：
```bash
# Docker Compose Environment Variables

# HTTP_PROXY=http://127.0.0.1:7897
# HTTPS_PROXY=http://127.0.0.1:7897
# http_proxy=http://127.0.0.1:7897
# https_proxy=http://127.0.0.1:7897
```

**修改 .gitignore**：
```gitignore
# Docker
*.tar.gz
.env
```

---

## CI 错误4: 权限拒绝错误

### 错误现象
```
error: could not lock config file /usr/local/cargo/git/config: Permission denied (os error 13)
error: could not write config file /usr/local/cargo/.package-cache: Permission denied (os error 13)
```

### 根本原因
Docker 容器以 root 启动，但需要以非 root 用户运行构建任务。Cargo 目录的权限不正确。

### 解决方案
创建 entrypoint 脚本，在容器启动时自动修复权限。

**新建文件**：`docker-entrypoint.sh`

```bash
#!/bin/bash
set -e

USERNAME=${USERNAME:-starry}
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

fix_permissions() {
    echo "Fixing permissions for cargo directories..."
    if [ -d "/usr/local/cargo" ]; then
        chown -R ${USERNAME}:${USERNAME} /usr/local/cargo 2>/dev/null || true
    fi
    if [ -d "/usr/local/rustup" ]; then
        chown -R ${USERNAME}:${USERNAME} /usr/local/rustup 2>/dev/null || true
    fi
    if [ -d "/workspace" ]; then
        chown -R ${USERNAME}:${USERNAME} /workspace 2>/dev/null || true
    fi
    echo "Permissions fixed."
}

if [ "$(id -u)" = "0" ]; then
    fix_permissions
    if [ $# -eq 0 ]; then
        exec gosu ${USERNAME} bash
    else
        exec gosu ${USERNAME} "$@"
    fi
else
    echo "Running as non-root user: $(whoami)"
    if [ $# -eq 0 ]; then
        exec bash
    else
        exec "$@"
    fi
fi
```

**修改 Dockerfile**（第150-151行）：
```dockerfile
# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
```

**修改 Dockerfile**（第189-191行）：
```dockerfile
# Set entrypoint to handle permissions and user switching
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
```

---

## CI 错误5: 多架构工具链缺失

### 错误现象
```
Build GalOS for loongarch64
error: linker `loongarch64-linux-musl-gcc` not found

Build GalOS for x86_64
error: linker `x86_64-linux-musl-gcc` not found

Build GalOS for aarch64
error: linker `aarch64-linux-musl-gcc` not found
```

只有 riscv64 通过测试。

### 根本原因
Dockerfile 只下载了 riscv64 的 musl 工具链，缺少其他三个架构的交叉编译工具链。

**分析过程**：
1. 检查 `arceos/scripts/make/build_c.mk`，发现所有架构都需要 C 编译器
2. 确认 Dockerfile 只包含 riscv64 工具链下载

### 解决方案
在 Dockerfile 中下载所有4个架构的 musl 工具链。

**修改文件**：`Dockerfile`

**Stage 2: Musl Toolchain Downloader**（第54-72行）：
```dockerfile
WORKDIR /tmp/musl
# Download Musl toolchains for all architectures
RUN mkdir -p /opt/musl-toolchains && \
    # RISC-V 64
    wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/riscv64-linux-musl-cross.tgz && \
    tar -xzf riscv64-linux-musl-cross.tgz -C /opt/musl-toolchains/ && \
    rm riscv64-linux-musl-cross.tgz && \
    # LoongArch 64
    wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/loongarch64-linux-musl-cross.tgz && \
    tar -xzf loongarch64-linux-musl-cross.tgz -C /opt/musl-toolchains/ && \
    rm loongarch64-linux-musl-cross.tgz && \
    # AArch64
    wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/aarch64-linux-musl-cross.tgz && \
    tar -xzf aarch64-linux-musl-cross.tgz -C /opt/musl-toolchains/ && \
    rm aarch64-linux-musl-cross.tgz && \
    # x86_64
    wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/x86_64-linux-musl-cross.tgz && \
    tar -xzf x86_64-linux-musl-cross.tgz -C /opt/musl-toolchains/ && \
    rm x86_64-linux-musl-cross.tgz
```

**更新 PATH 环境变量**（第84-89行）：
```dockerfile
ENV PATH=/opt/qemu/bin:\
/opt/musl-toolchains/riscv64-linux-musl-cross/bin:\
/opt/musl-toolchains/loongarch64-linux-musl-cross/bin:\
/opt/musl-toolchains/aarch64-linux-musl-cross/bin:\
/opt/musl-toolchains/x86_64-linux-musl-cross/bin:\
$CARGO_HOME/bin:$PATH
```

**更新验证步骤**（第167-180行）：
```dockerfile
RUN echo "===== Environment Info =====" && \
    echo "Rust: $(rustc --version)" && \
    echo "Cargo: $(cargo --version)" && \
    echo "QEMU RISC-V: $(qemu-system-riscv64 --version | head -1)" && \
    echo "QEMU LoongArch: $(qemu-system-loongarch64 --version | head -1)" && \
    echo "QEMU x86_64: $(qemu-system-x86_64 --version | head -1)" && \
    echo "QEMU AArch64: $(qemu-system-aarch64 --version | head -1)" && \
    echo "RISC-V GCC: $(riscv64-linux-musl-gcc --version | head -1)" && \
    echo "LoongArch GCC: $(loongarch64-linux-musl-gcc --version | head -1)" && \
    echo "AArch64 GCC: $(aarch64-linux-musl-gcc --version | head -1)" && \
    echo "x86_64 GCC: $(x86_64-linux-musl-gcc --version | head -1)" && \
    echo "CMake: $(cmake --version | head -1)" && \
    echo "Clang: $(clang --version | head -1)" && \
    echo "============================"
```

---

## CI 错误6: 磁盘空间不足

### 错误现象
```
#7 149.3 /opt/musl-toolchains/x86_64-linux-musl-cross/libexec/gcc/x86_64-linux-musl/11.2.1/f951:
write /opt/musl-toolchains/x86_64-linux-musl-cross/libexec/gcc/x86_64-linux-musl/11.2.1/f951:
no space left on device
```

### 根本原因
1. Docker 镜像过大（包含4个架构的工具链 + 从源码编译的 QEMU）
2. GitHub Actions runner 磁盘空间有限（约 14GB 可用空间）

### 解决方案

#### 方案1：在 CI Workflow 中添加磁盘清理步骤

**修改文件**：`.github/workflows/docker-ci.yml`

**添加步骤**（第28-48行）：
```yaml
- name: Free disk space
  run: |
    echo "Before cleanup:"
    df -h

    # Remove unnecessary packages to free up disk space
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /usr/local/lib/android
    sudo rm -rf /opt/ghc
    sudo rm -rf /opt/hostedtoolcache/CodeQL
    sudo rm -rf /usr/local/share/boost
    sudo rm -rf "$AGENT_TOOLSDIRECTORY"

    # Clean up docker
    docker system prune -af --volumes

    # Clean apt cache
    sudo apt-get clean

    echo "After cleanup:"
    df -h
```

**效果**：释放约 14GB 磁盘空间

#### 方案2：优化 Dockerfile 减少镜像大小

**修改文件**：`Dockerfile`

**Stage 1: QEMU Builder 优化**（第40-41行）：
```dockerfile
# 添加清理步骤
RUN ... && \
    make install && \
    cd .. && \
    rm -rf qemu-${QEMU_VERSION} qemu-${QEMU_VERSION}.tar.xz
```

**Stage 3: Rust 安装优化**（第133-134行）：
```dockerfile
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain ${RUST_VERSION} \
    --profile minimal \
    --component rust-src,llvm-tools,rustfmt,clippy && \
    rm -rf /tmp/*
```

**Cargo 工具安装优化**（第144-147行）：
```dockerfile
RUN cargo install cargo-axplat --version 0.2.2 && \
    cargo install axconfig-gen --version 0.2.0 && \
    cargo install cargo-binutils --version 0.4.0 && \
    rm -rf $CARGO_HOME/registry $CARGO_HOME/git
```

### QEMU 版本调整

**问题**：应该使用 QEMU 9.2.4（与 arceos 一致）还是 10.1.2？

**分析**：
- 检查 `arceos/Dockerfile` 发现使用 QEMU 9.2.4
- arceos CI 配置也使用 9.2.4
- 为保证兼容性，应与上游保持一致

**修改**：
- `Dockerfile` 第7行：`ARG QEMU_VERSION=9.2.4`
- `docker-compose.yml` 第9行和第80行：`QEMU_VERSION: "9.2.4"`

---

## CI 错误7: LoongArch64 启动失败

### 错误现象
```
Run CI tests for loongarch64
qemu-system-loongarch64: could not load kernel
'/workspace/GalOS/GalOS_loongarch64-qemu-virt.bin': The image is not ELF
```

其他三个架构（riscv64, x86_64, aarch64）均通过。

### 根本原因分析

**关键发现**：这不是 arceos 代码问题，而是 **GalOS Docker 镜像中 QEMU 与 loongarch64 之间的配置问题**。

**证据**：
1. 所有架构都能在本地（非 Docker）通过 build and test
2. 只有在 Docker CI 环境中 loongarch64 失败
3. Docker CI 与本地测试使用基本相同的环境

**技术分析**：

1. **QEMU 9.2.4 的 loongarch64 需求**：
   - 检查发现 QEMU 包含 UEFI 固件：`edk2-loongarch64-code.fd`
   - 但 arceos 的 `qemu.mk` 没有为 loongarch64 指定 `-bios` 参数

2. **内核格式问题**：
   ```makefile
   # arceos/scripts/make/qemu.mk:43-45
   qemu_args-loongarch64 := \
     -machine $(machine) \
     -kernel $(FINAL_IMG)  # 使用 binary 格式
   ```

   - 错误信息："The image is not ELF"
   - QEMU 9.2.4 的 loongarch64 要求 ELF 格式，不接受 raw binary

3. **对比其他架构**：
   - riscv64: 使用 `$(FINAL_IMG)` + `-bios default`
   - x86_64: 使用 `$(OUT_ELF)`（ELF 格式）
   - aarch64: 使用 `$(FINAL_IMG)`

### 尝试的解决方案

#### 尝试1：修改 arceos 子模块（已撤销）

**错误做法**：直接修改 `arceos/scripts/make/qemu.mk`
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(OUT_ELF)  # 改用 ELF
```

**为什么撤销**：
- arceos 作为成熟的独立项目，不应该有这种基础错误
- 不应修改子模块内容
- 问题应该在 GalOS 项目层面解决

#### 尝试2：在 GalOS Makefile 中覆盖配置（有效但不完整）

**修改文件**：`Makefile`

**添加内容**（第44-56行）：
```makefile
# LoongArch64 QEMU fix: use ELF format kernel instead of binary
# QEMU 9.2.4's loongarch64 emulator requires ELF format
ifeq ($(ARCH), loongarch64)
justrun:
	@echo "    \033[96;1mRunning\033[0m on qemu (loongarch64 with ELF)..."
	@qemu-system-loongarch64 -m $(MEM) -smp $(SMP) -machine virt \
		-kernel $(PWD)/GalOS_loongarch64-qemu-virt.elf \
		$(if $(filter y,$(BLK)),-device virtio-blk-pci$(COMMA)drive=disk0 -drive id=disk0$(COMMA)if=none$(COMMA)format=raw$(COMMA)file=arceos/disk.img) \
		$(if $(filter y,$(NET)),-device virtio-net-pci$(COMMA)netdev=net0 -netdev user$(COMMA)id=net0$(COMMA)hostfwd=tcp::5555-:5555$(COMMA)hostfwd=udp::5555-:5555) \
		-nographic \
		$(QEMU_ARGS)
else
justrun:
	@make -C arceos $@
endif
```

**添加辅助变量**（第12-16行）：
```makefile
export SMP := 1
# Helper variables
COMMA := ,
```

**测试结果**：
- QEMU 能够加载 ELF 文件（不再报错）
- 但内核无法启动，没有串口输出

#### 尝试3：添加 UEFI BIOS（导致进入 UEFI Shell）

**发现**：loongarch64 QEMU 包含 UEFI 固件配置
```bash
$ cat /opt/qemu/share/qemu/firmware/60-edk2-loongarch64.json
{
    "description": "UEFI firmware for loongarch64",
    "interface-types": ["uefi"],
    "mapping": {
        "device": "flash",
        "executable": {
            "filename": "/opt/qemu/share/qemu/edk2-loongarch64-code.fd",
            "format": "raw"
        }
    },
    ...
}
```

**测试添加 BIOS 参数**：
```makefile
-bios /opt/qemu/share/qemu/edk2-loongarch64-code.fd \
-kernel $(PWD)/GalOS_loongarch64-qemu-virt.elf \
```

**结果**：
- UEFI 固件成功启动
- 但进入 UEFI Shell 而不是直接启动内核
- 不符合预期（应该直接启动内核）

### 当前状态与结论

**问题本质**：
从源码编译的 QEMU 9.2.4 无法为 loongarch64 提供正确的直接内核启动（direct kernel boot）支持。

**可能原因**：
1. 缺少特定的 QEMU 编译配置选项
2. 需要 FDT (Flattened Device Tree) 支持
3. arceos 的 `setup-qemu` action 可能使用预编译的特殊版本

**Web 搜索发现**：
- QEMU 添加了 loongarch64 ELF kernel + FDT 启动支持
- 但需要特定配置和参数
- 可能需要 `-dtb` 参数或其他配置

**当前测试状态**：
- ✅ riscv64: 完全通过 CI 测试
- ✅ x86_64: 通过 build 测试
- ✅ aarch64: 通过 build 测试
- ❌ loongarch64:
  - ✅ Build 成功
  - ✅ QEMU 能加载 ELF
  - ❌ 内核无法启动（无输出）

### 建议方案

**短期方案**：
1. 在 CI 中暂时跳过 loongarch64 测试
2. 或标注为已知问题

**长期方案**：
1. 研究 `arceos-org/setup-qemu` action 的实现
2. 找到正确的 QEMU 配置或使用预编译版本
3. 或等待 arceos 团队提供 loongarch64 QEMU 配置指导

**相关资源**：
- QEMU LoongArch文档: https://www.qemu.org/docs/master/system/target-loongarch.html
- QEMU ELF kernel + FDT 补丁: https://www.mail-archive.com/qemu-devel@nongnu.org/msg1038209.html

---

## 总结

### 成功修复的问题

1. ✅ **Docker Compose V2 兼容性**：统一使用 `docker compose` 命令
2. ✅ **UID/GID 冲突**：使用条件逻辑处理已存在的用户/组
3. ✅ **代理配置**：使用环境变量默认值支持本地和 CI 环境
4. ✅ **权限问题**：创建 entrypoint 脚本自动修复权限
5. ✅ **多架构支持**：下载所有4个架构的 musl 工具链
6. ✅ **磁盘空间**：CI 清理步骤 + Dockerfile 优化
7. ✅ **QEMU 版本**：统一使用 9.2.4 与 arceos 保持一致

### 待解决问题

1. ⚠️ **LoongArch64 QEMU 启动**：
   - 技术原因：Docker 镜像中 QEMU 配置问题
   - 当前状态：能编译但无法运行
   - 建议：研究 arceos setup-qemu 或使用预编译版本

### 提交记录

所有修复已通过以下提交完成：

```bash
# Commit 1: Docker Compose V2
fix(ci): use Docker Compose V2 syntax

# Commit 2: Multi-arch support + QEMU 9.2.4 + optimizations
feat(docker): add multi-arch support and optimize build

- Add musl toolchains for all 4 architectures (riscv64, loongarch64, aarch64, x86_64)
- Downgrade QEMU to 9.2.4 for compatibility with arceos
- Add disk cleanup step in CI to free ~14GB space
- Optimize Dockerfile to reduce image size
- Add docker-entrypoint.sh to fix permissions
- Use environment variables for proxy configuration

Fixes #N/A

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 文件修改清单

**新增文件**：
- `docker-entrypoint.sh` - 权限修复脚本
- `.env` - 本地代理配置（git-ignored）
- `.env.example` - 配置模板
- `docs/ci-troubleshooting.md` - 本文档

**修改文件**：
- `.github/workflows/docker-ci.yml` - Docker Compose V2 语法 + 磁盘清理
- `Dockerfile` - 多架构工具链 + QEMU 9.2.4 + 优化
- `docker-compose.yml` - 代理环境变量 + QEMU 版本
- `.gitignore` - 添加 .env
- `Makefile` - LoongArch64 QEMU 启动修复（待完善）

### 参考资源

- Docker Compose V2: https://docs.docker.com/compose/migrate/
- GitHub Actions Runners: https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners
- QEMU LoongArch: https://www.qemu.org/docs/master/system/target-loongarch.html
- Musl Toolchains: https://github.com/arceos-org/setup-musl
