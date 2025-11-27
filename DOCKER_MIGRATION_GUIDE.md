# StarryOS Docker 迁移指南

本文档为团队提供项目 Docker 化的快速参考和行动指南。

## 📦 已生成的文件

本次分析和方案设计已生成以下文件：

| 文件 | 路径 | 说明 |
|------|------|------|
| **Dockerfile** | `/Dockerfile` | 多阶段构建的 Docker 镜像定义 |
| **docker-compose.yml** | `/docker-compose.yml` | Docker Compose 配置，包含开发和 CI 环境 |
| **.dockerignore** | `/.dockerignore` | Docker 构建忽略规则 |
| **Docker 使用指南** | `/docs/docker-guide.md` | 详细的 Docker 环境使用文档（必读） |
| **环境依赖清单** | `/docs/environment-requirements.md` | 完整的开发环境依赖说明 |
| **环境配置脚本** | `/setup-env.sh` | 交互式环境配置脚本 |

---

## 🎯 核心发现：需要统一的依赖项

### ⚠️ 关键依赖（必须严格统一）

| 依赖项 | 要求版本 | 重要性 | 说明 |
|--------|----------|--------|------|
| **Rust 工具链** | `nightly-2025-05-20` | 🔴 极高 | 必须精确匹配，否则编译失败 |
| **QEMU (LoongArch64)** | **>= 10.0** | 🔴 极高 | **系统默认版本不满足要求** |
| **QEMU (其他架构)** | >= 6.0，推荐 8.2+ | 🟡 中等 | 可用系统包管理器安装 |
| **riscv64-linux-musl-gcc** | GCC 11.2.1 | 🟡 中等 | 交叉编译工具链 |
| **cargo-axplat** | v0.2.2 | 🟢 一般 | 构建系统依赖 |
| **axconfig-gen** | v0.2.0 | 🟢 一般 | 配置生成工具 |
| **cargo-binutils** | v0.4.0 | 🟢 一般 | 二进制工具 |

### 🚨 最大痛点：QEMU 版本

**问题**：
- StarryOS 支持 LoongArch64 架构，**严格要求 QEMU 10.0+**
- 大多数 Linux 发行版的默认 QEMU 版本不满足要求：
  - Ubuntu 24.04: QEMU 8.2.2 ❌
  - Ubuntu 22.04: QEMU 7.2 ❌
  - Debian 12: QEMU 7.2 ❌

**解决方案**：
1. **推荐**：使用 Docker（已包含 QEMU 10.2.0）
2. 手动从源码编译 QEMU 10+（需 20-40 分钟）

---

## 🚀 快速开始（3 种方式）

### 方式 1：使用 Docker（强烈推荐）

**优点**：
- ✅ 所有依赖已预配置，包括 QEMU 10+
- ✅ 跨平台支持（Linux/macOS/Windows）
- ✅ 环境一致性保证
- ✅ 无需手动安装任何工具

**步骤**：

```bash
# 1. 安装 Docker（如果未安装）
# Linux: https://docs.docker.com/engine/install/
# macOS/Windows: https://docs.docker.com/desktop/

# 2. 构建镜像（首次需要 20-40 分钟）
docker-compose build

# 3. 启动开发环境
docker-compose run --rm starryos-dev

# 4. 在容器内构建和运行 StarryOS
make build
make img
make run          # RISC-V 64
make la           # LoongArch 64
```

**详细文档**：[docs/docker-guide.md](docs/docker-guide.md)

---

### 方式 2：使用环境配置脚本

我们提供了一个交互式脚本，帮助您选择最适合的配置方式：

```bash
./setup-env.sh
```

脚本功能：
- 选项 1：自动构建 Docker 环境
- 选项 2：在 Ubuntu/Debian 上安装原生环境（⚠️ 不包含 QEMU 10+）
- 选项 3：检查当前环境状态

---

### 方式 3：手动配置原生环境

**仅适用于**：
- 不需要 LoongArch64 支持
- 或愿意手动编译 QEMU 10+

**步骤**：

