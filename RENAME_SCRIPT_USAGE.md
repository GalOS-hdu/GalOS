# 重命名脚本使用说明

## 🐛 原脚本为什么没效果？

### 问题分析

**原脚本** (`rename-to-galos.sh`) 检测逻辑有问题：

```bash
# 原脚本的检测逻辑
if ! grep -q -E "(${OLD_NAME_UPPER}|${OLD_NAME_LOWER})" "$file"
```

这会搜索 `"StarryOS"` 或 `"starryos"`，但是：

1. **Cargo.toml 中实际内容**：
   ```toml
   name = "starry"  # 不是 "starryos"！
   ```

2. **没有匹配到**，所以脚本跳过了 Cargo.toml

3. **结果**：脚本说"文件无需修改"，实际上是检测逻辑不对

---

## ✅ 使用修复版脚本

### 1. 先预览（推荐）

```bash
# 查看将要修改的内容，不实际执行
./rename-to-galos-fixed.sh --dry-run
```

**输出示例**：
```
[INFO] 开始项目重命名：StarryOS → GalOS
[WARNING] 运行在 DRY-RUN 模式，不会实际修改文件
[INFO] 开始替换文件内容...

[INFO] [DRY-RUN] 将在 Cargo.toml 中替换: package name: starry → galos
  匹配的行：
    83:name = "starry"

[INFO] [DRY-RUN] 将在 docker-compose.yml 中替换: Docker service name
  匹配的行：
    4:  starryos-dev:
    15:    image: starryos-dev:latest
    16:    container_name: starryos-dev
...
```

### 2. 执行重命名

```bash
# 确认无误后，执行实际修改
./rename-to-galos-fixed.sh
```

**输出示例**：
```
[INFO] 开始项目重命名：StarryOS → GalOS
[INFO] 开始替换文件内容...

[SUCCESS] ✓ 已修改 Cargo.toml: package name: starry → galos
[SUCCESS] ✓ 已修改 docker-compose.yml: Docker service name
[SUCCESS] ✓ 已修改 docker-compose.yml: workspace path
[SUCCESS] ✓ 已修改 Dockerfile: Dockerfile comment
...

[INFO] 验证修改结果...
[SUCCESS] ✓ Cargo.toml package name 已更新为 'galos'
[SUCCESS] ✓ docker-compose.yml 已更新
[SUCCESS] ✓ Docker Compose 配置有效
[SUCCESS] ✓ Cargo 配置有效
  Package name: galos

========================================
[SUCCESS] 重命名完成！

[INFO] 修改摘要：
  - Cargo package: starry → galos
  - Docker service: starryos-dev → galos-dev
  - 工作目录: /workspace/StarryOS → /workspace/GalOS
  - 所有文档已更新

[INFO] 下一步操作：
  1. 检查修改: git diff
  2. 测试构建: cargo build
  3. 测试 Docker: docker-compose build galos-dev
  4. 重命名文件夹:
       cd ..
       mv StarryOS GalOS
       cd GalOS
  5. 提交修改: git add . && git commit
========================================
```

### 3. 验证修改

```bash
# 查看 Git 修改
git diff

# 查看具体修改的文件
git diff Cargo.toml
git diff docker-compose.yml
git diff Dockerfile

# 验证配置有效性
cargo metadata --format-version 1 > /dev/null && echo "Cargo OK"
docker-compose config > /dev/null && echo "Docker Compose OK"
```

### 4. 重命名文件夹

```bash
# 退出当前目录
cd ..

# 重命名文件夹
mv StarryOS GalOS

# 进入新目录
cd GalOS
```

### 5. 测试构建

```bash
# 测试 Cargo 构建
cargo build --dry-run

# 测试 Docker 构建
docker-compose build galos-dev

# 测试容器启动
docker-compose run --rm galos-dev bash -c "rustc --version && echo 'GalOS container works!'"
```

### 6. 提交修改

```bash
git add .
git commit -m "refactor: rename project from StarryOS to GalOS

- Rename Cargo package: starry → galos
- Update Docker service: starryos-dev → galos-dev
- Update workspace paths: /workspace/StarryOS → /workspace/GalOS
- Update all documentation

BREAKING CHANGE: Project name changed to GalOS"
```

---

## 📊 修复版脚本改了什么？

### 核心差异

| 方面 | 原脚本 | 修复版 |
|------|--------|--------|
| **检测方式** | 搜索 "StarryOS" 或 "starryos" | 精确匹配具体内容 |
| **Cargo.toml** | ❌ 跳过（未检测到） | ✅ 修改 `name = "starry"` |
| **替换方式** | 全局替换 | 针对性替换 |
| **文档处理** | 批量处理 | 逐个文件处理 |

