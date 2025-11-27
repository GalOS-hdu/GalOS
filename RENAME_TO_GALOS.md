# 项目重命名指南：StarryOS → GalOS

本指南详细说明将项目从 StarryOS 重命名为 GalOS 需要修改的所有内容。

## 📊 影响范围统计

通过扫描发现，项目中共有 **109 处** "StarryOS" 引用和 **30+ 处** "starryos" 引用需要修改。

---

## 🔧 需要修改的内容分类

### 1️⃣ 文件夹名称（最外层）

```bash
# 当前路径
/home/c20h30o2/files/StarryOS

# 重命名后
/home/c20h30o2/files/GalOS
```

**操作**：
```bash
cd /home/c20h30o2/files
mv StarryOS GalOS
cd GalOS
```

---

### 2️⃣ Cargo 项目配置（1 个文件）

#### `Cargo.toml`

**需要修改**：
- **第 83 行**：`name = "starry"` → `name = "galos"`
- **第 19 行**：`repository = "https://github.com/arceos-org/starry-next"` → 改为你的团队仓库

**不需要修改**（这些是外部依赖）：
- `starry-process`
- `starry-signal`
- `starry-vm`
- `starry-core`
- `starry-api`

**修改示例**：
```toml
[package]
name = "galos"  # 改这里
version.workspace = true
edition.workspace = true
authors.workspace = true
license.workspace = true
homepage.workspace = true
repository.workspace = true  # 可选：改为你的仓库地址
```

---

### 3️⃣ Docker 配置（2 个文件）

#### `Dockerfile`

**需要修改的行**：
- **第 1 行**：注释 `# StarryOS Development Environment` → `# GalOS Development Environment`
- **第 35 行**：`LABEL maintainer="StarryOS Team"` → `LABEL maintainer="GalOS Team"`
- **第 36 行**：`LABEL description="StarryOS Development Environment..."` → `LABEL description="GalOS Development Environment..."`

#### `docker-compose.yml`

**需要修改的行**：
- **服务名**：`starryos-dev` → `galos-dev`（2 处）
- **镜像名**：`image: starryos-dev:latest` → `image: galos-dev:latest`（2 处）
- **容器名**：`container_name: starryos-dev` → `container_name: galos-dev`（2 处）
- **工作目录**：`/workspace/StarryOS` → `/workspace/GalOS`（4 处）
- **挂载路径**：`.:/workspace/StarryOS` → `.:/workspace/GalOS`（2 处）
- **target 路径**：`/workspace/StarryOS/target` → `/workspace/GalOS/target`

**修改示例**：
```yaml
services:
  galos-dev:  # 改这里
    build:
      context: .
      dockerfile: Dockerfile
    image: galos-dev:latest  # 改这里
    container_name: galos-dev  # 改这里

    volumes:
      - .:/workspace/GalOS  # 改这里
      - cargo-cache:/usr/local/cargo/registry
      - cargo-git-cache:/usr/local/cargo/git
      - target-cache:/workspace/GalOS/target  # 改这里

    working_dir: /workspace/GalOS  # 改这里
```

---

### 4️⃣ GitHub Actions CI/CD（1 个文件）

#### `.github/workflows/docker-ci.yml`

**需要修改的行**：
- 所有 `starryos-dev` → `galos-dev`（4 处）
- 所有 `Build StarryOS` 相关描述 → `Build GalOS`

**修改示例**：
```yaml
- name: Build GalOS for ${{ matrix.arch }}
  run: |
    docker-compose run --rm galos-dev \
      bash -c "make ARCH=${{ matrix.arch }} build"

- name: Prepare rootfs for ${{ matrix.arch }}
  run: |
    docker-compose run --rm galos-dev \
      bash -c "make ARCH=${{ matrix.arch }} img"

- name: Run CI tests for ${{ matrix.arch }}
  run: |
    docker-compose run --rm galos-dev \
      bash -c "python3 scripts/ci-test.py ${{ matrix.arch }}"
```

---

### 5️⃣ 文档文件（8+ 个文件）

需要批量替换的文档：

| 文件 | StarryOS 出现次数 | 主要修改内容 |
|------|------------------|-------------|
| `README.md` | ~5 | 项目名称、描述 |
| `docs/docker-guide.md` | ~30 | 所有 StarryOS 和 starryos-dev |
| `docs/environment-requirements.md` | ~15 | 项目名称、路径、仓库地址 |
| `docs/x11.md` | ~3 | 项目名称 |
| `UPLOAD_TO_ORGANIZATION.md` | ~20 | 仓库名、路径、容器名 |
| `QUICK_START_UPLOAD.md` | ~15 | 仓库名、路径、容器名 |
| `TEAM_UPLOAD_CHECKLIST.md` | ~10 | 项目名称、路径 |
| `DOCKER_MIGRATION_GUIDE.md` | ~10 | 项目名称、容器名 |
| `CONTRIBUTING.md` | 未知 | 项目名称、仓库地址 |

**通用替换规则**：
- `StarryOS` → `GalOS`
- `starryos-dev` → `galos-dev`
- `starryos-ci` → `galos-ci`
- `/workspace/StarryOS` → `/workspace/GalOS`
- `git@github.com:Starry-OS/StarryOS.git` → `git@github.com:YOUR_ORG/GalOS.git`

---

### 6️⃣ 环境配置脚本（1 个文件）

#### `setup-env.sh`

**需要修改的行**：
- 标题：`StarryOS Environment Setup` → `GalOS Environment Setup`
- 容器名：所有 `starryos-dev` → `galos-dev`（多处）
- 项目名：所有 `StarryOS` → `GalOS`

