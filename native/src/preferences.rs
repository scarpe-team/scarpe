//! Read OS accessibility preferences without changing settings or spawning shell commands.

/// Whether the desktop asks applications to reduce motion. Unsupported systems and failed
/// OS queries return false. This is deliberately not cached: callers can recheck at any time.
#[cfg(target_os = "windows")]
pub fn reduced_motion() -> bool {
    #[link(name = "user32")]
    unsafe extern "system" {
        fn SystemParametersInfoW(action: u32, param: u32, value: *mut std::ffi::c_void, flags: u32) -> i32;
    }
    const SPI_GETCLIENTAREAANIMATION: u32 = 0x1042;
    let mut animations: i32 = 1;
    // SAFETY: this GET action writes one Win32 BOOL to an initialized, aligned i32. It does
    // not retain the pointer or alter a setting. A failed call must not look like opt-out.
    let success = unsafe { SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, (&mut animations as *mut i32).cast(), 0) };
    success != 0 && animations == 0
}

#[cfg(target_os = "macos")]
pub fn reduced_motion() -> bool {
    use objc2::{class, msg_send, runtime::AnyObject};
    // SAFETY: requests run on the renderer's main thread. AppKit owns the shared workspace;
    // the documented accessibility getter takes no arguments and returns BOOL.
    unsafe {
        let workspace: *mut AnyObject = msg_send![class!(NSWorkspace), sharedWorkspace];
        if workspace.is_null() {
            return false;
        }
        let reduced: bool = msg_send![workspace, accessibilityDisplayShouldReduceMotion];
        reduced
    }
}

// Linux desktop environments do not share a query implemented by this renderer yet.
#[cfg(not(any(target_os = "windows", target_os = "macos")))]
pub fn reduced_motion() -> bool {
    false
}
