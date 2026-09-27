//! Window mode: winit 0.30 + softbuffer, one window per running App.
//! stdin is read on a thread and fed to the event loop through a proxy; the
//! loop waits (ControlFlow::Wait) and redraws only apps whose view is dirty.

use crate::input::{CursorShape, Key, KeyInput, Modifiers, Named};
use crate::props::Id;
use crate::protocol::Outbox;
use crate::runtime::stats::{self, Phase};
use crate::runtime::{Effect, Options, Runtime};
use std::collections::HashMap;
use std::io::BufRead;
use std::num::NonZeroU32;
use std::rc::Rc;
use std::time::{Duration, Instant};
use tiny_skia::Pixmap;
use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::{ElementState, KeyEvent, MouseButton, MouseScrollDelta, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::keyboard::{Key as WKey, ModifiersState, NamedKey};
use winit::platform::modifier_supplement::KeyEventExtModifierSupplement;
use winit::window::{CursorIcon, Window, WindowId};

pub enum UserEvent {
    Line(String),
    Eof,
}

pub struct WindowOptions {
    pub exit_after: Option<Duration>,
    /// Create windows without activating the app or taking keyboard focus.
    pub inactive: bool,
}

struct Win {
    app: Id,
    window: Rc<Window>,
    // Declared before the context so it is dropped first.
    surface: softbuffer::Surface<Rc<Window>, Rc<Window>>,
    _context: softbuffer::Context<Rc<Window>>,
    surface_size: (u32, u32),
    pixmap: Option<Pixmap>,
    modifiers: ModifiersState,
}

struct Shell {
    rt: Runtime,
    windows: HashMap<WindowId, Win>,
    deadline: Option<Instant>,
    inactive: bool,
    /// The user closed a window at some point.
    user_closed: bool,
    /// When the user closed the last window; if Ruby never answers with
    /// `quit`, we leave on our own after a grace period.
    orphaned_since: Option<Instant>,
}

pub fn run(opts: Options, window_opts: WindowOptions) -> i32 {
    stats::process_started();
    let trace = opts.trace;
    let mut builder = EventLoop::<UserEvent>::with_user_event();
    #[cfg(target_os = "macos")]
    {
        use winit::platform::macos::{ActivationPolicy, EventLoopBuilderExtMacOS};
        if window_opts.inactive {
            builder.with_activation_policy(ActivationPolicy::Accessory);
            builder.with_activate_ignoring_other_apps(false);
        }
    }
    let event_loop = match builder.build() {
        Ok(el) => el,
        Err(e) => {
            eprintln!("[scarpe-native] could not start the event loop: {e}");
            return 1;
        }
    };
    event_loop.set_control_flow(ControlFlow::Wait);
    let proxy = event_loop.create_proxy();
    std::thread::spawn(move || {
        let stdin = std::io::stdin();
        for line in stdin.lock().lines() {
            let Ok(line) = line else { break };
            if proxy.send_event(UserEvent::Line(line)).is_err() {
                return;
            }
        }
        let _ = proxy.send_event(UserEvent::Eof);
    });
    let mut shell = Shell {
        rt: Runtime::new(opts, Outbox::stdout(trace)),
        windows: HashMap::new(),
        deadline: window_opts.exit_after.map(|d| Instant::now() + d),
        inactive: window_opts.inactive,
        user_closed: false,
        orphaned_since: None,
    };
    if let Err(e) = event_loop.run_app(&mut shell) {
        eprintln!("[scarpe-native] event loop failed: {e}");
        return 1;
    }
    shell.rt.out.flush();
    shell.rt.exit.unwrap_or(0)
}

impl Shell {
    fn window_for(&self, app: Id) -> Option<&Win> {
        self.windows.values().find(|w| w.app == app)
    }

    fn open_window(&mut self, el: &ActiveEventLoop, app: Id) {
        if self.window_for(app).is_some() {
            return;
        }
        let Some(view) = self.rt.views.get(&app) else { return };
        let props = self.rt.doc.get(app).map(|n| n.props.clone()).unwrap_or_default();
        let title = props.text("title").unwrap_or_else(|| "Shoes!".into());
        let resizable = props.get("resizable").and_then(|v| v.as_bool()).unwrap_or(true);
        let attrs = Window::default_attributes()
            .with_title(title)
            .with_inner_size(LogicalSize::new(view.size.0 as f64, view.size.1 as f64))
            .with_resizable(resizable)
            .with_active(!self.inactive);
        let window = match el.create_window(attrs) {
            Ok(w) => Rc::new(w),
            Err(e) => {
                eprintln!("[scarpe-native] could not open a window: {e}");
                return;
            }
        };
        let context = match softbuffer::Context::new(window.clone()) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("[scarpe-native] softbuffer: {e}");
                return;
            }
        };
        let surface = match softbuffer::Surface::new(&context, window.clone()) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("[scarpe-native] softbuffer surface: {e}");
                return;
            }
        };
        if let Some(view) = self.rt.views.get_mut(&app) {
            view.scale = window.scale_factor() as f32;
            view.dirty = true;
        }
        self.rt.stats.mark("window");
        if match_frame_colour_space(&window) {
            self.rt.stats.mark("colour_space_matched");
        }
        window.request_redraw();
        let id = window.id();
        self.windows.insert(
            id,
            Win { app, window, surface, _context: context, surface_size: (0, 0), pixmap: None, modifiers: ModifiersState::empty() },
        );
    }

    fn apply_effects(&mut self, el: &ActiveEventLoop) {
        for effect in std::mem::take(&mut self.rt.effects) {
            match effect {
                Effect::OpenWindow(app) => self.open_window(el, app),
                Effect::CloseWindow(app) => self.windows.retain(|_, w| w.app != app),
                Effect::SetTitle(app, title) => {
                    if let Some(w) = self.window_for(app) {
                        w.window.set_title(&title);
                    }
                }
                Effect::ResizeWindow(app, w, h) => {
                    if let Some(win) = self.window_for(app) {
                        let _ = win.window.request_inner_size(LogicalSize::new(w as f64, h as f64));
                    }
                }
                Effect::Cursor(app, shape) => {
                    if let Some(win) = self.window_for(app) {
                        win.window.set_cursor(match shape {
                            CursorShape::Arrow => CursorIcon::Default,
                            CursorShape::Hand => CursorIcon::Pointer,
                            CursorShape::Text => CursorIcon::Text,
                        });
                    }
                }
                Effect::Dialog { req, kind, message, default } => {
                    let (value, cancelled) = crate::dialogs::native(&kind, &message, &default);
                    self.rt.dialog_answered(req, value, cancelled);
                }
                Effect::OpenUrl(url) => open_url(&url),
            }
        }
    }

    /// After every event: run effects, ask dirty windows to redraw, write output.
    fn settle(&mut self, el: &ActiveEventLoop) {
        self.apply_effects(el);
        if !self.rt.mid_batch {
            for win in self.windows.values() {
                if self.rt.views.get(&win.app).is_some_and(|v| v.dirty) {
                    win.window.request_redraw();
                }
            }
        }
        self.rt.out.flush();
        if self.rt.exit.is_some() || self.rt.out.broken {
            el.exit();
        }
        let any_running = self.rt.views.values().any(|v| v.running);
        if self.user_closed && self.windows.is_empty() && !any_running {
            self.orphaned_since.get_or_insert_with(Instant::now);
        } else {
            self.orphaned_since = None;
        }
    }

    fn redraw(&mut self, id: WindowId) {
        let Some(win) = self.windows.get_mut(&id) else { return };
        let size = win.window.inner_size();
        let (w, h) = (size.width.max(1), size.height.max(1));
        let scale = win.window.scale_factor() as f32;
        let pm = match &mut win.pixmap {
            Some(pm) if pm.width() == w && pm.height() == h => pm,
            slot => slot.insert(match Pixmap::new(w, h) {
                Some(pm) => pm,
                None => return,
            }),
        };
        if let Some(view) = self.rt.views.get_mut(&win.app) {
            view.scale = scale;
        }
        self.rt.render(win.app, pm, scale);
        let presenting = Instant::now();
        if win.surface_size != (w, h) {
            if win.surface.resize(NonZeroU32::new(w).expect("w"), NonZeroU32::new(h).expect("h")).is_err() {
                return;
            }
            win.surface_size = (w, h);
        }
        let Ok(mut buffer) = win.surface.buffer_mut() else { return };
        for (dst, px) in buffer.iter_mut().zip(pm.data().chunks_exact(4)) {
            *dst = ((px[0] as u32) << 16) | ((px[1] as u32) << 8) | (px[2] as u32);
        }
        let _ = buffer.present();
        self.rt.stats.since(Phase::Present, presenting);
        let app = win.app;
        self.rt.frame_presented(app);
    }
}

