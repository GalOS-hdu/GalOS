use core::ffi::{c_char, c_int};

use axerrno::{AxError, AxResult};
use linux_raw_sys::general::{AT_EMPTY_PATH, AT_FDCWD, AT_SYMLINK_NOFOLLOW};
use starry_vm::{VmMutPtr, VmPtr};

use crate::{
    file::{Directory, File, FileLike, get_file_like, resolve_at},
    mm::vm_load_string,
};

/// Get the value of an extended attribute by path
///
/// # Arguments
/// * `path` - File path
/// * `name` - Attribute name (with namespace prefix, e.g., "user.comment")
/// * `value` - Buffer to store the attribute value
/// * `size` - Size of the buffer
///
/// Returns the size of the attribute value, or error if not found
#[cfg(target_arch = "x86_64")]
pub fn sys_getxattr(
    path: *const c_char,
    name: *const c_char,
    value: *mut u8,
    size: usize,
) -> AxResult<isize> {
    sys_fgetxattrat(AT_FDCWD, path, name, value, size, 0)
}

/// Get the value of an extended attribute by path (don't follow symlinks)
#[cfg(target_arch = "x86_64")]
pub fn sys_lgetxattr(
    path: *const c_char,
    name: *const c_char,
    value: *mut u8,
    size: usize,
) -> AxResult<isize> {
    sys_fgetxattrat(AT_FDCWD, path, name, value, size, AT_SYMLINK_NOFOLLOW)
}

/// Get the value of an extended attribute by file descriptor
pub fn sys_fgetxattr(
    fd: c_int,
    name: *const c_char,
    value: *mut u8,
    size: usize,
) -> AxResult<isize> {
    sys_fgetxattrat(fd, core::ptr::null(), name, value, size, AT_EMPTY_PATH)
}

/// Internal helper for getxattr family
fn sys_fgetxattrat(
    dirfd: c_int,
    path: *const c_char,
    name: *const c_char,
    value: *mut u8,
    size: usize,
    flags: u32,
) -> AxResult<isize> {
    let path = path.nullable().map(vm_load_string).transpose()?;
    let name = name.vm_load_cstr()?;

    debug!(
        "sys_getxattr <= dirfd: {dirfd}, path: {path:?}, name: {name:?}, size: {size}"
    );

    // Resolve the file or get from fd
    let file_like = if path.is_none() && flags & AT_EMPTY_PATH != 0 {
        get_file_like(dirfd)?
    } else {
        let loc = resolve_at(dirfd, path.as_deref(), flags)?
            .into_file()
            .ok_or(AxError::NotSupported)?;
        crate::file::new_file(loc)?
    };

    // Try to downcast to File or Directory
    let any = file_like.into_any();
    let result = if let Some(file) = any.downcast_ref::<File>() {
        if size == 0 {
            // Query size
            let mut dummy = [0u8; 1];
            file.getxattr(&name, &mut dummy)
                .or_else(|e| {
                    // If buffer too small, that means the attribute exists
                    // We need to get the actual size
                    if e == AxError::InvalidInput {
                        // Try with a larger buffer to get the size
                        let mut temp = vec![0u8; 65536];
                        file.getxattr(&name, &mut temp)
                    } else {
                        Err(e)
                    }
                })
        } else {
            let mut buffer = vec![0u8; size];
            let len = file.getxattr(&name, &mut buffer)?;
            value.vm_write_bytes(&buffer[..len])?;
            Ok(len)
        }
    } else if let Some(dir) = any.downcast_ref::<Directory>() {
        if size == 0 {
            let mut dummy = [0u8; 1];
            dir.getxattr(&name, &mut dummy)
                .or_else(|e| {
                    if e == AxError::InvalidInput {
                        let mut temp = vec![0u8; 65536];
                        dir.getxattr(&name, &mut temp)
                    } else {
                        Err(e)
                    }
                })
        } else {
            let mut buffer = vec![0u8; size];
            let len = dir.getxattr(&name, &mut buffer)?;
            value.vm_write_bytes(&buffer[..len])?;
            Ok(len)
        }
    } else {
        Err(AxError::NotSupported)
    }?;

    Ok(result as isize)
}