---

### 7️⃣ GitHub Issue/PR 模板（可选）

#### `.github/ISSUE_TEMPLATE/config.yml`

**需要修改的行**：
- `url: https://github.com/Starry-OS/StarryOS/discussions` → 改为你的团队仓库

---

## 🤖 自动化重命名脚本

我为你准备了自动化脚本，在下一步提供。

---

## ⚠️ 不需要修改的内容

### 1. 子模块
- `arceos` 子模块路径和配置**不需要修改**
- `.gitmodules` 文件**不需要修改**

### 2. 外部依赖包名
在 `Cargo.toml` 中，这些**保持不变**：
- `starry-process`
- `starry-signal`
- `starry-vm`
- `starry-core`
- `starry-api`

这些是外部 crate，不是你项目的一部分。

### 3. Git 历史
- Git 提交历史**不受影响**
- 远程仓库配置（如果已设置）需要单独更新

---

## 📋 重命名检查清单

在执行重命名后，请验证以下内容：

### 基本验证
- [ ] 文件夹名称已改为 `GalOS`
- [ ] `Cargo.toml` 中的 `name` 已改为 `"galos"`
- [ ] Docker 配置文件已更新（服务名、镜像名、路径）
- [ ] GitHub Actions 配置已更新

### 构建验证
- [ ] `cargo build` 能正常编译
- [ ] `docker-compose build` 能正常构建镜像
- [ ] `docker-compose run --rm galos-dev` 能正常启动容器
- [ ] `make build` 在容器内能正常执行

### 文档验证
- [ ] 所有文档中的项目名称已更新
- [ ] README.md 中的描述准确
- [ ] 链接和路径正确（如果引用了 GitHub 仓库）

### Git 验证
- [ ] `git status` 显示所有修改的文件
- [ ] 提交信息准确描述了重命名操作
- [ ] 远程仓库地址正确（如果需要）

---

## 🚀 推荐的重命名流程

### 选项 A：使用自动化脚本（推荐）

```bash
# 1. 进入项目目录
cd /home/c20h30o2/files/StarryOS

# 2. 运行重命名脚本
./rename-to-galos.sh

# 3. 验证修改
git diff
```

### 选项 B：手动重命名

```bash
# 1. 备份项目（可选但推荐）
cd /home/c20h30o2/files
cp -r StarryOS StarryOS-backup

# 2. 重命名文件夹
mv StarryOS GalOS
cd GalOS

# 3. 手动编辑以上列出的所有文件

# 4. 验证修改
git diff
cargo build --dry-run
docker-compose config
```

---

## 🔍 验证命令

### 检查是否还有遗漏的引用

```bash
# 在 GalOS 目录下执行
cd /home/c20h30o2/files/GalOS

# 搜索 StarryOS（应该只在文档中出现，如迁移说明）
grep -r "StarryOS" --include="*.toml" --include="*.yml" --include="*.sh" --include="Dockerfile" . | grep -v ".git/"

# 搜索 starryos（应该只在文档中出现）
grep -r "starryos" --include="*.toml" --include="*.yml" --include="*.sh" --include="Dockerfile" . | grep -v ".git/"

# 搜索旧的工作目录路径
grep -r "/workspace/StarryOS" --include="*.yml" . | grep -v ".git/"
```

### 测试构建

```bash
# 测试 Cargo 配置
cargo metadata --format-version 1 | grep -i "galos"

# 测试 Docker Compose 配置
docker-compose config | grep -E "(galos|GalOS)"

# 测试 Docker 构建
docker-compose build galos-dev

# 测试容器启动
docker-compose run --rm galos-dev bash -c "echo 'GalOS container works!'"
```

---

## 📝 Git 提交建议

重命名完成后，建议的提交信息：

```bash
git add .
git commit -m "refactor: rename project from StarryOS to GalOS

- Rename Cargo package name to 'galos'
- Update Docker service names and paths
- Update all documentation references
- Update GitHub Actions workflow
- Update environment setup script

BREAKING CHANGE: Project name changed from StarryOS to GalOS.
Docker service name changed from starryos-dev to galos-dev."
```

---

## 🔗 后续步骤

重命名完成后：

1. **更新 README.md**
   - 确保项目描述准确
   - 更新徽章（如果有）
   - 更新快速开始指南

2. **更新 Git 远程仓库**（如果需要）
   ```bash
   git remote set-url origin git@github.com:YOUR_ORG/GalOS.git
   ```

3. **通知团队成员**
   - 新的项目名称
   - 新的仓库地址
   - 新的 Docker 服务名
   - 重新克隆或更新本地仓库的步骤

4. **更新 CI/CD**
   - 确保 GitHub Actions 使用正确的名称
   - 更新任何外部 CI 系统的配置

5. **更新文档链接**
   - 检查所有指向 GitHub 仓库的链接
   - 更新团队文档（Wiki、Confluence 等）

---

## 📞 获取帮助

如果在重命名过程中遇到问题：

1. **检查语法错误**：
   ```bash
   # YAML 语法检查
   docker-compose config

   # TOML 语法检查
   cargo metadata
   ```

2. **恢复备份**（如果出错）：
   ```bash
   cd /home/c20h30o2/files
   rm -rf GalOS
   cp -r StarryOS-backup StarryOS
   ```

3. **查看脚本日志**：
   - 自动化脚本会生成 `rename.log` 文件

---

**下一步**：运行 `./rename-to-galos.sh` 脚本或手动按照本指南进行修改。
