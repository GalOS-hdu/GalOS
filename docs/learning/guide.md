# Docker 学习指南 - GalOS 实战案例

本文档基于 GalOS 项目的 Docker 工作流实践，记录了实际遇到的问题、原因分析和解决方案，适合学习 Docker 的实际应用。

## 目录

- [基础概念](#基础概念)
  - [镜像 vs 容器](#镜像-vs-容器)
  - [数据流](#数据流主机--容器)
  - [镜像存储位置](#镜像存储位置)
  - [镜像分层存储](#镜像分层存储)
- [Docker 交互命令](#docker-交互命令)
- [问题排查案例](#问题排查案例)
- [网络配置](#网络配置)
- [代理配置](#代理配置)
- [镜像和缓存管理](#镜像和缓存管理)
- [最佳实践](#最佳实践)

---

## 基础概念

### 镜像 vs 容器

```
镜像 (Image)          容器 (Container)
    ↓                       ↓
 蓝图/模板              运行中的实例
 静态文件               动态进程
 可复用                 临时/持久
```

**类比**：
- 镜像 = 类（Class）
- 容器 = 对象实例（Object）

### 数据流：主机 ↔ 容器

```
主机文件系统
    ↓ (volume mount)
容器文件系统
    ↓ (stdout/stderr)
主机 shell 输出
```

### 镜像存储位置

#### Docker 存储架构

Docker 镜像存储在 Docker 的本地存储系统中，并非以普通文件形式存在。

**Linux 系统（默认路径）**：
```
/var/lib/docker/
├── image/          # 镜像元数据和层信息
├── overlay2/       # 实际的镜像层数据（使用 overlay2 存储驱动）
├── containers/     # 容器数据
├── volumes/        # 数据卷
└── buildx/         # 构建缓存
```

**查看 Docker 根目录**：
```bash
docker info | grep "Docker Root Dir"
# Output: Docker Root Dir: /var/lib/docker
```

**实际示例（GalOS 镜像）**：
```bash
$ docker images galos
IMAGE          ID             DISK USAGE   CONTENT SIZE
galos:latest   c3eb249f3113       3.89GB             0B

$ docker image inspect galos:latest --format '{{.Id}}'
sha256:c3eb249f3113963fa6e2278b84f74288cdc0402dca76400d0f60d6b82bc6aefe
```

**重要提示**：
- ⚠️ **不要直接修改** `/var/lib/docker/` 下的文件
- ⚠️ **查看该目录需要 root 权限**：`sudo ls /var/lib/docker/`
- ✅ 使用 Docker 命令管理镜像，而不是直接操作文件系统

#### 查看镜像存储信息

```bash
# 查看所有镜像
docker images

# 查看详细信息（包括层结构）
docker image inspect galos:latest

# 查看磁盘使用情况
docker system df
```

**输出示例**：
```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          1         0         3.895GB   3.836GB (98%)
Containers      1         0         0B        0B
Local Volumes   1         0         0B        0B
Build Cache     0         0         0B        0B
```

#### 导出和备份镜像

镜像可以导出为 tar 文件，便于传输和备份：

```bash
# 导出镜像为 tar 文件
docker save galos:latest -o galos-image.tar

# 查看文件大小
ls -lh galos-image.tar
# -rw-r--r-- 1 user user 3.8G ... galos-image.tar

# 在其他机器上加载镜像
docker load -i galos-image.tar
```

**使用场景**：
- 在无网络环境中传输镜像
- 备份镜像到外部存储
- 在多台机器间快速分发镜像

### 镜像分层存储

#### 分层架构原理

Docker 使用**联合文件系统（Union File System）**实现镜像的分层存储：

```
galos:latest 镜像（3.89 GB）
├── Layer 1: Ubuntu 22.04 基础层      (~500 MB)
├── Layer 2: QEMU 构建依赖            (~200 MB)
├── Layer 3: QEMU 10.1.2 二进制       (~100 MB)
├── Layer 4: Rust 工具链              (~2 GB)
├── Layer 5: Musl 交叉编译工具链      (~800 MB)
└── Layer 6: 最终配置和库文件         (~300 MB)
```

**关键特性**：
1. **层只读**：每一层在创建后都是只读的
2. **增量存储**：只存储与上一层的差异
3. **层共享**：多个镜像可以共享相同的基础层

#### 查看镜像层

```bash
# 查看镜像的层历史
docker history galos:latest

# 查看层的详细信息
docker image inspect galos:latest --format '{{json .RootFS.Layers}}' | python3 -m json.tool
```

**输出示例**：
```
IMAGE          CREATED        CREATED BY                                      SIZE
c3eb249f3113   4 hours ago    CMD ["bash"]                                    0B
<missing>      4 hours ago    RUN /bin/sh -c apt-get install -y libfdt1 ...   50MB
<missing>      8 hours ago    COPY qemu/bin/* /opt/qemu/bin/ # buildkit       100MB
...
```

#### 容器的可写层

当运行容器时，Docker 在镜像层之上添加一个**可写层**：

```
容器运行时
    ↓
┌─────────────────────────┐
│ 可写层（容器层）          │ ← 所有修改都在这里
├─────────────────────────┤
│ Layer 6: 配置和库         │
│ Layer 5: Musl 工具链      │ ← 只读镜像层
│ Layer 4: Rust 工具链      │
│ ...                      │
└─────────────────────────┘
```

**重要理解**：
- ✅ **容器删除 = 可写层删除**，镜像层不变
- ✅ **多个容器共享同一镜像**，每个容器有独立的可写层
- ⚠️ **可写层数据是临时的**，容器删除后丢失

**示例**：
```bash
# 启动容器并创建文件
docker run --rm -it galos:latest bash
# 在容器内：
echo "test" > /tmp/test.txt
exit

# 文件已丢失（因为使用了 --rm）
docker run --rm galos:latest cat /tmp/test.txt
# cat: /tmp/test.txt: No such file or directory
```

#### 分层存储的优势

1. **存储效率**：
   ```bash
   # 两个基于相同基础镜像的镜像
   ubuntu:22.04    → 500 MB
   galos:latest    → 3.89 GB（包含 ubuntu:22.04）
   another-image   → 2 GB（也包含 ubuntu:22.04）

   # 实际磁盘使用：3.89 + 2 - 0.5 = 5.39 GB
   # 而不是：3.89 + 2 = 5.89 GB
   ```

2. **构建速度**：
   ```bash
   # 修改 Dockerfile 最后一行
   # 只需重新构建最后一层，其他层使用缓存
   ```

3. **分发效率**：
   ```bash
   # docker pull 只下载本地不存在的层
   # 如果已有 ubuntu:22.04，pull galos:latest 时会跳过基础层
   ```

---

## Docker 交互命令

### 1. 基础命令

#### 列出镜像
```bash
# 列出所有镜像
docker images

# 列出特定镜像
docker images | grep galos

# 格式化输出（显示大小）
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

**输出示例**：
```
REPOSITORY   TAG       SIZE
galos        latest    3.84GB
```

#### 列出容器
```bash
# 列出运行中的容器
docker ps

# 列出所有容器（包括已停止）
docker ps -a

# 只显示容器 ID
docker ps -q
```

### 2. 运行容器的三种方式

#### 方式1：一次性执行（非交互）
```bash
docker run --rm galos:latest echo "Hello from container"
```

**特点**：
- `--rm`：容器退出后自动删除
- 执行完命令立即退出
- 适合：单条命令执行

**输出**：
```
Hello from container
```

#### 方式2：交互式 Shell
```bash
docker run --rm -it galos:latest bash
```

**参数说明**：
- `-i`：保持 STDIN 打开（interactive）
- `-t`：分配伪终端（TTY）
- `bash`：进入 bash shell

**使用场景**：
```bash
# 进入容器后可以执行多条命令
root@container:/# pwd
/workspace
root@container:/# ls
root@container:/# exit  # 退出容器
```

#### 方式3：后台运行
```bash
docker run -d --name my-container galos:latest sleep 3600
```

**参数说明**：
- `-d`：detached 模式（后台运行）
- `--name`：给容器命名
- 返回容器 ID

**管理后台容器**：
```bash
# 查看日志
docker logs my-container

# 进入运行中的容器
docker exec -it my-container bash

# 停止容器
docker stop my-container

# 删除容器
docker rm my-container
```

### 3. 数据挂载（Volume）

#### 挂载主机目录
```bash
docker run --rm \
  -v /host/path:/container/path \
  galos:latest
```

**实际案例**：
```bash
docker run --rm \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  ls -la
```

**参数说明**：
- `-v $(pwd):/workspace/GalOS`：挂载当前目录到容器的 /workspace/GalOS
- `-w /workspace/GalOS`：设置工作目录
- 容器内对文件的修改会同步到主机

**权限问题示例**：
```bash
# 容器内创建的文件属于 root
docker run --rm -v $(pwd):/data galos:latest touch /data/test.txt

# 主机上查看
ls -l test.txt
# 输出：-rw-r--r-- 1 root root ...
```

### 4. 网络模式

#### Bridge 模式（默认）
```bash
docker run --rm --network=bridge galos:latest
```

**特点**：
- 容器有独立的 IP
- 通过 NAT 访问外网
- 容器访问主机：需要主机的 Docker 网桥 IP（172.17.0.1）

**问题**：无法访问主机的 `127.0.0.1` 服务

#### Host 模式
```bash
docker run --rm --network=host galos:latest
```

**特点**：
- 容器与主机共享网络命名空间
- 容器内可以直接访问 `127.0.0.1`
- 适合：需要访问主机服务（如代理）

**对比**：
```bash
# Bridge 模式 - 失败
docker run --rm galos:latest curl http://127.0.0.1:7897
# Error: Connection refused

# Host 模式 - 成功
docker run --rm --network=host galos:latest curl http://127.0.0.1:7897
# 可以访问主机的 7897 端口
```

### 5. 环境变量

```bash
docker run --rm \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e CUSTOM_VAR=value \
  galos:latest \
  env | grep PROXY
```

**输出**：
```
HTTP_PROXY=http://127.0.0.1:7897
```

### 6. 实用组合命令

#### 完整的开发环境
```bash
docker run --rm -it \
  --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash
```

**每个参数的作用**：
1. `--rm`：退出后自动清理
2. `-it`：交互式终端
3. `--network=host`：使用主机网络（访问代理）
4. `-e HTTP_PROXY=...`：设置代理环境变量
5. `-v $(pwd):/workspace/GalOS`：挂载代码目录
6. `-w /workspace/GalOS`：设置工作目录
7. `bash`：启动 shell

---

## 问题排查案例

### 案例 1：缺少运行时库

#### 问题表现
```bash
$ docker run --rm galos:latest qemu-system-riscv64 --version
qemu-system-riscv64: error while loading shared libraries: libfdt.so.1: cannot open shared object file: No such file or directory
```

#### 错误分析
```
错误类型：运行时库缺失
症状：error while loading shared libraries
原因：镜像构建时未安装运行时依赖
```

#### 排查步骤

**1. 检查库依赖**
```bash
docker run --rm galos:latest ldd /opt/qemu/bin/qemu-system-riscv64
```

**输出**：
```
libfdt.so.1 => not found    ← 找不到
libslirp.so.0 => not found  ← 找不到
```

**2. 检查镜像中是否安装了包**
```bash
docker run --rm galos:latest dpkg -l | grep libfdt
# 无输出 = 未安装
```

**3. 查看 Dockerfile 定义**
```dockerfile
# Dockerfile 中有定义
RUN apt-get install -y \
    libfdt1 \
    libslirp0
```

**结论**：Dockerfile 定义正确，但当前镜像不是用该 Dockerfile 构建的。

#### 解决方案

**方案1：快速修复（2-5分钟）**
```bash
# 1. 启动临时容器
docker run -d --name galos-fix galos:latest sleep 300

# 2. 安装缺失的库
docker exec -u root galos-fix bash -c "apt-get update && apt-get install -y libfdt1 libslirp0"

# 3. 保存为新镜像
docker commit galos-fix galos:latest

# 4. 清理临时容器
docker stop galos-fix && docker rm galos-fix

# 5. 验证
docker run --rm galos:latest qemu-system-riscv64 --version
# 输出：QEMU emulator version 10.1.2
```

**方案2：重新构建（30-60分钟）**
```bash
docker build -t galos:latest .
```

**选择建议**：
- 只缺少几个库 → 快速修复
- 需要更新基础组件 → 重新构建

---

### 案例 2：网络 SSL 错误

#### 问题表现
```bash
$ docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS \
  galos:latest make ARCH=riscv64 defconfig

# 输出（15分钟后）：
error: failed to clone into: /usr/local/cargo/git/db/slab_allocator-xxx
Caused by:
  SSL error: unknown error; class=Ssl (16)
  network failure seems to have happened
```

#### 错误分析

**错误信息解读**：
```
SSL error: unknown error
  ↓
libgit2 内置的 SSL 实现有兼容性问题
  ↓
Cargo 使用 libgit2 克隆 Git 仓库失败
```

**时间线**：
```
0分钟：开始更新依赖
  ↓
2分钟：更新 crates.io 索引（成功）
  ↓
3-15分钟：更新 Git 仓库（反复重试）
  ↓
15分钟：SSL 错误，失败退出
```

#### 排查步骤

**1. 测试网络连接**
```bash
# 在容器内测试
docker run --rm galos:latest curl -I https://github.com
# 可能成功，说明基础网络正常
```

**2. 测试 Git 克隆**
```bash
docker run --rm galos:latest \
  git clone https://github.com/arceos-org/slab_allocator.git /tmp/test
# 失败：SSL error
```

**3. 检查是否是代理问题**
```bash
# 主机上测试（有代理）
curl -I https://github.com
# HTTP/2 200  ← 成功

# 容器内测试（无代理）
docker run --rm galos:latest curl -I https://github.com
# 可能很慢或超时
```

#### 解决方案

**问题根源**：
1. 容器内网络受限或不稳定
2. Cargo 使用的 libgit2 有 SSL 兼容性问题
3. 无法访问主机的代理服务

**解决步骤**：

**Step 1：配置 Cargo 使用 Git CLI**

创建 `.cargo/config.toml`：
```toml
[net]
# 使用 Git CLI 代替 libgit2（绕过 SSL 问题）
git-fetch-with-cli = true

# 重试配置
retry = 3

[http]
timeout = 60
```

**为什么有效？**
- Git CLI 使用系统的 OpenSSL，兼容性更好
- libgit2 使用内置 SSL 实现，可能有 bug

**Step 2：配置代理访问**

检查主机代理监听地址：
```bash
netstat -tln | grep 7897
# tcp  0  0  127.0.0.1:7897  0.0.0.0:*  LISTEN
#            ^^^^^^^^^^
#            只监听 127.0.0.1，容器无法访问
```

**问题**：Bridge 网络模式下，容器内 `127.0.0.1` 指向容器自己，不是主机。

**解决**：使用 Host 网络模式
```bash
docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  make ARCH=riscv64 defconfig
```

**Step 3：更新 `.cargo/config.toml` 添加代理**
```toml
[http]
proxy = "http://127.0.0.1:7897"

[https]
proxy = "http://127.0.0.1:7897"
```

**Step 4：验证**
```bash
# 清理旧配置
rm -f .axconfig.toml

# 重新运行
docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  make ARCH=riscv64 defconfig
```

**结果对比**：
| 配置 | 时间 | 结果 |
|------|------|------|
| 无代理 | 15+ 分钟 | ❌ SSL 错误 |
| Host网络+代理 | 3 分钟 | ✅ 成功 |

---

### 案例 3：Makefile 变量评估错误

#### 问题表现
```bash
$ docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS \
  galos:latest make ARCH=riscv64 build

Makefile:84: *** Application path "" is not valid.  Stop.
```

#### 错误分析

**Makefile 相关代码**：
```makefile
# GalOS/Makefile
export A := $(PWD)

# arceos/Makefile
APP ?= $(A)
ifeq ($(wildcard $(APP)),)
  $(error Application path "$(APP)" is not valid)
endif
```

**问题原因**：
```
docker run galos:latest make build
    ↓
单次命令执行，shell 环境不完整
    ↓
$(PWD) 评估为空字符串
    ↓
A="" → APP=""
    ↓
错误：Application path "" is not valid
```

#### 排查步骤

**1. 检查变量**
```bash
docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS \
  galos:latest bash -c "echo 'PWD=$PWD' && echo 'A=$A'"

# 输出：
PWD=/workspace/GalOS  ← PWD 有值
A=                    ← A 是空的！
```

**2. 对比不同运行方式**
```bash
# 方式1：直接运行 make（失败）
docker run --rm galos:latest make build
# 错误：Application path "" is not valid

# 方式2：通过 bash -c（成功）
docker run --rm galos:latest bash -c "make build"
# 正常工作

# 方式3：交互式（成功）
docker run --rm -it galos:latest
root@container:/# make build  # 正常工作
```

#### 解决方案

**方案1：使用 bash -c 包装（推荐）**
```bash
docker run --rm \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash -c "make ARCH=riscv64 build"
#         ^^^^^^^^ 包装在 bash -c 中
```

**为什么有效？**
- `bash -c` 启动完整的 bash 环境
- Shell 变量和 Makefile 变量正确初始化
- `$(PWD)` 正确评估

**方案2：使用交互式容器**
```bash
# 进入容器
docker run --rm -it \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest

# 在容器内执行
make ARCH=riscv64 build
```

**方案3：使用 docker-compose**
```bash
# docker-compose.yml 已配置好环境
docker-compose run --rm galos-dev make ARCH=riscv64 build
```

**技术原理**：

```
直接执行 make
    ↓
docker run <image> make
    ↓
execve("make", ["make"], []) ← 最小环境
    ↓
$(PWD) 未设置

使用 bash -c
    ↓
docker run <image> bash -c "make"
    ↓
execve("bash", ["bash", "-c", "make"], [])
    ↓
bash 初始化环境 → 设置 PWD
    ↓
$(PWD) 正确评估
```

---

### 案例 4：容器内文件权限问题

#### 问题表现
```bash
# 在容器内构建
docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS \
  galos:latest make build

# 查看生成的文件
ls -l GalOS_riscv64-qemu-virt.elf
# -rwxr-xr-x 1 root root 46M ...
#                ^^^^ ^^^^
#                属于 root
```

#### 问题
- 容器内以 root 用户运行
- 生成的文件属于 root
- 主机用户无法修改/删除

#### 解决方案

**方案1：构建时指定用户**
```bash
docker run --rm \
  --user $(id -u):$(id -g) \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash -c "make build"

# 生成的文件属于当前用户
ls -l GalOS_riscv64-qemu-virt.elf
# -rwxr-xr-x 1 user user 46M ...
```

**方案2：构建后修改权限**
```bash
docker run --rm -v $(pwd):/workspace/GalOS -w /workspace/GalOS \
  galos:latest bash -c "make build && chown -R $(id -u):$(id -g) ."
```

**方案3：使用 docker-compose（已配置）**
```yaml
# docker-compose.yml
services:
  galos-dev:
    build:
      args:
        USER_UID: 1000  # 使用非 root 用户
        USER_GID: 1000
```

---

## 网络配置

### 网络模式对比

#### Bridge 模式（默认）

**网络拓扑**：
```
主机 (192.168.1.100)
    ↓
Docker Bridge (172.17.0.1)
    ↓
容器 (172.17.0.2)
```

**访问规则**：
```bash
# 容器访问外网
容器 → NAT → 外网  ✅

# 容器访问主机
容器 → 172.17.0.1:port  ✅
容器 → 127.0.0.1:port   ❌ (指向容器自己)

# 主机访问容器
主机 → 172.17.0.2:port  ✅
主机 → localhost:port   ❌ (需要端口映射)
```

**示例**：
```bash
# 启动监听在 127.0.0.1:7897 的主机代理
# 容器无法访问
docker run --rm galos:latest curl http://127.0.0.1:7897
# Error: Connection refused
```

#### Host 模式

**网络拓扑**：
```
主机 (192.168.1.100)
    = (共享网络)
容器 (192.168.1.100)  ← 相同 IP
```

**访问规则**：
```bash
# 容器访问主机服务
容器 → 127.0.0.1:port  ✅ (直接访问)

# 端口冲突
主机和容器不能同时监听相同端口
```

**示例**：
```bash
# 容器可以访问主机的 127.0.0.1:7897
docker run --rm --network=host \
  galos:latest curl http://127.0.0.1:7897
# 成功！
```

### 端口映射 (Bridge 模式)

```bash
docker run --rm \
  -p 8080:80 \
  nginx

# 访问：
# 主机: http://localhost:8080 → 容器:80
```

**语法**：
```
-p <主机端口>:<容器端口>
-p 8080:80               # 单个端口
-p 8080:80 -p 8443:443   # 多个端口
-p 127.0.0.1:8080:80     # 绑定特定 IP
```

---

## 代理配置

### 场景：容器需要访问主机代理

#### 检查主机代理配置

```bash
# 查看代理环境变量
env | grep -i proxy

# 输出示例：
HTTP_PROXY=http://127.0.0.1:7897
HTTPS_PROXY=http://127.0.0.1:7897

# 检查监听地址
netstat -tln | grep 7897
# tcp  0  0  127.0.0.1:7897  0.0.0.0:*  LISTEN
```

#### 配置方法

**方法1：Host 网络模式（推荐）**

```bash
docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  galos:latest \
  curl https://www.google.com
```

**优点**：
- 简单直接
- 容器可以访问 `127.0.0.1`

**缺点**：
- 网络隔离性降低
- 端口可能冲突

**方法2：使用 Docker 网桥 IP（不推荐）**

```bash
# 1. 获取 Docker 网桥 IP
ip addr show docker0 | grep "inet "
# inet 172.17.0.1/16

# 2. 代理需要监听 0.0.0.0 或 172.17.0.1
# 修改代理配置文件，让其监听所有接口

# 3. 容器使用网桥 IP
docker run --rm \
  -e HTTP_PROXY=http://172.17.0.1:7897 \
  galos:latest \
  curl https://www.google.com
```

**问题**：需要修改代理服务器配置，安全性降低。

**方法3：使用 host.docker.internal（Mac/Windows）**

```bash
# Docker Desktop 提供的特殊域名
docker run --rm \
  -e HTTP_PROXY=http://host.docker.internal:7897 \
  galos:latest \
  curl https://www.google.com
```

**注意**：Linux 上默认不支持，需要额外配置。

#### Cargo 代理配置

创建 `.cargo/config.toml`：

```toml
[http]
proxy = "http://127.0.0.1:7897"

[https]
proxy = "http://127.0.0.1:7897"
```

**结合 Docker 使用**：

```bash
docker run --rm --network=host \
  -v $(pwd)/.cargo:/root/.cargo \
  -v $(pwd):/workspace \
  -w /workspace \
  galos:latest \
  cargo build
```

---

## 镜像和缓存管理

### 构建缓存概述

Docker 在构建镜像时会创建**构建缓存（Build Cache）**，用于加速后续构建。

#### 什么是构建缓存？

构建缓存是 `docker build` 过程中产生的中间层，只在构建镜像时产生：

```
Dockerfile 指令             → 构建缓存层
├── FROM ubuntu:22.04       → 缓存层 1
├── RUN apt-get update      → 缓存层 2
├── RUN apt-get install...  → 缓存层 3
├── COPY qemu /opt/qemu     → 缓存层 4
└── RUN rustup install...   → 缓存层 5
```

**关键概念**：
- ✅ **构建缓存 ≠ 镜像**：缓存是临时的中间层
- ✅ **只在 `docker build` 时产生**，运行容器不会产生缓存
- ✅ **删除缓存不影响已构建的镜像**

#### 何时产生构建缓存？

```bash
# ✅ 产生构建缓存
docker build -t galos:latest .
docker buildx build -t galos:latest .

# ❌ 不产生构建缓存
docker run ...              # 只运行容器
docker-compose up           # 只启动服务
docker pull ...             # 只下载镜像
```

### 查看构建缓存

#### 查看缓存使用情况

```bash
# 查看总体磁盘使用
docker system df
```

**输出示例**：
```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          1         0         3.895GB   3.836GB (98%)
Containers      1         0         0B        0B
Local Volumes   1         0         0B        0B
Build Cache     32        0         12.35GB   12.35GB (100%)
                ^^              ^^^^^^^^    ^^^^^^^^^^^
              数量               总大小      可回收大小
```

#### 查看详细缓存信息

```bash
# 查看每个缓存层的详细信息
docker buildx du
```

**输出示例**（GalOS 实际数据）：
```
ID                           RECLAIMABLE   SIZE       LAST ACCESSED
b3wcns8rqqxx5k2bkfzthrkiq*   true          3.571GB    4 hours ago
u9kbqnex7b7vgk8ftowpjbguq    true          1.442GB    4 hours ago
9il936qprplk7owo8mg0mjirr    true          1.443GB
o4x13qi7yfupks295nxky7th9    true          854.4MB    4 hours ago
xp6ao1h6gaoh6pwa4jr5j10lt    true          721.8MB    4 hours ago
...

Shared:      3.758GB
Private:     8.588GB
Reclaimable: 12.35GB    ← 可安全删除
Total:       12.35GB
```

**字段说明**：
- `RECLAIMABLE`: `true` 表示可以安全删除
- `SIZE`: 缓存层大小
- `LAST ACCESSED`: 最后使用时间（越久未使用越安全删除）

### 清除构建缓存

#### 方法 1：清除旧缓存（推荐）⭐

```bash
# 只删除超过 7 天未使用的缓存
docker buildx prune --filter until=168h

# 只删除超过 24 小时未使用的缓存
docker buildx prune --filter until=24h
```

**优势**：
- ✅ 保留最近使用的缓存，加速后续构建
- ✅ 清理长期不用的缓存，释放空间
- ✅ 适合定期维护

#### 方法 2：清除所有构建缓存

```bash
# 交互式确认
docker buildx prune -a

# 强制清除（不确认）
docker buildx prune -a -f
```

**输出示例**：
```bash
$ docker buildx prune -a -f
...
Total: 12.35GB

$ docker system df
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Build Cache     0         0         0B        0B
                                    ^^
                                  全部清除
```

#### 方法 3：全面系统清理

```bash
# 清理所有未使用资源（镜像、容器、卷、缓存）
docker system prune -a

# 包括卷（慎用！会删除持久化数据）
docker system prune -a --volumes
```

### 清除缓存的影响

#### 实际测试结果（GalOS 项目）

**清除前**：
```bash
$ docker system df
Build Cache     32        0         12.35GB   12.35GB (100%)

$ docker images galos
galos:latest   c3eb249f3113       3.89GB      ← 镜像正常
```

**执行清除**：
```bash
$ docker buildx prune -a -f
Total: 12.35GB
```

**清除后**：
```bash
$ docker system df
Build Cache     0         0         0B        0B       ← 缓存清空

$ docker images galos
galos:latest   c3eb249f3113       3.89GB      ← 镜像完全正常

$ docker run --rm galos:latest rustc --version
rustc 1.89.0-nightly (60dabef95 2025-05-19)  ← 功能正常

$ docker run --rm galos:latest qemu-system-riscv64 --version
QEMU emulator version 10.1.2                  ← 功能正常
```

**结论**：
- ✅ 释放了 12.35 GB 磁盘空间
- ✅ 镜像完全保留，大小不变
- ✅ 容器运行完全正常
- ✅ 所有功能都正常工作

#### 影响对比表

| 场景 | 清除缓存的影响 |
|------|---------------|
| **使用现有镜像** | ✅ 无影响（镜像保留） |
| **运行容器** | ✅ 无影响 |
| **docker-compose up** | ✅ 无影响 |
| **重新构建镜像** | ⚠️ 变慢（需要重新执行所有构建步骤）|
| **构建时间** | ⚠️ 从缓存的几分钟 → 无缓存的 30-60 分钟 |
| **网络使用** | ⚠️ 需要重新下载依赖（记得配置代理）|

### 最佳清理策略

#### 策略 1：定期自动清理（推荐）

```bash
# 添加到 crontab，每周清理一次旧缓存
# 每周日凌晨 2 点执行
0 2 * * 0 docker buildx prune --filter until=168h -f
```

#### 策略 2：磁盘空间监控

```bash
# 磁盘空间不足时才清理
df -h / | awk 'NR==2 {if ($(NF-1) > 80) system("docker buildx prune -a -f")}'
```

#### 策略 3：按需手动清理

```bash
# 构建前检查，按需清理
docker system df
# 如果 Build Cache 很大，手动清理
docker buildx prune -a
```

### 清理其他资源

#### 清理未使用的镜像

```bash
# 查看未使用的镜像
docker images -f "dangling=true"

# 清理悬空镜像（无标签的中间镜像）
docker image prune

# 清理所有未使用的镜像（包括有标签但无容器使用的）
docker image prune -a
```

**实际示例（GalOS）**：
```bash
$ docker images -a
IMAGE          ID             DISK USAGE
galos:latest   c3eb249f3113       3.89GB
<untagged>     9b295e92438f       3.84GB    ← 旧版本，可删除
               ^^^^^^^^^^
              没有名称的旧镜像

$ docker image prune
Deleted Images:
untagged: sha256:9b295e92438f...
Total reclaimed space: 3.84GB
```

#### 清理停止的容器

```bash
# 查看所有容器（包括停止的）
docker ps -a

# 清理所有停止的容器
docker container prune

# 强制删除特定容器
docker rm -f <container-id>
```

#### 清理未使用的卷

```bash
# 查看所有卷
docker volume ls

# 清理未使用的卷
docker volume prune

# ⚠️ 谨慎：卷中可能包含重要数据
```

### 清理命令速查表

| 命令 | 清理对象 | 安全性 |
|------|---------|--------|
| `docker buildx prune -a -f` | 所有构建缓存 | ✅ 安全 |
| `docker image prune` | 悬空镜像 | ✅ 安全 |
| `docker image prune -a` | 所有未使用镜像 | ⚠️ 谨慎（可能删除需要的镜像）|
| `docker container prune` | 停止的容器 | ✅ 安全 |
| `docker volume prune` | 未使用的卷 | ⚠️ 谨慎（可能丢失数据）|
| `docker system prune` | 容器+镜像+网络+缓存 | ⚠️ 谨慎 |
| `docker system prune -a --volumes` | 全部清理 | ❌ 危险（会删除所有数据）|

### 监控磁盘使用

#### 实时监控

```bash
# 查看总体使用情况
docker system df

# 查看详细使用（每个镜像/容器）
docker system df -v

# 持续监控
watch -n 5 docker system df
```

#### 生成使用报告

```bash
# 生成详细报告
docker system df -v > docker-usage-report.txt

# 查看最大的镜像
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | sort -k 3 -h

# 查看最大的构建缓存
docker buildx du | sort -k 3 -h
```

### 常见问题

#### Q1: 清除缓存后镜像还能用吗？
**A**: ✅ 完全可以！构建缓存只影响构建速度，不影响已构建的镜像。

#### Q2: 清除缓存会影响 `docker-compose` 吗？
**A**: ✅ 不会！`docker-compose` 使用的是已构建的镜像，不依赖缓存。

#### Q3: 如何避免重复下载依赖？
**A**: 使用 **named volume** 缓存依赖：
```yaml
# docker-compose.yml
volumes:
  - cargo-cache:/usr/local/cargo/registry
  - cargo-git:/usr/local/cargo/git

volumes:
  cargo-cache:
  cargo-git:
```

#### Q4: 缓存清除后多久会重新产生？
**A**: 只有在执行 `docker build` 时才会产生新缓存。如果只运行容器，不会产生缓存。

---

## 最佳实践

### 1. 使用 docker-compose

**好处**：
- 配置集中管理
- 避免长命令
- 易于版本控制

**示例**：
```yaml
# docker-compose.yml
version: '3.8'
services:
  galos-dev:
    image: galos:latest
    network_mode: host
    working_dir: /workspace/GalOS
    volumes:
      - .:/workspace/GalOS
    environment:
      - HTTP_PROXY=http://127.0.0.1:7897
      - HTTPS_PROXY=http://127.0.0.1:7897
```

**使用**：
```bash
# 代替长 docker run 命令
docker-compose run --rm galos-dev make build
```

### 2. 创建辅助脚本

```bash
#!/bin/bash
# docker-build.sh

docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash -c "$@"
```

**使用**：
```bash
chmod +x docker-build.sh
./docker-build.sh "make ARCH=riscv64 build"
```

### 3. 调试技巧

#### 进入运行中的容器
```bash
# 启动长运行容器
docker run -d --name debug galos:latest sleep 3600

# 进入容器调试
docker exec -it debug bash

# 完成后删除
docker stop debug && docker rm debug
```

#### 查看容器日志
```bash
# 实时查看
docker logs -f <container-id>

# 查看最后 100 行
docker logs --tail 100 <container-id>
```

#### 检查容器内进程
```bash
docker exec <container-id> ps aux
```

#### 检查网络
```bash
# 容器内网络配置
docker exec <container-id> ip addr

# 测试连接
docker exec <container-id> ping -c 3 google.com
```

### 4. 清理资源

```bash
# 删除所有停止的容器
docker container prune

# 删除未使用的镜像
docker image prune

# 删除未使用的卷
docker volume prune

# 全面清理
docker system prune -a
```

---

## 总结

### 关键要点

1. **网络模式选择**
   - 需要访问主机服务 → Host 模式
   - 需要网络隔离 → Bridge 模式

2. **代理配置**
   - Host 网络 + 环境变量
   - Cargo 配置文件 + git-fetch-with-cli

3. **命令执行**
   - 简单命令 → 直接 docker run
   - 复杂命令 → bash -c 包装
   - 交互开发 → docker run -it

4. **数据持久化**
   - 代码目录 → volume 挂载
   - 构建缓存 → named volume

### 常见错误速查表

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `error while loading shared libraries` | 缺少运行时库 | 安装对应的 lib 包 |
| `SSL error: unknown error` | libgit2 SSL 问题 | git-fetch-with-cli + 代理 |
| `Application path "" is not valid` | Makefile 变量未初始化 | 使用 bash -c 包装 |
| `Connection refused (127.0.0.1)` | 网络模式不正确 | 使用 --network=host |
| `Permission denied` | 文件权限问题 | --user 或 chown |

### 学习资源

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [Dockerfile 最佳实践](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

---

## 附录：实际案例完整记录

### GalOS Docker 工作流完整流程

**初始问题**：容器构建失败，耗时 15+ 分钟后 SSL 错误

**排查过程**：
1. 发现 QEMU 库缺失 → 快速修复镜像
2. 测试 defconfig → SSL 错误
3. 检查网络 → 发现需要代理
4. 配置代理 → Bridge 模式无法访问
5. 改用 Host 网络 → 成功

**最终方案**：
```bash
# 1. 修复镜像
docker commit <fixed-container> galos:latest

# 2. 配置代理
# .cargo/config.toml
[net]
git-fetch-with-cli = true
[http]
proxy = "http://127.0.0.1:7897"

# 3. 使用正确的运行方式
docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash -c "make ARCH=riscv64 build"
```

**性能对比**：
- 修复前：15+ 分钟失败
- 修复后：3 分钟 + 26 秒成功
- 总耗时：< 4 分钟

**关键学习点**：
1. 理解 Docker 网络模式的区别
2. 正确配置代理访问
3. 使用 bash -c 包装复杂命令
4. 快速修复 vs 完全重建的权衡
