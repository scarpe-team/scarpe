//! What VoiceOver gets from a window: its view read in-process through NSAccessibility, the
//! calls an assistive app makes (from inside the process they need no permission). The first
//! question wakes the window's AccessKit adapter as VoiceOver's does, and the whole tree follows
//! at once. Tests use this to prove the tree reaches AppKit, and that a press, a focus or a new
//! value made there comes back through AccessKit to the app (a11y ops with `platform`).

use super::{tell_screen_reader, Win};
use crate::a11y::PlatformAct;
use crate::runtime::Runtime;
use serde_json::Value;

#[cfg(not(target_os = "macos"))]
pub fn answer(_rt: &mut Runtime, _win: &mut Win, _act: Option<PlatformAct>) -> Result<Value, String> {
    let _ = tell_screen_reader;
    Err("the platform tree is read on macOS only".into())
}

#[cfg(target_os = "macos")]
pub fn answer(rt: &mut Runtime, win: &mut Win, act: Option<PlatformAct>) -> Result<Value, String> {
    let window = win.window.clone();
    objc2::rc::autoreleasepool(|_| {
        let view = appkit::view(&window).ok_or("the window has no view")?;
        // The first question wakes the adapter, as VoiceOver's does; the whole tree follows at once.
        appkit::children(view);
        tell_screen_reader(rt, win);
        if let Some(act) = act {
            appkit::act(view, &act)?;
        }
        Ok(serde_json::json!({ "role": "AXWindow", "children": appkit::children(view).into_iter().map(appkit::describe).collect::<Vec<_>>() }))
    })
}

#[cfg(target_os = "macos")]
mod appkit {
    use crate::a11y::PlatformAct;
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};
    use serde_json::{json, Map, Value};
    use std::ffi::{c_char, CStr, CString};
    use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};
    use winit::window::Window;

    /// Deeper than any tree a screen reader walks; it keeps a loop from hanging a test.
    const DEPTH: usize = 64;

    pub fn view(window: &Window) -> Option<&AnyObject> {
        let handle = window.window_handle().ok()?;
        let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return None };
        // SAFETY: winit's live NSView for a window the caller holds for the whole answer.
        Some(unsafe { appkit.ns_view.cast::<AnyObject>().as_ref() })
    }

    pub fn children(element: &AnyObject) -> Vec<&AnyObject> {
        // SAFETY: NSAccessibility's -accessibilityChildren returns an NSArray of elements or
        // nil, and -count and -objectAtIndex: read it; everything runs on the main thread.
        unsafe {
            let list: *mut AnyObject = msg_send![element, accessibilityChildren];
            let Some(list) = list.as_ref() else { return Vec::new() };
            let count: usize = msg_send![list, count];
            (0..count)
                .filter_map(|i| {
                    let child: *mut AnyObject = msg_send![list, objectAtIndex: i];
                    child.as_ref()
                })
                .collect()
        }
    }

    fn text(object: *mut AnyObject) -> Option<String> {
        // SAFETY: `object` is nil or an NSString, whose -UTF8String is a C string it owns.
        unsafe {
            let object = object.as_ref()?;
            let utf8: *const c_char = msg_send![object, UTF8String];
            (!utf8.is_null()).then(|| CStr::from_ptr(utf8).to_string_lossy().into_owned())
        }
    }

    fn value(element: &AnyObject) -> Option<Value> {
        // SAFETY: -accessibilityValue is nil, an NSString or an NSNumber, told apart by class.
        unsafe {
            let object: *mut AnyObject = msg_send![element, accessibilityValue];
            let object = object.as_ref()?;
            let is_string: bool = msg_send![object, isKindOfClass: class!(NSString)];
            let is_number: bool = msg_send![object, isKindOfClass: class!(NSNumber)];
            if is_string {
                text(object as *const AnyObject as *mut AnyObject).map(Value::String)
            } else if is_number {
                let number: f64 = msg_send![object, doubleValue];
                Some(json!(number))
            } else {
                None
            }
        }
    }

    fn title(element: &AnyObject) -> Option<String> {
        // SAFETY: -accessibilityTitle returns nil or an NSString.
        text(unsafe { msg_send![element, accessibilityTitle] })
    }

    /// An element as VoiceOver reads it: role, subrole, title, value and help.
    pub fn describe(element: &AnyObject) -> Value {
        describe_to(element, 0)
    }

    fn describe_to(element: &AnyObject, depth: usize) -> Value {
        let mut out = Map::new();
        // SAFETY: each of these NSAccessibility getters returns nil or an NSString.
        let (role, subrole, help) = unsafe {
            (text(msg_send![element, accessibilityRole]), text(msg_send![element, accessibilitySubrole]), text(msg_send![element, accessibilityHelp]))
        };
        let fields = [("role", role), ("subrole", subrole.filter(|s| s != "AXUnknown")), ("title", title(element)), ("help", help)];
        for (key, text) in fields {
            if let Some(text) = text {
                out.insert(key.into(), json!(text));
            }
        }
        if let Some(value) = value(element) {
            out.insert("value".into(), value);
        }
        let kids: Vec<Value> = if depth < DEPTH { children(element).into_iter().map(|c| describe_to(c, depth + 1)).collect() } else { Vec::new() };
        if !kids.is_empty() {
            out.insert("children".into(), Value::Array(kids));
        }
        Value::Object(out)
    }

    fn titled<'a>(element: &'a AnyObject, wanted: &str, depth: usize) -> Option<&'a AnyObject> {
        if depth > DEPTH {
            return None;
        }
        children(element).into_iter().find_map(|child| if title(child).as_deref() == Some(wanted) { Some(child) } else { titled(child, wanted, depth + 1) })
    }

    /// Presses, focuses or sets the value of the element titled so, as VoiceOver would.
    pub fn act(view: &AnyObject, act: &PlatformAct) -> Result<(), String> {
        let element = titled(view, &act.title, 0).ok_or_else(|| format!("no element is titled `{}`", act.title))?;
        // SAFETY: NSAccessibility actions on a live element: -accessibilityPerformPress returns
        // BOOL, the setters take BOOL and an NSString made here.
        let done = unsafe {
            match act.action.as_str() {
                "click" => msg_send![element, accessibilityPerformPress],
                "focus" => {
                    let _: () = msg_send![element, setAccessibilityFocused: true];
                    true
                }
                "set_value" => {
                    let value = CString::new(act.value.clone().unwrap_or_default()).map_err(|_| "the value holds a NUL")?;
                    let string: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: value.as_ptr()];
                    let _: () = msg_send![element, setAccessibilityValue: string];
                    true
                }
                other => return Err(format!("unknown platform action `{other}`")),
            }
        };
        if done {
            Ok(())
        } else {
            Err(format!("`{}` would not {}", act.title, act.action))
        }
    }
}