```bash
# 1. 安装系统依赖
sudo apt update
sudo apt install -y build-essential cmake clang qemu-system

# 2. 安装 Rust nightly-2025-05-20
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    -y --default-toolchain nightly-2025-05-20 \
    --profile minimal \
    --component rust-src,llvm-tools,rustfmt,clippy

source $HOME/.cargo/env

# 3. 添加 Rust 目标平台
rustup target add x86_64-unknown-none \
    riscv64gc-unknown-none-elf \
    aarch64-unknown-none-softfloat \
    loongarch64-unknown-none-softfloat

# 4. 安装 Cargo 工具
cargo install cargo-axplat --version 0.2.2
cargo install axconfig-gen --version 0.2.0
cargo install cargo-binutils --version 0.4.0

# 5. 下载 Musl 工具链
cd /tmp
wget https://github.com/arceos-org/setup-musl/releases/download/prebuilt/riscv64-linux-musl-cross.tgz
sudo tar -xzf riscv64-linux-musl-cross.tgz -C /opt/
echo 'export PATH=/opt/riscv64-linux-musl-cross/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# 6. 验证环境
rustc --version
qemu-system-riscv64 --version
riscv64-linux-musl-gcc --version
```

⚠️ **警告**：此方法安装的系统 QEMU 不支持 LoongArch64。若需支持，请参考 [docs/environment-requirements.md](docs/environment-requirements.md) 手动编译 QEMU 10+。

---

## 📋 团队迁移行动计划

### 阶段 1：准备和测试（1-2 周）

**目标**：验证 Docker 方案可行性

- [ ] 技术负责人或指定人员测试 Docker 环境
- [ ] 在 Docker 中完成一次完整的构建、测试、运行流程
- [ ] 验证所有支持的架构（RISC-V 64、LoongArch 64、x86_64、AArch64）
- [ ] 识别潜在问题（如网络、权限、性能）

**输出**：
- 测试报告（是否所有功能正常）
- Docker 镜像大小和构建时间记录

---

### 阶段 2：团队培训（1 周）

**目标**：让团队成员熟悉 Docker 工作流

- [ ] 组织技术分享会，介绍 Docker 方案
- [ ] 分发文档：[docker-guide.md](docs/docker-guide.md) 和 [environment-requirements.md](docs/environment-requirements.md)
- [ ] 每位成员完成一次 Docker 环境搭建
- [ ] 建立常见问题知识库

**资源**：
- PPT/演示材料（可基于本文档制作）
- 演示视频（可选）
- Slack/微信支持群组

---

### 阶段 3：镜像分发（1 周）

**目标**：加速团队成员环境配置

**方案 A：导出/导入镜像**（适合小团队）

```bash
# 构建并导出镜像
docker-compose build
docker save starryos-dev:latest | gzip > starryos-dev.tar.gz

# 团队成员导入
gunzip -c starryos-dev.tar.gz | docker load
```

**方案 B：私有镜像仓库**（推荐，适合中大型团队）

```bash
# 设置私有仓库（如 Harbor、GitLab Registry、AWS ECR）
docker tag starryos-dev:latest registry.company.com/starryos-dev:latest
docker push registry.company.com/starryos-dev:latest

# 团队成员拉取
docker pull registry.company.com/starryos-dev:latest
```

---

### 阶段 4：切换到 Docker 开发（2-4 周过渡期）

**目标**：全员使用 Docker 进行日常开发

- [ ] 新功能开发强制使用 Docker
- [ ] 老功能维护建议使用 Docker
- [ ] 收集反馈，优化 Dockerfile 和文档
- [ ] 解决兼容性问题（文件权限、网络、性能）

**关键指标**：
- Docker 使用率（目标：80%+）
- 环境配置问题工单数量（目标：减少 50%+）

---

### 阶段 5：CI/CD 集成（并行进行）

**目标**：自动化测试和构建流程

- [ ] 更新 GitHub Actions / GitLab CI 配置
- [ ] 使用 Docker 镜像运行 CI 任务
- [ ] 配置多架构测试矩阵（riscv64, loongarch64, x86_64, aarch64）
- [ ] 设置自动化测试报告

