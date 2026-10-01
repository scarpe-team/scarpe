//! The Runtime: the retained document, per-app view state and the protocol
//! handler, shared by the window and the headless canvas.

mod repaint;
mod startup;
pub mod stats;

use crate::doc::{Doc, Kind, NewNode};
use crate::elements::image::ImageCache;
use crate::input::{Clipboard, CursorShape, ViewState};
use crate::layout::{self, Inputs, Layout};
use crate::limits;
use crate::paint::damage::{FrameMemory, Revisions};
use crate::paint::{self, Scene};
use crate::props::Id;
use crate::protocol::{self, Create, DialogRequest, Incoming, Op, Outbox, Outgoing};
use crate::text::{FontMode, TextEngine};
use serde_json::{Map, Value};
use stats::{Phase, Stats};
use repaint::DamageMode;
pub use startup::{load_fonts, FontsLoading};
use std::collections::{BTreeMap, HashMap};
use std::time::Instant;
use tiny_skia::Pixmap;

/// An app that names no size opens at Shoes 3 and Shoes 4's 600x500 (ledger A1).
pub const DEFAULT_SIZE: (f32, f32) = (600.0, 500.0);

/// How long Rust waits for Ruby's `quit` after telling it every window closed, then leaves.
pub const QUIT_GRACE: std::time::Duration = std::time::Duration::from_secs(3);

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
    /// App `opacity`, 0.0 (clear) to 1.0.
    Opacity(Id, f32),
    /// A native dialog, or an `ask` no app window can hold (dialogs::open_standalone).
    Dialog { req: u64, dialog: DialogRequest },
    OpenUrl(String),
    /// Read the window's accessibility as AppKit hands it to VoiceOver, after acting on the
    /// element with a title, and answer `req` (a11y ops with `platform`).
    PlatformA11y { req: u64, app: Id, act: Option<crate::a11y::PlatformAct> },
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
    /// The rects Ruby was last told about, `[x, y, w, h, scroll_h]` by id.
    pub told: HashMap<Id, [f64; 5]>,
    /// A window of its own for a dialog no app window could hold (dialogs::open_standalone):
    /// no document, and Ruby never hears of it.
    pub standalone: bool,
}

impl AppView {
    pub fn new(app: Id, doc_root: Id, size: (f32, f32), scale: f32) -> Self {
        AppView {
            app,
            doc_root,
            size,
            scale,
            running: false,
            layout: None,
            ui: ViewState::default(),
            dirty: true,
            frames: 0,
            told: HashMap::new(),
            standalone: false,
        }
    }
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
    /// System fonts still loading on another thread; the first layout waits for them.
    fonts_loading: Option<FontsLoading>,
    /// Something that could show a picture went away or changed: the next flush lets go of
    /// pictures nothing shows any more.
    pictures_to_check: bool,
}

