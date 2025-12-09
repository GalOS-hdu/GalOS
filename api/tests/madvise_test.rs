use starry_api::syscall::mm::mmap::{sys_mmap, sys_munmap, PROT_READ, PROT_WRITE, MAP_ANONYMOUS, MAP_PRIVATE};
use starry_api::syscall::mm::mmap::{sys_madvise, MADV_NORMAL, MADV_RANDOM, MADV_SEQUENTIAL, MADV_WILLNEED, MADV_DONTNEED};
use axerrno::AxResult;

// 测试正常的madvise调用
#[test]
fn test_madvise_normal() -> AxResult<()> {
    // 分配内存
    let size = 4096 * 4; // 4页
    let addr = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0)? };
    let addr = addr as usize;
    
    // 测试MADV_NORMAL
    assert!(sys_madvise(addr, size, MADV_NORMAL).is_ok());
    
    // 清理|
    unsafe { sys_munmap(addr as _, size)? };
    Ok(())
}

// 测试MADV_WILLNEED
#[test]
fn test_madvise_willneed() -> AxResult<()> {
    let size = 4096 * 4;
    let addr = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0)? };
    let addr = addr as usize;
    
    // 测试MADV_WILLNEED - 这应该预加载内存页
    assert!(sys_madvise(addr, size, MADV_WILLNEED).is_ok());
    
    // 验证内存可以访问
    unsafe { *(addr as *mut u8) = 42; }
    assert_eq!(unsafe { *(addr as *const u8) }, 42);
    
    unsafe { sys_munmap(addr as _, size)? };
    Ok(())
}

// 测试MADV_DONTNEED
#[test]
fn test_madvise_dontneed() -> AxResult<()> {
    let size = 4096 * 4;
    let addr = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0)? };
    let addr = addr as usize;
    
    // 写入数据
    unsafe { *(addr as *mut u8) = 42; }
    
    // 测试MADV_DONTNEED - 这应该释放内存页但保留地址空间
    assert!(sys_madvise(addr, size, MADV_DONTNEED).is_ok());
    
    // 验证地址空间仍然有效（读取不会崩溃，但值可能被清零）
    let val = unsafe { *(addr as *const u8) };
    
    unsafe { sys_munmap(addr as _, size)? };
    Ok(())
}

// 测试随机访问和顺序访问提示
#[test]
fn test_madvise_access_patterns() -> AxResult<()> {
    let size = 4096 * 4;
    let addr = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0)? };
    let addr = addr as usize;
    
    // 测试MADV_RANDOM
    assert!(sys_madvise(addr, size, MADV_RANDOM).is_ok());
    
    // 测试MADV_SEQUENTIAL
    assert!(sys_madvise(addr, size, MADV_SEQUENTIAL).is_ok());
    
    unsafe { sys_munmap(addr as _, size)? };
    Ok(())
}

// 测试错误情况
#[test]
fn test_madvise_errors() -> AxResult<()> {
    let size = 4096 * 4;
    
    // 测试未对齐的地址
    let unaligned_addr = 0x1001; // 不是4K对齐
    assert!(sys_madvise(unaligned_addr, size, MADV_NORMAL).is_err());
    
    // 测试长度为0
    assert!(sys_madvise(0x1000, 0, MADV_NORMAL).is_err());
    
    // 测试无效的内存区域
    let invalid_addr = 0x10000000; // 假设这是一个无效地址
    assert!(sys_madvise(invalid_addr, size, MADV_NORMAL).is_err());
    
    // 测试无效的advice参数
    let addr = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0)? };
    let addr = addr as usize;
    
    assert!(sys_madvise(addr, size, 999).is_err()); // 无效的advice值
    
    unsafe { sys_munmap(addr as _, size)? };
    Ok(())
}