# LoongArch64 启动问题调查记录

## 问题描述

执行命令：
```bash
docker compose run --rm galos-dev bash -c "python3 scripts/ci-test.py loongarch64"
```

**当前状态**：
- ✅ QEMU 成功启动
- ✅ QEMU 接受 ELF 格式内核（不再报 "The image is not ELF" 错误）
- ❌ 内核无任何串口输出，5秒后超时

**错误信息**：
```
❌ Boot failed or timed out
TimeoutError: timed out
```

---

## 调查过程时间线

### 1. 初始错误（已解决）

**错误现象**：
```
qemu-system-loongarch64: could not load kernel 'GalOS_loongarch64-qemu-virt.bin': The image is not ELF
```

**原因**：
- GalOS 项目使用的 arceos 子模块版本为 `4d1be13`
- 该版本的 `arceos/scripts/make/qemu.mk` 第 45 行配置为：
  ```makefile
  qemu_args-loongarch64 := \
    -machine $(machine) \
    -kernel $(FINAL_IMG)  # FINAL_IMG 指向 .bin 二进制文件
  ```
- QEMU 9.2.4 的 loongarch64 直接内核启动要求 ELF 格式

**解决方案**：
修改 `arceos/scripts/make/qemu.mk` 第 45 行：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(OUT_ELF)  # 改为使用 ELF 格式
```

**修改位置**：`/home/c20h30o2/files/GalOS/arceos/scripts/make/qemu.mk:45`

**注意**：这是对子模块的临时测试修改，不应提交！

---

### 2. 当前问题（未解决）

**现象**：
- QEMU 启动成功
- QEMU 等待串口连接：`info: QEMU waiting for connection on: disconnected:tcp:0.0.0.0:4444,server=on`
- CI 测试脚本成功连接到串口
- **内核无任何输出**
- 10秒后超时

**测试输出**：
```
qemu-system-loongarch64 -m 1G -smp 1 -machine virt -kernel /workspace/GalOS/GalOS_loongarch64-qemu-virt.elf -device virtio-blk-pci,drive=disk0 -drive id=disk0,if=none,format=raw,file=disk.img -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::5555-:5555,hostfwd=udp::5555-:5555 -nographic -monitor none -serial tcp::4444,server=on
```

**QEMU 日志**：
- 启用 `QEMU_LOG=y` 后生成的 `arceos/qemu.log` 文件为空（0 字节）
- 说明 CPU 从未开始执行任何指令

---

## 技术分析

### 3.1 ELF 文件分析

**入口点地址**：
```bash
readelf -h GalOS_loongarch64-qemu-virt.elf
Entry point address: 0xffff800000200000
```

**对比其他架构**：
- **riscv64** 入口点：`0xffffffc080200000`（虚拟地址，可正常启动）
- **loongarch64** 入口点：`0xffff800000200000`（虚拟地址，无法启动）

**结论**：虚拟地址本身不是问题，因为 riscv64 也使用虚拟地址并能正常工作。

---

### 3.2 QEMU 参数对比

**riscv64 配置**（可正常启动）：
```makefile
qemu_args-riscv64 := \
  -machine $(machine) \
  -bios default \      # ← 有 BIOS (OpenSBI)
  -kernel $(FINAL_IMG)
```

**loongarch64 配置**（当前测试版本）：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(OUT_ELF)   # ← 无 BIOS
```

**尝试添加 BIOS**：
修改为 `-bios default` 后出现错误：
```
qemu-system-loongarch64: Could not find ROM image 'default'
```

**结论**：loongarch64 没有类似 OpenSBI 的默认 BIOS ROM。

---

### 3.3 Arceos 上游研究

**当前使用版本**：
```bash
git submodule status arceos
# 4d1be13842ab800e585c375f723694224b4a1a7e arceos (4d1be13)
```

**重要提交历史**：

1. **`6f67c50` - feat: add loongarch64 support**
   - 最初添加 loongarch64 支持
   - 使用 `$(OUT_ELF)` 格式

2. **`4b0bc46` - feat(la64-qemu): boot from binary** (2025-09-07)
   - 将 loongarch64 改为使用 `$(FINAL_IMG)` (binary 格式)
   - 这个修改导致了我们在 QEMU 9.2.4 上的 "The image is not ELF" 错误
   - diff 显示：
     ```diff
     qemu_args-loongarch64 := \
       -machine $(machine) \
     -  -kernel $(OUT_ELF)
     +  -kernel $(FINAL_IMG)
     ```