### 修复版脚本修改的文件

1. ✅ **Cargo.toml**
   - `name = "starry"` → `name = "galos"`

2. ✅ **docker-compose.yml**
   - `starryos-dev` → `galos-dev`
   - `starryos-ci` → `galos-ci`
   - `/workspace/StarryOS` → `/workspace/GalOS`

3. ✅ **Dockerfile**
   - 注释、标签中的项目名

4. ✅ **.github/workflows/docker-ci.yml**
   - 容器名、任务名

5. ✅ **setup-env.sh**
   - 标题、容器名引用

6. ✅ **README.md**
   - 标题和内容

7. ✅ **所有文档**
   - `docs/docker-guide.md`
   - `docs/environment-requirements.md`
   - `docs/x11.md`
   - `UPLOAD_TO_ORGANIZATION.md`
   - `QUICK_START_UPLOAD.md`
   - `TEAM_UPLOAD_CHECKLIST.md`
   - `DOCKER_MIGRATION_GUIDE.md`

---

## 🔍 预期的修改内容

### Cargo.toml

```diff
[package]
-name = "starry"
+name = "galos"
version.workspace = true
```

### docker-compose.yml

```diff
services:
-  starryos-dev:
+  galos-dev:
     build:
       context: .
-    image: starryos-dev:latest
-    container_name: starryos-dev
+    image: galos-dev:latest
+    container_name: galos-dev

     volumes:
-      - .:/workspace/StarryOS
+      - .:/workspace/GalOS
-      - target-cache:/workspace/StarryOS/target
+      - target-cache:/workspace/GalOS/target

-    working_dir: /workspace/StarryOS
+    working_dir: /workspace/GalOS
```

### Dockerfile

```diff
-# StarryOS Development Environment
+# GalOS Development Environment

-LABEL maintainer="StarryOS Team"
-LABEL description="StarryOS Development Environment with..."
+LABEL maintainer="GalOS Team"
+LABEL description="GalOS Development Environment with..."
```

---

## ⚠️ 注意事项

### 不会修改的内容

以下内容**不会被修改**（这是正确的）：

1. **外部依赖包名**（Cargo.toml 中）：
   ```toml
   starry-process = "0.2"        # 保持不变
   starry-signal = "0.2"         # 保持不变
   starry-vm = "0.2"             # 保持不变
   starry-core = { path = "./core" }   # 保持不变
   starry-api = { path = "./api" }     # 保持不变
   ```

2. **子模块**：
   - `arceos` 子模块保持不变
   - `.gitmodules` 不需要修改

3. **Git 历史**：
   - 所有提交历史完整保留

---

## 🆘 问题排查

### 问题 1：脚本说"文件无需修改"

**原因**：使用了旧版本脚本

**解决**：使用修复版
```bash
./rename-to-galos-fixed.sh --dry-run
```

### 问题 2：修改后 Cargo 构建失败

**检查**：
```bash
# 查看 Cargo.toml 的 name 字段
grep '^name = ' Cargo.toml

# 应该显示：
# name = "galos"

# 验证语法
cargo metadata --format-version 1
```

### 问题 3：Docker Compose 报错

**检查**：
```bash
# 验证配置
docker-compose config

# 查看服务名
docker-compose config --services
# 应该显示：galos-dev
```

### 问题 4：想回滚修改

**方法 1**：使用 Git
```bash
git checkout .
```

**方法 2**：如果已提交
```bash
git revert HEAD
```

---

## 📝 日志文件

脚本会生成 `rename.log` 文件，记录所有操作：

```bash
# 查看日志
cat rename.log

# 搜索错误
grep ERROR rename.log
```

---

## ✅ 完整流程总结

```bash
# 1. 预览修改（确保没问题）
./rename-to-galos-fixed.sh --dry-run

# 2. 执行重命名
./rename-to-galos-fixed.sh

# 3. 检查修改
git diff

# 4. 验证配置
cargo metadata --format-version 1
docker-compose config

# 5. 重命名文件夹
cd ..
mv StarryOS GalOS
cd GalOS

# 6. 测试构建
docker-compose build galos-dev

# 7. 提交修改
git add .
git commit -m "refactor: rename project to GalOS"
```

**预计时间**：5-10 分钟

**推荐**：先运行 `--dry-run` 查看预览，确认无误后再执行！