impl ApplicationHandler<UserEvent> for Shell {
    fn resumed(&mut self, _el: &ActiveEventLoop) {}

    fn user_event(&mut self, el: &ActiveEventLoop, event: UserEvent) {
        match event {
            UserEvent::Line(line) => self.rt.handle_line(&line),
            UserEvent::Eof => {
                self.rt.out.flush();
                el.exit();
                return;
            }
        }
        self.settle(el);
    }

    fn window_event(&mut self, el: &ActiveEventLoop, id: WindowId, event: WindowEvent) {
        // The user acts on what is on screen: input ends any batch still arriving.
        if !matches!(event, WindowEvent::RedrawRequested) {
            self.rt.mid_batch = false;
        }
        let Some(win) = self.windows.get(&id) else { return };
        let app = win.app;
        let scale = win.window.scale_factor();
        match event {
            WindowEvent::CloseRequested => {
                self.windows.remove(&id);
                self.user_closed = true;
                self.rt.window_closed(app);
            }
            WindowEvent::RedrawRequested => self.redraw(id),
            WindowEvent::Resized(size) => {
                let logical = size.to_logical::<f64>(scale);
                self.rt.resize_view(app, logical.width as f32, logical.height as f32, true);
            }
            WindowEvent::ScaleFactorChanged { .. } => self.rt.request_redraw(app),
            WindowEvent::Focused(true) => self.rt.active_app = Some(app),
            WindowEvent::CursorMoved { position, .. } => {
                let p = position.to_logical::<f64>(scale);
                self.rt.pointer_move(app, p.x as f32, p.y as f32);
            }
            WindowEvent::CursorLeft { .. } => self.rt.pointer_left(app),
            WindowEvent::MouseInput { state, button, .. } => {
                self.rt.stats.input();
                let b = match button {
                    MouseButton::Left => 1,
                    MouseButton::Middle => 2,
                    MouseButton::Right => 3,
                    _ => return,
                };
                self.rt.active_app = Some(app);
                match state {
                    ElementState::Pressed => self.rt.pointer_down(app, b),
                    ElementState::Released => self.rt.pointer_up(app, b),
                }
            }
            WindowEvent::MouseWheel { delta, .. } => {
                let dy = match delta {
                    MouseScrollDelta::LineDelta(_, y) => -y * 40.0,
                    MouseScrollDelta::PixelDelta(p) => -(p.to_logical::<f64>(scale).y as f32),
                };
                self.rt.wheel(app, dy, None);
            }
            WindowEvent::ModifiersChanged(m) => {
                let state = m.state();
                if let Some(win) = self.windows.get_mut(&id) {
                    win.modifiers = state;
                }
                self.rt.set_modifiers(app, modifiers(state));
            }
            WindowEvent::KeyboardInput { event, .. } if event.state == ElementState::Pressed => {
                self.rt.stats.input();
                let mods = self.windows.get(&id).map(|w| w.modifiers).unwrap_or_default();
                if let Some(key) = key_input(&event, mods) {
                    self.rt.key_input(app, key);
                }
            }
            _ => {}
        }
        self.settle(el);
    }

