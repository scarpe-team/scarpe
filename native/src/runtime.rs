//! The Runtime: the retained document, per-app view state and the protocol
//! handler, shared by the window and the headless canvas.

mod repaint;
pub mod stats;

use crate::doc::{Doc, Kind, NewNode};
use crate::elements::image::ImageCache;
use crate::input::{Clipboard, CursorShape, ViewState};
use crate::layout::{self, Inputs, Layout};
use crate::paint::damage::{FrameMemory, Revisions};
use crate::paint::{self, Scene};
use crate::props::Id;
use crate::protocol::{self, Create, Incoming, Op, Outbox, Outgoing};
use crate::text::{FontMode, TextEngine};
use serde_json::{Map, Value};
use stats::{Phase, Stats};
use repaint::DamageMode;
use std::collections::{BTreeMap, HashMap};
use std::time::Instant;
use tiny_skia::Pixmap;

pub const DEFAULT_SIZE: (f32, f32) = (480.0, 420.0);

#[derive(Clone, Debug)]
pub struct Options {
    pub headless: bool,
    /// `--scale`: the default for headless canvases and snapshots.
    pub scale: Option<f32>,
    pub fonts: FontMode,
    pub trace: bool,
}

impl Default for Options {
    fn default() -> Self {
        Options { headless: true, scale: None, fonts: FontMode::Bundled, trace: false }
    }
}

/// Things only the window layer can do, queued by the Runtime.
#[derive(Clone, Debug, PartialEq)]
pub enum Effect {
    OpenWindow(Id),
    CloseWindow(Id),
    SetTitle(Id, String),
    ResizeWindow(Id, f32, f32),
    Cursor(Id, CursorShape),
    Dialog { req: u64, kind: String, message: String, default: Value },
    OpenUrl(String),
}

pub struct AppView {
    pub app: Id,
    pub doc_root: Id,
    /// Logical content size.
    pub size: (f32, f32),
    /// Pixels per logical px of the canvas or window.
    pub scale: f32,
    /// `run` arrived: the window (or canvas) is showing.
    pub running: bool,
    /// None when the document changed since the last layout.
    pub layout: Option<Layout>,
    pub ui: ViewState,
    /// Needs a repaint.
    pub dirty: bool,
    pub frames: u64,
}

struct PendingFrames {
    req: u64,
    app: Id,
    remaining: u32,
}

pub struct Runtime {
    pub doc: Doc,
    pub text: TextEngine,
    pub images: ImageCache,
    pub views: BTreeMap<Id, AppView>,
    pub out: Outbox,
    pub opts: Options,
    pub effects: Vec<Effect>,
    pub clipboard: Clipboard,
    /// The app that most recently ran or had input: dialogs open there.
    pub active_app: Option<Id>,
    /// Set when Rust should exit with this code.
    pub exit: Option<i32>,
    /// Document changes arrived and their `flush` has not: windows wait for it
    /// rather than show half a batch.
    pub mid_batch: bool,
    pending_frames: Vec<PendingFrames>,
    pub stats: Stats,
    /// When each node last changed, for windows that repaint only what changed.
    pub revisions: Revisions,
    damage: DamageMode,
    /// SCARPE_NATIVE_DAMAGE=check: the last full paint per app, and headless, a frame per
    /// app repainted in part alongside every picture.
    last_full: HashMap<Id, Pixmap>,
    checked_frames: HashMap<Id, (Pixmap, FrameMemory)>,
}

impl Runtime {
    pub fn new(opts: Options, out: Outbox) -> Self {
        let clipboard = if opts.headless { Clipboard::local() } else { Clipboard::system() };
        let mut stats = Stats::default();
        let text = TextEngine::new(opts.fonts);
        stats.mark("fonts");
        Runtime {
            doc: Doc::default(),
            text,
            images: ImageCache::default(),
            views: BTreeMap::new(),
            out,
            opts,
            effects: Vec::new(),
            clipboard,
            active_app: None,
            exit: None,
            mid_batch: false,
            pending_frames: Vec::new(),
            stats,
            revisions: Revisions::default(),
            damage: DamageMode::from_env(),
            last_full: HashMap::new(),
            checked_frames: HashMap::new(),
        }
    }

    /// A Runtime that captures its output, for tests.
    pub fn headless_for_tests() -> Self {
        Runtime::new(Options::default(), Outbox::capture())
    }

