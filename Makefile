# Build Options
export ARCH := riscv64
export LOG := warn
export BACKTRACE := y
export MEMTRACK := n

# QEMU Options
export BLK := y
export NET := y
export VSOCK := n
export MEM := 1G
export SMP := 1
export ICOUNT := n

# Helper variables
COMMA := ,

# Generated Options
export A := $(PWD)
export NO_AXSTD := y
export AX_LIB := axfeat
export APP_FEATURES := qemu

ifeq ($(MEMTRACK), y)
	APP_FEATURES += starry-api/memtrack
endif

IMG_URL = https://github.com/Starry-OS/rootfs/releases/download/20250917
IMG = rootfs-$(ARCH).img

img:
	@if [ ! -f $(IMG) ]; then \
		echo "Image not found, downloading..."; \
		curl -f -L $(IMG_URL)/$(IMG).xz -O; \
		xz -d $(IMG).xz; \
	fi
	@cp $(IMG) arceos/disk.img

defconfig clean:
	@make -C arceos $@

# LoongArch64 QEMU fix: use ELF format kernel with UEFI firmware
# QEMU 9.2.4's loongarch64 emulator requires both ELF format AND UEFI BIOS
ifeq ($(ARCH), loongarch64)
justrun:
	@echo "    \033[96;1mRunning\033[0m on qemu (loongarch64 with ELF + UEFI)..."
	@qemu-system-loongarch64 -m $(MEM) -smp $(SMP) -machine virt \
		-bios /opt/qemu/share/qemu/edk2-loongarch64-code.fd \
		-kernel $(PWD)/GalOS_loongarch64-qemu-virt.elf \
		$(if $(filter y,$(BLK)),-device virtio-blk-pci$(COMMA)drive=disk0 -drive id=disk0$(COMMA)if=none$(COMMA)format=raw$(COMMA)file=arceos/disk.img) \
		$(if $(filter y,$(NET)),-device virtio-net-pci$(COMMA)netdev=net0 -netdev user$(COMMA)id=net0$(COMMA)hostfwd=tcp::5555-:5555$(COMMA)hostfwd=udp::5555-:5555) \
		-nographic \
		$(QEMU_ARGS)
else
justrun:
	@make -C arceos $@
endif

build run debug disasm: defconfig
	@make -C arceos $@

# Aliases
rv:
	$(MAKE) ARCH=riscv64 run

la:
	$(MAKE) ARCH=loongarch64 run

vf2:
	$(MAKE) ARCH=riscv64 APP_FEATURES=vf2 MYPLAT=axplat-riscv64-visionfive2 BUS=mmio build

.PHONY: build run justrun debug disasm clean