**Arceos 上游 CI 配置**：
- 文件：`arceos/.github/workflows/test.yml`
- QEMU 版本：`9.2.4`（与我们相同）
- Rust 工具链：`nightly-2025-05-20`（与我们相同）
- 测试的架构：`[x86_64, riscv64, aarch64, loongarch64]`
- **上游在相同 QEMU 版本下成功测试 loongarch64**

**关键发现**：
- 上游使用相同的 QEMU 9.2.4
- 上游当前版本应该已经包含 `4b0bc46` 提交（使用 binary 格式）
- 但上游测试通过，我们失败

**可能原因**：
1. 我们的 arceos 版本 `4d1be13` 可能早于 `4b0bc46`
2. 或者我们的 QEMU 编译配置与上游不同

---

### 3.4 QEMU 版本能力研究

**Web 搜索结果**：

**QEMU 9.1** (2024年9月发布):
- **关键特性**：引入了 LoongArch64 直接 ELF 内核启动支持
- 支持通过 extioi virt 扩展运行最多 256 个 vCPU

**QEMU 9.2** (2024年12月发布):
- 1700+ 提交，209 位贡献者
- 继续支持 LoongArch64 ELF 直接启动
- 没有针对 LoongArch 的额外重大变更

**QEMU 7.1** (更早):
- 首次添加 LoongArch 64 位架构支持
- 匹配 Loongson 3A5000 SoC 和 Loongson 7A1000 主桥

**结论**：
- QEMU 9.2.4 **应该支持** ELF 格式的直接内核启动
- 我们的修改方向是正确的

---

## 构建系统分析

### 4.1 ELF 和 BIN 文件生成流程

**顶层 Makefile** (`GalOS/Makefile:38-39`):
```makefile
build run debug disasm: defconfig
	@make -C arceos $@
```

**Arceos Makefile** (`arceos/Makefile:150-161`):
```makefile
OUT_ELF := $(OUT_DIR)/$(APP_NAME)_$(PLAT_NAME).elf
OUT_BIN := $(patsubst %.elf,%.bin,$(OUT_ELF))

ifeq ($(UIMAGE), y)
  FINAL_IMG := $(OUT_UIMG)
else
  FINAL_IMG := $(OUT_BIN)  # 默认使用 BIN
endif

build: $(OUT_DIR) $(FINAL_IMG)
```

**构建规则** (`arceos/scripts/make/build.mk:51-71`):
```makefile
_cargo_build: oldconfig
	$(call cargo_build,$(APP),$(AX_FEAT) $(LIB_FEAT) $(APP_FEAT))
	@cp $(rust_elf) $(OUT_ELF)  # Cargo 生成 ELF

$(OUT_BIN): _cargo_build $(OUT_ELF)
	$(call run_cmd,$(OBJCOPY),$(OUT_ELF) -O binary --strip-all $@)
```

**结论**：
- ELF 文件是 Cargo/rustc 直接生成的
- BIN 文件是通过 objcopy 从 ELF 转换的
- 两个文件都存在，只是 QEMU 参数决定使用哪个

---

### 4.2 QEMU 编译配置

**Dockerfile** (`GalOS/Dockerfile:27-41`):
```dockerfile
WORKDIR /tmp/qemu-build
RUN wget https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz && \
    tar xf qemu-${QEMU_VERSION}.tar.xz && \
    cd qemu-${QEMU_VERSION} && \
    ./configure \
        --prefix=/opt/qemu \
        --target-list=x86_64-softmmu,riscv64-softmmu,aarch64-softmmu,loongarch64-softmmu \
        --enable-kvm \
        --enable-slirp \
        --disable-docs && \
    make -j$(nproc) && \
    make install
```

**docker-compose.yml** (QEMU 版本):
```yaml
args:
  QEMU_VERSION: "9.2.4"
```

**结论**：我们的 QEMU 编译配置看起来是标准的。

---

## 尝试的调试方法

### 5.1 QEMU 调试日志

**尝试**：
```bash
make ARCH=loongarch64 ACCEL=n QEMU_LOG=y justrun
```

**配置** (`arceos/scripts/make/qemu.mk:93-95`):
```makefile
ifeq ($(QEMU_LOG), y)
  qemu_args-y += -D qemu.log -d in_asm,int,mmu,pcall,cpu_reset,guest_errors
endif
```

**结果**：
- 生成的 `arceos/qemu.log` 文件大小为 0 字节
- 说明 CPU 从未开始执行代码
- 甚至连 CPU reset 都没有记录

---

### 5.2 Git 历史查找