    pub fn default_scale(&self) -> f32 {
        self.opts.scale.unwrap_or(1.0)
    }

    pub fn handle_line(&mut self, line: &str) {
        let line = line.trim();
        if line.is_empty() {
            return;
        }
        if self.opts.trace {
            eprintln!("[scarpe-native] << {line}");
        }
        let parsing = Instant::now();
        let parsed = protocol::parse_line(line);
        self.stats.since(Phase::Parse, parsing);
        match parsed {
            Ok(msg) => self.apply(msg),
            Err(e) => {
                eprintln!("[scarpe-native] {e}: {line}");
                self.out.send(Outgoing::Log { level: "warn".into(), msg: format!("{e}") });
            }
        }
    }

    pub fn apply(&mut self, msg: Incoming) {
        self.mid_batch = !matches!(msg, Incoming::Flush | Incoming::Req { .. } | Incoming::Hello { .. });
        let started = Instant::now();
        let change = matches!(msg, Incoming::Create(_) | Incoming::Props { .. } | Incoming::Destroy { .. } | Incoming::Reparent { .. });
        match msg {
            Incoming::Hello { .. } => {
                self.out.send(Outgoing::ready());
                self.stats.mark("ready");
            }
            Incoming::Create(c) => self.create(c),
            Incoming::Props { id, props } => self.set_props(id, props),
            Incoming::Destroy { id } => self.destroy(id),
            Incoming::Reparent { id, parent, index } => {
                self.doc.reparent(id, parent, index);
                self.revisions.touch(id);
                self.invalidate();
            }
            Incoming::Run { app } => self.run_app(app),
            Incoming::Quit { app } => self.quit(app),
            Incoming::Focus { id } => {
                if let Some(app) = self.doc.app_of(id) {
                    self.ensure_layout(app);
                    self.set_focus(app, Some(id));
                    if let Some(view) = self.views.get_mut(&app) {
                        view.ui.focus_visible = true;
                    }
                }
            }
            Incoming::ScrollTo { id, top } => {
                if let Some(app) = self.doc.app_of(id) {
                    if let Some(view) = self.views.get_mut(&app) {
                        view.ui.scroll.insert(id, top.max(0.0));
                        view.layout = None;
                        view.dirty = true;
                    }
                }
            }
            Incoming::Font { path } => {
                self.text.fonts.register(std::path::Path::new(&path));
                self.revisions.touch_everything();
                self.invalidate();
            }
            Incoming::Flush => self.flush(),
            Incoming::Req { req, op } => {
                self.flush();
                if is_input(&op) {
                    self.stats.input();
                }
                let answering = Instant::now();
                self.handle_req(req, op);
                self.stats.since(Phase::Req, answering);
                self.out.flush();
            }
        }
        if change {
            self.stats.since(Phase::Apply, started);
        }
    }

    fn create(&mut self, c: Create) {
        self.stats.mark("first_create");
        let is_app = c.kind == "App";
        let size = app_size(&c.props);
        let doc_root = c.doc_root.unwrap_or(c.id + 1);
        self.doc.create(NewNode {
            id: c.id,
            class: c.kind,
            parent: c.parent,
            index: c.index,
            widget: c.widget,
            props: c.props,
            doc_root: c.doc_root,
            owner: c.owner,
        });
        self.revisions.touch(c.id);
        if is_app {
            let scale = self.default_scale();
            self.views.insert(
                c.id,
                AppView { app: c.id, doc_root, size, scale, running: false, layout: None, ui: ViewState::default(), dirty: true, frames: 0 },
            );
        }
        self.invalidate();
    }

