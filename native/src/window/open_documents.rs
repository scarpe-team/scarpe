//! Files the system asks the app to open: Finder's Open With, a double-click on a file whose
//! default app this is, a file dropped on the Dock icon. macOS sends them to the app delegate's
//! `application:openURLs:`, the file that launched the app among them, during launch and before
//! any window. winit 0.30 does not implement that method, so `listen` adds it to winit's
//! delegate class once the event loop is built and before it runs. Each batch of paths reaches
//! the Runtime as `UserEvent::Open`, which hands them to `drop` blocks (input.rs
//! `open_documents`, ledger H11). The app also has to declare what it opens in its Info.plist
//! (`scarpe package --opens`), or Finder will not offer it.

use super::UserEvent;
use objc2::runtime::{AnyClass, AnyObject, Imp, Sel};
use objc2::{class, msg_send, sel};
use std::ffi::CStr;
use std::os::raw::c_char;
use std::sync::{Mutex, OnceLock};
use winit::event_loop::EventLoopProxy;

/// Where `open_urls` sends what it hears: AppKit calls it with no way to pass our state.
static PROXY: OnceLock<Mutex<EventLoopProxy<UserEvent>>> = OnceLock::new();

/// Adds `application:openURLs:` to the app delegate's class. Call after the event loop is built
/// (winit sets the delegate then) and before it runs (AppKit sends a launch's files while the
/// loop starts). Does nothing when there is no delegate, or its class already answers.
pub fn listen(proxy: EventLoopProxy<UserEvent>) {
    if PROXY.set(Mutex::new(proxy)).is_err() {
        return;
    }
    let open_urls: unsafe extern "C-unwind" fn(*mut AnyObject, Sel, *mut AnyObject, *mut AnyObject) = open_urls;
    // SAFETY: NSApplication and its delegate are main-thread objects and we are on the main
    // thread, where the event loop was built. class_addMethod takes an IMP of any signature that
    // matches the type encoding given: void, self, _cmd, and two objects.
    unsafe {
        let app: *mut AnyObject = msg_send![class!(NSApplication), sharedApplication];
        let delegate: *mut AnyObject = msg_send![app, delegate];
        let Some(delegate) = delegate.as_ref() else { return };
        let cls = delegate.class() as *const AnyClass as *mut AnyClass;
        let imp: Imp = std::mem::transmute(open_urls);
        let added = objc2::ffi::class_addMethod(cls, sel!(application:openURLs:), imp, c"v@:@@".as_ptr());
        if !added.as_bool() {
            eprintln!("[scarpe-native] the app delegate already has application:openURLs:; opened files are left to it");
        }
    }
}

/// `- (void)application:(NSApplication *)app openURLs:(NSArray<NSURL *> *)urls`: the file
/// URLs' paths, sent to the event loop as one batch. Other URLs (a custom scheme) are skipped.
unsafe extern "C-unwind" fn open_urls(_this: *mut AnyObject, _cmd: Sel, _app: *mut AnyObject, urls: *mut AnyObject) {
    let mut paths = Vec::new();
    // SAFETY: AppKit hands us an NSArray of NSURL on the main thread.
    unsafe {
        let count: usize = msg_send![urls, count];
        for i in 0..count {
            let url: *mut AnyObject = msg_send![urls, objectAtIndex: i];
            let is_file: bool = msg_send![url, isFileURL];
            if !is_file {
                continue;
            }
            let path: *mut AnyObject = msg_send![url, path];
            let utf8: *const c_char = msg_send![path, UTF8String];
            if !utf8.is_null() {
                paths.push(CStr::from_ptr(utf8).to_string_lossy().into_owned());
            }
        }
    }
    if paths.is_empty() {
        return;
    }
    if let Some(proxy) = PROXY.get().and_then(|p| p.lock().ok()) {
        let _ = proxy.send_event(UserEvent::Open(paths));
    }
}
