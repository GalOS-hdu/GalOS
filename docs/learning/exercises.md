# Docker 实践练习

通过实际操作学习 Docker，基于 GalOS 项目的真实场景。

## 📚 练习说明

- ⭐ = 基础级别
- ⭐⭐ = 中级级别
- ⭐⭐⭐ = 高级级别

每个练习包含：
1. 目标
2. 操作步骤
3. 预期结果
4. 解释说明

---

## 练习 1：运行第一个容器 ⭐

### 目标
学习基本的容器运行和交互

### 步骤

**1.1 运行一个简单命令**
```bash
docker run --rm galos:latest echo "Hello Docker"
```

**预期输出**：
```
Hello Docker
```

**问题**：
- `--rm` 参数是什么意思？
- 容器运行完成后发生了什么？

<details>
<summary>答案</summary>

- `--rm`：容器退出后自动删除
- 容器执行完命令后立即退出并被删除
</details>

**1.2 查看容器是否还存在**
```bash
docker ps -a | grep galos
```

**预期输出**：
```
（空，没有输出）
```

**1.3 不使用 --rm 参数运行**
```bash
docker run galos:latest echo "Hello Docker"
docker ps -a | grep galos
```

**预期输出**：
```
CONTAINER ID   IMAGE          COMMAND                  CREATED
abc123def456   galos:latest   "echo 'Hello Docker'"    5 seconds ago   Exited (0)
```

**1.4 清理容器**
```bash
docker container prune
```

---

## 练习 2：进入容器交互 ⭐

### 目标
学习交互式容器的使用

### 步骤

**2.1 启动交互式 Shell**
```bash
docker run --rm -it galos:latest bash
```

**2.2 在容器内执行命令**
```bash
# 现在你在容器内部
pwd                    # 查看当前目录
ls /opt/qemu/bin       # 查看 QEMU 文件
rustc --version        # 查看 Rust 版本
exit                   # 退出容器
```

**预期行为**：
- 看到容器的提示符（如 `root@abc123:/workspace#`）
- 可以执行多条命令
- `exit` 后返回主机

**问题**：
- 容器内的文件系统和主机一样吗？
- 退出后容器还在运行吗？

<details>
<summary>答案</summary>

- 不一样，容器有独立的文件系统
- 使用 `--rm` 参数，退出后容器自动删除
</details>

---

## 练习 3：数据挂载 ⭐⭐

### 目标
学习在容器和主机间共享文件

### 步骤

**3.1 创建测试文件**
```bash
echo "Hello from host" > /tmp/test.txt
cat /tmp/test.txt
```

**3.2 挂载目录到容器**
```bash
docker run --rm -v /tmp:/container_tmp galos:latest \
  cat /container_tmp/test.txt
```

**预期输出**：
```
Hello from host
```

**3.3 在容器内创建文件**
```bash
docker run --rm -v /tmp:/container_tmp galos:latest \
  bash -c "echo 'Hello from container' > /container_tmp/from_container.txt"
```

**3.4 在主机上查看**
```bash
cat /tmp/from_container.txt
ls -l /tmp/from_container.txt
```

**预期输出**：
```
Hello from container
-rw-r--r-- 1 root root ... /tmp/from_container.txt
```

**问题**：
- 文件属于谁（哪个用户）？
- 如何让文件属于当前用户？

<details>
<summary>答案</summary>

- 文件属于 root（容器内默认用户）
- 使用 `--user $(id -u):$(id -g)` 参数
</details>

**3.5 使用当前用户**
```bash
docker run --rm \
  --user $(id -u):$(id -g) \
  -v /tmp:/container_tmp \
  galos:latest \
  bash -c "echo 'From current user' > /container_tmp/from_user.txt"

ls -l /tmp/from_user.txt
```

**预期输出**：
```
-rw-r--r-- 1 youruser yourgroup ... /tmp/from_user.txt
```

---

## 练习 4：网络模式对比 ⭐⭐

### 目标
理解不同网络模式的区别