    fn set_props(&mut self, id: Id, props: Map<String, Value>) {
        let new_text = props.get("text").map(crate::props::value_text);
        let title = props.get("title").map(crate::props::value_text);
        let resized = props.contains_key("width") || props.contains_key("height");
        let restyled = ["font", "stroke", "secret"].iter().any(|k| props.contains_key(*k));
        if !self.doc.set_props(id, props) {
            return;
        }
        self.revisions.touch(id);
        let kind = self.doc.get(id).map(|n| n.kind.clone());
        match kind {
            Some(Kind::App) => {
                if let Some(title) = title {
                    self.effects.push(Effect::SetTitle(id, title));
                }
                if resized {
                    let size = self.doc.get(id).map(|n| app_size(&n.props.0)).unwrap_or(DEFAULT_SIZE);
                    if let Some(view) = self.views.get_mut(&id) {
                        view.size = size;
                    }
                    self.effects.push(Effect::ResizeWindow(id, size.0, size.1));
                }
            }
            Some(Kind::EditLine) | Some(Kind::EditBox) => {
                for view in self.views.values_mut() {
                    if restyled {
                        // Rebuilt from the new props on next use.
                        view.ui.fields.remove(&id);
                    } else if let (Some(field), Some(text)) = (view.ui.fields.get_mut(&id), new_text.as_ref()) {
                        field.set_text(&mut self.text.fonts.system, text);
                    }
                }
            }
            _ => {}
        }
        self.invalidate();
    }

    fn destroy(&mut self, id: Id) {
        if self.views.contains_key(&id) {
            self.close_view(id);
            return;
        }
        let removed = self.doc.destroy(id);
        if removed.is_empty() {
            return;
        }
        self.revisions.forget(&removed);
        for view in self.views.values_mut() {
            view.ui.forget(&removed);
        }
        self.invalidate();
    }

    fn run_app(&mut self, app: Option<Id>) {
        self.stats.mark("run");
        let Some(app) = app.or_else(|| self.doc.apps().last().map(|a| a.id)) else { return };
        let Some(view) = self.views.get_mut(&app) else { return };
        if !view.running {
            view.running = true;
            view.dirty = true;
            self.effects.push(Effect::OpenWindow(app));
        }
        self.active_app = Some(app);
    }

    fn quit(&mut self, app: Option<Id>) {
        let targets: Vec<Id> = match app {
            Some(a) => vec![a],
            None => self.views.keys().copied().collect(),
        };
        for a in targets {
            self.close_view(a);
        }
        if self.views.is_empty() {
            self.exit = Some(0);
        }
    }

    /// The user closed a window: tell Ruby, which destroys the app and sends `quit`.
    pub fn window_closed(&mut self, app: Id) {
        if let Some(view) = self.views.get_mut(&app) {
            view.running = false;
        }
        self.out.send(Outgoing::Closed { app });
        self.out.flush();
    }

    fn close_view(&mut self, app: Id) {
        let Some(view) = self.views.remove(&app) else { return };
        if let Some(modal) = view.ui.modal {
            self.out.send(crate::dialogs::reply(modal.req, Value::Null, true));
        }
        let mut still_pending = Vec::new();
        for p in std::mem::take(&mut self.pending_frames) {
            if p.app == app {
                self.out.send(Outgoing::error(p.req, "app closed", Value::Null));
            } else {
                still_pending.push(p);
            }
        }
        self.pending_frames = still_pending;
        self.doc.remove_app(app);
        self.effects.push(Effect::CloseWindow(app));
        if self.active_app == Some(app) {
            self.active_app = self.views.keys().next().copied();
        }
    }

    /// The document changed: every app lays out again before its next paint.
    pub fn invalidate(&mut self) {
        for view in self.views.values_mut() {
            view.layout = None;
            view.dirty = true;
        }
    }

    pub fn request_redraw(&mut self, app: Id) {
        if let Some(view) = self.views.get_mut(&app) {
            view.dirty = true;
        }
    }

    /// End of a batch: lay out whatever changed.
    pub fn flush(&mut self) {
        let running: Vec<Id> = self.views.iter().filter(|(_, v)| v.running && v.layout.is_none()).map(|(id, _)| *id).collect();
        for app in running {
            self.ensure_layout(app);
        }
    }

    pub fn ensure_layout(&mut self, app: Id) {
        let Some(view) = self.views.get_mut(&app) else { return };
        if view.layout.is_some() {
            return;
        }
        let started = Instant::now();
        let inputs = Inputs { doc: &self.doc, text: &mut self.text, images: &mut self.images, scroll: &view.ui.scroll };
        view.layout = Some(layout::layout(inputs, view.doc_root, view.size));
        self.stats.since(Phase::Layout, started);
        self.stats.mark("first_layout");
    }

    pub fn layout_of(&mut self, app: Id) -> Option<&Layout> {
        self.ensure_layout(app);
        self.views.get(&app)?.layout.as_ref()
    }

