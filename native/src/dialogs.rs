//! Builtin dialogs. Headless runs never open anything and answer with the
//! DESIGN 5.2 defaults. In a window, alert/confirm and the file pickers are
//! native (rfd); `ask` and `ask_color` are a modal we draw, in a running app's
//! window, or in a small window of its own when no app window is running yet.

use crate::elements::text_field::{Face, TextField};
use crate::elements::{ACCENT, CONTROL_TEXT_SIZE};
use crate::input::{Key, KeyInput, Named, ViewState};
use crate::layout::Rect;
use crate::paint::text::draw_shaped;
use crate::paint::Canvas;
use crate::props::Id;
use crate::protocol::{DialogRequest, Outgoing};
use crate::runtime::{AppView, Effect, Runtime};
use crate::style::Color;
use crate::text::rich::{TextStyle, INK};
use crate::text::{FamilyName, RichText, TextEngine};
use serde_json::{json, Map, Value};

/// The dialogs we draw ourselves rather than hand to the OS.
pub fn drawn_by_us(kind: &str) -> bool {
    matches!(kind, "ask" | "ask_color")
}

/// The value and `cancelled` flag a headless run answers with.
pub fn headless_answer(kind: &str) -> (Value, bool) {
    match kind {
        "alert" => (Value::Null, false),
        "confirm" => (Value::Bool(false), true),
        "ask" => (Value::String(String::new()), true),
        _ => (Value::Null, true),
    }
}

pub fn reply(req: u64, value: Value, cancelled: bool) -> Outgoing {
    let mut extra = Map::new();
    extra.insert("cancelled".into(), Value::Bool(cancelled));
    Outgoing::Reply { req, value, error: None, extra }
}

/// Native dialogs, run on the main thread while the event loop waits.
pub fn native(kind: &str, message: &str, default: &Value) -> (Value, bool) {
    use rfd::{FileDialog, MessageButtons, MessageDialog, MessageDialogResult};
    let path = |p: Option<std::path::PathBuf>| match p {
        Some(p) => (Value::String(p.to_string_lossy().into_owned()), false),
        None => (Value::Null, true),
    };
    let start = default.as_str().map(std::path::PathBuf::from);
    let with_dir = |d: FileDialog| match &start {
        Some(p) if p.is_dir() => d.set_directory(p),
        _ => d,
    };
    match kind {
        "alert" => {
            MessageDialog::new().set_title("Shoes").set_description(message).set_buttons(MessageButtons::Ok).show();
            (Value::Null, false)
        }
        "confirm" => {
            let answer = MessageDialog::new().set_title("Shoes").set_description(message).set_buttons(MessageButtons::OkCancel).show();
            let yes = matches!(answer, MessageDialogResult::Ok | MessageDialogResult::Yes);
            (Value::Bool(yes), !yes)
        }
        "ask_open_file" => path(with_dir(FileDialog::new().set_title(message)).pick_file()),
        "ask_save_file" => path(with_dir(FileDialog::new().set_title(message)).save_file()),
        "ask_open_folder" | "ask_save_folder" => path(with_dir(FileDialog::new().set_title(message)).pick_folder()),
        _ => (Value::Null, true),
    }
}

pub enum ModalKind {
    Ask(Box<TextField>),
    Color { selected: usize },
}

