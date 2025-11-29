# GalOS Docker 使用指南

## 快速开始

### 方法1：使用测试脚本（推荐）

```bash
./docker-test.sh
```

然后选择要执行的操作。

### 方法2：手动命令

#### 交互式开发

```bash
# 进入容器
docker run --rm -it -v $(pwd):/workspace/GalOS -w /workspace/GalOS galos:latest

# 在容器内执行命令
make ARCH=riscv64 defconfig
make ARCH=riscv64 build
make ARCH=riscv64 run
exit
```

#### 一次性构建

```bash
# 生成配置并构建
docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS galos:latest \
  bash -c "make ARCH=riscv64 defconfig && make ARCH=riscv64 build"
```

#### 运行测试

```bash
# 完整测试流程
docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS galos:latest \
  bash -c "make ARCH=riscv64 img && python3 scripts/ci-test.py riscv64"
```

## 支持的架构

- `riscv64` (默认)
- `loongarch64`
- `x86_64`
- `aarch64`

## 常用命令

```bash
# 构建特定架构
make ARCH=loongarch64 build
make ARCH=x86_64 build
make ARCH=aarch64 build

# 清理构建产物
make clean

# 下载rootfs镜像
make ARCH=riscv64 img

# 仅运行QEMU（不重新构建）
make ARCH=riscv64 justrun

# 调试模式
make ARCH=riscv64 debug
```

## 使用 docker-compose

```bash
# 进入开发容器
docker-compose run --rm galos-dev bash

# 直接执行命令
docker-compose run --rm galos-dev make ARCH=riscv64 build

# 停止所有容器
docker-compose down
```

## 容器环境信息

- **基础镜像**: Ubuntu 24.04
- **Rust**: nightly-2025-05-20
- **QEMU**: 10.1.2
- **GCC**: riscv64-linux-musl-gcc 11.2.1
- **工作目录**: /workspace/GalOS

## 故障排除

### 问题：构建时提示 "Application path is not valid"

**原因**：Makefile变量未正确评估

**解决方案**：
1. 使用交互式容器（推荐）：
   ```bash
   docker run --rm -it -v $(pwd):/workspace/GalOS -w /workspace/GalOS galos:latest
   # 然后在容器内运行 make 命令
   ```

2. 或者使用 bash -c 包装命令：
   ```bash
   docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS galos:latest \
     bash -c "make ARCH=riscv64 defconfig && make ARCH=riscv64 build"
   ```

### 问题：QEMU缺少库文件

如果遇到 `libfdt.so.1` 或 `libslirp.so.0` 错误，镜像可能需要更新。

**解决方案**：使用已修复的 `galos:latest` 镜像（已包含所有必需库）

### 问题：容器内网络/SSL错误（重要！）

**症状**：
```
SSL error: unknown error; class=Ssl (16)
network failure seems to have happened
```

**原因**：容器内 Cargo 使用的 libgit2 可能有 SSL 问题

**解决方案**：

**方案1：在主机上直接构建（推荐，更快）**
```bash
# 主机已安装所需工具
make ARCH=riscv64 build
make ARCH=riscv64 run
```

**方案2：使用已配置的 Cargo 配置文件**

项目已包含 `.cargo/config.toml`，配置了：
- 使用 Git CLI 代替 libgit2（绕过 SSL 问题）
- 网络重试机制
- 超时设置

这个配置会自动挂载到容器中使用。

**方案3：使用网络代理（如果在中国大陆）**

在 `.cargo/config.toml` 中添加：
```toml
[http]
proxy = "http://your-proxy:port"
```

## CI/CD 集成

GitHub Actions 工作流位于 `.github/workflows/docker-ci.yml`

本地测试 CI 流程：
```bash
# 测试单个架构
docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS galos:latest \
  bash -c "make ARCH=riscv64 build && make ARCH=riscv64 img && python3 scripts/ci-test.py riscv64"
```

## 性能优化

### 使用缓存卷

docker-compose.yml 已配置缓存卷：
- `cargo-cache`: Cargo registry 缓存
- `cargo-git-cache`: Git 依赖缓存
- `target-cache`: 编译产物缓存

这些缓存可以显著加快重复构建速度。

### KVM 加速（Linux 主机）

取消 docker-compose.yml 中的注释：
```yaml
privileged: true
devices:
  - /dev/kvm:/dev/kvm
```

然后构建时使用：
```bash
make ARCH=x86_64 ACCEL=y run
```
