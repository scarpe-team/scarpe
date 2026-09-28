//! Window mode: winit 0.30 + softbuffer, one window per running App.
//! stdin is read on a thread and fed to the event loop through a proxy; the
//! loop waits (ControlFlow::Wait) and redraws only apps whose view is dirty.
//! Each window has an AccessKit adapter, so a screen reader can read and work it (a11y.rs).

mod ghost;
mod pacing;
mod voiceover;

use crate::a11y::Mirror;
use crate::input::{us_shifted, CursorShape, Key, KeyInput, Modifiers, Named};
use crate::paint::damage::FrameMemory;
use crate::props::Id;
use crate::protocol::{Outbox, Outgoing};
use crate::runtime::stats::{self, Phase};
use crate::runtime::{load_fonts, Effect, Options, Runtime, QUIT_GRACE};
use crate::text::FontMode;
use pacing::Pacing;
use std::collections::HashMap;
use std::num::NonZeroU32;
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tiny_skia::Pixmap;
use winit::application::ApplicationHandler;
use winit::dpi::{LogicalPosition, LogicalSize};
use winit::event::{ElementState, Ime, KeyEvent, MouseButton, MouseScrollDelta, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop, EventLoopProxy};
use winit::keyboard::{Key as WKey, ModifiersState, NamedKey};
use winit::platform::modifier_supplement::KeyEventExtModifierSupplement;
use winit::window::{CursorIcon, Window, WindowId};

pub enum UserEvent {
    /// Every complete line stdin had ready, so a batch wakes the loop once.
    Lines(Vec<String>),
    Eof,
    /// A screen reader wants a window's whole tree, or asks something of a node.
    A11y(accesskit_winit::Event),
}

/// A window's screen reader handlers, which AccessKit calls on whatever thread its platform uses.
/// Starting or stopping raises the Mirror's flag right there, while the adapter changes its state,
/// so the next update is whole exactly when the adapter needs it; the rest goes to the event loop.
#[derive(Clone)]
struct Listening {
    window: WindowId,
    proxy: EventLoopProxy<UserEvent>,
    restarted: Arc<AtomicBool>,
}

impl Listening {
    fn send(&self, window_event: accesskit_winit::WindowEvent) {
        let _ = self.proxy.send_event(UserEvent::A11y(accesskit_winit::Event { window_id: self.window, window_event }));
    }
}

impl accesskit::ActivationHandler for Listening {
    /// The tree comes from the event loop, where the document is: None here, and the adapter
    /// shows a placeholder until the loop's first update.
    fn request_initial_tree(&mut self) -> Option<accesskit::TreeUpdate> {
        self.restarted.store(true, Ordering::SeqCst);
        self.send(accesskit_winit::WindowEvent::InitialTreeRequested);
        None
    }
}

impl accesskit::ActionHandler for Listening {
    fn do_action(&mut self, request: accesskit::ActionRequest) {
        self.send(accesskit_winit::WindowEvent::ActionRequested(request));
    }
}

impl accesskit::DeactivationHandler for Listening {
    fn deactivate_accessibility(&mut self) {
        self.restarted.store(true, Ordering::SeqCst);
    }
}

pub struct WindowOptions {
    pub exit_after: Option<Duration>,
    /// Create windows without activating the app or taking keyboard focus.
    pub inactive: bool,
    /// Windows nobody can see or touch (window::ghost), for automated runs. Implies `inactive`.
    pub ghost: bool,
}

struct Win {
    app: Id,
    /// Declared before the window so it lets go of the window's view first.
    a11y: accesskit_winit::Adapter,
    /// What the screen reader was last sent, so a frame sends only what changed.
    mirror: Mirror,
    window: Rc<Window>,
    // Declared before the context so it is dropped first.
    surface: softbuffer::Surface<Rc<Window>, Rc<Window>>,
    _context: softbuffer::Context<Rc<Window>>,
    surface_size: (u32, u32),
    /// The last frame, kept so the next one repaints only what changed.
    pixmap: Option<Pixmap>,
    memory: FrameMemory,
    pacing: Pacing,
    modifiers: ModifiersState,
    /// Where the input method was last told the caret is; None while it is off.
    ime: Option<crate::layout::Rect>,
}

