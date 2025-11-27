# 📋 上传前检查清单

**项目**：StarryOS
**日期**：______________________
**负责人**：______________________

---

## ✅ 预检查（在任何操作前）

- [ ] 已阅读 `UPLOAD_TO_ORGANIZATION.md` 完整文档
- [ ] 已在 GitHub 创建团队 Organization 仓库（仓库名：__________________）
- [ ] 团队成员已被邀请加入 Organization
- [ ] 已确定使用的上传方案：
  - [ ] 方案 A：保留上游历史（推荐）
  - [ ] 方案 B：从零开始

---

## 🔍 文件检查

### 必须存在的文件

- [ ] `README.md`
- [ ] `Cargo.toml`
- [ ] `Makefile`
- [ ] `rust-toolchain.toml`
- [ ] `Dockerfile`
- [ ] `docker-compose.yml`
- [ ] `.dockerignore`
- [ ] `.gitignore`（已更新）
- [ ] `setup-env.sh`（可执行）
- [ ] `docs/docker-guide.md`
- [ ] `docs/environment-requirements.md`
- [ ] `DOCKER_MIGRATION_GUIDE.md`
- [ ] `UPLOAD_TO_ORGANIZATION.md`

### 必须 NOT 存在的文件（应被 .gitignore 忽略）

- [ ] `rootfs-*.img`（1GB 镜像文件）
- [ ] `*.xz`（压缩文件）
- [ ] `target/`（构建目录）
- [ ] `*.elf`, `*.bin`（二进制文件）
- [ ] `disk.img`
- [ ] `qemu.log`
- [ ] `.axconfig.toml`

**验证命令**：
```bash
git status
# 应该只显示新增的配置和文档文件
```

---

## 🔐 安全检查

### 敏感信息扫描

- [ ] 没有密钥文件（.key, .pem, .p12）
- [ ] 没有密码文件（.env, .secret）
- [ ] 没有个人 token 或 credentials
- [ ] 代码中没有硬编码的密码或 API key

**验证命令**：
```bash
git ls-files | grep -E '\.(env|key|pem|secret|credential)'
# 应该没有输出

grep -r "password\|api_key\|secret" --include="*.rs" --include="*.toml" .
# 检查是否有可疑的硬编码
```

### 大文件检查

- [ ] 没有超过 50MB 的文件被 Git 跟踪
- [ ] `rootfs-*.img` 已被 .gitignore 忽略

**验证命令**：
```bash
find . -type f -size +10M -not -path "./.git/*" -exec ls -lh {} \;
# 只应该看到未被跟踪的 rootfs 镜像
```

---

## 🔧 配置检查

### Git 配置

- [ ] 子模块已正确配置
  ```bash
  cat .gitmodules
  # 应该显示 arceos 子模块信息
  ```

- [ ] 子模块处于正确的提交
  ```bash
  git submodule status
  # 应该显示: 4d1be13842ab800e585c375f723694224b4a1a7e arceos (4d1be13)
  ```

- [ ] 远程仓库配置正确
  ```bash
  git remote -v
  # 方案 A 应该显示 origin（团队）和 upstream（上游）
  # 方案 B 应该只显示 origin（团队）
  ```

### Docker 配置

- [ ] `Dockerfile` 语法正确
- [ ] `docker-compose.yml` 格式正确
- [ ] `.dockerignore` 包含必要的忽略规则

**验证命令**：
```bash
docker-compose config
# 应该输出正确的配置，无错误
```

---

## 🏗️ 构建验证

### 清理环境

```bash
make clean
rm -f *.img *.xz
```

- [ ] 清理完成，无构建产物残留

### Docker 构建测试（推荐）

```bash
docker-compose build
```

- [ ] Docker 镜像构建成功
- [ ] 构建时间：__________ 分钟（首次预计 20-40 分钟）
- [ ] 镜像大小：__________ GB（预计 5-6 GB）

### 功能验证（可选）

```bash
docker-compose run --rm starryos-dev bash -c "make build"
```

- [ ] RISC-V 64 构建成功
- [ ] 其他架构构建测试（可选）

---

## 📝 提交准备

### 提交信息

- [ ] 提交信息清晰、准确
- [ ] 使用 Conventional Commits 格式
- [ ] 包含变更说明

**建议的提交信息**：
```
feat: add Docker development environment and documentation

- Add Dockerfile with QEMU 10.2.0 for LoongArch64 support
- Add docker-compose.yml for development and CI environments
- Add comprehensive documentation for Docker setup
- Add environment requirements specification
- Add setup script for automated configuration
- Update .gitignore for Docker artifacts

This commit prepares the project for team development with
unified development environment using Docker containers.
```

### Git 状态检查

```bash
git status
```

- [ ] 只有预期的文件被添加
- [ ] 没有未跟踪的意外文件
- [ ] 工作目录干净

**预期添加的文件**：
```
新文件：   .dockerignore
新文件：   .github/ISSUE_TEMPLATE/bug_report.md
新文件：   .github/ISSUE_TEMPLATE/feature_request.md
新文件：   .github/PULL_REQUEST_TEMPLATE.md
新文件：   .github/workflows/docker-ci.yml
新文件：   DOCKER_MIGRATION_GUIDE.md
新文件：   Dockerfile
新文件：   TEAM_UPLOAD_CHECKLIST.md
新文件：   UPLOAD_TO_ORGANIZATION.md
新文件：   docker-compose.yml
新文件：   docs/docker-guide.md
新文件：   docs/environment-requirements.md
新文件：   setup-env.sh
修改：     .gitignore
```

