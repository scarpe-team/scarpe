//! Preserve Windows touchpad zoom's per-message Control flag. winit checks the
//! keyboard state instead, which can lose MK_CONTROL synthesized by a touchpad.
//! A subclass sees both sent and posted messages, before winit can scroll them.
use super::UserEvent;
use crate::input::windows_zoom_delta;
use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, POINT, WPARAM};
use windows_sys::Win32::Graphics::Gdi::{ClientToScreen, ScreenToClient};
use windows_sys::Win32::UI::Shell::{DefSubclassProc, RemoveWindowSubclass, SetWindowSubclass};
use windows_sys::Win32::UI::WindowsAndMessaging::{SendMessageW, WM_MOUSEWHEEL};
use std::cell::Cell;
use winit::event_loop::EventLoopProxy;
use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};
use winit::window::{Window, WindowId};

const SUBCLASS: usize = 0x53435a;

struct Context { proxy: EventLoopProxy<UserEvent>, window: WindowId, request: Cell<Option<u64>> }

pub struct Hook { hwnd: HWND, _context: Box<Context> }

impl Hook {
    pub fn install(window: &Window, proxy: EventLoopProxy<UserEvent>) -> Option<Self> {
        let RawWindowHandle::Win32(raw) = window.window_handle().ok()?.as_raw() else { return None };
        let hwnd = raw.hwnd.get() as HWND;
        let context = Box::new(Context { proxy, window: window.id(), request: Cell::new(None) });
        // SAFETY: installed on the window's thread. The box's address stays stable
        // until Drop removes the subclass, before the window itself is dropped.
        if unsafe { SetWindowSubclass(hwnd, Some(receive), SUBCLASS, &*context as *const Context as usize) } == 0 {
            eprintln!("[scarpe-native] could not install touchpad zoom handler");
            return None;
        }
        Some(Self { hwnd, _context: context })
    }

    pub fn inject(&self, req: u64, delta: i16, x: f64, y: f64) -> bool {
        let mut point = POINT { x: x.round() as i32, y: y.round() as i32 };
        // SAFETY: the live HWND belongs to this thread. SendMessage calls the same
        // subclass as a touchpad, without changing global keys, cursor or focus.
        unsafe {
            if ClientToScreen(self.hwnd, &mut point) == 0 || i16::try_from(point.x).is_err() || i16::try_from(point.y).is_err() { return false; }
            let wp = ((delta as u16 as usize) << 16) | 0x0008;
            let lp = ((point.y as u16 as usize) << 16) | point.x as u16 as usize;
            self._context.request.set(Some(req));
            SendMessageW(self.hwnd, WM_MOUSEWHEEL, wp, lp as isize);
        }
        self._context.request.take().is_none()
    }
}

impl Drop for Hook {
    fn drop(&mut self) {
        // SAFETY: Win drops this registration before its live Window.
        unsafe { RemoveWindowSubclass(self.hwnd, Some(receive), SUBCLASS); }
    }
}

unsafe extern "system" fn receive(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM, _id: usize, data: usize) -> LRESULT {
    if msg == WM_MOUSEWHEEL {
        if let Some(dy) = windows_zoom_delta(wp) {
            // Signed coordinates also work on monitors to the left/above the primary.
            let mut point = POINT { x: lp as u16 as i16 as i32, y: (lp >> 16) as u16 as i16 as i32 };
            // SAFETY: callback data belongs to this live registration; hwnd and point
            // are valid for ScreenToClient. No Runtime borrowing inside a window proc.
            if unsafe { ScreenToClient(hwnd, &mut point) } != 0 {
                let context = unsafe { &*(data as *const Context) };
                let _ = context.proxy.send_event(UserEvent::ZoomWheel { window: context.window, dy, x: point.x as f64, y: point.y as f64, req: context.request.take() });
                return 0;
            }
        }
    }
    unsafe { DefSubclassProc(hwnd, msg, wp, lp) }
}
