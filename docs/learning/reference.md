# Docker 快速参考卡片

基于 GalOS 项目实践的 Docker 命令速查表。

## 🚀 快速开始

### 运行容器的三种方式

```bash
# 1. 一次性执行
docker run --rm galos:latest <command>

# 2. 交互式 Shell
docker run --rm -it galos:latest bash

# 3. 后台运行
docker run -d --name <name> galos:latest <command>
```

## 📋 常用命令

### 镜像管理
```bash
docker images                          # 列出镜像
docker images | grep galos             # 过滤镜像
docker rmi <image-id>                  # 删除镜像
docker image prune                     # 清理未使用镜像
```

### 容器管理
```bash
docker ps                              # 列出运行中容器
docker ps -a                           # 列出所有容器
docker stop <container-id>             # 停止容器
docker rm <container-id>               # 删除容器
docker logs <container-id>             # 查看日志
docker logs -f <container-id>          # 实时查看日志
docker exec -it <container-id> bash    # 进入容器
```

### 清理命令
```bash
docker container prune                 # 清理停止的容器
docker image prune                     # 清理未使用镜像
docker volume prune                    # 清理未使用卷
docker system prune -a                 # 全面清理
```

## 🔧 GalOS 常用命令

### 完整开发环境
```bash
docker run --rm -it --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash
```

### 构建项目
```bash
docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash -c "make ARCH=riscv64 build"
```

### 使用 docker-compose（推荐）
```bash
docker-compose run --rm galos-dev bash
docker-compose run --rm galos-dev make ARCH=riscv64 build
```

## 🐛 故障排查

### 问题：缺少库文件
```bash
# 错误：error while loading shared libraries: libfdt.so.1
# 解决：
docker run -d --name fix galos:latest sleep 300
docker exec -u root fix apt-get update
docker exec -u root fix apt-get install -y libfdt1 libslirp0
docker commit fix galos:latest
docker stop fix && docker rm fix
```

### 问题：SSL 错误
```bash
# 错误：SSL error: unknown error
# 解决：配置代理 + git-fetch-with-cli

# 1. 创建 .cargo/config.toml
[net]
git-fetch-with-cli = true
[http]
proxy = "http://127.0.0.1:7897"

# 2. 使用 host 网络
docker run --network=host -e HTTP_PROXY=... galos:latest ...
```

### 问题：Makefile 变量错误
```bash
# 错误：Application path "" is not valid
# 解决：使用 bash -c 包装
docker run --rm galos:latest bash -c "make build"
#                               ^^^^^^^ 包装命令
```

### 问题：无法访问主机代理
```bash
# 错误：Connection refused to 127.0.0.1:7897
# 解决：使用 host 网络模式
docker run --network=host galos:latest ...
#          ^^^^^^^^^^^^^^ 关键参数
```

## 🌐 网络模式

### Bridge（默认）
```bash
docker run --network=bridge galos:latest ...
```
- 容器有独立 IP（172.17.0.x）
- 无法访问主机的 127.0.0.1
- 需要端口映射：`-p 8080:80`

### Host
```bash
docker run --network=host galos:latest ...
```
- 与主机共享网络
- 可以访问主机的 127.0.0.1
- 适合访问主机代理

## 📁 数据挂载

```bash
# 挂载当前目录
-v $(pwd):/container/path

# 挂载并设置工作目录
-v $(pwd):/workspace -w /workspace

# 指定用户（避免权限问题）
--user $(id -u):$(id -g)
```

## 🔐 环境变量

```bash
# 单个变量
-e VAR=value

# 多个变量
-e HTTP_PROXY=http://127.0.0.1:7897 \
-e HTTPS_PROXY=http://127.0.0.1:7897

# 从文件加载
--env-file .env
```

## 💡 参数速查

| 参数 | 说明 | 示例 |
|------|------|------|
| `--rm` | 退出后删除容器 | `docker run --rm ...` |
| `-it` | 交互式终端 | `docker run -it ...` |
| `-d` | 后台运行 | `docker run -d ...` |
| `--name` | 命名容器 | `docker run --name myapp ...` |
| `-v` | 挂载卷 | `-v $(pwd):/app` |
| `-w` | 工作目录 | `-w /workspace` |
| `-e` | 环境变量 | `-e KEY=value` |
| `-p` | 端口映射 | `-p 8080:80` |
| `--network` | 网络模式 | `--network=host` |
| `--user` | 指定用户 | `--user 1000:1000` |

## 📊 性能对比（GalOS 实测）

| 操作 | 无代理 | 有代理（Host网络） |
|------|--------|-------------------|
| defconfig | ❌ 15+分钟失败 | ✅ 3分钟 |
| build | - | ✅ 26秒 |
| 总耗时 | 失败 | < 4分钟 |

## 💾 镜像存储和缓存管理

### 镜像存储位置

```bash
# Docker 根目录（Linux）
/var/lib/docker/

# 查看 Docker 根目录
docker info | grep "Docker Root Dir"

# 查看镜像详情
docker image inspect galos:latest

# 导出镜像为文件
docker save galos:latest -o galos-image.tar

# 从文件加载镜像
docker load -i galos-image.tar
```

### 磁盘使用查看

```bash
# 查看总体磁盘使用
docker system df

# 查看详细使用情况
docker system df -v

# 查看构建缓存详情
docker buildx du
```

**输出示例**：
```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          1         0         3.895GB   3.836GB (98%)
Build Cache     32        0         12.35GB   12.35GB (100%)
```

### 清理构建缓存

```bash
# 清理旧缓存（推荐，保留最近使用的）
docker buildx prune --filter until=168h  # 7天前的

# 清理所有构建缓存
docker buildx prune -a -f

# 验证清理结果
docker system df
```

**重要提示**：
- ✅ 清理缓存**不影响**已构建的镜像
- ✅ 清理缓存**不影响**运行中的容器
- ⚠️ 清理缓存会导致下次构建变慢（需要重新执行所有步骤）

### 清理其他资源

```bash
# 清理悬空镜像（无标签的旧镜像）
docker image prune

# 清理所有未使用的镜像
docker image prune -a

# 清理停止的容器
docker container prune

# 清理未使用的卷（谨慎！）
docker volume prune

# 全面清理（谨慎！）
docker system prune -a
```

### 清理命令安全性

| 命令 | 安全性 | 说明 |
|------|--------|------|
| `docker buildx prune -a -f` | ✅ 安全 | 只删除构建缓存 |
| `docker image prune` | ✅ 安全 | 只删除悬空镜像 |
| `docker container prune` | ✅ 安全 | 只删除停止的容器 |
| `docker image prune -a` | ⚠️ 谨慎 | 会删除未使用的镜像 |
| `docker volume prune` | ⚠️ 谨慎 | 会删除数据 |
| `docker system prune -a --volumes` | ❌ 危险 | 删除所有未使用资源 |

## ⚡ 最佳实践

1. **使用 docker-compose** - 避免长命令
2. **使用 .dockerignore** - 加快构建
3. **定期清理缓存** - 节省磁盘空间（每周运行 `docker buildx prune -f`）
4. **使用 named volumes** - 缓存依赖
5. **指定用户运行** - 避免权限问题
6. **监控磁盘使用** - 定期运行 `docker system df`

## 🔗 相关文档

- [详细学习指南](./guide.md)
- [Docker 使用指南](../usage/docker-usage.md)
- [迁移指南](../usage/docker-migration.md)