**查找 loongarch 相关提交**：
```bash
git -C arceos log --all --oneline --grep="loongarch" | head -10
```

**结果**：
```
8469c4b fix: disable unwind for loongarch64
5de5772 [axplat] remove platform-specific codes and import them externally during build
55d983d Merge pull request #255 from arceos-org/softfloat
22921f7 [fp/simd] always use `-softfloat` target for aarch64 and loongarch64
983fb98 [loongarch64] add support of LSX extension (SIMD instruction)
29bdc92 Merge pull request #225 from yfblock/main
6f67c50 feat: add loongarch64 support
```

**查看关键提交**：
```bash
git -C arceos show 4b0bc46
# 该提交将 loongarch64 从 ELF 改为 binary
```

---

## 所有修改尝试详细记录

### 尝试 1：修改为使用 ELF 格式（部分成功）

**时间**：调查初期

**问题**：
```
qemu-system-loongarch64: could not load kernel 'GalOS_loongarch64-qemu-virt.bin': The image is not ELF
```

**分析过程**：
1. 检查了 QEMU 参数，发现使用 `$(FINAL_IMG)` 指向 `.bin` 文件
2. 对比 riscv64 配置（使用 binary 但正常工作）
3. 查看 git 历史，发现原始 loongarch64 支持使用 ELF

**修改内容**：
```bash
文件：arceos/scripts/make/qemu.mk
行号：45
```

**修改前**：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(FINAL_IMG)
```

**修改后**：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(OUT_ELF)
```

**执行命令**：
```bash
docker compose run --rm galos-dev bash -c "python3 scripts/ci-test.py loongarch64"
```

**结果**：
- ✅ 不再报 "The image is not ELF" 错误
- ✅ QEMU 成功启动
- ❌ 内核无输出，超时

**完整输出**：
```
Fixing permissions for cargo directories...
Permissions fixed.
make[1]: Entering directory '/workspace/GalOS/arceos'
    Running on qemu...
qemu-system-loongarch64 -m 1G -smp 1 -machine virt -kernel /workspace/GalOS/GalOS_loongarch64-qemu-virt.elf -device virtio-blk-pci,drive=disk0 -drive id=disk0,if=none,format=raw,file=disk.img -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::5555-:5555,hostfwd=udp::5555-:5555 -nographic -monitor none -serial tcp::4444,server=on
make[1]: Leaving directory '/workspace/GalOS/arceos'
qemu-system-loongarch64: -serial tcp::4444,server=on: info: QEMU waiting for connection on: disconnected:tcp:0.0.0.0:4444,server=on

❌ Boot failed or timed out
TimeoutError: timed out
```

**结论**：
- 修改方向正确（QEMU 接受 ELF）
- 但存在更深层次的问题

---

### 尝试 2：添加 BIOS 参数（失败）

**时间**：尝试 1 之后

**假设**：loongarch64 可能像 riscv64 一样需要 BIOS

**分析过程**：
1. 对比 riscv64 配置，发现有 `-bios default` 参数
2. riscv64 使用 OpenSBI 作为默认 BIOS
3. 尝试为 loongarch64 添加相同参数

**修改内容**：
```bash
文件：arceos/scripts/make/qemu.mk
行号：43-46
```

**修改后**：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -bios default \
  -kernel $(OUT_ELF)
```

**执行命令**：
```bash
docker compose run --rm galos-dev bash -c "python3 scripts/ci-test.py loongarch64"
```

**结果**：
- ❌ 立即失败
- 错误：`Could not find ROM image 'default'`

**完整错误输出**：
```
qemu-system-loongarch64: -serial tcp::4444,server=on: info: QEMU waiting for connection on: disconnected:tcp:0.0.0.0:4444,server=on
qemu-system-loongarch64: Could not find ROM image 'default'
make[1]: *** [Makefile:188: justrun] Error 1
make: *** [Makefile:36: justrun] Error 2
Traceback (most recent call last):
  File "/workspace/GalOS/scripts/ci-test.py", line 76, in <module>
    raise Exception("Did not reach BusyBox shell prompt")
Exception: Did not reach BusyBox shell prompt
```

**执行的恢复操作**：
```bash
# 立即恢复修改
文件：arceos/scripts/make/qemu.mk
行号：43-46
```

**恢复为**：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(OUT_ELF)
```

**结论**：
- loongarch64 没有名为 'default' 的 ROM 镜像
- QEMU loongarch64 不像 riscv64 那样有内置的 BIOS

---

### 尝试 3：启用 QEMU 调试日志（无有效输出）

**时间**：尝试 2 之后