    fn about_to_wait(&mut self, el: &ActiveEventLoop) {
        let now = Instant::now();
        if self.deadline.is_some_and(|d| now >= d) && !self.windows.is_empty() {
            // --exit-after closes the windows the way a person would, so Ruby sees `closed`
            // and quits cleanly; if nobody answers, the orphan timer below still ends us.
            self.deadline = None;
            for (_, win) in std::mem::take(&mut self.windows) {
                self.rt.window_closed(win.app);
            }
            self.user_closed = true;
            self.orphaned_since = Some(now);
        }
        if self.deadline.is_some_and(|d| now >= d) || self.orphaned_since.is_some_and(|t| now.duration_since(t) > Duration::from_secs(3)) {
            self.rt.out.flush();
            el.exit();
            return;
        }
        let wake = [self.deadline, self.orphaned_since.map(|t| t + Duration::from_secs(3))].into_iter().flatten().min();
        el.set_control_flow(match wake {
            Some(at) => ControlFlow::WaitUntil(at),
            None => ControlFlow::Wait,
        });
    }
}

/// softbuffer hands CoreAnimation DeviceRGB frames. A window in any other colour space makes
/// CoreAnimation colour-match every frame on the CPU as it commits (2.4 ms of a 2.7 ms present
/// at 1200x1000, native/PERF.md). In the frame's own colour space the window server does that
/// conversion while compositing, on the GPU, and the colours on screen are the same.
#[cfg(target_os = "macos")]
fn match_frame_colour_space(window: &Window) -> bool {
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};
    use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};

    let Ok(handle) = window.window_handle() else { return false };
    let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return false };
    // SAFETY: winit hands us a live NSView on the main thread; NSView -window and the
    // NSWindow/NSColorSpace calls below are plain AppKit API with object arguments.
    unsafe {
        let view: &AnyObject = appkit.ns_view.cast().as_ref();
        let ns_window: Option<&AnyObject> = msg_send![view, window];
        let Some(ns_window) = ns_window else { return false };
        let device_rgb: *const AnyObject = msg_send![class!(NSColorSpace), deviceRGBColorSpace];
        let _: () = msg_send![ns_window, setColorSpace: device_rgb];
        let now: *const AnyObject = msg_send![ns_window, colorSpace];
        let same: bool = msg_send![now, isEqual: device_rgb];
        same
    }
}