pub struct Modal {
    pub req: u64,
    pub message: String,
    /// `ask`'s `title:`, shown as a heading (and as the title of a window of its own).
    pub title: Option<String>,
    /// It has a window of its own, with nothing under it to dim.
    pub standalone: bool,
    pub kind: ModalKind,
    pub pressed: Option<ModalButton>,
    /// A press began in the text field: moves extend its selection.
    pub selecting: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModalButton {
    Ok,
    Cancel,
    Swatch(usize),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PointerPhase {
    Move,
    Down,
    Up,
}

pub const SWATCHES: [Color; 12] = [
    Color::rgb(0xff, 0x3b, 0x30),
    Color::rgb(0xff, 0x95, 0x00),
    Color::rgb(0xff, 0xcc, 0x00),
    Color::rgb(0x34, 0xc7, 0x59),
    Color::rgb(0x00, 0xc7, 0xbe),
    Color::rgb(0x0a, 0x84, 0xff),
    Color::rgb(0x58, 0x56, 0xd6),
    Color::rgb(0xaf, 0x52, 0xde),
    Color::rgb(0xff, 0x2d, 0x55),
    Color::rgb(0xa2, 0x84, 0x5e),
    Color::rgb(0x8e, 0x8e, 0x93),
    Color::rgb(0x1d, 0x1d, 0x1f),
];

const PANEL: Color = Color::rgb(0xf6, 0xf6, 0xf8);

pub(crate) struct Geometry {
    pub panel: Rect,
    pub message: (f32, f32, f32),
    pub field: Rect,
    pub swatch: Vec<Rect>,
    pub ok: Rect,
    pub cancel: Rect,
}

/// The modal's words: its title as a heading, then its message.
fn words(modal: &Modal) -> RichText {
    let style = TextStyle::new(CONTROL_TEXT_SIZE, INK);
    let mut rich = RichText::plain(&modal.message, style.clone());
    if let Some(title) = modal.title.as_deref().filter(|t| !t.is_empty()) {
        let heading = crate::text::rich::Run { text: format!("{title}\n"), style: TextStyle { weight: 600, ..style }, node: 0, spans: Vec::new() };
        rich.runs.insert(0, heading);
    }
    rich
}

/// The widest a panel gets.
const PANEL_WIDTH: f32 = 360.0;

/// The panel's width in a window `size` wide; a window of its own is all panel.
fn panel_width(modal: &Modal, window_w: f32) -> f32 {
    if modal.standalone {
        window_w
    } else {
        (window_w - 40.0).clamp(160.0, PANEL_WIDTH)
    }
}

pub(crate) fn geometry(modal: &Modal, size: (f32, f32), text: &mut TextEngine) -> (Geometry, crate::text::ShapedText) {
    let w = panel_width(modal, size.0);
    let shaped = text.shape(&words(modal), Some(w - 32.0));
    let body = body_height(&modal.kind);
    let h = panel_height(shaped.height, body);
    let panel = if modal.standalone { Rect::new(0.0, 0.0, w, h) } else { Rect::new((size.0 - w) / 2.0, ((size.1 - h) / 2.0).max(8.0), w, h) };
    let body_y = panel.y + 16.0 + shaped.height + 12.0;
    let field = Rect::new(panel.x + 16.0, body_y, w - 32.0, 28.0);
    let side = ((w - 32.0 - 5.0 * 8.0) / 6.0).min(30.0);
    let grid_x = panel.x + (w - (6.0 * side + 5.0 * 8.0)) / 2.0;
    let swatch = (0..SWATCHES.len())
        .map(|i| {
            let (col, row) = ((i % 6) as f32, (i / 6) as f32);
            Rect::new(grid_x + col * (side + 8.0), body_y + row * 36.0, side, 30.0)
        })
        .collect();
    let ok = Rect::new(panel.right() - 16.0 - 72.0, panel.bottom() - 16.0 - 28.0, 72.0, 28.0);
    let cancel = Rect::new(ok.x - 8.0 - 80.0, ok.y, 80.0, 28.0);
    (Geometry { panel, message: (panel.x + 16.0, panel.y + 16.0, w - 32.0), field, swatch, ok, cancel }, shaped)
}

fn panel_height(words_height: f32, body: f32) -> f32 {
    16.0 + words_height + 12.0 + body + 16.0 + 28.0 + 16.0
}

fn body_height(kind: &ModalKind) -> f32 {
    match kind {
        ModalKind::Ask(_) => 28.0,
        ModalKind::Color { .. } => 2.0 * 30.0 + 6.0,
    }
}

/// The size of a window of its own for `modal`: just the panel.
fn standalone_size(modal: &Modal, text: &mut TextEngine) -> (f32, f32) {
    let words_height = text.shape(&words(modal), Some(PANEL_WIDTH - 32.0)).height;
    (PANEL_WIDTH, panel_height(words_height, body_height(&modal.kind)))
}

pub fn paint_modal(canvas: &mut Canvas, view: &mut ViewState, text: &mut TextEngine, size: (f32, f32)) {
    let Some(modal) = view.modal.as_mut() else { return };
    let (g, message) = geometry(modal, size, text);
    if modal.standalone {
        canvas.fill_rect(Rect::new(0.0, 0.0, size.0, size.1), PANEL, None);
    } else {
        canvas.fill_rect(Rect::new(0.0, 0.0, size.0, size.1), Color::rgba(0, 0, 0, 70), None);
        for (grow, alpha) in [(12.0, 10), (6.0, 16), (2.0, 28)] {
            let p = g.panel;
            canvas.fill_rounded(Rect::new(p.x - grow, p.y - grow + 6.0, p.w + grow * 2.0, p.h + grow * 2.0), 12.0 + grow, Color::rgba(0, 0, 0, alpha), None);
        }
        canvas.fill_rounded(g.panel, 12.0, PANEL, None);
    }
    draw_shaped(canvas, text, &message, g.message.0, g.message.1, None, None);
    match &mut modal.kind {
        ModalKind::Ask(field) => {
            crate::elements::edit_line::frame(canvas, &crate::elements::edit_line::Colors::PLAIN, g.field, None, true);
            let inner = crate::elements::edit_line::inner_rect(g.field, field.line_height());
            field.fit(&mut text.fonts.system, inner);
            let area = Rect::new(g.field.x + 3.0, g.field.y + 1.0, g.field.w - 6.0, g.field.h - 2.0);
            crate::elements::edit_line::draw_field(canvas, field, area, None, true, crate::elements::ACCENT, text);
        }
        ModalKind::Color { selected } => {
            for (i, r) in g.swatch.iter().enumerate() {
                if i == *selected {
                    canvas.fill_rounded(Rect::new(r.x - 3.0, r.y - 3.0, r.w + 6.0, r.h + 6.0), 9.0, ACCENT, None);
                    canvas.fill_rounded(Rect::new(r.x - 1.0, r.y - 1.0, r.w + 2.0, r.h + 2.0), 7.0, Color::WHITE, None);
                }
                canvas.fill_rounded(*r, 6.0, SWATCHES[i], None);
            }
        }
    }
    for (rect, label, primary) in [(g.cancel, "Cancel", false), (g.ok, "OK", true)] {
        let (fill, ink) = if primary { (ACCENT, Color::WHITE) } else { (Color::WHITE, INK) };
        canvas.fill_rounded(rect, 6.0, fill, None);
        if !primary {
            canvas.stroke_rounded(rect, 6.0, Color::rgba(0, 0, 0, 38), 1.0, None);
        }
        let shaped = text.shape(&RichText::plain(label, TextStyle::new(CONTROL_TEXT_SIZE, ink)), None);
        draw_shaped(canvas, text, &shaped, rect.x + (rect.w - shaped.width) / 2.0, rect.y + (rect.h - shaped.height) / 2.0, None, None);
    }
}

impl Runtime {
    /// A running app's window that can hold an in-window `ask` or `ask_color`: the active
    /// one, else the first running. None while no app window is up yet, as when an app asks
    /// while its body is still being built, before `run`.
    pub fn modal_host(&self) -> Option<Id> {
        let app_window = |id: &Id| self.views.get(id).is_some_and(|v| v.running && !v.standalone);
        self.active_app.filter(app_window).or_else(|| self.views.keys().copied().find(app_window))
    }

    fn modal(&mut self, req: u64, dialog: &DialogRequest, standalone: bool) -> Modal {
        let kind = if dialog.kind == "ask" {
            let initial = dialog.default.as_str().unwrap_or("");
            let fs = &mut self.text.fonts.system;
            let mut field = TextField::new(fs, initial, false, dialog.secret, Face::plain(FamilyName::Sans), CONTROL_TEXT_SIZE, INK);
            field.select_all();
            ModalKind::Ask(Box::new(field))
        } else {
            ModalKind::Color { selected: 5 }
        };
        Modal { req, message: dialog.message.clone(), title: dialog.title.clone(), standalone, kind, pressed: None, selecting: false }
    }

    /// Opens the in-window modal for `ask` / `ask_color` in `app`.
    pub fn open_modal(&mut self, app: Id, req: u64, dialog: &DialogRequest) {
        if !self.views.contains_key(&app) {
            self.out.send(reply(req, Value::Null, true));
            return;
        }
        let modal = self.modal(req, dialog, false);
        if let Some(view) = self.views.get_mut(&app) {
            view.ui.modal = Some(modal);
        }
        self.request_redraw(app);
    }

    /// A view of its own for an `ask` or `ask_color` no app window can hold: the window layer
    /// opens a window for it, sized to the dialog. It has no document; it lasts as long as its
    /// modal, and Ruby never hears of it. Returns its id (negative, so no drawable has it).
    pub fn open_standalone(&mut self, req: u64, dialog: &DialogRequest) -> Id {
        let id = -(req as Id) - 1;
        let modal = self.modal(req, dialog, true);
        let size = standalone_size(&modal, &mut self.text);
        let scale = self.default_scale();
        let mut view = AppView::new(id, id, size, scale);
        view.standalone = true;
        view.running = true;
        view.ui.modal = Some(modal);
        self.views.insert(id, view);
        id
    }

    /// The title a window gets: the App's `title`, a dialog's own title, else "Shoes".
    pub fn window_title(&self, app: Id) -> String {
        let dialog = || self.views.get(&app)?.ui.modal.as_ref()?.title.clone().filter(|_| self.is_standalone(app));
        self.doc.get(app).and_then(|n| n.props.text("title")).or_else(dialog).unwrap_or_else(|| "Shoes".into())
    }

    pub fn is_standalone(&self, app: Id) -> bool {
        self.views.get(&app).is_some_and(|v| v.standalone)
    }

    pub(crate) fn close_modal(&mut self, app: Id, ok: bool) {
        let Some(modal) = self.views.get_mut(&app).and_then(|v| v.ui.modal.take()) else { return };
        let msg = match (&modal.kind, ok) {
            (ModalKind::Ask(field), true) => reply(modal.req, Value::String(field.text()), false),
            (ModalKind::Color { selected }, true) => {
                let c = SWATCHES[*selected];
                reply(modal.req, json!([c.r, c.g, c.b, c.a]), false)
            }
            (_, false) => reply(modal.req, Value::Null, true),
        };
        self.out.send(msg);
        self.out.flush();
        if self.is_standalone(app) {
            self.drop_standalone(app);
            self.effects.push(Effect::CloseWindow(app));
        } else {
            self.request_redraw(app);
        }
    }

    pub(crate) fn modal_pointer(&mut self, app: Id, x: f32, y: f32, phase: PointerPhase) -> bool {
        let size = match self.views.get(&app) {
            Some(v) if v.ui.modal.is_some() => v.size,
            _ => return false,
        };
        let view = self.views.get_mut(&app).expect("view");
        let modal = view.ui.modal.as_mut().expect("modal");
        let (g, _) = geometry(modal, size, &mut self.text);
        let under = if g.ok.contains(x, y) {
            Some(ModalButton::Ok)
        } else if g.cancel.contains(x, y) {
            Some(ModalButton::Cancel)
        } else {
            g.swatch.iter().position(|r| r.contains(x, y)).filter(|_| matches!(modal.kind, ModalKind::Color { .. })).map(ModalButton::Swatch)
        };
        match phase {
            PointerPhase::Move => {
                if let (ModalKind::Ask(field), true) = (&mut modal.kind, modal.selecting) {
                    field.drag(&mut self.text.fonts.system, x, y);
                }
            }
            PointerPhase::Down => {
                modal.pressed = under;
                if let (ModalKind::Ask(field), true) = (&mut modal.kind, g.field.contains(x, y)) {
                    field.press(&mut self.text.fonts.system, x, y, 1, false);
                    modal.selecting = true;
                }
                if let (ModalKind::Color { selected }, Some(ModalButton::Swatch(i))) = (&mut modal.kind, under) {
                    *selected = i;
                }
            }
            PointerPhase::Up => {
                modal.selecting = false;
                if let ModalKind::Ask(field) = &mut modal.kind {
                    field.drop_empty_selection();
                }
                let pressed = modal.pressed.take();
                if pressed.is_some() && pressed == under {
                    match under {
                        Some(ModalButton::Ok) => self.close_modal(app, true),
                        Some(ModalButton::Cancel) => self.close_modal(app, false),
                        _ => {}
                    }
                }
            }
        }
        self.request_redraw(app);
        true
    }

    pub(crate) fn modal_key(&mut self, app: Id, key: &KeyInput) -> bool {
        let Some(view) = self.views.get_mut(&app) else { return false };
        let Some(modal) = view.ui.modal.as_mut() else { return false };
        match &key.key {
            Key::Named(Named::Enter) => self.close_modal(app, true),
            Key::Named(Named::Escape) => self.close_modal(app, false),
            _ => {
                match &mut modal.kind {
                    ModalKind::Ask(field) => {
                        field.key(&mut self.text.fonts.system, key, &mut self.clipboard);
                    }
                    ModalKind::Color { selected } => match key.key {
                        Key::Named(Named::Left) => *selected = selected.saturating_sub(1),
                        Key::Named(Named::Right) => *selected = (*selected + 1).min(SWATCHES.len() - 1),
                        _ => {}
                    },
                }
                self.request_redraw(app);
            }
        }
        true
    }
}