**目的**：查看 CPU 是否执行了任何代码

**方法 3.1：使用内置的 QEMU_LOG 功能**

**执行命令**：
```bash
docker compose run --rm galos-dev bash -c "
make ARCH=loongarch64 ACCEL=n QEMU_LOG=y justrun QEMU_ARGS='-monitor none -serial tcp::4444,server=on' &
QEMU_PID=\$!
sleep 3
pkill -f 'qemu-system-loongarch64'
sleep 1
if [ -f /workspace/GalOS/arceos/qemu.log ]; then
  head -100 /workspace/GalOS/arceos/qemu.log
else
  echo 'No qemu.log file found'
fi
"
```

**QEMU 参数**（由 QEMU_LOG=y 自动添加）：
```
-D qemu.log -d in_asm,int,mmu,pcall,cpu_reset,guest_errors
```

**结果**：
```bash
ls -lh arceos/qemu.log
# -rw-r--r-- 1 c20h30o2 c20h30o2 0 Nov 30 00:17 arceos/qemu.log
```

- ✅ 日志文件已创建
- ❌ 文件大小为 0 字节
- ❌ 无任何调试输出

**结论**：
- CPU 从未执行任何指令
- 甚至连 CPU reset 事件都没有记录
- 说明问题在 QEMU 初始化阶段，而不是内核代码

---

**方法 3.2：尝试使用自定义调试参数**

**执行命令**：
```bash
docker compose run --rm galos-dev bash -c "
make ARCH=loongarch64 ACCEL=n justrun QEMU_ARGS='-monitor none -serial tcp::4444,server=on -d cpu_reset,in_asm -D /tmp/qemu-debug.log' &
sleep 3
cat /tmp/qemu-debug.log 2>/dev/null || echo 'No log file created'
pkill -9 qemu-system-loongarch64"
```

**结果**：
```
No log file created
```

- ❌ 在容器内 /tmp 也无法生成日志
- 说明 QEMU 可能在更早的阶段就停止了日志记录

---

### 尝试 4：检查 ELF 文件入口点（正常）

**时间**：调试过程中

**目的**：确认 ELF 文件格式是否正确

**执行命令**：
```bash
docker compose run --rm galos-dev bash -c "readelf -h /workspace/GalOS/GalOS_loongarch64-qemu-virt.elf"
```

**输出**（关键部分）：
```
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           LoongArch
  Version:                           0x1
  Entry point address:               0xffff800000200000
  ...
```

**分析**：
- ✅ ELF 格式正确
- ✅ Machine 类型：LoongArch
- ✅ 入口点：0xffff800000200000（虚拟地址）

**对比 riscv64**：
```bash
docker compose run --rm galos-dev bash -c "make ARCH=riscv64 build && readelf -h GalOS_riscv64-qemu-virt.elf | grep Entry"
```

**输出**：
```
Entry point address:               0xffffffc080200000
```

**结论**：
- riscv64 也使用虚拟地址，并且能正常工作
- 虚拟地址本身不是问题
- loongarch64 入口点地址格式正常

---

### 尝试 5：查找 Git 历史以理解变更（发现关键信息）

**时间**：调试中期

**目的**：了解 loongarch64 支持的演变

**执行命令 5.1：查找 loongarch 相关提交**
```bash
git -C /home/c20h30o2/files/GalOS/arceos log --all --oneline --grep="loongarch" | head -10
```

**输出**：
```
8469c4b fix: disable unwind for loongarch64
5de5772 [axplat] remove platform-specific codes and import them externally during build
55d983d Merge pull request #255 from arceos-org/softfloat
22921f7 [fp/simd] always use `-softfloat` target for aarch64 and loongarch64
983fb98 [loongarch64] add support of LSX extension (SIMD instruction)
29bdc92 Merge pull request #225 from yfblock/main
6f67c50 feat: add loongarch64 support
```

**执行命令 5.2：查看 qemu.mk 的修改历史**
```bash
git -C /home/c20h30o2/files/GalOS/arceos log --oneline --all -- scripts/make/qemu.mk | head -20
```

**输出**：
```
4d1be13 refactor: pin dependencies (#18)
0662dd4 feat(hal): patch axplat
80e5a0a feat: vsock (#3)
be6ac48 feat(build): flexible mem & smp config
c1684c7 feat(build): icount
4b0bc46 feat(la64-qemu): boot from binary    ← 关键提交
30fe569 chore: custom QEMU_ARGS
75c624e add: qemu custom arguments
f4ead9b feat: add input devices
377e649 feat: add icount
a5f0206 feat: generally improve robustness
c7f8fc7 chore: improve qemu debug
46b3900 [hal] link default platform crate for x86_64 and aarch64
6f67c50 feat: add loongarch64 support        ← 初始支持
...
```

