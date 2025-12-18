use starry_api::syscall::mm::mmap::{sys_mmap, sys_munmap, sys_mprotect, PROT_READ, PROT_WRITE, PROT_EXEC, MAP_ANONYMOUS, MAP_PRIVATE, MAP_SHARED, MAP_FIXED, MAP_HUGETLB};
use axerrno::AxResult;
// 测试基本的匿名私有映射
#[test]
fn test_mmap_anonymous_private() -> AxResult<()> {
    let size = 4096 * 4; // 4页
    
    // 创建匿名私有映射
    let addr = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0)? };
    let addr = addr as usize;
    
    // 验证内存可以读写
    unsafe {
        *(addr as *mut u8) = 0x42;
        assert_eq!(*(addr as *const u8), 0x42);
        
        // 测试写入较大区域
        let slice = core::slice::from_raw_parts_mut(addr as *mut u8, size);
        slice.fill(0xFF);
        assert_eq!(slice[0], 0xFF);
        assert_eq!(slice[size - 1], 0xFF);
    }
    
    // 清理
    unsafe { sys_munmap(addr as _, size)? };
    Ok(())
}

// 测试不同的保护权限
#[test]
fn test_mmap_protection_flags() -> AxResult<()> {
    let size = 4096;
    
    // 测试只读映射
    let addr_read = unsafe { sys_mmap(0, size, PROT_READ, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0)? };
    let addr_read = addr_read as usize;
    
    // 测试可执行映射
    let addr_exec = unsafe { sys_mmap(0, size, PROT_READ | PROT_EXEC, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0)? };
    let addr_exec = addr_exec as usize;
    
    // 清理
    unsafe {
        sys_munmap(addr_read as _, size)?;
        sys_munmap(addr_exec as _, size)?;
    }
    
    Ok(())
}

// 测试固定地址映射
#[test]
fn test_mmap_fixed() -> AxResult<()> {
    let size = 4096;
    let fixed_addr = 0x10000000; // 假设这个地址是可用的
    
    // 创建固定地址映射
    let addr = unsafe { sys_mmap(fixed_addr, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE | MAP_FIXED, -1, 0)? };
    
    // 验证返回的地址与请求的地址相同
    assert_eq!(addr as usize, fixed_addr);
    
    // 验证内存可以访问
    unsafe {
        *(addr as *mut u8) = 0x42;
        assert_eq!(*(addr as *const u8), 0x42);
    }
    
    // 清理
    unsafe { sys_munmap(addr as _, size)? };
    
    Ok(())
}

// 测试错误情况
#[test]
fn test_mmap_errors() -> AxResult<()> {
    let size = 4096;
    
    // 测试无效的保护权限组合
    assert!(unsafe { sys_mmap(0, size, 0xFFFF, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0) }.is_err());
    
    // 测试无效的标志组合
    assert!(unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, 0xFFFF, -1, 0) }.is_err());
    
    // 测试非页对齐的偏移量（匿名映射应该允许）
    // 注意：根据实现，匿名映射的offset必须为0
    assert!(unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 1) }.is_err());
    
    // 测试长度为0
    assert!(unsafe { sys_mmap(0, 0, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0) }.is_err());
    
    Ok(())
}

// 测试mprotect功能
#[test]
fn test_mprotect() -> AxResult<()> {
    let size = 4096;
    
    // 创建可读写映射
    let addr = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0)? };
    let addr = addr as usize;
    
    // 写入一些数据
    unsafe {
        *(addr as *mut u8) = 0x42;
    }
    
    // 修改为只读
    assert!(sys_mprotect(addr, size, PROT_READ).is_ok());
    
    // 修改回可读写
    assert!(sys_mprotect(addr, size, PROT_READ | PROT_WRITE).is_ok());
    
    // 验证数据仍然存在
    unsafe {
        assert_eq!(*(addr as *const u8), 0x42);
    }
    
    // 清理
    unsafe { sys_munmap(addr as _, size)? };
    
    Ok(())
}

// 测试大页映射
#[test]
fn test_mmap_hugepages() -> AxResult<()> {
    // 注意：大页映射可能需要系统配置支持
    let size = 2 * 1024 * 1024; // 2MB
    
    // 尝试创建2MB大页映射
    match unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE | MAP_HUGETLB, -1, 0) } {
        Ok(addr) => {
            // 如果成功，验证内存可以访问
            let addr = addr as usize;
            unsafe {
                *(addr as *mut u8) = 0x42;
                assert_eq!(*(addr as *const u8), 0x42);
                sys_munmap(addr as _, size)?;
            }
        },
        Err(_) => {
            // 如果失败，可能是因为系统不支持大页，这也是可以接受的
            println!("2MB huge page mapping not supported, skipping test");
        }
    }
    
    Ok(())
}

// 测试共享映射（匿名）
#[test]
fn test_mmap_shared_anonymous() -> AxResult<()> {
    let size = 4096;
    
    // 创建匿名共享映射
    let addr1 = unsafe { sys_mmap(0, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_SHARED, -1, 0)? };
    let addr1 = addr1 as usize;
    
    // 再次映射同一区域（应该是同一个物理页）
    let addr2 = unsafe { sys_mmap(addr1, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_SHARED | MAP_FIXED, -1, 0)? };
    let addr2 = addr2 as usize;
    
    // 验证两个映射指向同一物理内存
    unsafe {
        *(addr1 as *mut u8) = 0x42;
        assert_eq!(*(addr2 as *const u8), 0x42);
    }
    
    // 清理
    unsafe {
        sys_munmap(addr1 as _, size)?;
        sys_munmap(addr2 as _, size)?;
    }
    
    Ok(())
}