**示例配置**：参见 [docs/docker-guide.md - CI/CD 集成](docs/docker-guide.md#cicd-集成)

---

## 🛠️ 维护和更新策略

### 定期维护任务

| 任务 | 频率 | 负责人 | 说明 |
|------|------|--------|------|
| 更新 Rust 工具链 | 每月 | 技术负责人 | 跟踪上游 Rust 更新 |
| 更新 QEMU 版本 | 每季度 | DevOps | 关注 QEMU 安全补丁 |
| 更新依赖工具 | 按需 | 开发者 | cargo-axplat、axconfig-gen 等 |
| 清理 Docker 缓存 | 每周 | 自动化 | 防止磁盘空间不足 |
| 镜像安全扫描 | 每月 | DevOps | 使用 Trivy/Clair 扫描漏洞 |

### 版本发布流程

当项目依赖版本变更时（例如 Rust 版本升级）：

1. **更新配置文件**：
   - `rust-toolchain.toml`
   - `Dockerfile` 中的 `ARG` 参数
   - `docs/environment-requirements.md`

2. **测试新版本**：
   - 本地构建镜像：`docker-compose build --no-cache`
   - 完整测试所有架构

3. **发布通知**：
   - 团队公告（Slack/邮件）
   - 更新 README 或 CHANGELOG
   - 提供迁移指南（如有 Breaking Changes）

4. **推送新镜像**：
   - 标记版本：`docker tag starryos-dev:latest starryos-dev:v1.1.0`
   - 推送到镜像仓库

---

## 🔍 验证清单

在完成 Docker 迁移后，使用以下清单验证环境：

### 开发环境验证

- [ ] Rust 版本正确：`rustc --version` 显示 `nightly-2025-05-20`
- [ ] 所有目标平台已安装：`rustup target list --installed`
- [ ] QEMU 版本满足要求：`qemu-system-loongarch64 --version` 显示 `10.0+`
- [ ] Musl 工具链可用：`riscv64-linux-musl-gcc --version`
- [ ] Cargo 工具可用：`cargo axplat --version`, `axconfig-gen --version`

### 构建验证

- [ ] RISC-V 64 构建：`make ARCH=riscv64 build` 成功
- [ ] LoongArch 64 构建：`make ARCH=loongarch64 build` 成功
- [ ] x86_64 构建：`make ARCH=x86_64 build` 成功
- [ ] AArch64 构建：`make ARCH=aarch64 build` 成功

### 运行验证

- [ ] RISC-V 64 运行：`make rv` 能启动到 BusyBox shell
- [ ] LoongArch 64 运行：`make la` 能启动到 BusyBox shell
- [ ] CI 测试通过：`python3 scripts/ci-test.py riscv64`

---

## 📞 支持和帮助

### 文档资源

- **Docker 使用指南**：[docs/docker-guide.md](docs/docker-guide.md)（包含常见问题解答）
- **环境依赖清单**：[docs/environment-requirements.md](docs/environment-requirements.md)
- **StarryOS README**：[README.md](README.md)

### 故障排查

**常见问题**：参见 [docker-guide.md - 常见问题](docs/docker-guide.md#常见问题)

**联系方式**：
- GitHub Issues：[https://github.com/Starry-OS/StarryOS/issues](https://github.com/Starry-OS/StarryOS/issues)
- 团队内部沟通渠道（Slack/微信/钉钉等）

---

## 📈 预期收益

使用 Docker 统一开发环境后，团队可以获得：

| 收益 | 量化目标 |
|------|---------|
| **环境配置时间** | 从 2-4 小时减少到 **< 5 分钟**（使用预构建镜像） |
| **环境一致性问题** | 减少 **90%+** 的"在我机器上能跑"问题 |
| **新成员上手时间** | 从 1-2 天减少到 **< 1 小时** |
| **CI/CD 可靠性** | 提升 **100%**（环境固定，无漂移） |
| **跨平台支持** | 支持 **Linux/macOS/Windows** 开发 |

---

## 📝 总结

### 为什么选择 Docker？

1. **QEMU 10+ 要求**：系统默认版本不满足 LoongArch64 需求
2. **Rust 工具链锁定**：nightly-2025-05-20 必须精确匹配
3. **依赖工具多**：Cargo 工具、Musl 工具链、构建工具等
4. **团队协作**：消除环境差异，提高开发效率

### 推荐方案

**对于团队**：
- ✅ 使用 Docker 作为标准开发环境
- ✅ 建立私有镜像仓库加速分发
- ✅ 集成到 CI/CD 流程

**对于个人开发者**：
- ✅ 优先使用 Docker
- 如有特殊需求（如本地调试器集成），可配合原生环境

---

**下一步行动**：

1. **立即尝试**：运行 `docker-compose build && docker-compose run --rm starryos-dev`
2. **阅读文档**：[docs/docker-guide.md](docs/docker-guide.md)
3. **团队讨论**：根据本指南制定迁移计划

**文档生成日期**：2025-11-26
**维护者**：StarryOS Team