**执行命令 5.3：查看关键提交 4b0bc46**
```bash
git -C /home/c20h30o2/files/GalOS/arceos show 4b0bc46
```

**输出（关键部分）**：
```diff
commit 4b0bc467bd3e74ab8b18a4a664b24915947bdd11
Author: Asakura Mizu <asakuramizu111@gmail.com>
Date:   Sun Sep 7 21:29:30 2025 +0800

    feat(la64-qemu): boot from binary

diff --git a/scripts/make/qemu.mk b/scripts/make/qemu.mk
index 33e3eaf..3046737 100644
--- a/scripts/make/qemu.mk
+++ b/scripts/make/qemu.mk
@@ -44,7 +44,7 @@ qemu_args-aarch64 := \

 qemu_args-loongarch64 := \
   -machine $(machine) \
-  -kernel $(OUT_ELF)
+  -kernel $(FINAL_IMG)
```

**执行命令 5.4：查看初始支持 6f67c50**
```bash
git -C /home/c20h30o2/files/GalOS/arceos show 6f67c50:scripts/make/qemu.mk | grep -A 5 "qemu_args-loongarch64"
```

**输出**：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(OUT_ELF)

qemu_args-y := -m $(MEM) -smp $(SMP) $(qemu_args-$(ARCH))
```

**执行命令 5.5：检查当前子模块状态**
```bash
cd /home/c20h30o2/files/GalOS && git submodule status arceos
```

**输出**：
```
4d1be13842ab800e585c375f723694224b4a1a7e arceos (4d1be13)
```

**分析**：
- 初始支持（6f67c50）使用 ELF 格式
- 2025年9月7日的提交（4b0bc46）改为 binary 格式
- 当前版本（4d1be13）在 git log 中出现在 4b0bc46 之前
- 这意味着我们的版本**早于** binary 格式的修改

**疑问**：
- 为什么我们的版本配置是 binary 而不是 ELF？
- 可能是 cherry-pick 或 rebase 导致的

**执行命令 5.6：检查当前实际配置**
```bash
git -C /home/c20h30o2/files/GalOS/arceos show HEAD:scripts/make/qemu.mk | grep -A 3 "qemu_args-loongarch64"
```

**输出**：
```makefile
qemu_args-loongarch64 := \
  -machine $(machine) \
  -kernel $(FINAL_IMG)
```

**结论**：
- 当前 HEAD (4d1be13) 确实使用 binary 格式
- Git 历史可能被重写或者分支合并过
- 我们的修改回到了类似初始支持的配置

---

### 尝试 6：研究 QEMU 版本支持（Web 搜索）

**时间**：调试后期

**目的**：确认 QEMU 9.2.4 是否支持 ELF 直接启动

**搜索查询**：
```
"QEMU 9.2 loongarch64 direct kernel boot ELF binary format"
```

**关键发现**：

1. **QEMU 9.1 发布信息**（2024年9月）：
   - 引入了 LoongArch64 **直接 ELF 内核启动**支持
   - 支持通过 extioi virt 扩展运行最多 256 个 vCPU

2. **QEMU 9.2 发布信息**（2024年12月）：
   - 1700+ 提交，209 位贡献者
   - 继续支持 LoongArch64 功能
   - 没有针对 LoongArch 的重大变更

3. **QEMU 7.1**（更早）：
   - 首次添加 LoongArch 64 位架构支持

**重要结论**：
- ✅ QEMU 9.2.4 **应该支持** ELF 格式直接启动
- ✅ 我们使用 ELF 的方向是正确的
- ❓ 但为什么 2025年9月的提交要改回 binary？

---

### 尝试 7：检查 Arceos 上游 CI 配置（发现矛盾）

**时间**：调试后期

**目的**：了解上游如何测试 loongarch64

**执行命令**：
```bash
cat arceos/.github/workflows/test.yml
```

**关键内容**：
```yaml
env:
  qemu-version: 9.2.4              ← 与我们相同
  rust-toolchain: nightly-2025-05-20  ← 与我们相同
  arceos-apps: '7ad6143'

jobs:
  app-test:
    strategy:
      matrix:
        arch: [x86_64, riscv64, aarch64, loongarch64]  ← 包含 loongarch64
    steps:
    - uses: arceos-org/setup-qemu@v1
      with:
        version: ${{ env.qemu-version }}
        arch_list: x86_64,aarch64,riscv64,loongarch64