### 准备
在主机上启动一个简单的 HTTP 服务器：
```bash
# 在一个终端运行
python3 -m http.server 8888
```

### 步骤

**4.1 Bridge 模式访问主机服务（失败）**
```bash
docker run --rm --network=bridge galos:latest \
  curl -I http://127.0.0.1:8888
```

**预期结果**：
```
curl: (7) Failed to connect to 127.0.0.1 port 8888: Connection refused
```

**原因**：Bridge 模式下，容器的 `127.0.0.1` 指向容器自己

**4.2 查找 Docker 网桥 IP**
```bash
ip addr show docker0 | grep "inet "
```

**预期输出**：
```
inet 172.17.0.1/16 ...
```

**4.3 使用网桥 IP 访问（成功）**
```bash
docker run --rm --network=bridge galos:latest \
  curl -I http://172.17.0.1:8888
```

**预期结果**：
```
HTTP/1.0 200 OK
```

**4.4 Host 模式访问（成功）**
```bash
docker run --rm --network=host galos:latest \
  curl -I http://127.0.0.1:8888
```

**预期结果**：
```
HTTP/1.0 200 OK
```

**总结**：
| 网络模式 | 访问 127.0.0.1 | 访问 172.17.0.1 |
|---------|----------------|-----------------|
| Bridge  | ❌ 失败         | ✅ 成功          |
| Host    | ✅ 成功         | ✅ 成功          |

---

## 练习 5：构建 GalOS ⭐⭐⭐

### 目标
在容器内完成完整的项目构建

### 步骤

**5.1 生成配置**
```bash
cd /path/to/GalOS

docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash -c "make ARCH=riscv64 defconfig"
```

**预期输出**：
```
Updating crates.io index
Updating git repository ...
...
Config generated successfully
```

**检查生成的文件**：
```bash
ls -l .axconfig.toml
cat .axconfig.toml | head -10
```

**5.2 构建项目**
```bash
docker run --rm --network=host \
  -e HTTP_PROXY=http://127.0.0.1:7897 \
  -e HTTPS_PROXY=http://127.0.0.1:7897 \
  -v $(pwd):/workspace/GalOS \
  -w /workspace/GalOS \
  galos:latest \
  bash -c "make ARCH=riscv64 build"
```

**预期输出**：
```
Building App: GalOS, Arch: riscv64
Compiling proc-macro2 v1.0.103
...
Finished release profile [optimized] target(s) in 26.04s
```

**检查构建产物**：
```bash
ls -lh GalOS_riscv64-qemu-virt.*
file GalOS_riscv64-qemu-virt.elf
```

**预期输出**：
```
-rwxr-xr-x 1 root root 46M ... GalOS_riscv64-qemu-virt.elf
-rwxr-xr-x 1 root root 34M ... GalOS_riscv64-qemu-virt.bin

GalOS_riscv64-qemu-virt.elf: ELF 64-bit LSB executable, UCB RISC-V
```

---

## 练习 6：调试容器问题 ⭐⭐⭐

### 目标
学习排查和修复容器问题

### 场景
模拟缺少库文件的问题

**6.1 检测问题**
```bash
docker run --rm galos:latest ldd /opt/qemu/bin/qemu-system-riscv64 | grep "not found"
```

**如果有输出（如 `libfdt.so.1 => not found`），说明缺少库**

**6.2 启动调试容器**
```bash
docker run -d --name debug-galos galos:latest sleep 3600
```

**6.3 进入容器调试**
```bash
docker exec -it debug-galos bash
```

**6.4 在容器内安装库**
```bash
# 容器内执行
apt-get update
apt-get install -y libfdt1 libslirp0
exit
```

**6.5 测试修复**
```bash
docker exec debug-galos qemu-system-riscv64 --version
```

**预期输出**：
```
QEMU emulator version 10.1.2
```

**6.6 保存修复后的镜像**
```bash
docker commit debug-galos galos:fixed
```

**6.7 清理**
```bash
docker stop debug-galos
docker rm debug-galos
```

**6.8 使用修复后的镜像**
```bash
docker run --rm galos:fixed qemu-system-riscv64 --version
```

