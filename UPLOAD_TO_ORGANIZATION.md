# 上传项目到团队 GitHub Organization 指南

本文档提供将 GalOS 项目（包含 Docker 配置）上传到团队 GitHub Organization 仓库的完整步骤和注意事项。

## 📋 目录

1. [准备工作](#准备工作)
2. [上传步骤](#上传步骤)
3. [重要注意事项](#重要注意事项)
4. [验证检查清单](#验证检查清单)
5. [团队协作设置](#团队协作设置)
6. [常见问题](#常见问题)

---

## 🎯 当前项目状态

### 项目信息

- **当前仓库**：`Starry-OS/GalOS`（上游原始仓库）
- **当前分支**：`main`
- **提交历史**：保留了上游完整历史
- **子模块**：`arceos` (commit: 4d1be13)
- **新增文件**：Docker 配置、文档、脚本等

### 新增的文件（7个）

| 文件 | 类型 | 大小 | 说明 |
|------|------|------|------|
| `Dockerfile` | 配置 | ~5KB | Docker 镜像定义 |
| `docker-compose.yml` | 配置 | ~2KB | Docker Compose 配置 |
| `.dockerignore` | 配置 | ~1KB | Docker 构建忽略规则 |
| `setup-env.sh` | 脚本 | ~10KB | 环境配置脚本 |
| `docs/docker-guide.md` | 文档 | ~25KB | Docker 使用指南 |
| `docs/environment-requirements.md` | 文档 | ~20KB | 环境依赖清单 |
| `DOCKER_MIGRATION_GUIDE.md` | 文档 | ~15KB | 团队迁移指南 |

---

## 🚀 上传步骤

### 方案选择

根据你的需求，选择以下方案之一：

#### 方案 A：保留上游历史（推荐）

**适用场景**：
- 希望保留原项目的完整 Git 历史
- 方便未来与上游同步更新
- 团队需要追溯历史提交记录

**优点**：
- ✅ 保留所有原始提交记录和作者信息
- ✅ 可以追溯功能演进历史
- ✅ 方便未来合并上游更新

**缺点**：
- ⚠️ 历史包含上游所有提交（可能有上百个）
- ⚠️ 团队成员克隆时会下载完整历史

---

#### 方案 B：从零开始（干净历史）

**适用场景**：
- 希望团队仓库有干净的起点
- 不需要追溯上游历史
- 独立维护，不计划与上游同步

**优点**：
- ✅ 仓库历史干净，只有团队提交
- ✅ 初始提交大小较小

**缺点**：
- ❌ 失去上游历史信息
- ❌ 难以与上游合并更新

---

### 📝 详细步骤

#### 方案 A：保留上游历史（推荐）

**步骤 1：在 GitHub 上创建团队仓库**

1. 登录 GitHub
2. 进入你的 Organization 页面
3. 点击 "New repository"
4. 填写仓库信息：
   - **Repository name**: `GalOS`（或自定义名称）
   - **Description**: `GalOS - A kernel based on ArceOS with Docker development environment`
   - **Visibility**:
     - `Private`（推荐）：仅团队成员可见
     - `Public`：开源项目
   - **不要勾选**：
     - ❌ Add a README file
     - ❌ Add .gitignore
     - ❌ Choose a license
   - （保持空仓库，我们会推送现有内容）

**步骤 2：配置本地仓库**

```bash
# 进入项目目录
cd /home/c20h30o2/files/GalOS

# 查看当前远程仓库
git remote -v
# 输出: origin	git@github.com:Starry-OS/GalOS.git (fetch)
#       origin	git@github.com:Starry-OS/GalOS.git (push)

# 重命名当前 origin 为 upstream（保留上游引用）
git remote rename origin upstream

# 添加团队仓库为新的 origin
# 将下面的 YOUR_ORG 替换为你的 Organization 名称
git remote add origin git@github.com:YOUR_ORG/GalOS.git

# 验证远程仓库
git remote -v
# 应该输出：
# origin    git@github.com:YOUR_ORG/GalOS.git (fetch)
# origin    git@github.com:YOUR_ORG/GalOS.git (push)
# upstream  git@github.com:Starry-OS/GalOS.git (fetch)
# upstream  git@github.com:Starry-OS/GalOS.git (push)
```

**步骤 3：添加新文件到 Git**

```bash
# 查看未跟踪的文件
git status

# 添加所有新文件
git add .dockerignore \
        Dockerfile \
        docker-compose.yml \
        setup-env.sh \
        docs/docker-guide.md \
        docs/environment-requirements.md \
        DOCKER_MIGRATION_GUIDE.md \
        UPLOAD_TO_ORGANIZATION.md

# 同时添加更新的 .gitignore
git add .gitignore

# 查看将要提交的文件
git status
```

**步骤 4：创建初始提交**

```bash
# 创建提交
git commit -m "feat: add Docker development environment and documentation

- Add Dockerfile with QEMU 10.2.0 for LoongArch64 support
- Add docker-compose.yml for development and CI environments
- Add comprehensive documentation for Docker setup
- Add environment requirements specification
- Add setup script for automated configuration
- Update .gitignore for Docker artifacts

This commit prepares the project for team development with
unified development environment using Docker containers."

# 或使用更简洁的提交信息
git commit -m "feat: add Docker development environment

Add Docker configuration, documentation, and setup scripts
for unified team development environment with QEMU 10+ support."
```

**步骤 5：推送到团队仓库**

```bash
# 推送主分支（包含完整历史）
git push -u origin main

# 如果需要推送其他分支
# git push -u origin <branch-name>

# 推送所有标签（如果有）
git push --tags
```

**步骤 6：验证子模块**

```bash
# 确保子模块信息正确
cat .gitmodules

# 团队成员克隆后需要执行：
# git clone --recursive git@github.com:YOUR_ORG/GalOS.git
```

---

#### 方案 B：从零开始（干净历史）

**步骤 1：在 GitHub 上创建团队仓库**

（与方案 A 相同）

**步骤 2：创建新的 Git 仓库**

```bash
# 进入项目目录
cd /home/c20h30o2/files/GalOS

# 备份当前 .git 目录（以防需要恢复）
mv .git .git.backup

# 初始化新的 Git 仓库
git init

# 添加团队仓库为远程
git remote add origin git@github.com:YOUR_ORG/GalOS.git

# 可选：保留上游引用
git remote add upstream git@github.com:Starry-OS/GalOS.git
```

**步骤 3：添加所有文件**

```bash
# 添加所有文件
git add .

# 检查将要提交的文件
git status

# 确保没有大文件或敏感信息
# 特别检查：
# - rootfs-*.img 文件应该被忽略
# - target/ 目录应该被忽略
# - *.elf, *.bin 应该被忽略
```

**步骤 4：创建初始提交**

```bash
git commit -m "feat: initial commit with Docker development environment

This is the initial version of GalOS project for team development.

Features:
- Based on ArceOS kernel framework
- Docker development environment with QEMU 10+
- Support for RISC-V 64, LoongArch 64, x86_64, AArch64
- Comprehensive documentation
- Automated setup scripts

Project structure:
- /api: API definitions
- /core: Core functionality
- /arceos: ArceOS submodule
- /docs: Documentation
- /scripts: Build and test scripts"
```

**步骤 5：添加子模块**

```bash
# 如果从零开始，需要重新添加子模块
git submodule add https://github.com/arceos-org/arceos.git arceos
cd arceos
git checkout 4d1be13842ab800e585c375f723694224b4a1a7e
cd ..
git add .gitmodules arceos
git commit -m "chore: add arceos submodule"
```

**步骤 6：推送到团队仓库**

```bash
# 推送主分支
git push -u origin main
```

---

## ⚠️ 重要注意事项

### 1. 不要提交的文件（已在 .gitignore 中）

| 文件/目录 | 原因 | 大小 |
|----------|------|------|
| `rootfs-*.img` | 根文件系统镜像，太大 | 1GB |
| `*.xz` | 压缩的镜像文件 | 数百 MB |
| `target/` | Rust 编译产物 | 可能数 GB |
| `*.elf`, `*.bin` | 二进制可执行文件 | 数 MB |
| `disk.img` | 虚拟磁盘镜像 | 数百 MB |
| `qemu.log` | QEMU 日志 | 可变 |
| `.axconfig.toml` | 自动生成的配置 | 小 |

**验证命令**：
```bash
# 确认这些文件/目录没有被 git 跟踪
git status --ignored
```

### 2. 子模块处理

**当前子模块状态**：
- `arceos` @ commit `4d1be13842ab800e585c375f723694224b4a1a7e`

**团队成员克隆时**：
```bash
# 方法 1：克隆时包含子模块
git clone --recursive git@github.com:YOUR_ORG/GalOS.git

# 方法 2：克隆后初始化子模块
git clone git@github.com:YOUR_ORG/GalOS.git
cd GalOS
git submodule update --init --recursive
```

**更新子模块**：
```bash
# 更新到最新版本
cd arceos
git pull origin main
cd ..
git add arceos
git commit -m "chore: update arceos submodule"
```

### 3. 大文件检查

**在推送前检查大文件**：
```bash
# 查找大于 10MB 的文件
find . -type f -size +10M -not -path "./.git/*" -exec ls -lh {} \;

# 应该只看到 rootfs-*.img（已被 .gitignore 忽略）
```

### 4. 敏感信息检查

**确保没有提交敏感信息**：
```bash
# 搜索潜在的敏感文件
git ls-files | grep -E '\.(env|key|pem|p12|pfx|secret|credential)'

# 应该没有输出
```

### 5. 分支策略

建议团队使用以下分支策略：

| 分支 | 用途 | 保护规则 |
|------|------|---------|
| `main` | 稳定版本 | 禁止直接推送，需要 PR |
| `dev` | 开发分支 | 允许推送，鼓励 PR |
| `feature/*` | 功能开发 | 临时分支，完成后删除 |
| `fix/*` | Bug 修复 | 临时分支，完成后删除 |

**创建开发分支**：
```bash
# 在推送 main 后
git checkout -b dev
git push -u origin dev
```

---

## ✅ 验证检查清单

在推送到团队仓库前，请完成以下检查：

### 基本检查

- [ ] ✅ GitHub Organization 仓库已创建
- [ ] ✅ 本地 Git 远程配置正确（`git remote -v`）
- [ ] ✅ 所有新文件已添加（`git status`）
- [ ] ✅ `.gitignore` 已更新
- [ ] ✅ 没有大文件被跟踪（rootfs-*.img, *.xz, target/）
- [ ] ✅ 没有敏感信息（密钥、密码、token）
- [ ] ✅ 提交信息清晰准确

### 功能验证

- [ ] ✅ 子模块配置正确（`.gitmodules` 存在）
- [ ] ✅ Docker 配置文件完整（Dockerfile, docker-compose.yml）
- [ ] ✅ 文档齐全（README.md, docker-guide.md, 等）
- [ ] ✅ 脚本可执行（setup-env.sh 有执行权限）

### 构建验证（推送前最后检查）

```bash
# 1. 清理环境
make clean
rm -f *.img *.xz

# 2. 验证构建（可选，在 Docker 中）
docker-compose build
docker-compose run --rm galos-dev bash -c "make build"

# 3. 检查 git 状态
git status
# 应该显示：nothing to commit, working tree clean
```

---

## 🤝 团队协作设置

### 1. 仓库设置（在 GitHub 上）

#### 基本设置

1. **Settings** → **General**
   - Description: 填写项目描述
   - Topics: 添加标签（如 `os`, `kernel`, `rust`, `docker`, `riscv`, `loongarch`）
   - Features:
     - ✅ Issues（启用问题跟踪）
     - ✅ Projects（启用项目管理）
     - ✅ Preserve this repository（存档保护）

2. **Settings** → **Branches**
   - Default branch: `main`
   - Branch protection rules for `main`:
     - ✅ Require pull request reviews before merging
     - ✅ Require status checks to pass before merging
     - ✅ Require branches to be up to date before merging
     - ✅ Include administrators

#### 访问控制

**Settings** → **Collaborators and teams**

| 团队/成员 | 权限 | 说明 |
|----------|------|------|
| Maintainers | Admin | 项目维护者，可修改设置 |
| Core Developers | Write | 核心开发者，可直接推送到 dev |
| Contributors | Write | 贡献者，通过 PR 提交 |
| Reviewers | Triage | 仅审查和评论权限 |

### 2. CI/CD 配置（推荐）

创建 `.github/workflows/ci.yml`：

```yaml
name: CI

on:
  push:
    branches: [ main, dev ]
  pull_request:
    branches: [ main, dev ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [riscv64, loongarch64, x86_64, aarch64]

    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        submodules: recursive

    - name: Build Docker image
      run: docker-compose build

    - name: Build GalOS
      run: |
        docker-compose run --rm galos-dev \
          bash -c "make ARCH=${{ matrix.arch }} build"

    - name: Prepare rootfs
      run: |
        docker-compose run --rm galos-dev \
          bash -c "make ARCH=${{ matrix.arch }} img"

    - name: Run tests
      run: |
        docker-compose run --rm galos-dev \
          bash -c "python3 scripts/ci-test.py ${{ matrix.arch }}"
```

### 3. 团队开发流程

#### 标准工作流程

```bash
# 1. 克隆团队仓库
git clone --recursive git@github.com:YOUR_ORG/GalOS.git
cd GalOS

# 2. 创建功能分支
git checkout -b feature/my-feature

# 3. 开发（使用 Docker）
docker-compose run --rm galos-dev

# 4. 提交更改
git add <files>
git commit -m "feat: add new feature"

# 5. 推送并创建 PR
git push -u origin feature/my-feature
# 然后在 GitHub 上创建 Pull Request
```

#### 代码审查规范

- **提交前**：
  - ✅ 代码通过 `cargo fmt` 格式化
  - ✅ 代码通过 `cargo clippy` 检查
  - ✅ 所有测试通过
  - ✅ 提交信息符合规范（见下文）

- **PR 要求**：
  - 标题清晰，描述变更内容
  - 关联相关 Issue（如有）
  - 至少 1 名审查者批准
  - CI 检查全部通过

#### 提交信息规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**类型（type）**：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例**：
```bash
git commit -m "feat(docker): add multi-stage Dockerfile with QEMU 10

- Build QEMU 10.2.0 from source for LoongArch64 support
- Add Rust nightly-2025-05-20 with all required components
- Include Musl cross-compilation toolchains
- Optimize image size using multi-stage build

Closes #123"
```

### 4. 文档维护

**团队文档结构**：

```
docs/
├── docker-guide.md              # Docker 使用指南
├── environment-requirements.md  # 环境依赖
├── development-guide.md         # 开发指南（建议新建）
├── api-reference.md             # API 文档（建议新建）
└── troubleshooting.md           # 故障排查（建议新建）
```

---

## 🐛 常见问题

### Q1: 推送时提示 "Permission denied"

**原因**：SSH 密钥未配置或权限不足

**解决方案**：
```bash
# 检查 SSH 密钥
ssh -T git@github.com
# 应该显示: Hi YOUR_USERNAME! You've successfully authenticated...

# 如果失败，配置 SSH 密钥
# 参考: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
```

### Q2: 子模块没有正确推送

**原因**：子模块是引用，不是完整内容

**解决方案**：
```bash
# 确保 .gitmodules 文件被提交
git add .gitmodules
git commit -m "chore: add submodule configuration"

# 团队成员克隆时使用 --recursive
git clone --recursive <repo-url>
```

### Q3: 推送后发现提交了大文件

**解决方案**：
```bash
# 方法 1：如果还没有其他人拉取，强制推送覆盖
# (谨慎使用！)
git reset --soft HEAD~1
git reset HEAD <large-file>
echo "<large-file-pattern>" >> .gitignore
git add .gitignore
git commit -m "fix: remove large file and update .gitignore"
git push --force

# 方法 2：使用 BFG Repo-Cleaner 清理历史
# https://rtyley.github.io/bfg-repo-cleaner/
```

### Q4: 如何与上游 Starry-OS/GalOS 同步更新？

**仅适用于方案 A（保留历史）**：

```bash
# 1. 确保有 upstream 远程
git remote -v
# 应该看到 upstream	git@github.com:Starry-OS/GalOS.git

# 2. 拉取上游更新
git fetch upstream

# 3. 合并到本地分支
git checkout main
git merge upstream/main

# 4. 解决冲突（如果有）

# 5. 推送到团队仓库
git push origin main
```

### Q5: Docker 镜像太大，如何优化？

**优化方案**：
1. 使用 `.dockerignore` 排除不必要的文件
2. 多阶段构建（已实现）
3. 清理构建缓存：
   ```bash
   docker-compose build --no-cache
   docker system prune -a
   ```
4. 使用私有镜像仓库缓存

---

## 📞 获取帮助

- **项目文档**：查看 `docs/` 目录
- **GitHub Issues**：提交问题到团队仓库的 Issues
- **内部沟通**：联系项目维护者

---

## 🎉 完成后的下一步

上传成功后，建议：

1. **📝 更新 README.md**：添加团队仓库链接和徽章
2. **👥 邀请团队成员**：在 GitHub 上添加协作者
3. **🔧 配置 CI/CD**：设置 GitHub Actions（见上文）
4. **📋 创建初始 Issues**：规划任务和功能
5. **📢 团队通知**：告知团队成员新仓库地址

**团队成员开始开发**：
```bash
git clone --recursive git@github.com:YOUR_ORG/GalOS.git
cd GalOS
docker-compose build
docker-compose run --rm galos-dev
```

---

**祝项目顺利！** 🚀

如有问题，请参考 [docker-guide.md](docs/docker-guide.md) 或联系项目维护者。