```

**分析**：
- ✅ 上游在相同 QEMU 9.2.4 下测试 loongarch64
- ✅ 使用相同的 Rust 工具链
- ❓ 上游测试通过，我们失败

**可能原因**：
1. 上游使用 `setup-qemu` action，可能是预编译的 QEMU
2. 我们自己编译 QEMU，可能配置不同
3. 上游的 arceos 版本可能更新

---

### 尝试 8：对比 QEMU 编译配置（未发现问题）

**时间**：调试后期

**我们的配置**（Dockerfile:32-37）：
```dockerfile
./configure \
    --prefix=/opt/qemu \
    --target-list=x86_64-softmmu,riscv64-softmmu,aarch64-softmmu,loongarch64-softmmu \
    --enable-kvm \
    --enable-slirp \
    --disable-docs
```

**分析**：
- ✅ 包含 loongarch64-softmmu
- ✅ 启用了 KVM（虽然测试时用 ACCEL=n）
- ✅ 启用了 slirp（网络支持）
- ❓ 是否缺少其他必要的选项？

**未尝试**：
- 查看 setup-qemu action 的实际配置
- 对比预编译 QEMU 的编译参数

---

### 尝试 9：尝试查看 QEMU 文档（被用户中断）

**时间**：调查最后

**计划的操作**：
```
WebFetch: https://www.qemu.org/docs/master/system/target-loongarch.html
目的：查找直接内核启动的要求
```

**状态**：❌ 被用户中断，未执行

**原因**：用户要求停止并记录所有信息

---

## 修改状态总结

### 当前文件状态

**已修改文件**（临时，不应提交）：

1. **arceos/scripts/make/qemu.mk**
   ```diff
   - 原始（行 45）：-kernel $(FINAL_IMG)
   + 当前（行 45）：-kernel $(OUT_ELF)
   ```
   - ⚠️ **这是临时测试修改**
   - ⚠️ **不要提交到仓库**
   - ⚠️ **是对子模块的本地修改**

**已修改文件**（已提交或可提交）：

1. **docker-compose.yml**
   ```diff
   - 原始（行 1）：version: '3.8'
   + 当前（行 1）：# 删除了 version 行
   ```
   - ✅ 这是正常的更新（消除过时警告）
   - ✅ 可以提交

### Git 子模块状态

**检查命令**：
```bash
git status
```

**当前状态**：
```
M arceos  ← 子模块有本地修改
```

**详细检查**：
```bash
cd arceos && git status
```

**输出**：
```
HEAD detached at 4d1be13
Changes not staged for commit:
  modified:   scripts/make/qemu.mk
```

**恢复方法**（如果需要）：
```bash
# 在 arceos 子目录内
git restore scripts/make/qemu.mk

# 或在主仓库
git submodule update --force arceos
```

---

## 所有执行的命令清单

### 初始错误复现
```bash
docker compose run --rm galos-dev bash -c "python3 scripts/ci-test.py loongarch"
# 错误：架构名称错误

docker compose run --rm galos-dev bash -c "python3 scripts/ci-test.py loongarch64"
# 错误：The image is not ELF
```

### 文件检查
```bash
# 读取 qemu.mk 配置
cat arceos/scripts/make/qemu.mk

# 检查 ELF 文件
docker compose run --rm galos-dev bash -c "readelf -h /workspace/GalOS/GalOS_loongarch64-qemu-virt.elf"

# 对比 riscv64
docker compose run --rm galos-dev bash -c "make ARCH=riscv64 build && readelf -h GalOS_riscv64-qemu-virt.elf"
```

### Git 历史分析
```bash
# 查找 loongarch 提交
git -C arceos log --all --oneline --grep="loongarch" | head -10

# 查看 qemu.mk 历史
git -C arceos log --oneline --all -- scripts/make/qemu.mk | head -20

# 查看具体提交
git -C arceos show 4b0bc46
git -C arceos show 6f67c50:scripts/make/qemu.mk

# 检查子模块状态
git submodule status arceos

# 检查当前配置
git -C arceos show HEAD:scripts/make/qemu.mk
```

### 修改和测试
```bash
# 修改 1：改为 ELF 格式
# （通过 Edit 工具完成）

# 测试修改 1
docker compose run --rm galos-dev bash -c "python3 scripts/ci-test.py loongarch64"
# 结果：QEMU 启动但无输出

# 修改 2：添加 -bios default
# （通过 Edit 工具完成）