---

## 练习 7：容器资源管理 ⭐⭐

### 目标
学习监控和限制容器资源

**7.1 启动容器并查看资源使用**
```bash
# 启动一个占用 CPU 的容器
docker run -d --name cpu-test galos:latest \
  bash -c "while true; do echo test > /dev/null; done"

# 查看资源使用
docker stats cpu-test
```

**预期输出**：
```
CONTAINER ID   NAME       CPU %     MEM USAGE / LIMIT
abc123def      cpu-test   99.5%     10MiB / 16GiB
```

**7.2 限制 CPU**
```bash
docker stop cpu-test && docker rm cpu-test

# 限制为 50% CPU
docker run -d --name cpu-test --cpus=0.5 galos:latest \
  bash -c "while true; do echo test > /dev/null; done"

docker stats cpu-test --no-stream
```

**预期结果**：CPU 使用率约 50%

**7.3 限制内存**
```bash
docker run --rm --memory=100m galos:latest \
  bash -c "free -h"
```

**7.4 清理**
```bash
docker stop cpu-test && docker rm cpu-test
```

---

## 练习 8：使用 docker-compose ⭐⭐

### 目标
学习使用 docker-compose 简化操作

**8.1 查看配置**
```bash
cat docker-compose.yml
```

**8.2 使用 docker-compose 构建**
```bash
docker-compose run --rm galos-dev bash -c "make ARCH=riscv64 defconfig"
docker-compose run --rm galos-dev bash -c "make ARCH=riscv64 build"
```

**8.3 进入交互式环境**
```bash
docker-compose run --rm galos-dev bash

# 在容器内
make ARCH=riscv64 build
exit
```

**对比**：
```bash
# 不使用 docker-compose（长命令）
docker run --rm --network=host -e HTTP_PROXY=... -e HTTPS_PROXY=... -v $(pwd):... galos:latest bash

# 使用 docker-compose（简洁）
docker-compose run --rm galos-dev bash
```

---

## 挑战练习 🏆

### 挑战 1：多阶段构建
修改 Dockerfile 优化构建时间和镜像大小

### 挑战 2：自动化脚本
编写脚本自动完成：构建 → 测试 → 清理

### 挑战 3：CI/CD 集成
设置 GitHub Actions 使用 Docker 进行持续集成

---

## 学习检查清单

完成所有练习后，你应该能够：

- [ ] 运行和管理容器
- [ ] 使用交互式 Shell
- [ ] 挂载和共享文件
- [ ] 理解不同网络模式
- [ ] 配置环境变量
- [ ] 排查和修复问题
- [ ] 监控资源使用
- [ ] 使用 docker-compose
- [ ] 完成实际项目构建

---

## 下一步

完成这些练习后，建议：

1. 阅读 [详细学习指南](./guide.md)
2. 查阅 [快速参考](./reference.md)
3. 实践构建自己的 Dockerfile
4. 探索 Docker 网络和卷的高级用法

## 常见错误和解决方案

### 错误 1：权限被拒绝
```bash
# 错误
docker: permission denied while trying to connect to the Docker daemon socket

# 解决
sudo usermod -aG docker $USER
# 然后注销并重新登录
```

### 错误 2：端口已被占用
```bash
# 错误
Bind for 0.0.0.0:8080 failed: port is already allocated

# 解决
# 查找占用端口的进程
sudo lsof -i :8080
# 或者使用其他端口
docker run -p 8081:80 ...
```

### 错误 3：磁盘空间不足
```bash
# 错误
no space left on device

# 解决
docker system prune -a  # 清理所有未使用的资源
```

---

## 实践技巧

1. **保持简单**：从简单命令开始，逐步增加复杂度
2. **多实验**：不要害怕尝试，容器是隔离的，不会影响主机
3. **查看日志**：遇到问题先看日志 `docker logs <container>`
4. **使用帮助**：`docker --help` 和 `docker <command> --help`
5. **清理资源**：定期运行 `docker system prune`

祝你学习愉快！🎉