#[cfg(not(target_os = "macos"))]
fn match_frame_colour_space(_window: &Window) -> bool {
    false
}

fn modifiers(state: ModifiersState) -> Modifiers {
    let command = cfg!(target_os = "macos") && state.super_key();
    Modifiers { ctrl: state.control_key() || command, shift: state.shift_key(), alt: state.alt_key() }
}

fn key_input(event: &KeyEvent, state: ModifiersState) -> Option<KeyInput> {
    let m = modifiers(state);
    let key = match &event.logical_key {
        WKey::Named(named) => match named {
            NamedKey::Enter => Key::Named(Named::Enter),
            NamedKey::Tab => Key::Named(Named::Tab),
            NamedKey::Backspace => Key::Named(Named::Backspace),
            NamedKey::Delete => Key::Named(Named::Delete),
            NamedKey::Escape => Key::Named(Named::Escape),
            NamedKey::ArrowLeft => Key::Named(Named::Left),
            NamedKey::ArrowRight => Key::Named(Named::Right),
            NamedKey::ArrowUp => Key::Named(Named::Up),
            NamedKey::ArrowDown => Key::Named(Named::Down),
            NamedKey::Home => Key::Named(Named::Home),
            NamedKey::End => Key::Named(Named::End),
            NamedKey::PageUp => Key::Named(Named::PageUp),
            NamedKey::PageDown => Key::Named(Named::PageDown),
            NamedKey::Insert => Key::Named(Named::Insert),
            NamedKey::Space => Key::Char(" ".into()),
            NamedKey::F1 => Key::Named(Named::F(1)),
            NamedKey::F2 => Key::Named(Named::F(2)),
            NamedKey::F3 => Key::Named(Named::F(3)),
            NamedKey::F4 => Key::Named(Named::F(4)),
            NamedKey::F5 => Key::Named(Named::F(5)),
            NamedKey::F6 => Key::Named(Named::F(6)),
            NamedKey::F7 => Key::Named(Named::F(7)),
            NamedKey::F8 => Key::Named(Named::F(8)),
            NamedKey::F9 => Key::Named(Named::F(9)),
            NamedKey::F10 => Key::Named(Named::F(10)),
            NamedKey::F11 => Key::Named(Named::F(11)),
            NamedKey::F12 => Key::Named(Named::F(12)),
            _ => return None,
        },
        WKey::Character(s) => {
            if m.ctrl || m.alt {
                match event.key_without_modifiers() {
                    WKey::Character(base) => Key::Char(base.to_string()),
                    _ => Key::Char(s.to_string()),
                }
            } else {
                Key::Char(s.to_string())
            }
        }
        _ => return None,
    };
    let text = if m.ctrl || m.alt { None } else { event.text.as_ref().map(|t| t.to_string()) };
    Some(KeyInput { key, text, ctrl: m.ctrl, alt: m.alt, shift: m.shift })
}

fn open_url(url: &str) {
    let cmd = if cfg!(target_os = "macos") {
        std::process::Command::new("open").arg(url).spawn()
    } else if cfg!(target_os = "windows") {
        std::process::Command::new("cmd").args(["/C", "start", "", url]).spawn()
    } else {
        std::process::Command::new("xdg-open").arg(url).spawn()
    };
    if let Err(e) = cmd {
        eprintln!("[scarpe-native] could not open {url}: {e}");
    }
}