# 测试修改 2
docker compose run --rm galos-dev bash -c "python3 scripts/ci-test.py loongarch64"
# 结果：Could not find ROM image 'default'

# 恢复修改 2
# （通过 Edit 工具完成）
```

### 调试尝试
```bash
# 启用 QEMU 日志
docker compose run --rm galos-dev bash -c "
make ARCH=loongarch64 ACCEL=n QEMU_LOG=y justrun QEMU_ARGS='-monitor none -serial tcp::4444,server=on' &
sleep 3
pkill -f 'qemu-system-loongarch64'
cat /workspace/GalOS/arceos/qemu.log
"

# 检查日志文件
ls -lh arceos/qemu.log
head -50 arceos/qemu.log
```

### 文件搜索
```bash
# 查找 loongarch 目录
find arceos -type d -name "*loongarch*"

# 查找 loongarch 源文件
find arceos -name "*.rs" -o -name "*.S" | xargs grep -l "loongarch"

# 查找汇编文件
find arceos/modules/axhal -name "*.S"
```

---

## 待调查方向

### 6.1 未完成的调查

1. **QEMU 文档查看**（被用户中断）
   - 原计划：查看 https://www.qemu.org/docs/master/system/target-loongarch.html
   - 目的：了解 LoongArch64 直接内核启动的具体要求
   - 可能包含：所需的固件、设备树、内存布局等信息

2. **与 arceos 上游对比**
   - 上游在相同 QEMU 9.2.4 下测试通过
   - 需要确认：
     - 上游当前 HEAD 的 qemu.mk 配置
     - 上游是否使用了额外的 QEMU 参数
     - 上游的 arceos-apps 测试流程

3. **检查是否需要设备树 (FDT)**
   - riscv64 和 aarch64 通常需要设备树
   - loongarch64 可能也需要
   - 参数：`-dtb <file>` 或 QEMU 自动生成

4. **检查内核链接脚本**
   - 确认内存布局是否符合 QEMU virt machine 的要求
   - 检查入口点地址是否正确

5. **对比其他项目的 loongarch64 配置**
   - 搜索 GitHub 上其他使用 QEMU loongarch64 的项目
   - 查看它们的启动参数

---

## 可能的问题原因

### 7.1 假设 1：缺少固件/BIOS

**证据**：
- riscv64 使用 `-bios default`（OpenSBI）
- loongarch64 没有 BIOS 参数
- 尝试添加 `-bios default` 报错找不到 ROM

**反驳**：
- QEMU 9.1+ 支持 ELF 直接启动，理论上不需要 BIOS
- 上游测试通过，也可能不使用 BIOS

**状态**：不确定

---

### 7.2 假设 2：我们的 arceos 版本问题

**证据**：
- 当前版本 `4d1be13`
- 提交 `4b0bc46` 改为使用 binary（可能在我们之后）
- 但我们手动改回 ELF 后仍无输出

**反驳**：
- 即使改回 ELF，问题依然存在
- 说明不仅仅是格式问题

**状态**：不太可能

---

### 7.3 假设 3：内核本身的问题

**证据**：
- QEMU 日志为空，CPU 未执行代码
- 可能内核入口点不正确
- 可能内核期望某些初始化状态

**需要检查**：
- 内核链接脚本
- 入口函数实现
- loongarch64 平台初始化代码

**状态**：可能性较高

---

### 7.4 假设 4：QEMU 编译配置问题

**证据**：
- 我们自己编译 QEMU 9.2.4
- 上游使用预编译的 QEMU (通过 setup-qemu action)

**需要检查**：
- setup-qemu action 的实现
- 是否有额外的编译选项
- 是否需要特定的依赖

**状态**：可能性中等

---

### 7.5 假设 5：缺少 UEFI 支持

**背景**：
- LoongArch64 可能需要 UEFI 环境
- 之前的讨论提到了 UEFI Shell

**需要尝试**：
- 使用 EDK2 编译的 LoongArch UEFI 固件
- 通过 `-bios` 加载 UEFI 固件

**状态**：可能性较高

---

## CI 测试流程

### 8.1 测试脚本分析

**脚本**：`scripts/ci-test.py`

**流程**：
```python
1. 启动 QEMU：
   make ARCH=loongarch64 ACCEL=n justrun \
   QEMU_ARGS="-monitor none -serial tcp::4444,server=on"

2. 等待 QEMU 启动（5秒超时）

3. 连接串口：socket.create_connection(("localhost", 4444), timeout=5)

4. 读取输出，等待提示符 "starry:~#"

5. 发送 "exit\n" 命令

