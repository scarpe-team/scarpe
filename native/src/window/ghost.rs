//! Ghost windows (`--ghost`; the shim passes it for SCARPE_NATIVE_GHOST=1). A ghost is a real
//! window that lays out, paints and presents real frames, but nobody can see or touch it, so
//! automated windowed runs (tests, benches, cold starts) never cover what someone is looking at
//! or catch a click meant for something else. Snapshots, `pixel` and the rest of automation
//! read our own pixmap, never the screen, so they work the same.
//!
//! On macOS the window is fully transparent (alphaValue 0), lets every mouse event through, has
//! no shadow and no opening animation, and stays out of Mission Control, the window cycle and
//! the Window menu. It is created hidden and only put on screen once it reads back as
//! transparent and click-through. The app is an accessory that never activates (window::run),
//! so it has no Dock icon and never takes focus. Elsewhere the window opens far off-screen.

use winit::window::WindowAttributes;

#[cfg(target_os = "macos")]
pub use macos::{hide_from_dock, show};

/// How a ghost is created: never active, and on macOS hidden until `show`.
pub fn attributes(attrs: WindowAttributes) -> WindowAttributes {
    let attrs = attrs.with_active(false);
    if cfg!(target_os = "macos") {
        attrs.with_visible(false)
    } else {
        far_away(attrs)
    }
}

/// Where a ghost opens on platforms with no transparency knob: off every screen. (Wayland
/// ignores positions, so a ghost there is not hidden.)
fn far_away(attrs: WindowAttributes) -> WindowAttributes {
    attrs.with_position(winit::dpi::PhysicalPosition::new(-30_000, -30_000))
}

/// Off macOS a ghost opens out of sight, far off every screen.
#[cfg(not(target_os = "macos"))]
pub fn show(window: &winit::window::Window) -> bool {
    window.set_visible(true);
    true
}

#[cfg(not(target_os = "macos"))]
pub fn hide_from_dock() {}

#[cfg(target_os = "macos")]
mod macos {
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};
    use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};
    use winit::window::Window;

    /// NSWindowCollectionBehavior: floats in Spaces and Mission Control hides it (Transient),
    /// out of Cmd-` cycling (IgnoresCycle), never full screen (FullScreenNone).
    const TRANSIENT: usize = 1 << 3;
    const IGNORES_CYCLE: usize = 1 << 6;
    const FULL_SCREEN_NONE: usize = 1 << 9;
    /// NSWindowAnimationBehaviorNone.
    const NO_ANIMATION: isize = 2;

    /// Makes the window invisible and click-through, then puts it on screen without activating
    /// anything. False when it could not be made invisible: the window then stays hidden.
    pub fn show(window: &Window) -> bool {
        super::super::set_opacity(window, 0.0);
        let Ok(handle) = window.window_handle() else { return false };
        let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return false };
        // SAFETY: winit hands us a live NSView on the main thread; -window and the NSWindow
        // setters and getters below are plain AppKit API taking BOOL, NSUInteger, NSInteger or id.
        unsafe {
            let view: &AnyObject = appkit.ns_view.cast().as_ref();
            let ns_window: Option<&AnyObject> = msg_send![view, window];
            let Some(ns_window) = ns_window else { return false };
            let _: () = msg_send![ns_window, setIgnoresMouseEvents: true];
            let _: () = msg_send![ns_window, setHasShadow: false];
            let _: () = msg_send![ns_window, setExcludedFromWindowsMenu: true];
            let _: () = msg_send![ns_window, setCollectionBehavior: TRANSIENT | IGNORES_CYCLE | FULL_SCREEN_NONE];
            let _: () = msg_send![ns_window, setAnimationBehavior: NO_ANIMATION];
            let alpha: f64 = msg_send![ns_window, alphaValue];
            let click_through: bool = msg_send![ns_window, ignoresMouseEvents];
            if alpha != 0.0 || !click_through {
                return false;
            }
            // Front of its level, as an inactive window opens, without making it key or main.
            let _: () = msg_send![ns_window, orderFront: std::ptr::null::<AnyObject>()];
        }
        true
    }

    /// Keeps a packaged app's Dock icon from ever showing. AppKit checks the app in with
    /// LaunchServices as it starts, as whatever its Info.plist says (a regular app, with a Dock
    /// icon), and winit only makes it an accessory once it has finished launching, about a tenth
    /// of a second later. So the bundle's own copy of that dictionary says LSUIElement first. Call
    /// it before the event loop is built. A bare binary has no bundle and checks in as a
    /// background app.
    pub fn hide_from_dock() {
        // SAFETY: NSBundle and NSString class methods and -setObject:forKey: on the main thread.
        // CFBundle reads a bundle's Info.plist with mutable containers, and that dictionary is
        // the one -infoDictionary returns and LaunchServices check-in reads.
        unsafe {
            let bundle: *mut AnyObject = msg_send![class!(NSBundle), mainBundle];
            let id: *mut AnyObject = msg_send![bundle, bundleIdentifier];
            let info: *mut AnyObject = msg_send![bundle, infoDictionary];
            if id.is_null() || info.is_null() {
                return;
            }
            let key: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"LSUIElement".as_ptr()];
            let yes: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"1".as_ptr()];
            let _: () = msg_send![info, setObject: yes, forKey: key];
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use winit::window::Window;

    /// Nobody may see a ghost before it is clear: on macOS it is created hidden and only `show`
    /// puts it on screen, elsewhere it opens off every screen. It never activates either way.
    #[test]
    fn a_ghost_is_created_out_of_sight_and_inactive() {
        let attrs = attributes(Window::default_attributes());
        assert!(!attrs.active);
        if cfg!(target_os = "macos") {
            assert!(!attrs.visible);
        } else {
            assert!(attrs.position.is_some());
        }
    }
}
