//! Read the desktop's application appearance without changing settings or spawning commands.

#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum ColorScheme {
    Light,
    Dark,
}

#[cfg(any(target_os = "windows", test))]
fn windows_preference(value: u32) -> Option<ColorScheme> {
    match value {
        0 => Some(ColorScheme::Dark),
        1 => Some(ColorScheme::Light),
        _ => None,
    }
}

/// Query each time. Unavailable settings and an explicit lack of preference return None.
#[cfg(target_os = "windows")]
pub fn preferred_color_scheme() -> Option<ColorScheme> {
    use std::ffi::c_void;
    #[link(name = "advapi32")]
    unsafe extern "system" {
        fn RegGetValueW(key: *mut c_void, subkey: *const u16, value: *const u16, flags: u32,
            kind: *mut u32, data: *mut c_void, size: *mut u32) -> i32;
    }
    let path: Vec<u16> = "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize".encode_utf16().chain([0]).collect();
    let name: Vec<u16> = "AppsUseLightTheme".encode_utf16().chain([0]).collect();
    let mut value = 0u32;
    let mut size = std::mem::size_of_val(&value) as u32;
    // SAFETY: the predefined HKCU handle is valid; the strings are NUL-terminated. Restrict
    // the value to REG_DWORD and give the API an aligned four-byte output buffer. Read only.
    let result = unsafe { RegGetValueW((-2147483647isize) as *mut c_void, path.as_ptr(), name.as_ptr(),
        0x10, std::ptr::null_mut(), (&mut value as *mut u32).cast(), &mut size) };
    if result != 0 || size != 4 { return None; }
    windows_preference(value)
}

#[cfg(target_os = "macos")]
pub fn preferred_color_scheme() -> Option<ColorScheme> {
    use objc2::{class, msg_send, rc::autoreleasepool, runtime::AnyObject};
    #[link(name = "Foundation", kind = "framework")]
    unsafe extern "C" {}
    // SAFETY: requests run on the renderer's main thread. Foundation owns the defaults and
    // NSStrings; no pointer escapes this autorelease pool. The methods only read preferences.
    autoreleasepool(|_| unsafe {
        let defaults: *mut AnyObject = msg_send![class!(NSUserDefaults), standardUserDefaults];
        if defaults.is_null() { return None; }
        let key: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"AppleInterfaceStyle".as_ptr()];
        let value: *mut AnyObject = msg_send![defaults, stringForKey: key];
        // macOS removes AppleInterfaceStyle when the system uses its default light appearance.
        if value.is_null() { return Some(ColorScheme::Light); }
        let dark: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"Dark".as_ptr()];
        let is_dark: bool = msg_send![value, isEqualToString: dark];
        if is_dark { return Some(ColorScheme::Dark); }
        let light: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"Light".as_ptr()];
        let is_light: bool = msg_send![value, isEqualToString: light];
        is_light.then_some(ColorScheme::Light)
    })
}

#[cfg(target_os = "linux")]
pub fn preferred_color_scheme() -> Option<ColorScheme> {
    portal::with_deadline(portal::query(), std::time::Duration::from_millis(250))
}

#[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
pub fn preferred_color_scheme() -> Option<ColorScheme> { None }

#[cfg(target_os = "linux")]
mod portal {
    use super::ColorScheme;
    use zbus::zvariant::{OwnedValue, Value};

    pub fn with_deadline(query: impl std::future::Future<Output = Option<ColorScheme>>, timeout: std::time::Duration) -> Option<ColorScheme> {
        futures_lite::future::block_on(futures_lite::future::or(query, async {
            async_io::Timer::after(timeout).await;
            None
        }))
    }

    pub async fn query() -> Option<ColorScheme> {
        let bus = zbus::Connection::session().await.ok()?;
        let reply = bus.call_method(Some("org.freedesktop.portal.Desktop"), "/org/freedesktop/portal/desktop",
            Some("org.freedesktop.portal.Settings"), "Read", &("org.freedesktop.appearance", "color-scheme")).await.ok()?;
        decode(reply.body().deserialize::<OwnedValue>().ok()?)
    }

    fn decode(value: OwnedValue) -> Option<ColorScheme> {
        // Older portal implementations wrap Read's result in an extra variant.
        let value = if let Ok(inner) = value.downcast_ref::<Value>() { inner.try_to_owned().ok()? } else { value };
        match u32::try_from(value).ok()? {
            1 => Some(ColorScheme::Dark),
            2 => Some(ColorScheme::Light),
            _ => None, // 0 is the portal's explicit "no preference" value.
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn portal_values_and_legacy_variants_preserve_no_preference() {
            for (value, expected) in [(0, None), (1, Some(ColorScheme::Dark)), (2, Some(ColorScheme::Light)), (99, None)] {
                assert_eq!(decode(OwnedValue::from(value as u32)), expected);
                let nested = OwnedValue::try_from(Value::Value(Box::new(Value::U32(value as u32)))).unwrap();
                assert_eq!(decode(nested), expected);
            }
            assert_eq!(decode(OwnedValue::try_from(Value::from("dark")).unwrap()), None);
        }

        #[test]
        fn unavailable_portals_cannot_wait_forever() {
            assert_eq!(with_deadline(std::future::pending(), std::time::Duration::from_millis(10)), None);
            assert_eq!(with_deadline(async { Some(ColorScheme::Dark) }, std::time::Duration::from_secs(1)), Some(ColorScheme::Dark));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn windows_values_are_not_confused_with_portal_values() {
        assert_eq!(windows_preference(0), Some(ColorScheme::Dark));
        assert_eq!(windows_preference(1), Some(ColorScheme::Light));
        assert_eq!(windows_preference(2), None);
    }
}