/// Set the value of an extended attribute by path
///
/// # Arguments
/// * `path` - File path
/// * `name` - Attribute name
/// * `value` - Attribute value to set
/// * `size` - Size of the value
/// * `flags` - Creation flags (XATTR_CREATE=0x1, XATTR_REPLACE=0x2)
#[cfg(target_arch = "x86_64")]
pub fn sys_setxattr(
    path: *const c_char,
    name: *const c_char,
    value: *const u8,
    size: usize,
    flags: c_int,
) -> AxResult<isize> {
    sys_fsetxattrat(AT_FDCWD, path, name, value, size, flags as u32, 0)
}

/// Set the value of an extended attribute by path (don't follow symlinks)
#[cfg(target_arch = "x86_64")]
pub fn sys_lsetxattr(
    path: *const c_char,
    name: *const c_char,
    value: *const u8,
    size: usize,
    flags: c_int,
) -> AxResult<isize> {
    sys_fsetxattrat(
        AT_FDCWD,
        path,
        name,
        value,
        size,
        flags as u32,
        AT_SYMLINK_NOFOLLOW,
    )
}

/// Set the value of an extended attribute by file descriptor
pub fn sys_fsetxattr(
    fd: c_int,
    name: *const c_char,
    value: *const u8,
    size: usize,
    flags: c_int,
) -> AxResult<isize> {
    sys_fsetxattrat(
        fd,
        core::ptr::null(),
        name,
        value,
        size,
        flags as u32,
        AT_EMPTY_PATH,
    )
}

/// Internal helper for setxattr family
fn sys_fsetxattrat(
    dirfd: c_int,
    path: *const c_char,
    name: *const c_char,
    value: *const u8,
    size: usize,
    xattr_flags: u32,
    resolve_flags: u32,
) -> AxResult<isize> {
    let path = path.nullable().map(vm_load_string).transpose()?;
    let name = name.vm_load_cstr()?;
    let value_buf = value.vm_load_bytes(size)?;

    debug!(
        "sys_setxattr <= dirfd: {dirfd}, path: {path:?}, name: {name:?}, size: {size}, flags: {xattr_flags}"
    );

    // Resolve the file or get from fd
    let file_like = if path.is_none() && resolve_flags & AT_EMPTY_PATH != 0 {
        get_file_like(dirfd)?
    } else {
        let loc = resolve_at(dirfd, path.as_deref(), resolve_flags)?
            .into_file()
            .ok_or(AxError::NotSupported)?;
        crate::file::new_file(loc)?
    };

    // Try to downcast to File or Directory
    let any = file_like.into_any();
    if let Some(file) = any.downcast_ref::<File>() {
        file.setxattr(&name, &value_buf, xattr_flags)?;
    } else if let Some(dir) = any.downcast_ref::<Directory>() {
        dir.setxattr(&name, &value_buf, xattr_flags)?;
    } else {
        return Err(AxError::NotSupported);
    }

    Ok(0)
}

/// List all extended attribute names by path
///
/// Returns a list of null-terminated attribute names
#[cfg(target_arch = "x86_64")]
pub fn sys_listxattr(path: *const c_char, list: *mut u8, size: usize) -> AxResult<isize> {
    sys_flistxattrat(AT_FDCWD, path, list, size, 0)
}

/// List all extended attribute names by path (don't follow symlinks)
#[cfg(target_arch = "x86_64")]
pub fn sys_llistxattr(path: *const c_char, list: *mut u8, size: usize) -> AxResult<isize> {
    sys_flistxattrat(AT_FDCWD, path, list, size, AT_SYMLINK_NOFOLLOW)
}

