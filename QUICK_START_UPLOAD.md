# 🚀 快速上传指南

> 完整指南请查看：[UPLOAD_TO_ORGANIZATION.md](UPLOAD_TO_ORGANIZATION.md)

## 立即行动：5 步上传

### 1️⃣ 在 GitHub 创建空仓库

- 进入你的 Organization
- 创建名为 `GalOS` 的**空仓库**（不要添加 README/LICENSE）
- 记下仓库地址：`git@github.com:YOUR_ORG/GalOS.git`

### 2️⃣ 配置本地 Git

```bash
cd /home/c20h30o2/files/GalOS

# 重命名当前 origin 为 upstream
git remote rename origin upstream

# 添加团队仓库为新的 origin（替换 YOUR_ORG）
git remote add origin git@github.com:YOUR_ORG/GalOS.git

# 验证
git remote -v
```

### 3️⃣ 添加所有新文件

```bash
# 添加所有新文件
git add .

# 查看将要提交的内容
git status
```

**预期新增文件**：
- `.dockerignore`
- `Dockerfile`
- `docker-compose.yml`
- `setup-env.sh`
- `docs/docker-guide.md`
- `docs/environment-requirements.md`
- `DOCKER_MIGRATION_GUIDE.md`
- `UPLOAD_TO_ORGANIZATION.md`
- `TEAM_UPLOAD_CHECKLIST.md`
- `.github/workflows/docker-ci.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/*.md`

**以及修改的文件**：
- `.gitignore`（更新了 Docker 相关忽略规则）

### 4️⃣ 创建提交

```bash
git commit -m "feat: add Docker development environment and documentation

- Add Dockerfile with QEMU 10.2.0 for LoongArch64 support
- Add docker-compose.yml for development and CI environments
- Add comprehensive documentation for Docker setup
- Add environment requirements specification
- Add setup script for automated configuration
- Add GitHub templates for issues and PRs
- Add CI/CD workflow for automated testing
- Update .gitignore for Docker artifacts

This commit prepares the project for team development with
unified development environment using Docker containers."
```

### 5️⃣ 推送到团队仓库

```bash
# 推送 main 分支（包含完整历史）
git push -u origin main

# 如果推送成功，也推送标签（如果有）
git push --tags
```

---

## ✅ 验证上传成功

1. **访问 GitHub 仓库**：`https://github.com/YOUR_ORG/GalOS`
2. **检查文件**：确认所有文件已上传
3. **检查子模块**：`arceos` 应显示为链接（不是目录）
4. **测试克隆**：
   ```bash
   cd /tmp
   git clone --recursive git@github.com:YOUR_ORG/GalOS.git
   cd GalOS
   ls -la
   ```

---

## ⚠️ 重要注意事项

### 1. 检查大文件（必须！）

```bash
# 确认这个文件没有被 Git 跟踪
ls -lh rootfs-riscv64.img
# 应该显示 1.0G，但 git status 不应显示它

git status --ignored | grep -E "\.(img|xz)$"
# 应该显示这些文件被忽略
```

### 2. 子模块处理

团队成员克隆时必须使用：
```bash
git clone --recursive git@github.com:YOUR_ORG/GalOS.git
```

或者：
```bash
git clone git@github.com:YOUR_ORG/GalOS.git
cd GalOS
git submodule update --init --recursive
```

### 3. 保留上游引用

你已经将原始仓库重命名为 `upstream`，以后可以这样同步更新：

```bash
# 拉取上游更新
git fetch upstream

# 合并到本地 main
git checkout main
git merge upstream/main

# 推送到团队仓库
git push origin main
```

---

## 🎯 上传后的任务

### 立即完成

- [ ] 在 GitHub 上设置分支保护规则（Settings → Branches）
- [ ] 邀请团队成员（Settings → Collaborators and teams）
- [ ] 启用 Issues 和 Projects（Settings → General）

### 尽快完成

- [ ] 通知团队成员新仓库地址
- [ ] 创建 `dev` 开发分支：
  ```bash
  git checkout -b dev
  git push -u origin dev
  ```
- [ ] 在 GitHub 上添加仓库描述和 Topics 标签

### 后续计划

- [ ] 组织团队培训（Docker 使用）
- [ ] 创建初始 Issues（功能规划）
- [ ] 构建 Docker 镜像并推送到私有仓库（可选）

---

## 📋 使用检查清单

如果你需要详细的检查清单，请使用：
- **详细版**：[TEAM_UPLOAD_CHECKLIST.md](TEAM_UPLOAD_CHECKLIST.md)（打印使用）
- **完整指南**：[UPLOAD_TO_ORGANIZATION.md](UPLOAD_TO_ORGANIZATION.md)

---

## 🆘 遇到问题？

### 常见错误

**错误：`Permission denied (publickey)`**

解决：检查 SSH 密钥配置
```bash
ssh -T git@github.com
```

**错误：`failed to push some refs`**

原因：远程仓库不是空的

解决：
```bash
git pull origin main --allow-unrelated-histories
# 解决冲突后重新推送
git push origin main
```

**错误：子模块没有内容**

解决：
```bash
git submodule update --init --recursive
```

---

## 🎉 完成！

上传成功后，团队成员可以开始开发：

```bash
# 克隆仓库
git clone --recursive git@github.com:YOUR_ORG/GalOS.git
cd GalOS

# 使用 Docker 开发
docker-compose build
docker-compose run --rm galos-dev

# 在容器内
make build
make img
make run
```

**祝项目顺利！** 🚀

---

**需要帮助？**
- 完整指南：[UPLOAD_TO_ORGANIZATION.md](UPLOAD_TO_ORGANIZATION.md)
- Docker 使用：[docs/docker-guide.md](docs/docker-guide.md)
- 环境依赖：[docs/environment-requirements.md](docs/environment-requirements.md)
