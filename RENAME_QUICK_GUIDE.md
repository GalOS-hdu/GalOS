# 🚀 快速重命名指南：StarryOS → GalOS

> 完整指南请查看：[RENAME_TO_GALOS.md](RENAME_TO_GALOS.md)

## 立即行动：3 步完成重命名

### 方案 A：自动化脚本（推荐，5 分钟）

```bash
# 1. 查看将要修改的内容（可选）
./rename-to-galos.sh --dry-run

# 2. 执行自动化重命名
./rename-to-galos.sh

# 3. 验证修改
git diff
cargo build --dry-run
docker-compose config
```

### 方案 B：手动重命名（需要 30 分钟+）

参见详细指南：[RENAME_TO_GALOS.md](RENAME_TO_GALOS.md)

---

## 📊 需要修改的内容速览

### 核心配置（必须修改）

| 文件 | 修改内容 | 重要性 |
|------|---------|--------|
| **Cargo.toml** | `name = "starry"` → `name = "galos"` | 🔴 必须 |
| **docker-compose.yml** | 服务名、镜像名、路径 | 🔴 必须 |
| **Dockerfile** | 标签和描述 | 🟡 推荐 |
| **.github/workflows/docker-ci.yml** | 容器名 | 🟡 推荐 |

### 文档（推荐修改）

- `README.md`
- `docs/docker-guide.md`
- `docs/environment-requirements.md`
- 所有上传指南文档

### 文件夹名称

```bash
cd /home/c20h30o2/files
mv StarryOS GalOS
cd GalOS
```

---

## ✅ 修改后验证清单

### 立即验证

```bash
# 1. 检查 Git 修改
git status
git diff Cargo.toml
git diff docker-compose.yml

# 2. 验证配置有效性
cargo metadata --format-version 1 > /dev/null
docker-compose config > /dev/null

# 3. 搜索遗漏的引用
grep -r "StarryOS" --include="*.toml" --include="*.yml" . | grep -v ".git/"
grep -r "starryos" --include="*.toml" --include="*.yml" . | grep -v ".git/"
```

### 构建测试

```bash
# 测试 Cargo 构建
cargo build --dry-run

# 测试 Docker 构建
docker-compose build galos-dev

# 测试容器启动
docker-compose run --rm galos-dev bash -c "rustc --version"
```

---

## ⚠️ 重要提示

### ✅ 需要修改的

- 项目名称：`StarryOS` → `GalOS`
- Cargo package：`starry` → `galos`
- Docker 服务：`starryos-dev` → `galos-dev`
- 工作目录路径：`/workspace/StarryOS` → `/workspace/GalOS`

### ❌ 不需要修改的

- 子模块 `arceos`（保持不变）
- 外部依赖：`starry-process`, `starry-signal`, `starry-vm`, `starry-core`, `starry-api`（这些是外部 crate）
- Git 历史（自动保留）

---

## 🔄 自动化脚本功能

`rename-to-galos.sh` 会自动：

- ✅ 创建备份（可选）
- ✅ 批量替换所有文件中的 `StarryOS` → `GalOS`
- ✅ 批量替换所有文件中的 `starryos` → `galos`
- ✅ 验证 Cargo 和 Docker 配置有效性
- ✅ 生成详细日志（`rename.log`）
- ✅ 提供回滚指导

**选项**：
- `--dry-run`：只显示将要修改的内容，不实际执行
- `--no-backup`：不创建备份（不推荐）

---

## 📝 提交建议

```bash
# 查看所有修改
git add .
git status

# 提交修改
git commit -m "refactor: rename project from StarryOS to GalOS

- Rename Cargo package name to 'galos'
- Update Docker service names (starryos-dev → galos-dev)
- Update all documentation references
- Update GitHub Actions workflow
- Update environment setup script
- Update working directory paths (/workspace/GalOS)

BREAKING CHANGE: Project name changed from StarryOS to GalOS.
Users need to update their local environment:
- Re-clone the repository
- Update Docker service names in commands
- Update any custom scripts referencing the old name"
```

---

## 🆘 出现问题？

### 回滚到原始状态

```bash
# 如果使用了自动化脚本（有备份）
cd /home/c20h30o2/files
rm -rf GalOS
mv StarryOS-backup-YYYYMMDD-HHMMSS StarryOS
cd StarryOS
```

### 查看脚本日志

```bash
cat rename.log
```

### 手动修复特定文件

```bash
# 查看某个文件的修改
git diff Cargo.toml

# 恢复某个文件（如果改错了）
git checkout Cargo.toml
```

---

## 🎯 完成后的下一步

1. **测试构建**：
   ```bash
   make clean
   docker-compose build galos-dev
   docker-compose run --rm galos-dev bash -c "make build"
   ```

2. **更新 Git 远程仓库**（如果需要）：
   ```bash
   git remote set-url origin git@github.com:YOUR_ORG/GalOS.git
   ```

3. **通知团队成员**：
   - 项目已重命名为 GalOS
   - 新的 Docker 服务名是 `galos-dev`
   - 需要重新克隆或更新本地仓库

4. **更新 README.md**：
   - 确保项目描述准确
   - 更新快速开始指南中的命令

---

## 📚 相关文档

- **详细指南**：[RENAME_TO_GALOS.md](RENAME_TO_GALOS.md)
- **Docker 使用**：[docs/docker-guide.md](docs/docker-guide.md)
- **环境依赖**：[docs/environment-requirements.md](docs/environment-requirements.md)

---

**预计时间**：
- 使用自动化脚本：5-10 分钟
- 手动修改：30-60 分钟

**推荐方式**：先运行 `./rename-to-galos.sh --dry-run` 查看预览，确认无误后执行 `./rename-to-galos.sh`。

祝重命名顺利！🎉