/// List all extended attribute names by file descriptor
pub fn sys_flistxattr(fd: c_int, list: *mut u8, size: usize) -> AxResult<isize> {
    sys_flistxattrat(fd, core::ptr::null(), list, size, AT_EMPTY_PATH)
}

/// Internal helper for listxattr family
fn sys_flistxattrat(
    dirfd: c_int,
    path: *const c_char,
    list: *mut u8,
    size: usize,
    flags: u32,
) -> AxResult<isize> {
    let path = path.nullable().map(vm_load_string).transpose()?;

    debug!("sys_listxattr <= dirfd: {dirfd}, path: {path:?}, size: {size}");

    // Resolve the file or get from fd
    let file_like = if path.is_none() && flags & AT_EMPTY_PATH != 0 {
        get_file_like(dirfd)?
    } else {
        let loc = resolve_at(dirfd, path.as_deref(), flags)?
            .into_file()
            .ok_or(AxError::NotSupported)?;
        crate::file::new_file(loc)?
    };

    // Try to downcast to File or Directory
    let any = file_like.into_any();
    let result = if let Some(file) = any.downcast_ref::<File>() {
        if size == 0 {
            // Query size
            let mut temp = vec![0u8; 65536];
            file.listxattr(&mut temp)
        } else {
            let mut buffer = vec![0u8; size];
            let len = file.listxattr(&mut buffer)?;
            list.vm_write_bytes(&buffer[..len])?;
            Ok(len)
        }
    } else if let Some(dir) = any.downcast_ref::<Directory>() {
        if size == 0 {
            let mut temp = vec![0u8; 65536];
            dir.listxattr(&mut temp)
        } else {
            let mut buffer = vec![0u8; size];
            let len = dir.listxattr(&mut buffer)?;
            list.vm_write_bytes(&buffer[..len])?;
            Ok(len)
        }
    } else {
        Err(AxError::NotSupported)
    }?;

    Ok(result as isize)
}

/// Remove an extended attribute by path
#[cfg(target_arch = "x86_64")]
pub fn sys_removexattr(path: *const c_char, name: *const c_char) -> AxResult<isize> {
    sys_fremovexattrat(AT_FDCWD, path, name, 0)
}

/// Remove an extended attribute by path (don't follow symlinks)
#[cfg(target_arch = "x86_64")]
pub fn sys_lremovexattr(path: *const c_char, name: *const c_char) -> AxResult<isize> {
    sys_fremovexattrat(AT_FDCWD, path, name, AT_SYMLINK_NOFOLLOW)
}

/// Remove an extended attribute by file descriptor
pub fn sys_fremovexattr(fd: c_int, name: *const c_char) -> AxResult<isize> {
    sys_fremovexattrat(fd, core::ptr::null(), name, AT_EMPTY_PATH)
}

/// Internal helper for removexattr family
fn sys_fremovexattrat(
    dirfd: c_int,
    path: *const c_char,
    name: *const c_char,
    flags: u32,
) -> AxResult<isize> {
    let path = path.nullable().map(vm_load_string).transpose()?;
    let name = name.vm_load_cstr()?;

    debug!("sys_removexattr <= dirfd: {dirfd}, path: {path:?}, name: {name:?}");

    // Resolve the file or get from fd
    let file_like = if path.is_none() && flags & AT_EMPTY_PATH != 0 {
        get_file_like(dirfd)?
    } else {
        let loc = resolve_at(dirfd, path.as_deref(), flags)?
            .into_file()
            .ok_or(AxError::NotSupported)?;
        crate::file::new_file(loc)?
    };

    // Try to downcast to File or Directory
    let any = file_like.into_any();
    if let Some(file) = any.downcast_ref::<File>() {
        file.removexattr(&name)?;
    } else if let Some(dir) = any.downcast_ref::<Directory>() {
        dir.removexattr(&name)?;
    } else {
        return Err(AxError::NotSupported);
    }

    Ok(0)
}