6. 检查是否成功进入 BusyBox shell
```

**当前行为**：
- QEMU 启动成功 ✅
- 串口连接成功 ✅
- **无任何输出** ❌
- 10秒后超时 ❌

---

## 下一步行动计划

### 优先级 1（高）

1. **查看 QEMU LoongArch 官方文档**
   - https://www.qemu.org/docs/master/system/target-loongarch.html
   - 确认直接内核启动的要求

2. **检查 arceos 上游当前状态**
   - 访问 https://github.com/Starry-OS/arceos
   - 查看最新的 scripts/make/qemu.mk
   - 查看 CI 是否仍然通过

3. **对比上游 arceos-apps 测试**
   - 克隆 arceos-apps
   - 运行上游的 loongarch64 测试
   - 观察是否能成功启动

### 优先级 2（中）

4. **研究 setup-qemu GitHub Action**
   - 查看 https://github.com/arceos-org/setup-qemu
   - 确认是否使用了特殊的 QEMU 编译配置

5. **检查内核代码**
   - 查看 loongarch64 平台初始化代码
   - 检查串口初始化
   - 确认是否有早期输出（early printk）

6. **尝试使用 UEFI 固件**
   - 搜索 LoongArch64 UEFI 固件
   - 尝试通过 `-bios` 加载

### 优先级 3（低）

7. **尝试其他 QEMU 版本**
   - 降级到 QEMU 9.1
   - 升级到 QEMU 10.0（如果可用）

8. **简化测试**
   - 编写最简单的 LoongArch64 裸机程序
   - 测试 QEMU 是否能执行任何代码

---

## 相关文件清单

### 已修改文件（临时，不要提交）

1. **arceos/scripts/make/qemu.mk**
   - 行号：45
   - 修改：`$(FINAL_IMG)` → `$(OUT_ELF)`

### 配置文件

1. **docker-compose.yml**
   - QEMU 版本：9.2.4
   - Rust 版本：nightly-2025-05-20

2. **Dockerfile**
   - QEMU 编译配置
   - 目标架构列表

3. **arceos/scripts/make/qemu.mk**
   - QEMU 参数配置
   - 各架构的启动参数

4. **scripts/ci-test.py**
   - CI 测试脚本
   - 串口连接和输出检查

### 参考文件

1. **arceos/.github/workflows/test.yml**
   - 上游 CI 配置
   - 使用的 QEMU 版本和工具链

2. **arceos/Makefile**
   - 构建目标定义
   - ELF 和 BIN 文件路径

3. **arceos/scripts/make/build.mk**
   - 实际构建过程
   - objcopy 转换

---

## 环境信息

**主机系统**：
```
OS: Linux 6.14.0-36-generic
Platform: linux
```

**Docker 环境**：
```
Image: galos-dev:latest
Container: galos-dev
User: starry (UID 1000, GID 1000)
```

**工具版本**：
```
QEMU: 9.2.4 (自编译)
Rust: nightly-2025-05-20
Musl toolchain: 20241227
```

**Git 状态**：
```
Branch: main
Arceos submodule: 4d1be13842ab800e585c375f723694224b4a1a7e
```

---

## 参考资源

### 官方文档
- QEMU LoongArch: https://www.qemu.org/docs/master/system/target-loongarch.html
- QEMU 9.2.0 发布说明: https://www.qemu.org/2024/12/11/qemu-9-2-0/

### GitHub 仓库
- Arceos: https://github.com/Starry-OS/arceos
- Arceos-apps: https://github.com/arceos-org/arceos-apps
- setup-qemu: https://github.com/arceos-org/setup-qemu
- qemu-loongarch-runenv: https://github.com/foxsen/qemu-loongarch-runenv

### 相关提交
- 6f67c50: feat: add loongarch64 support
- 4b0bc46: feat(la64-qemu): boot from binary
- 4d1be13: refactor: pin dependencies (当前版本)

---

## 总结

**已解决**：
- ✅ "The image is not ELF" 错误（通过使用 ELF 格式）

**当前问题**：
- ❌ 内核启动后无任何输出
- ❌ CPU 似乎未执行代码（QEMU 日志为空）

**最可能的原因**：
1. 缺少 UEFI 固件支持
2. 内核初始化代码问题
3. QEMU 配置缺少必要参数

**下一步**：
1. 查看 QEMU 官方文档
2. 对比上游最新配置
3. 研究 UEFI 固件需求

**重要提示**：
当前对 `arceos/scripts/make/qemu.mk` 的修改是**临时测试**，不应提交到仓库！