---

## 🚀 上传执行

### 方案 A：保留上游历史（推荐）

#### 步骤 1：配置远程仓库

```bash
git remote rename origin upstream
git remote add origin git@github.com:YOUR_ORG/StarryOS.git
```

- [ ] 远程仓库重命名成功
- [ ] 新的 origin 指向团队仓库
- [ ] 验证：`git remote -v` 显示正确

#### 步骤 2：添加文件

```bash
git add .
```

- [ ] 所有新文件已添加
- [ ] `.gitignore` 更新已添加

#### 步骤 3：创建提交

```bash
git commit -m "feat: add Docker development environment and documentation

- Add Dockerfile with QEMU 10.2.0 for LoongArch64 support
- Add docker-compose.yml for development and CI environments
- Add comprehensive documentation for Docker setup
- Update .gitignore for Docker artifacts"
```

- [ ] 提交创建成功
- [ ] 提交信息准确

#### 步骤 4：推送到团队仓库

```bash
git push -u origin main
```

- [ ] 推送成功
- [ ] 在 GitHub 上验证文件已上传
- [ ] 子模块显示正确

### 方案 B：从零开始

#### 步骤 1：备份和重新初始化

```bash
mv .git .git.backup
git init
git remote add origin git@github.com:YOUR_ORG/StarryOS.git
```

- [ ] 旧 .git 已备份
- [ ] 新仓库已初始化
- [ ] 远程仓库已配置

#### 步骤 2：添加文件和提交

```bash
git add .
git commit -m "feat: initial commit with Docker development environment"
```

- [ ] 所有文件已添加
- [ ] 初始提交已创建

#### 步骤 3：添加子模块

```bash
git submodule add https://github.com/arceos-org/arceos.git arceos
cd arceos
git checkout 4d1be13842ab800e585c375f723694224b4a1a7e
cd ..
git commit -m "chore: add arceos submodule"
```

- [ ] 子模块已添加
- [ ] 子模块提交正确

#### 步骤 4：推送

```bash
git push -u origin main
```

- [ ] 推送成功

---

## ✅ 推送后验证

### GitHub 仓库检查

在浏览器中访问：`https://github.com/YOUR_ORG/StarryOS`

- [ ] 仓库可访问
- [ ] 所有文件已正确显示
- [ ] README.md 正确渲染
- [ ] 子模块链接正确（显示为链接，不是目录）
- [ ] `.gitignore` 生效（大文件没有被提交）

### 克隆测试

在另一个目录测试克隆：

```bash
cd /tmp
git clone --recursive git@github.com:YOUR_ORG/StarryOS.git
cd StarryOS
ls -la
```

- [ ] 克隆成功
- [ ] 子模块正确拉取
- [ ] 所有文件完整

### Docker 构建测试

```bash
docker-compose build
docker-compose run --rm starryos-dev bash -c "rustc --version"
```

- [ ] 镜像构建成功
- [ ] 容器可以正常启动
- [ ] 环境配置正确

---

## 🤝 团队配置

### GitHub 仓库设置

- [ ] 仓库描述已填写
- [ ] Topics/标签已添加（os, kernel, rust, docker, riscv, loongarch）
- [ ] Issues 已启用
- [ ] Projects 已启用（可选）

### 分支保护

- [ ] `main` 分支保护规则已设置：
  - [ ] 需要 PR 审查
  - [ ] 需要状态检查通过
  - [ ] 禁止直接推送

### 团队成员

- [ ] 所有团队成员已被邀请
- [ ] 权限已正确分配：
  - [ ] Maintainers: Admin
  - [ ] Core Developers: Write
  - [ ] Contributors: Write

### CI/CD

- [ ] GitHub Actions 已启用
- [ ] `.github/workflows/docker-ci.yml` 已存在
- [ ] 首次 CI 运行成功（如果有推送）

---

## 📢 通知团队

### 准备通知内容

**标题**：StarryOS 项目已上传到团队仓库

**内容模板**：
```
Hi Team,

StarryOS 项目已经上传到我们的 Organization 仓库：
https://github.com/YOUR_ORG/StarryOS

## 快速开始

克隆仓库：
```bash
git clone --recursive git@github.com:YOUR_ORG/StarryOS.git
cd StarryOS
```

使用 Docker 开发环境：
```bash
docker-compose build
docker-compose run --rm starryos-dev
```

## 文档

- Docker 使用指南: docs/docker-guide.md
- 环境依赖清单: docs/environment-requirements.md
- 迁移指南: DOCKER_MIGRATION_GUIDE.md

## 开发流程

1. 创建功能分支: git checkout -b feature/your-feature
2. 开发和测试
3. 提交 PR 到 main 分支

有问题请在 Issues 中提出或直接联系我。
```

### 通知渠道

- [ ] 团队邮件已发送
- [ ] Slack/微信/钉钉通知已发送
- [ ] 团队会议上已宣布（如适用）

---

## 🎉 完成后的任务

- [ ] 更新 README.md，添加团队仓库链接
- [ ] 创建初始 Issues（规划任务）
- [ ] 创建 `dev` 分支用于日常开发
- [ ] 安排团队培训会议（Docker 使用）
- [ ] 更新团队文档（Wiki/Confluence）

---

## 📝 备注

**遇到的问题**：

**解决方案**：

**改进建议**：

---

**检查完成日期**：______________________
**上传完成日期**：______________________
**签名**：______________________

---

**保留此清单作为记录！**