impl Runtime {
    pub fn new(opts: Options, out: Outbox) -> Self {
        let clipboard = Clipboard::for_run(opts.headless);
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
            fonts_loading: None,
            pictures_to_check: false,
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
                    self.scroll_slot(app, id, top.max(0.0));
                }
            }
            Incoming::Font { path } => {
                self.fonts_ready();
                self.text.fonts.register(std::path::Path::new(&path));
                self.revisions.touch_everything();
                self.invalidate();
            }
            Incoming::TextMode { mode } => match crate::text::TextMode::parse(&mode) {
                Some(mode) if mode != self.text.fonts.text_mode => {
                    self.fonts_ready();
                    self.text.fonts.text_mode = mode;
                    self.revisions.touch_everything();
                    self.invalidate();
                }
                Some(_) => {}
                None => self.out.send(Outgoing::Log { level: "warn".into(), msg: format!("unknown text_mode {mode:?}; it is scarpe or shoes3") }),
            },
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
            self.views.insert(c.id, AppView::new(c.id, doc_root, size, scale));
        }
        self.invalidate();
    }

    fn set_props(&mut self, id: Id, props: Map<String, Value>) {
        let new_text = props.get("text").map(crate::props::value_text);
        let title = props.get("title").map(crate::props::value_text);
        let resized = props.contains_key("width") || props.contains_key("height");
        let restyled = ["font", "stroke", "secret"].iter().any(|k| props.contains_key(*k));
        let opacity = props.get("opacity").and_then(Value::as_f64).map(|o| o as f32);
        let recursor = props.contains_key("cursor");
        self.pictures_to_check |= ["url", "icon", "fill", "stroke", "draw_context"].iter().any(|k| props.contains_key(*k));
        let looks_only = self.doc.get(id).is_some_and(|n| props.keys().all(|key| changes_only_looks(&n.kind, key)));
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
                if let Some(opacity) = opacity {
                    self.effects.push(Effect::Opacity(id, opacity));
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
        if recursor {
            for app in self.views.keys().copied().collect::<Vec<_>>() {
                self.refresh_cursor(app);
            }
        }
        // Only the app the node is drawn in can change. A node no app holds (a text span, which
        // its paras list without being its parent) might show in any.
        let changed: Vec<Id> = match self.doc.app_of(id).filter(|app| self.views.contains_key(app)) {
            Some(app) => vec![app],
            None => self.views.keys().copied().collect(),
        };
        for app in changed {
            let Some(view) = self.views.get_mut(&app) else { continue };
            view.dirty = true;
            if !looks_only {
                // Else paint reads these straight from the props: the layout stands and the node repaints.
                view.layout = None;
            }
        }
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
        self.pictures_to_check = true;
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

    /// The user closed a window. Ruby may be blocked waiting on it (an `ask` in its modal, a
    /// `frames` request), so those are answered first; then Ruby hears `closed`, destroys the
    /// app and sends `quit`.
    pub fn window_closed(&mut self, app: Id) {
        self.answer_what_waits_on(app, "window closed");
        if self.is_standalone(app) {
            // Ruby never knew this window: the dialog's answer was all it waited for.
            self.drop_standalone(app);
            return;
        }
        if let Some(view) = self.views.get_mut(&app) {
            view.running = false;
        }
        if self.active_app == Some(app) {
            self.active_app = self.views.iter().find(|(_, v)| v.running).map(|(id, _)| *id);
        }
        self.out.send(Outgoing::Closed { app });
        self.out.flush();
    }

    /// Lets go of a dialog's own view (dialogs::open_standalone), and what it owned.
    pub(crate) fn drop_standalone(&mut self, app: Id) {
        self.views.remove(&app);
        self.text.forget_layout(app);
        if self.active_app == Some(app) {
            self.active_app = None;
        }
    }

    fn close_view(&mut self, app: Id) {
        self.answer_what_waits_on(app, "app closed");
        let Some(view) = self.views.remove(&app) else { return };
        self.text.forget_layout(view.doc_root);
        let removed = self.doc.remove_app(app);
        self.revisions.forget(&removed);
        self.effects.push(Effect::CloseWindow(app));
        if self.active_app == Some(app) {
            self.active_app = self.views.keys().next().copied();
        }
    }

    /// Answers every request still waiting on `app`'s window: its modal as cancelled, its
    /// `frames` requests with `why`.
    fn answer_what_waits_on(&mut self, app: Id, why: &str) {
        if let Some(modal) = self.views.get_mut(&app).and_then(|view| view.ui.modal.take()) {
            self.out.send(crate::dialogs::reply(modal.req, Value::Null, true));
        }
        let (theirs, others): (Vec<_>, Vec<_>) = std::mem::take(&mut self.pending_frames).into_iter().partition(|p| p.app == app);
        self.pending_frames = others;
        for p in theirs {
            self.out.send(Outgoing::error(p.req, why, Value::Null));
        }
    }

    /// Scrolls a slot of `app` to `top`. Its contents move in the layout that stands, and Ruby
    /// hears the rects that moved; nothing is laid out again unless the layout cannot move
    /// them by itself (layout::Layout::scroll), when it is dropped instead.
    pub(crate) fn scroll_slot(&mut self, app: Id, slot: Id, top: f32) {
        let Some(view) = self.views.get_mut(&app) else { return };
        let before = view.layout.as_ref().and_then(|layout| layout.scrollers.get(&slot)).map(|s| s.top);
        let settled = view.layout.as_mut().and_then(|layout| layout.scroll(&self.doc, slot, top));
        view.ui.scroll.insert(slot, settled.unwrap_or(top));
        view.dirty = true;
        if settled.is_none() {
            view.layout = None;
        } else if settled != before {
            self.push_layout(app);
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
        self.images.next_batch();
        self.let_go_of_loose_spans();
        self.let_go_of_unshown_pictures();
        let running: Vec<Id> = self.views.iter().filter(|(_, v)| v.running && v.layout.is_none()).map(|(id, _)| *id).collect();
        for app in running {
            self.ensure_layout(app);
        }
    }

    /// Text spans no text has named for longest, past limits::LOOSE_SPANS (Doc's span names).
    fn let_go_of_loose_spans(&mut self) {
        let let_go = self.doc.let_go_of_loose_spans(limits::LOOSE_SPANS);
        if !let_go.is_empty() {
            self.revisions.forget(&let_go);
            for view in self.views.values_mut() {
                view.ui.forget(&let_go);
            }
        }
    }

    /// Pictures no drawable shows any more, once something that could show one went or changed.
    fn let_go_of_unshown_pictures(&mut self) {
        if std::mem::take(&mut self.pictures_to_check) && !self.images.is_empty() {
            let shown: std::collections::HashSet<std::path::PathBuf> = self.doc.iter().flat_map(crate::elements::image::shown_by).collect();
            self.images.retain(|path| shown.contains(path));
        }
    }

    pub fn ensure_layout(&mut self, app: Id) {
        self.fonts_ready();
        let Some(view) = self.views.get_mut(&app) else { return };
        if view.layout.is_some() {
            return;
        }
        let started = Instant::now();
        let inputs = Inputs { doc: &self.doc, text: &mut self.text, images: &mut self.images, scroll: &view.ui.scroll };
        view.layout = Some(layout::layout(inputs, view.doc_root, view.size));
        self.stats.since(Phase::Layout, started);
        self.stats.mark("first_layout");
        self.push_layout(app);
    }

    /// Tells Ruby where nodes landed, so Lacci's left, top, width, height and scroll_height
    /// can answer in pixels (contract a; ledger A4, C5): every rect after an app's first
    /// layout, then only those that moved. Ids that left the layout are simply dropped.
    pub(crate) fn push_layout(&mut self, app: Id) {
        let Some(view) = self.views.get_mut(&app) else { return };
        let Some(layout) = view.layout.as_ref() else { return };
        let mut told = HashMap::with_capacity(layout.boxes.len());
        let mut rects = Vec::new();
        for (&id, b) in &layout.boxes {
            let r = b.rect;
            let scroll_h = layout.content_heights.get(&id).copied().unwrap_or(r.h);
            let rect = [r.x, r.y, r.w, r.h, scroll_h].map(|v| (v as f64 * 100.0).round() / 100.0);
            if view.told.get(&id) != Some(&rect) {
                rects.push((id, rect[0], rect[1], rect[2], rect[3], rect[4]));
            }
            told.insert(id, rect);
        }
        view.told = told;
        if !rects.is_empty() {
            rects.sort_by_key(|r| r.0);
            self.out.send(Outgoing::Layout { app, rects });
        }
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
        self.count_resampled_images();
    }

    /// Pictures resampled to a new size since the last paint (elements::image::ImageCache::at_size).
    pub(crate) fn count_resampled_images(&mut self) {
        let made = self.images.take_resampled();
        if made > 0 {
            self.stats.count("images_resampled", made);
        }
    }

    /// Paints `app` for its window: the view is clean afterwards.
    pub fn render(&mut self, app: Id, pm: &mut Pixmap, scale: f32) {
        self.paint_into(app, pm, scale);
        if let Some(view) = self.views.get_mut(&app) {
            view.dirty = false;
        }
    }

    /// A fresh offscreen picture of `app`. The window still repaints if it was due to.
    /// None when the picture would be too large to make (limits::picture_size).
    pub fn picture(&mut self, app: Id, scale: f32) -> Option<Pixmap> {
        let (w, h) = limits::picture_size(self.views.get(&app)?.size, scale)?;
        let mut pm = Pixmap::new(w, h)?;
        self.paint_into(app, &mut pm, scale);
        if self.opts.headless {
            self.stats.frame_shown();
            if self.damage == DamageMode::Check {
                self.check_partial_repaint(app, &pm, scale);
            }
        }
        Some(pm)
    }

    /// The window changed size (logical px). A size that cannot be one (NaN, zero, negative:
    /// a minimised window) keeps the last; a huge one is capped at limits::MAX_SIDE.
    pub fn resize_view(&mut self, app: Id, w: f32, h: f32, notify: bool) {
        let (Some(w), Some(h)) = (limits::side(w), limits::side(h)) else { return };
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

    /// Picks the app a request means: the named one, else the active one. A dialog's window of
    /// its own is never the one meant unless named.
    pub fn app_for(&self, app: Option<Id>) -> Option<Id> {
        if let Some(a) = app.filter(|a| self.views.contains_key(a)) {
            return Some(a);
        }
        let apps = || self.views.iter().filter(|(_, v)| !v.standalone);
        self.active_app
            .filter(|a| self.views.get(a).is_some_and(|v| !v.standalone))
            .or_else(|| apps().find(|(_, v)| v.running).map(|(id, _)| *id))
            .or_else(|| apps().next().map(|(id, _)| *id))
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

/// Props that change how a node looks and never where anything goes, so they keep the layout:
/// paint reads them from the node itself. A line's strokewidth is not one (its box includes the
/// stroke), nor is anything a Para shapes into its text.
fn changes_only_looks(kind: &Kind, key: &str) -> bool {
    match kind {
        k if k.is_art() => matches!(key, "fill" | "stroke" | "cap"),
        Kind::Background | Kind::Border => matches!(key, "fill" | "stroke" | "strokewidth" | "curve"),
        Kind::Check | Kind::Radio => key == "checked",
        Kind::Progress | Kind::Slider => key == "fraction",
        Kind::EditLine | Kind::EditBox => key == "text",
        Kind::Para | Kind::TextDrawable => matches!(key, "text_cursor" | "text_marker"),
        _ => false,
    }
}

/// Requests that act like a person at the keyboard or mouse.
fn is_input(op: &Op) -> bool {
    matches!(op, Op::Click { .. } | Op::Mouse { .. } | Op::Type { .. } | Op::Key { .. } | Op::Wheel { .. } | Op::A11yAction { .. })
}

/// The App's `width` and `height`, each finite, positive and at most limits::MAX_SIDE.
pub fn app_size(props: &Map<String, Value>) -> (f32, f32) {
    let num = |k: &str, d: f32| props.get(k).and_then(Value::as_f64).and_then(|v| limits::side(v as f32)).unwrap_or(d);
    (num("width", DEFAULT_SIZE.0), num("height", DEFAULT_SIZE.1))
}