struct Shell {
    rt: Runtime,
    windows: HashMap<WindowId, Win>,
    /// Hands each window's screen reader requests to the event loop.
    proxy: EventLoopProxy<UserEvent>,
    deadline: Option<Instant>,
    inactive: bool,
    ghost: bool,
    /// The user closed a window at some point.
    user_closed: bool,
    /// When the user closed the last window; if Ruby never answers with
    /// `quit`, we leave on our own after a grace period.
    orphaned_since: Option<Instant>,
}

pub fn run(opts: Options, window_opts: WindowOptions) -> i32 {
    stats::process_started();
    // The system fonts load while the event loop starts and the window opens (runtime::startup).
    let fonts = (opts.fonts == FontMode::System).then(|| load_fonts(FontMode::System));
    let trace = opts.trace;
    let inactive = window_opts.inactive || window_opts.ghost;
    if window_opts.ghost {
        ghost::hide_from_dock();
    }
    let mut builder = EventLoop::<UserEvent>::with_user_event();
    #[cfg(target_os = "macos")]
    {
        use winit::platform::macos::{ActivationPolicy, EventLoopBuilderExtMacOS};
        if inactive {
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
    let loop_built = Instant::now();
    let proxy = event_loop.create_proxy();
    let stdin_proxy = proxy.clone();
    std::thread::spawn(move || read_stdin(stdin_proxy));
    let mut shell = Shell {
        rt: match fonts {
            Some(loading) => Runtime::with_fonts_loading(opts, Outbox::stdout(trace), loading),
            None => Runtime::new(opts, Outbox::stdout(trace)),
        },
        windows: HashMap::new(),
        proxy,
        deadline: window_opts.exit_after.map(|d| Instant::now() + d),
        inactive,
        ghost: window_opts.ghost,
        user_closed: false,
        orphaned_since: None,
    };
    shell.rt.stats.mark_at("event_loop_built", loop_built);
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

    /// Opens `app`'s window. Returns whether it has one.
    fn open_window(&mut self, el: &ActiveEventLoop, app: Id) -> bool {
        if self.window_for(app).is_some() {
            return true;
        }
        let Some(view) = self.rt.views.get(&app) else { return false };
        let props = self.rt.doc.get(app).map(|n| n.props.clone()).unwrap_or_default();
        let title = self.rt.window_title(app);
        let resizable = !view.standalone && props.get("resizable").and_then(|v| v.as_bool()).unwrap_or(true);
        // Hidden until its screen reader adapter is in place: AccessKit has to come first.
        let attrs = Window::default_attributes()
            .with_title(title)
            .with_inner_size(LogicalSize::new(view.size.0 as f64, view.size.1 as f64))
            .with_resizable(resizable)
            .with_visible(false);
        let attrs = if self.ghost { ghost::attributes(attrs) } else { attrs.with_active(!self.inactive) };
        let window = match el.create_window(attrs) {
            Ok(w) => Rc::new(w),
            Err(e) => {
                eprintln!("[scarpe-native] could not open a window: {e}");
                return false;
            }
        };
        let mirror = Mirror::default();
        let listening = Listening { window: window.id(), proxy: self.proxy.clone(), restarted: mirror.restarts() };
        let a11y = accesskit_winit::Adapter::with_direct_handlers(el, &window, listening.clone(), listening.clone(), listening);
        self.rt.stats.mark("window_created");
        let context = match softbuffer::Context::new(window.clone()) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("[scarpe-native] softbuffer: {e}");
                return false;
            }
        };
        let surface = match softbuffer::Surface::new(&context, window.clone()) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("[scarpe-native] softbuffer surface: {e}");
                return false;
            }
        };
        if let Some(view) = self.rt.views.get_mut(&app) {
            view.scale = window.scale_factor() as f32;
            view.dirty = true;
        }
        if self.ghost {
            if !ghost::show(&window) {
                eprintln!("[scarpe-native] --ghost: the window could not be made invisible, so it never showed");
                self.rt.exit = Some(1);
                return false;
            }
            self.rt.stats.mark("ghost");
        } else {
            if let Some(opacity) = props.f32("opacity") {
                set_opacity(&window, opacity);
            }
            show(&window, self.inactive);
        }
        self.rt.stats.mark("window");
        if match_frame_colour_space(&window) {
            self.rt.stats.mark("colour_space_matched");
        }
        let pacing = Pacing::new(window.current_monitor().and_then(|m| m.refresh_rate_millihertz()));
        window.request_redraw();
        let id = window.id();
        self.windows.insert(
            id,
            Win {
                app,
                a11y,
                mirror,
                window,
                surface,
                _context: context,
                surface_size: (0, 0),
                pixmap: None,
                memory: FrameMemory::default(),
                pacing,
                modifiers: ModifiersState::empty(),
                ime: None,
            },
        );
        true
    }

    fn apply_effects(&mut self, el: &ActiveEventLoop) {
        for effect in std::mem::take(&mut self.rt.effects) {
            match effect {
                Effect::OpenWindow(app) => {
                    self.open_window(el, app);
                }
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
                            CursorShape::Wait => CursorIcon::Wait,
                        });
                    }
                }
                // A ghost stays clear whatever the app asks; its snapshots still carry the opacity.
                Effect::Opacity(app, opacity) => {
                    if let Some(win) = self.window_for(app).filter(|_| !self.ghost) {
                        set_opacity(&win.window, opacity);
                    }
                }
                // Nobody can answer a ghost's dialog or see what it opens: it answers the way a
                // headless run does, and links stay shut.
                Effect::Dialog { req, dialog } if self.ghost => {
                    let (value, cancelled) = crate::dialogs::headless_answer(&dialog.kind);
                    self.rt.dialog_answered(req, value, cancelled);
                }
                // An `ask` or `ask_color` no app window can hold gets a small window of its own.
                Effect::Dialog { req, dialog } if crate::dialogs::drawn_by_us(&dialog.kind) => {
                    let app = self.rt.open_standalone(req, &dialog);
                    if !self.open_window(el, app) {
                        self.rt.window_closed(app);
                    }
                }
                Effect::Dialog { req, dialog } => {
                    let (value, cancelled) = crate::dialogs::native(&dialog.kind, &dialog.message, &dialog.default);
                    self.rt.dialog_answered(req, value, cancelled);
                }
                Effect::OpenUrl(url) => {
                    if !self.ghost {
                        open_url(&url);
                    }
                }
                Effect::PlatformA11y { req, app, act } => {
                    let answer = match self.windows.values_mut().find(|w| w.app == app) {
                        Some(win) => voiceover::answer(&mut self.rt, win, act),
                        None => Err("the app has no window".into()),
                    };
                    self.rt.out.send(match answer {
                        Ok(value) => Outgoing::reply(req, value),
                        Err(e) => Outgoing::error(req, e, serde_json::Value::Null),
                    });
                }
            }
        }
    }

    /// After every event: run effects, ask dirty windows to redraw, write output.
    fn settle(&mut self, el: &ActiveEventLoop) {
        self.apply_effects(el);
        self.follow_text_input();
        if !self.rt.mid_batch {
            let now = Instant::now();
            for win in self.windows.values_mut() {
                if self.rt.views.get(&win.app).is_some_and(|v| v.dirty) && win.pacing.want_frame(now) {
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

    /// Input methods (dead keys, Japanese, emoji) are on while a text field that takes text
    /// has focus, with their candidates beside its caret, and off otherwise.
    fn follow_text_input(&mut self) {
        for win in self.windows.values_mut() {
            let area = self.rt.text_input_area(win.app);
            if area == win.ime {
                continue;
            }
            if area.is_some() != win.ime.is_some() {
                win.window.set_ime_allowed(area.is_some());
            }
            if let Some(r) = area {
                win.window.set_ime_cursor_area(LogicalPosition::new(r.x as f64, r.y as f64), LogicalSize::new(r.w.max(1.0) as f64, r.h as f64));
            }
            win.ime = area;
        }
    }

    fn redraw(&mut self, id: WindowId) {
        let Some(win) = self.windows.get_mut(&id) else { return };
        win.pacing.drawing(Instant::now());
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
        self.rt.repaint(win.app, pm, scale, &mut win.memory);
        // A layout done for this frame has told Ruby where things are: say it before showing it.
        self.rt.out.flush();
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
        // A new frame shows a change, and a screen reader that is listening hears of it too.
        tell_screen_reader(&mut self.rt, win);
    }

    /// A screen reader wants the window's whole tree (the Mirror already knows it owes it), or
    /// asks something of one of its nodes.
    fn a11y_event(&mut self, event: accesskit_winit::Event) {
        let Some(win) = self.windows.get_mut(&event.window_id) else { return };
        match event.window_event {
            accesskit_winit::WindowEvent::InitialTreeRequested => tell_screen_reader(&mut self.rt, win),
            accesskit_winit::WindowEvent::ActionRequested(request) => {
                self.rt.stats.input();
                self.rt.active_app = Some(win.app);
                if let Err(e) = self.rt.a11y_action(win.app, &request) {
                    eprintln!("[scarpe-native] screen reader: {e}");
                }
            }
            accesskit_winit::WindowEvent::AccessibilityDeactivated => {}
        }
    }
}

/// Sends the window's tree to its screen reader adapter: the whole tree the first time and after a
/// screen reader starts again, else what changed. The adapter builds nothing unless a screen reader
/// is listening, so this costs a window nobody reads aloud nothing (a11y.rs).
fn tell_screen_reader(rt: &mut Runtime, win: &mut Win) {
    let (app, scale) = (win.app, win.window.scale_factor() as f32);
    let Win { a11y, mirror, .. } = win;
    a11y.update_if_active(|| mirror.update(rt.a11y_tree(app, scale)));
}

/// Puts a window that was created hidden on screen the way winit opens one: key and in front,
/// or, for an inactive run, in front without taking the keyboard.
fn show(window: &Window, inactive: bool) {
    #[cfg(target_os = "macos")]
    if inactive {
        order_front(window);
        return;
    }
    let _ = inactive;
    window.set_visible(true);
}

/// NSWindow's orderFront:, which winit uses for a new window that is not active.
#[cfg(target_os = "macos")]
fn order_front(window: &Window) {
    use objc2::msg_send;
    use objc2::runtime::AnyObject;
    use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};

    let Ok(handle) = window.window_handle() else { return };
    let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return };
    // SAFETY: winit hands us a live NSView on the main thread; -window and -orderFront: are
    // plain AppKit API taking id.
    unsafe {
        let view: &AnyObject = appkit.ns_view.cast().as_ref();
        let ns_window: Option<&AnyObject> = msg_send![view, window];
        if let Some(ns_window) = ns_window {
            let _: () = msg_send![ns_window, orderFront: std::ptr::null::<AnyObject>()];
        }
    }
}

impl ApplicationHandler<UserEvent> for Shell {
    fn resumed(&mut self, _el: &ActiveEventLoop) {}

    fn user_event(&mut self, el: &ActiveEventLoop, event: UserEvent) {
        match event {
            UserEvent::Lines(lines) => {
                for line in &lines {
                    self.rt.handle_line(line);
                }
            }
            UserEvent::Eof => {
                self.rt.out.flush();
                el.exit();
                return;
            }
            UserEvent::A11y(event) => self.a11y_event(event),
        }
        self.settle(el);
    }

    fn window_event(&mut self, el: &ActiveEventLoop, id: WindowId, event: WindowEvent) {
        // The user acts on what is on screen: input ends any batch still arriving.
        if !matches!(event, WindowEvent::RedrawRequested) {
            self.rt.mid_batch = false;
        }
        let Some(win) = self.windows.get_mut(&id) else { return };
        win.a11y.process_event(&win.window, &event);
        let app = win.app;
        let scale = win.window.scale_factor();
        match event {
            WindowEvent::CloseRequested => {
                self.windows.remove(&id);
                // Closing a dialog's own window is a Cancel, not the app going away.
                self.user_closed |= !self.rt.is_standalone(app);
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
            WindowEvent::Ime(ime) => {
                if let Some(text) = committed(&ime) {
                    self.rt.stats.input();
                    self.rt.ime_commit(app, text);
                }
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

    /// The app menu's Quit (Cmd-Q on macOS, Q5) ends the process as soon as this returns,
    /// so every window still open tells Ruby it closed, the way a click on its close box does.
    fn exiting(&mut self, _el: &ActiveEventLoop) {
        for (_, win) in std::mem::take(&mut self.windows) {
            self.rt.window_closed(win.app);
        }
        self.rt.out.flush();
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
        if self.deadline.is_some_and(|d| now >= d) || self.orphaned_since.is_some_and(|t| now.duration_since(t) > QUIT_GRACE) {
            self.rt.out.flush();
            el.exit();
            return;
        }
        // A tooltip whose time has come needs a frame; one still to come needs a wake-up.
        let tooltip = self.rt.tooltip_due();
        if let Some((app, _)) = tooltip.filter(|(_, due)| now >= *due) {
            self.rt.request_redraw(app);
            if let Some(win) = self.window_for(app) {
                win.window.request_redraw();
            }
        }
        let tooltip_wake = tooltip.map(|(_, due)| due).filter(|due| *due > now);
        // Frames that waited for the display's next refresh (window::pacing).
        for win in self.windows.values_mut() {
            if win.pacing.take_due(now) {
                win.window.request_redraw();
            }
        }
        let next_frame = self.windows.values().filter_map(|w| w.pacing.due()).min();
        let wake = [self.deadline, self.orphaned_since.map(|t| t + QUIT_GRACE), tooltip_wake, next_frame]
            .into_iter()
            .flatten()
            .min();
        el.set_control_flow(match wake {
            Some(at) => ControlFlow::WaitUntil(at),
            None => ControlFlow::Wait,
        });
    }
}

/// Reads stdin on a thread of its own, so a batch of lines wakes the event loop once.
fn read_stdin(proxy: EventLoopProxy<UserEvent>) {
    crate::protocol::read_batches(std::io::stdin(), |lines| proxy.send_event(UserEvent::Lines(lines)).is_ok());
    let _ = proxy.send_event(UserEvent::Eof);
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

/// The text an input method committed. Preedit (text still being composed) is not shown in
/// the field; the input method's own panel shows it until it commits.
fn committed(ime: &Ime) -> Option<&str> {
    match ime {
        Ime::Commit(text) if !text.is_empty() => Some(text),
        _ => None,
    }
}

/// On macOS, Command is Shoes 3's `alt_` in key names (Q5) and Control in text fields.
fn modifiers(state: ModifiersState) -> Modifiers {
    let command = cfg!(target_os = "macos") && state.super_key();
    Modifiers { ctrl: state.control_key(), shift: state.shift_key(), alt: state.alt_key(), command }
}

fn key_input(event: &KeyEvent, state: ModifiersState) -> Option<KeyInput> {
    key_from(&event.logical_key, &event.key_without_modifiers(), event.text.as_deref(), modifiers(state))
}

/// A winit key press as Shoes sees it. With Control, Alt or Command held a character
/// is the bare key with Shift folded in the US way, so Shift-Alt-7 is `:alt_&` (manual
/// 2223-2227), whatever the platform's Option layer would type.
fn key_from(logical: &WKey, bare: &WKey, text: Option<&str>, m: Modifiers) -> Option<KeyInput> {
    let key = match logical {
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
        WKey::Character(typed) => match bare {
            WKey::Character(bare) if m.ctrl || m.alt || m.command => Key::Char(if m.shift { us_shifted(bare) } else { bare.to_string() }),
            _ => Key::Char(typed.to_string()),
        },
        _ => return None,
    };
    let modified = m.ctrl || m.alt || m.command;
    let shift = m.shift && matches!(key, Key::Named(_));
    let text = if modified { None } else { text.map(str::to_string) };
    Some(KeyInput { key, text, ctrl: m.ctrl, alt: m.alt, shift, command: m.command })
}

/// App `opacity` (Shoes 3.3): the whole window turns see-through. On macOS that is
/// NSWindow's alphaValue, sent through the Objective-C runtime that winit already links;
/// elsewhere winit has no such knob and the window stays opaque.
#[cfg(target_os = "macos")]
fn set_opacity(window: &Window, opacity: f32) {
    use std::ffi::{c_char, c_void};
    use winit::raw_window_handle::{HasWindowHandle, RawWindowHandle};
    extern "C" {
        fn sel_registerName(name: *const c_char) -> *mut c_void;
        fn objc_msgSend();
    }
    let Ok(handle) = window.window_handle() else { return };
    let RawWindowHandle::AppKit(appkit) = handle.as_raw() else { return };
    // SAFETY: ns_view is the live NSView winit made for this window, and each call site
    // gives objc_msgSend the exact signature of the method it sends (-window, -setAlphaValue:).
    unsafe {
        let send = objc_msgSend as unsafe extern "C" fn();
        let get: unsafe extern "C" fn(*mut c_void, *mut c_void) -> *mut c_void = std::mem::transmute(send);
        let set: unsafe extern "C" fn(*mut c_void, *mut c_void, f64) = std::mem::transmute(send);
        let ns_window = get(appkit.ns_view.as_ptr(), sel_registerName(c"window".as_ptr()));
        if !ns_window.is_null() {
            set(ns_window, sel_registerName(c"setAlphaValue:".as_ptr()), opacity.clamp(0.0, 1.0) as f64);
        }
    }
}

#[cfg(not(target_os = "macos"))]
fn set_opacity(_window: &Window, _opacity: f32) {}

fn open_url(url: &str) {
    if let Err(e) = spawn_and_reap(opener(std::env::consts::OS, url)) {
        eprintln!("[scarpe-native] could not open {url}: {e}");
    }
}

/// The command that opens `url` in the browser on `os`. Windows gets url.dll's handler, not
/// `cmd /C start`: cmd.exe would read `&`, `|` and `^` in a URL as its own, so a link to
/// `https://example.com/?a=1&calc` would run calc.
fn opener(os: &str, url: &str) -> std::process::Command {
    let (program, args): (&str, &[&str]) = match os {
        "macos" => ("open", &[]),
        "windows" => ("rundll32", &["url.dll,FileProtocolHandler"]),
        _ => ("xdg-open", &[]),
    };
    let mut command = std::process::Command::new(program);
    command.args(args).arg(url);
    command
}

/// Starts a helper process without our stdin and stdout (they carry the protocol: an opener
/// must neither read Ruby's lines nor write its own into them, nor keep the pipe open after we
/// die) and reaps it on a thread of its own, so it never lingers as a zombie. Returns its pid.
fn spawn_and_reap(mut command: std::process::Command) -> std::io::Result<u32> {
    use std::process::Stdio;
    let mut child = command.stdin(Stdio::null()).stdout(Stdio::null()).spawn()?;
    let pid = child.id();
    std::thread::spawn(move || child.wait());
    Ok(pid)
}

#[cfg(test)]
mod tests {
    use super::*;
    use winit::keyboard::SmolStr;

    fn chr(s: &str) -> WKey {
        WKey::Character(SmolStr::new(s))
    }

    fn name(logical: WKey, bare: WKey, text: Option<&str>, m: Modifiers) -> Option<String> {
        key_from(&logical, &bare, text, m).and_then(|k| k.shoes_name())
    }

    #[test]
    fn links_open_without_a_shell_on_windows() {
        let url = "https://example.com/?a=1&calc";
        let args = |c: &std::process::Command| c.get_args().map(|a| a.to_string_lossy().into_owned()).collect::<Vec<_>>();
        let windows = opener("windows", url);
        assert_eq!(windows.get_program(), "rundll32");
        assert_eq!(args(&windows), ["url.dll,FileProtocolHandler", url], "the URL is one argument, never cmd.exe's");
        assert_eq!(opener("macos", url).get_program(), "open");
        assert_eq!(args(&opener("linux", url)), [url]);
    }

    /// An opener that has exited is waited for, not left a zombie for the life of the app.
    /// Zombies, `sh` and `ps` are Unix things; Windows keeps no zombies to reap.
    #[cfg(unix)]
    #[test]
    fn a_finished_opener_is_reaped() {
        let mut quick = std::process::Command::new("sh");
        quick.args(["-c", "exit 0"]);
        let pid = spawn_and_reap(quick).expect("sh runs");
        let gone = (0..200).any(|_| {
            std::thread::sleep(std::time::Duration::from_millis(10));
            let ps = std::process::Command::new("ps").args(["-o", "stat=", "-p", &pid.to_string()]).output().expect("ps runs");
            ps.stdout.is_empty()
        });
        assert!(gone, "pid {pid} is still in the process table");
    }

    /// Only a commit inserts text; composing, and switching the input method on or off, do not.
    #[test]
    fn only_a_commit_carries_text() {
        assert_eq!(committed(&Ime::Commit("é".into())), Some("é"));
        assert_eq!(committed(&Ime::Commit(String::new())), None);
        assert_eq!(committed(&Ime::Preedit("ni".into(), Some((0, 2)))), None);
        assert_eq!(committed(&Ime::Enabled), None);
        assert_eq!(committed(&Ime::Disabled), None);
    }

    /// Q5: on macOS Cmd-q arrives as :alt_q, like Shoes 3's Cocoa backend.
    #[test]
    fn command_is_named_alt() {
        let cmd = Modifiers { command: true, ..Modifiers::default() };
        assert_eq!(name(chr("q"), chr("q"), None, cmd).as_deref(), Some(":alt_q"));
        assert!(key_from(&chr("c"), &chr("c"), None, cmd).unwrap().shortcut(), "and copies in a text field");
    }

    /// manual 2223-2227: Shift folds into the character, even under Option's own layer.
    #[test]
    fn shift_folds_into_characters() {
        let shift = Modifiers { shift: true, ..Modifiers::default() };
        assert_eq!(name(chr("&"), chr("7"), Some("&"), shift).as_deref(), Some("&"));
        let shift_alt = Modifiers { shift: true, alt: true, ..Modifiers::default() };
        assert_eq!(name(chr("‡"), chr("7"), Some("‡"), shift_alt).as_deref(), Some(":alt_&"));
        let shift_ctrl = Modifiers { shift: true, ctrl: true, ..Modifiers::default() };
        assert_eq!(name(chr("A"), chr("a"), None, shift_ctrl).as_deref(), Some(":control_A"));
        assert_eq!(name(WKey::Named(NamedKey::F1), WKey::Named(NamedKey::F1), None, shift).as_deref(), Some(":shift_f1"));
    }
}
