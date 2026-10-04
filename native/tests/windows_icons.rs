//! Reads the actual Windows title-bar and taskbar icons, as Aljam3 Desktop's package check does.
//! Opt-in: this needs a Windows desktop session, but the renderer window stays off-screen.
#![cfg(windows)]

use image::{Rgba, RgbaImage};
use serde_json::json;
use std::io::Write;
use std::mem::size_of;
use std::os::windows::process::CommandExt;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::ptr::null_mut;
use std::time::{Duration, Instant};
use windows_sys::Win32::Foundation::HWND;
use windows_sys::Win32::Graphics::Gdi::{
    CreateCompatibleDC, DeleteDC, DeleteObject, GetDIBits, GetObjectW, BITMAP, BITMAPINFO,
    BITMAPINFOHEADER, BI_RGB, DIB_RGB_COLORS, HDC,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    FindWindowW, GetIconInfo, GetWindowThreadProcessId, SendMessageTimeoutW, HICON, ICONINFO,
    ICON_BIG, ICON_SMALL, SMTO_ABORTIFHUNG, WM_GETICON,
};

struct Renderer(Child);

impl Drop for Renderer {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

struct IconFile(PathBuf);

impl Drop for IconFile {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.0);
    }
}

// GetIconInfo owns copies of the bitmaps; the renderer still owns the HICON itself.
#[derive(Default)]
struct IconReadback {
    info: ICONINFO,
    dc: HDC,
}

impl Drop for IconReadback {
    fn drop(&mut self) {
        unsafe {
            if !self.dc.is_null() {
                DeleteDC(self.dc);
            }
            for bitmap in [self.info.hbmMask, self.info.hbmColor] {
                if !bitmap.is_null() {
                    DeleteObject(bitmap);
                }
            }
        }
    }
}

fn icon_pixels(window: HWND, kind: u32, width: u32, height: u32) -> RgbaImage {
    let mut icon = 0;
    let mut readback = IconReadback::default();
    let mut bitmap = BITMAP::default();
    let mut pixels = vec![0; (width * height * 4) as usize];
    let mut format = BITMAPINFO {
        bmiHeader: BITMAPINFOHEADER {
            biSize: size_of::<BITMAPINFOHEADER>() as u32,
            biWidth: width as i32,
            biHeight: -(height as i32), // top-down rows, as in the source PNG
            biPlanes: 1,
            biBitCount: 32,
            biCompression: BI_RGB,
            ..Default::default()
        },
        ..Default::default()
    };
    // All out-pointers refer to live, correctly sized structs/buffers. Bound both the window
    // message and the bitmap dimensions so a renderer failure cannot hang or overrun the test.
    unsafe {
        assert_ne!(SendMessageTimeoutW(window, WM_GETICON, kind as usize, 0, SMTO_ABORTIFHUNG, 2000, &mut icon), 0,
            "Windows did not answer WM_GETICON");
        assert_ne!(icon, 0, "Windows has no icon of kind {kind}");
        assert_ne!(GetIconInfo(icon as HICON, &mut readback.info), 0, "GetIconInfo failed");
        assert_eq!(GetObjectW(readback.info.hbmColor, size_of::<BITMAP>() as i32, (&mut bitmap as *mut BITMAP).cast()),
            size_of::<BITMAP>() as i32, "GetObjectW failed");
        assert_eq!((bitmap.bmWidth, bitmap.bmHeight), (width as i32, height as i32), "icon dimensions");
        readback.dc = CreateCompatibleDC(null_mut());
        assert!(!readback.dc.is_null(), "CreateCompatibleDC failed");
        assert_eq!(GetDIBits(readback.dc, readback.info.hbmColor, 0, height, pixels.as_mut_ptr().cast(), &mut format, DIB_RGB_COLORS),
            height as i32, "GetDIBits did not read every row");
    }
    for pixel in pixels.chunks_exact_mut(4) {
        pixel.swap(0, 2); // Windows BGRA -> PNG RGBA, keeping alpha intact.
    }
    RgbaImage::from_raw(width, height, pixels).expect("32-bit icon pixels")
}

#[test]
#[ignore = "needs a Windows desktop session; CI runs this explicitly with --ignored"]
fn window_and_taskbar_icon_pixels_match_the_png() {
    let title = format!("scarpe-icon-test-{}", std::process::id());
    let file = IconFile(std::env::temp_dir().join(format!("{title}.png")));
    // Unequal RGB channels, different rows, and three alpha levels expose channel swaps,
    // upside-down images, lost transparency, and accidental premultiplication.
    let expected = RgbaImage::from_fn(32, 32, |x, y| {
        Rgba([(x * 7) as u8, (y * 5) as u8, 231, [0, 128, 255][((x + y) % 3) as usize]])
    });
    expected.save(&file.0).expect("write the source PNG");
    let mut renderer = Renderer(Command::new(env!("CARGO_BIN_EXE_scarpe-native"))
        .args(["--ghost", "--fonts", "bundled", "--exit-after", "20"])
        .creation_flags(0x08000000) // CREATE_NO_WINDOW: no separate renderer console either.
        .stdin(Stdio::piped()).stdout(Stdio::null()).stderr(Stdio::inherit())
        .spawn().expect("start the renderer"));
    let mut input = renderer.0.stdin.take().expect("renderer stdin");
    for message in [
        json!({"t": "hello", "v": 1, "pid": std::process::id()}),
        json!({"t": "create", "id": 2, "kind": "DocumentRoot", "parent": null, "props": {}}),
        json!({"t": "create", "id": 1, "kind": "App", "doc_root": 2,
            "props": {"title": title, "width": 100, "height": 100, "icon": file.0}}),
        json!({"t": "run", "app": 1}),
        json!({"t": "flush"}),
    ] {
        writeln!(input, "{message}").expect("send the app");
    }
    input.flush().expect("flush the app");

    let wide_title: Vec<u16> = title.encode_utf16().chain([0]).collect();
    let deadline = Instant::now() + Duration::from_secs(10);
    let window = loop {
        let mut pid = 0;
        let window = unsafe {
            let window = FindWindowW(std::ptr::null(), wide_title.as_ptr());
            if !window.is_null() {
                GetWindowThreadProcessId(window, &mut pid);
            }
            window
        };
        if pid == renderer.0.id() {
            break window;
        }
        assert!(renderer.0.try_wait().expect("renderer status").is_none(), "renderer exited before creating its window");
        assert!(Instant::now() < deadline, "renderer window was not found");
        std::thread::sleep(Duration::from_millis(50));
    };
    for (kind, name) in [(ICON_SMALL, "title-bar"), (ICON_BIG, "taskbar")] {
        let actual = icon_pixels(window, kind, expected.width(), expected.height());
        if actual != expected {
            let pictures = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/tmp/golden-actual");
            std::fs::create_dir_all(&pictures).expect("icon failure directory");
            expected.save(pictures.join("window-icon-expected.png")).expect("save expected icon");
            actual.save(pictures.join(format!("window-icon-{name}.png"))).expect("save actual icon");
        }
        assert!(actual == expected, "Windows {name} icon pixels differ from the source PNG");
    }
}