    fn paint_into(&mut self, app: Id, pm: &mut Pixmap, scale: f32) {
        self.ensure_layout(app);
        let Some(view) = self.views.get_mut(&app) else { return };
        let AppView { layout, ui, frames, .. } = view;
        let Some(layout) = layout.as_ref() else { return };
        let started = Instant::now();
        let mut scene = Scene { doc: &self.doc, layout, view: ui, text: &mut self.text, images: &mut self.images };
        paint::paint(&mut scene, pm, scale);
        *frames += 1;
        self.stats.since(Phase::Paint, started);
        self.stats.mark("first_paint");
    }

    /// Paints `app` for its window: the view is clean afterwards.
    pub fn render(&mut self, app: Id, pm: &mut Pixmap, scale: f32) {
        self.paint_into(app, pm, scale);
        if let Some(view) = self.views.get_mut(&app) {
            view.dirty = false;
        }
    }

    /// A fresh offscreen picture of `app`. The window still repaints if it was due to.
    pub fn picture(&mut self, app: Id, scale: f32) -> Option<Pixmap> {
        let size = self.views.get(&app)?.size;
        let mut pm = Pixmap::new((size.0 * scale).ceil().max(1.0) as u32, (size.1 * scale).ceil().max(1.0) as u32)?;
        self.paint_into(app, &mut pm, scale);
        if self.opts.headless {
            self.stats.frame_shown();
            if self.damage == DamageMode::Check {
                self.check_partial_repaint(app, &pm, scale);
            }
        }
        Some(pm)
    }

    /// The window changed size (logical px).
    pub fn resize_view(&mut self, app: Id, w: f32, h: f32, notify: bool) {
        let Some(view) = self.views.get_mut(&app) else { return };
        if view.size == (w, h) {
            return;
        }
        view.size = (w, h);
        view.layout = None;
        view.dirty = true;
        view.ui.popup = None;
        if notify {
            self.out.send(Outgoing::Resize { app, w: w.round() as i64, h: h.round() as i64 });
        }
    }

    /// Picks the app a request means: the named one, else the active one.
    pub fn app_for(&self, app: Option<Id>) -> Option<Id> {
        if let Some(a) = app.filter(|a| self.views.contains_key(a)) {
            return Some(a);
        }
        self.active_app
            .filter(|a| self.views.contains_key(a))
            .or_else(|| self.views.iter().find(|(_, v)| v.running).map(|(id, _)| *id))
            .or_else(|| self.views.keys().next().copied())
    }

    pub(crate) fn wait_frames(&mut self, req: u64, app: Id, n: u32) {
        self.request_redraw(app);
        self.pending_frames.push(PendingFrames { req, app, remaining: n.max(1) });
    }

    /// The window presented a frame: answer `frames` requests that were waiting for it.
    pub fn frame_presented(&mut self, app: Id) {
        self.stats.frame_shown();
        self.stats.mark("first_present");
        let frames = self.views.get(&app).map(|v| v.frames).unwrap_or(0);
        let mut waiting = false;
        let mut kept = Vec::new();
        for mut p in std::mem::take(&mut self.pending_frames) {
            if p.app == app {
                p.remaining = p.remaining.saturating_sub(1);
                if p.remaining == 0 {
                    self.out.send(Outgoing::reply(p.req, Value::from(frames)));
                    continue;
                }
                waiting = true;
            }
            kept.push(p);
        }
        self.pending_frames = kept;
        if waiting {
            self.request_redraw(app);
        }
        self.out.flush();
    }

    pub fn dialog_answered(&mut self, req: u64, value: Value, cancelled: bool) {
        self.out.send(crate::dialogs::reply(req, value, cancelled));
        self.out.flush();
    }
}

/// Requests that act like a person at the keyboard or mouse.
fn is_input(op: &Op) -> bool {
    matches!(op, Op::Click { .. } | Op::Mouse { .. } | Op::Type { .. } | Op::Key { .. } | Op::Wheel { .. })
}

pub fn app_size(props: &Map<String, Value>) -> (f32, f32) {
    let num = |k: &str, d: f32| props.get(k).and_then(Value::as_f64).map(|v| v as f32).filter(|v| *v > 0.0).unwrap_or(d);
    (num("width", DEFAULT_SIZE.0), num("height", DEFAULT_SIZE.1))
}
