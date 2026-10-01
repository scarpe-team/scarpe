//! Input: hit-testing, hover transitions, press/release routing, focus and
//! tab order, keys (with Shoes key names), text editing and the wheel.
//!
//! The window and the automation ops both come through these methods, so a
//! synthetic click takes exactly the path a real one does.

use crate::doc::{Doc, Kind};
use crate::elements::list_box::{self, Popup, PopupKey};
use crate::elements::text_field::{self, TextField};
use crate::elements::tooltip::{self, Tooltip};
use crate::elements::{button, check};
use crate::layout::{Layout, TextBox};
use crate::props::Id;
use crate::protocol::Outgoing;
use crate::runtime::{Effect, Runtime};
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::time::{Duration, Instant};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Key {
    Char(String),
    Named(Named),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Named {
    Enter,
    Tab,
    Backspace,
    Delete,
    Escape,
    Left,
    Right,
    Up,
    Down,
    Home,
    End,
    PageUp,
    PageDown,
    Insert,
    F(u8),
}

impl Named {
    fn shoes(self) -> String {
        match self {
            Named::Enter => "enter".into(),
            Named::Tab => "tab".into(),
            Named::Backspace => "backspace".into(),
            Named::Delete => "delete".into(),
            Named::Escape => "escape".into(),
            Named::Left => "left".into(),
            Named::Right => "right".into(),
            Named::Up => "up".into(),
            Named::Down => "down".into(),
            Named::Home => "home".into(),
            Named::End => "end".into(),
            Named::PageUp => "page_up".into(),
            Named::PageDown => "page_down".into(),
            Named::Insert => "insert".into(),
            Named::F(n) => format!("f{n}"),
        }
    }

    fn from_shoes(name: &str) -> Option<Named> {
        Some(match name {
            "\n" | "return" | "enter" => Named::Enter,
            "tab" => Named::Tab,
            "backspace" => Named::Backspace,
            "delete" => Named::Delete,
            "escape" | "esc" => Named::Escape,
            "left" => Named::Left,
            "right" => Named::Right,
            "up" => Named::Up,
            "down" => Named::Down,
            "home" => Named::Home,
            "end" => Named::End,
            "page_up" => Named::PageUp,
            "page_down" => Named::PageDown,
            "insert" => Named::Insert,
            f if f.starts_with('f') && f.len() > 1 => Named::F(f[1..].parse().ok().filter(|n| (1..=12).contains(n))?),
            _ => return None,
        })
    }
}

/// A key press, independent of winit so automation can make them too.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct KeyInput {
    pub key: Key,
    pub text: Option<String>,
    pub ctrl: bool,
    pub alt: bool,
    /// Only for named keys: on characters Shift is already folded in ("&", not shift_7).
    pub shift: bool,
    /// Command on macOS. Key names spell it `alt_`, as Shoes 3 did (Q5); editing
    /// shortcuts treat it like Control.
    pub command: bool,
}

impl KeyInput {
    pub fn char(c: char) -> KeyInput {
        match c {
            '\n' | '\r' => KeyInput::named(Named::Enter),
            '\t' => KeyInput::named(Named::Tab),
            c => KeyInput { text: Some(c.to_string()), ..KeyInput::plain(Key::Char(c.to_string())) },
        }
    }

    pub fn named(named: Named) -> KeyInput {
        KeyInput::plain(Key::Named(named))
    }

    /// The key alone: no text, no modifiers.
    pub fn plain(key: Key) -> KeyInput {
        KeyInput { key, text: None, ctrl: false, alt: false, shift: false, command: false }
    }

    /// Control, or Command on macOS: the modifier of copy, paste and select-all.
    pub fn shortcut(&self) -> bool {
        self.ctrl || self.command
    }

    /// Any modifier that turns a character into a Symbol.
    pub fn modified(&self) -> bool {
        self.ctrl || self.alt || self.command
    }

    /// The value a `keypress` handler receives (DESIGN 4.4). Symbols travel as
    /// Strings starting with ":". Modifiers come in the order control, shift, alt.
    pub fn shoes_name(&self) -> Option<String> {
        let mods = |shift: bool| {
            let mut m = String::new();
            if self.ctrl {
                m.push_str("control_");
            }
            if shift {
                m.push_str("shift_");
            }
            if self.alt || self.command {
                m.push_str("alt_");
            }
            m
        };
        match &self.key {
            Key::Named(Named::Enter) if !(self.modified() || self.shift) => Some("\n".into()),
            Key::Named(named) => Some(format!(":{}{}", mods(self.shift), named.shoes())),
            Key::Char(c) if self.modified() => Some(format!(":{}{}", mods(false), c)),
            Key::Char(c) => Some(self.text.clone().filter(|t| !t.is_empty()).unwrap_or_else(|| c.clone())),
        }
    }

    /// A Shoes key name ("left", ":control_a", "a", "\n", ":shift_alt_7") as a key press.
    pub fn parse(name: &str) -> Option<KeyInput> {
        if name == "\n" || name == " " {
            return Some(KeyInput::char(name.chars().next()?));
        }
        let mut rest = name.strip_prefix(':').unwrap_or(name);
        let (mut ctrl, mut shift, mut alt, mut command) = (false, false, false, false);
        loop {
            if let Some(r) = rest.strip_prefix("control_").or_else(|| rest.strip_prefix("ctrl_")) {
                (ctrl, rest) = (true, r);
            } else if let Some(r) = rest.strip_prefix("shift_") {
                (shift, rest) = (true, r);
            } else if let Some(r) = rest.strip_prefix("alt_").or_else(|| rest.strip_prefix("option_")) {
                (alt, rest) = (true, r);
            } else if let Some(r) = rest.strip_prefix("command_").or_else(|| rest.strip_prefix("cmd_")).or_else(|| rest.strip_prefix("super_")) {
                (command, rest) = (true, r);
            } else {
                break;
            }
        }
        if rest.is_empty() {
            return None;
        }
        let key = match Named::from_shoes(rest) {
            Some(named) => Key::Named(named),
            None if rest == "space" => Key::Char(" ".into()),
            None if rest.chars().count() == 1 && shift => Key::Char(us_shifted(rest)),
            None if rest.chars().count() == 1 => Key::Char(rest.into()),
            None => return None,
        };
        let shift = shift && matches!(key, Key::Named(_));
        let mut k = KeyInput { ctrl, alt, shift, command, ..KeyInput::plain(key) };
        if let Key::Char(c) = &k.key {
            k.text = (!k.modified()).then(|| c.clone());
        }
        Some(k)
    }
}

/// The character Shift makes of a key on a US keyboard: "On US keyboards, `Shift-7`
/// is an ampersand" (manual 2223-2227).
pub fn us_shifted(key: &str) -> String {
    let mut chars = key.chars();
    let (Some(c), None) = (chars.next(), chars.next()) else { return key.to_string() };
    let shifted = match c {
        '1' => '!',
        '2' => '@',
        '3' => '#',
        '4' => '$',
        '5' => '%',
        '6' => '^',
        '7' => '&',
        '8' => '*',
        '9' => '(',
        '0' => ')',
        '-' => '_',
        '=' => '+',
        '[' => '{',
        ']' => '}',
        '\\' => '|',
        ';' => ':',
        '\'' => '"',
        ',' => '<',
        '.' => '>',
        '/' => '?',
        '`' => '~',
        c => return c.to_uppercase().collect(),
    };
    shifted.to_string()
}

/// Clipboard: the system one in a window, a private one when headless so a
/// test run never touches what the user copied. Text fields copy and paste
/// through it, and so do Shoes' `app.clipboard` and `app.clipboard=` (the
/// `clipboard` req).
pub struct Clipboard {
    system: Option<arboard::Clipboard>,
    /// SCARPE_CLIPBOARD_FILE: a file standing in for the system clipboard,
    /// which is how a sandboxed run (spec/run) shares one with its test code.
    file: Option<std::path::PathBuf>,
    local: String,
}

impl Clipboard {
    pub fn local() -> Self {
        Clipboard { system: None, file: None, local: String::new() }
    }

    pub fn system() -> Self {
        Clipboard { system: arboard::Clipboard::new().ok(), file: None, local: String::new() }
    }

    /// The stand-in file when SCARPE_CLIPBOARD_FILE names one; otherwise the
    /// system clipboard in a window and a private one headless.
    pub fn for_run(headless: bool) -> Self {
        match std::env::var_os("SCARPE_CLIPBOARD_FILE").filter(|file| !file.is_empty()) {
            Some(file) => Self::backed_by(file.into()),
            None if headless => Self::local(),
            None => Self::system(),
        }
    }

    pub fn backed_by(file: std::path::PathBuf) -> Self {
        Clipboard { system: None, file: Some(file), local: String::new() }
    }

    pub fn get(&mut self) -> String {
        if let Some(file) = &self.file {
            return std::fs::read(file).map(|bytes| String::from_utf8_lossy(&bytes).into_owned()).unwrap_or_default();
        }
        match self.system.as_mut() {
            Some(sys) => sys.get_text().unwrap_or_default(),
            None => self.local.clone(),
        }
    }

    pub fn set(&mut self, text: String) {
        if let Some(file) = &self.file {
            let _ = std::fs::write(file, text);
            return;
        }
        match self.system.as_mut() {
            Some(sys) => {
                let _ = sys.set_text(text);
            }
            None => self.local = text,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PressKind {
    /// Button, Check, Radio, Image, Link: `click` on release over the target.
    Click,
    /// A text field: dragging extends the selection.
    Field,
    /// Anything else (slots, text): no click of its own.
    Plain,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Press {
    pub target: Id,
    pub button: u8,
    pub kind: PressKind,
    /// An input widget or link took the press, so slot subscriptions stay quiet.
    pub consumed: bool,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum CursorShape {
    #[default]
    Arrow,
    Hand,
    Text,
    Wait,
}

impl CursorShape {
    /// A `cursor` style: Shoes 3's `:arrow_cursor`, `:hand_cursor`, `:text_cursor` and
    /// `:watch_cursor`, or the plain and CSS names.
    pub fn parse(name: &str) -> Option<CursorShape> {
        match name.trim_start_matches(':').trim_end_matches("_cursor") {
            "arrow" | "default" => Some(CursorShape::Arrow),
            "hand" | "pointer" | "link" => Some(CursorShape::Hand),
            "text" | "ibeam" => Some(CursorShape::Text),
            "watch" | "wait" | "busy" => Some(CursorShape::Wait),
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Modifiers {
    pub ctrl: bool,
    pub shift: bool,
    pub alt: bool,
    /// Command on macOS.
    pub command: bool,
}

/// Per-app interaction state.
#[derive(Default)]
pub struct ViewState {
    pub pointer: Option<(f32, f32)>,
    pub buttons: u8,
    pub modifiers: Modifiers,
    /// The hovered drawable and its ancestors, innermost first.
    pub hover_chain: Vec<Id>,
    pub hover_link: Option<Id>,
    /// SubscriptionItems whose parent slot holds the pointer.
    pub hover_items: HashSet<Id>,
    pub hover_para: Option<(Id, Option<i64>)>,
    pub pressed: Option<Press>,
    pub focus: Option<Id>,
    /// Focus arrived from the keyboard (tab, `focus`): buttons show their ring.
    pub focus_visible: bool,
    pub fields: HashMap<Id, TextField>,
    pub popup: Option<Popup>,
    pub tooltip: Option<Tooltip>,
    pub modal: Option<crate::dialogs::Modal>,
    pub scroll: HashMap<Id, f32>,
    pub cursor: CursorShape,
    last_click: Option<(Instant, f32, f32, u32)>,
}

impl ViewState {
    /// Forgets destroyed nodes.
    pub fn forget(&mut self, removed: &[Id]) {
        let gone = |id: &Id| removed.contains(id);
        self.hover_chain.retain(|id| !gone(id));
        self.hover_items.retain(|id| !gone(id));
        if self.hover_link.is_some_and(|id| gone(&id)) {
            self.hover_link = None;
        }
        if self.hover_para.is_some_and(|(id, _)| gone(&id)) {
            self.hover_para = None;
        }
        if self.pressed.as_ref().is_some_and(|p| gone(&p.target)) {
            self.pressed = None;
        }
        if self.focus.is_some_and(|id| gone(&id)) {
            self.focus = None;
        }
        if self.popup.as_ref().is_some_and(|p| gone(&p.list_box)) {
            self.popup = None;
        }
        if self.tooltip.as_ref().is_some_and(|t| gone(&t.owner)) {
            self.tooltip = None;
        }
        self.fields.retain(|id, _| !gone(id));
        self.scroll.retain(|id, _| !gone(id));
    }

    fn click_count(&mut self, x: f32, y: f32) -> u32 {
        let now = Instant::now();
        let count = match self.last_click {
            Some((at, lx, ly, n)) if now.duration_since(at) < Duration::from_millis(450) && (lx - x).abs() < 4.0 && (ly - y).abs() < 4.0 => n + 1,
            _ => 1,
        };
        self.last_click = Some((now, x, y, count));
        count
    }
}

/// What the pointer is over: a drawable and, inside a para, the text
/// fragments (spans, links) under it, innermost first.
#[derive(Clone, Debug, PartialEq)]
pub struct Hit {
    pub node: Id,
    pub link: Option<Id>,
    pub spans: Vec<Id>,
}

/// Topmost drawable at (x, y), in reverse paint order. Backgrounds and borders
/// never catch the pointer; the window's root catches whatever is left, and
/// nothing is hit outside the window.
pub fn hit_test(doc: &Doc, layout: &Layout, x: f32, y: f32) -> Option<Hit> {
    if x < 0.0 || y < 0.0 || x >= layout.size.0 || y >= layout.size.1 {
        return None;
    }
    if let Some(id) = layout.order.iter().rev().copied().find(|&id| covers(doc, layout, id, x, y)) {
        let node = doc.get(id)?;
        let fragment = layout.texts.get(&id).filter(|_| matches!(node.kind, Kind::Para | Kind::TextDrawable)).and_then(|tb| span_at(tb, x, y));
        let (link, spans) = fragment.map(|m| (m.link, m.spans.clone())).unwrap_or_default();
        return Some(Hit { node: id, link, spans });
    }
    layout.boxes.contains_key(&layout.root).then_some(Hit { node: layout.root, link: None, spans: Vec::new() })
}

/// Every drawable under (x, y) that can catch the pointer, topmost first.
pub fn under(doc: &Doc, layout: &Layout, x: f32, y: f32) -> Vec<Id> {
    if x < 0.0 || y < 0.0 || x >= layout.size.0 || y >= layout.size.1 {
        return Vec::new();
    }
    layout.order.iter().rev().copied().filter(|&id| covers(doc, layout, id, x, y)).collect()
}

/// Whether the pointer at (x, y) is over drawable `id`. Backgrounds, borders and the window's
/// root never catch it, and a paragraph's first-line indent belongs to what came before it
/// on the line.
fn covers(doc: &Doc, layout: &Layout, id: Id, x: f32, y: f32) -> bool {
    let Some(node) = doc.get(id) else { return false };
    if node.kind.is_decor() || id == layout.root {
        return false;
    }
    let Some(b) = layout.boxes.get(&id) else { return false };
    if !b.rect.contains(x, y) || b.clip.is_some_and(|c| !c.contains(x, y)) {
        return false;
    }
    layout.texts.get(&id).is_none_or(|tb| tb.owns(x, y))
}

/// The styled run whose glyphs are under (x, y), if any.
pub fn span_at(tb: &TextBox, x: f32, y: f32) -> Option<&crate::text::SpanMeta> {
    let (lx, ly) = (x - tb.x, y - tb.y);
    for run in tb.shaped.buffer.layout_runs() {
        if ly < run.line_top || ly >= run.line_top + run.line_height {
            continue;
        }
        for g in run.glyphs {
            if lx >= g.x && lx < g.x + g.w {
                return tb.shaped.meta(g.metadata);
            }
        }
    }
    None
}

/// The character index under (x, y) in a text block (for Para#hit).
pub fn char_at(tb: &TextBox, x: f32, y: f32) -> Option<i64> {
    let (lx, ly) = (x - tb.x, y - tb.y);
    if lx < 0.0 || ly < 0.0 || lx > tb.shaped.width + 1.0 || ly > tb.shaped.height {
        return None;
    }
    let cursor = tb.shaped.buffer.hit(lx, ly)?;
    Some(tb.shaped.char_index(cursor) as i64)
}

/// The character under (x, y) in a text block, as Shoes 3's Para#hit answers it from Pango's
/// xy_to_index (s3t_textblock.c:713-722, ledger F14): the one whose glyph the point is over,
/// the first on its line for a point left of the text, the last for one past the line's end,
/// and the nearest line for a point above or below the lines. None off `bounds`, the block.
pub fn char_under(tb: &TextBox, bounds: crate::layout::Rect, x: f32, y: f32) -> Option<i64> {
    if x < bounds.x || x > bounds.right() || y < bounds.y || y > bounds.bottom() {
        return None;
    }
    let (lx, ly) = (x - tb.x, y - tb.y);
    let runs: Vec<_> = tb.shaped.buffer.layout_runs().collect();
    // Under the last line of text that ends in a newline is the empty line after it.
    if tb.shaped.line_after_end().is_some_and(|(top, _)| ly >= top) {
        return Some(tb.shaped.text().chars().count() as i64);
    }
    let run = runs.iter().find(|r| ly < r.line_top + r.line_height).or(runs.last())?;
    let glyphs: Vec<_> = run.glyphs.iter().filter(|g| g.metadata != crate::text::shape_cache::INDENT_META).collect();
    let start = glyphs.iter().find(|g| lx < g.x + g.w).or(glyphs.last()).map_or(0, |g| g.start);
    Some(tb.shaped.char_index(cosmic_text::Cursor::new(run.line_i, start)) as i64)
}

pub fn chain(doc: &Doc, hit: &Hit) -> Vec<Id> {
    let mut chain = hit.spans.clone();
    if let Some(link) = hit.link.filter(|l| !chain.contains(l)) {
        chain.push(link);
    }
    chain.push(hit.node);
    chain.extend(doc.ancestors(hit.node));
    chain
}

/// The pointer a drawable asks for, if it has a say.
fn cursor_of(node: &crate::doc::Node) -> Option<CursorShape> {
    if let Some(own) = node.props.str("cursor").and_then(CursorShape::parse) {
        return Some(own);
    }
    match node.kind {
        Kind::Link => Some(CursorShape::Hand),
        _ if crate::elements::disabled(node) => None,
        Kind::Button | Kind::Check | Kind::Radio | Kind::ListBox => Some(CursorShape::Hand),
        Kind::EditLine | Kind::EditBox => Some(CursorShape::Text),
        _ => None,
    }
}

/// How a press on a drawable of `kind` is taken, and whether it keeps it (DESIGN 4.3): a link,
/// a button, check or radio, a text field or a list box keeps it; anything else, an image too,
/// only passes it on, to the slots and drawables that listen.
fn press_on(kind: &Kind, on_a_link: bool) -> (PressKind, bool) {
    if on_a_link {
        return (PressKind::Click, true);
    }
    match kind {
        Kind::Button | Kind::Check | Kind::Radio => (PressKind::Click, true),
        // An image's click block is heard like a shape's, through has_click on the press
        // (ledger E8), so it is not also clicked on the release.
        Kind::EditLine | Kind::EditBox => (PressKind::Field, true),
        Kind::ListBox => (PressKind::Plain, true),
        _ => (PressKind::Plain, false),
    }
}

fn api(doc: &Doc, item: Id) -> Option<&str> {
    let node = doc.get(item)?;
    if node.props.truthy("stopped") {
        return None;
    }
    node.props.str("shoes_api_name")
}

impl Runtime {
    /// Items of one api (click, motion, keypress...) with their parent slot's box.
    fn subscriptions(&self, app: Id, name: &str) -> Vec<(Id, crate::layout::LBox)> {
        let Some(layout) = self.views.get(&app).and_then(|v| v.layout.as_ref()) else { return Vec::new() };
        layout
            .subscriptions
            .iter()
            .filter(|&&item| api(&self.doc, item) == Some(name))
            .filter_map(|&item| {
                let parent = self.doc.get(item)?.parent?;
                Some((item, layout.boxes.get(&parent)?.clone()))
            })
            .collect()
    }

    fn inside(b: &crate::layout::LBox, x: f32, y: f32) -> bool {
        b.rect.contains(x, y) && b.clip.is_none_or(|c| c.contains(x, y))
    }

    /// Tells Ruby where the pointer is and whether it is held (the `mouse` builtin). A dialog's
    /// own window is none of the app's business.
    fn send_mouse_state(&mut self, app: Id) {
        let Some(view) = self.views.get(&app).filter(|v| !v.standalone) else { return };
        let (x, y) = view.ui.pointer.unwrap_or((0.0, 0.0));
        let held = (view.ui.buttons & 1 != 0) as i64;
        self.out.send(Outgoing::Mouse { app, state: [held, x.round() as i64, y.round() as i64] });
    }

    fn hit(&mut self, app: Id, x: f32, y: f32) -> Option<Hit> {
        self.ensure_layout(app);
        let layout = self.views.get(&app)?.layout.as_ref()?;
        hit_test(&self.doc, layout, x, y)
    }

    pub fn set_modifiers(&mut self, app: Id, modifiers: Modifiers) {
        if let Some(view) = self.views.get_mut(&app) {
            view.ui.modifiers = modifiers;
        }
    }

    pub fn pointer_move(&mut self, app: Id, x: f32, y: f32) {
        if !self.views.contains_key(&app) {
            return;
        }
        self.ensure_layout(app);
        // A press or release through automation moves the pointer first; where it is already
        // there, that is no motion (a window only reports the pointer when it moves).
        let moved = self.views.get(&app).is_some_and(|v| v.ui.pointer != Some((x, y)));
        if let Some(view) = self.views.get_mut(&app) {
            view.ui.pointer = Some((x, y));
        }
        self.send_mouse_state(app);
        if self.modal_pointer(app, x, y, crate::dialogs::PointerPhase::Move) {
            return;
        }
        let view = self.views.get_mut(&app).expect("view");
        if let Some(popup) = view.ui.popup.as_mut() {
            if let Some(i) = popup.item_at(x, y) {
                if popup.hovered != Some(i) {
                    popup.hovered = Some(i);
                    self.request_redraw(app);
                }
            }
            return;
        }
        if let Some(press) = view.ui.pressed.clone().filter(|p| p.kind == PressKind::Field) {
            if let Some(field) = view.ui.fields.get_mut(&press.target) {
                field.drag(&mut self.text.fonts.system, x, y);
                self.request_redraw(app);
            }
        }
        let hit = self.hit(app, x, y);
        self.update_hover(app, hit, x, y, moved);
    }

    /// Hover transitions for drawables and slot items. `moved`: the pointer
    /// itself moved (a scroll moves the page under it instead), so motion fires.
    fn update_hover(&mut self, app: Id, hit: Option<Hit>, x: f32, y: f32, moved: bool) {
        let new_chain = hit.as_ref().map(|h| chain(&self.doc, h)).unwrap_or_default();
        let link = hit.as_ref().and_then(|h| h.link);
        let view = self.views.get_mut(&app).expect("view");
        let old_chain = std::mem::replace(&mut view.ui.hover_chain, new_chain.clone());
        let link_changed = view.ui.hover_link != link;
        view.ui.hover_link = link;
        for id in old_chain.iter().filter(|id| !new_chain.contains(id)) {
            self.out.event("leave", Some(*id), vec![]);
        }
        for id in new_chain.iter().rev().filter(|id| !old_chain.contains(id)) {
            self.out.event("hover", Some(*id), vec![]);
        }
        let changed = old_chain != new_chain || link_changed;

        let mods = self.views[&app].ui.modifiers;
        for (item, parent) in self.subscriptions(app, "motion") {
            if moved && Self::inside(&parent, x, y) {
                self.out.event("motion", Some(item), vec![json!(x.round() as i64), json!(y.round() as i64), json!(mods.ctrl), json!(mods.shift)]);
            }
        }
        for name in ["hover", "leave"] {
            for (item, parent) in self.subscriptions(app, name) {
                let now = Self::inside(&parent, x, y);
                let ui = &mut self.views.get_mut(&app).expect("view").ui;
                let was = ui.hover_items.contains(&item);
                if now && !was {
                    ui.hover_items.insert(item);
                    if name == "hover" {
                        self.out.event("hover", Some(item), vec![]);
                    }
                } else if !now && was {
                    ui.hover_items.remove(&item);
                    if name == "leave" {
                        self.out.event("leave", Some(item), vec![]);
                    }
                }
            }
        }
        self.update_para_hit(app, hit.as_ref(), x, y);
        if self.update_tooltip(app, &new_chain, x, y) {
            self.request_redraw(app);
        }
        self.refresh_cursor(app);
        if changed {
            self.request_redraw(app);
        }
    }

    /// The tooltip follows the innermost hovered drawable that has one; it keeps its place
    /// while the pointer stays on the same owner. Returns whether it changed.
    fn update_tooltip(&mut self, app: Id, chain: &[Id], x: f32, y: f32) -> bool {
        let wanted = tooltip::owner(&self.doc, chain);
        let delay = self.tooltip_delay();
        let ui = &mut self.views.get_mut(&app).expect("view").ui;
        match (&mut ui.tooltip, wanted) {
            (Some(tip), Some((owner, text))) if tip.owner == owner => {
                let changed = tip.text != text;
                tip.text = text;
                changed
            }
            (slot, Some((owner, text))) => {
                *slot = Some(Tooltip::new(owner, text, (x, y), Instant::now() + delay));
                true
            }
            (slot, None) => slot.take().is_some(),
        }
    }

    /// Headless there is nobody to rest a pointer, so snapshots show the bubble at once.
    fn tooltip_delay(&self) -> Duration {
        if self.opts.headless {
            Duration::ZERO
        } else {
            tooltip::DELAY
        }
    }

    /// The next tooltip a window has to wake up and draw.
    pub fn tooltip_due(&self) -> Option<(Id, Instant)> {
        self.views.iter().filter_map(|(app, v)| Some((*app, v.ui.tooltip.as_ref()?.pending()?))).min_by_key(|(_, due)| *due)
    }

    /// Sets the window's pointer for what it is over now: a drawable's own `cursor` style,
    /// else a hand on links and clickable controls and an I-beam on text fields, else the
    /// App's `cursor` (Shoes 3's `app.cursor = :watch_cursor`), else the arrow.
    pub fn refresh_cursor(&mut self, app: Id) {
        let Some(view) = self.views.get(&app) else { return };
        let over = view.ui.hover_chain.iter().find_map(|id| self.doc.get(*id).and_then(cursor_of));
        let cursor = over
            .or_else(|| self.doc.get(app).and_then(|n| n.props.str("cursor")).and_then(CursorShape::parse))
            .unwrap_or_default();
        let view = self.views.get_mut(&app).expect("view");
        if view.ui.cursor != cursor {
            view.ui.cursor = cursor;
            self.effects.push(Effect::Cursor(app, cursor));
        }
    }

    fn update_para_hit(&mut self, app: Id, hit: Option<&Hit>, x: f32, y: f32) {
        let para = hit.filter(|h| self.doc.get(h.node).is_some_and(|n| n.kind == Kind::Para)).map(|h| h.node);
        let value = para.and_then(|id| {
            let tb = self.views.get(&app)?.layout.as_ref()?.texts.get(&id)?;
            char_at(tb, x, y)
        });
        let view = self.views.get_mut(&app).expect("view");
        let previous = view.ui.hover_para;
        match (previous, para) {
            (Some((old, _)), new) if Some(old) != new => {
                self.out.send(Outgoing::ParaHit { id: old, value: None });
            }
            _ => {}
        }
        if let Some(id) = para {
            if previous != Some((id, value)) {
                self.out.send(Outgoing::ParaHit { id, value });
            }
        }
        self.views.get_mut(&app).expect("view").ui.hover_para = para.map(|id| (id, value));
    }

    pub fn pointer_left(&mut self, app: Id) {
        if !self.views.contains_key(&app) {
            return;
        }
        let view = self.views.get_mut(&app).expect("view");
        view.ui.pointer = None;
        self.update_hover(app, None, -1.0, -1.0, false);
    }

    pub fn pointer_down(&mut self, app: Id, button: u8) {
        let Some((x, y)) = self.views.get(&app).and_then(|v| v.ui.pointer) else { return };
        self.ensure_layout(app);
        self.views.get_mut(&app).expect("view").ui.buttons |= 1 << (button - 1);
        self.send_mouse_state(app);
        if self.modal_pointer(app, x, y, crate::dialogs::PointerPhase::Down) {
            return;
        }
        if self.views[&app].ui.popup.is_some() {
            self.popup_press(app, x, y);
            return;
        }
        let Some(hit) = self.hit(app, x, y) else { return };
        let chain = chain(&self.doc, &hit);
        let kind = match self.doc.get(hit.node) {
            Some(n) if crate::elements::disabled(n) => Kind::Unknown("disabled".into()),
            Some(n) => n.kind.clone(),
            None => Kind::Unknown(String::new()),
        };
        if let Some(tip) = self.views.get_mut(&app).expect("view").ui.tooltip.as_mut() {
            tip.dismissed = true;
        }
        let shift = self.views[&app].ui.modifiers.shift;
        let clicks = self.views.get_mut(&app).expect("view").ui.click_count(x, y);
        let target = hit.link.unwrap_or(hit.node);
        let (press_kind, consumed) = press_on(&kind, hit.link.is_some());
        if hit.link.is_none() {
            match kind {
                Kind::EditLine | Kind::EditBox => self.focus_field_at(app, hit.node, x, y, clicks, shift),
                Kind::ListBox if button == 1 => self.open_popup(app, hit.node),
                _ => {}
            }
        }
        if kind.is_focusable() {
            self.set_focus(app, Some(hit.node));
            self.views.get_mut(&app).expect("view").ui.focus_visible = false;
        } else if !consumed {
            self.set_focus(app, None);
        }
        self.views.get_mut(&app).expect("view").ui.pressed = Some(Press { target, button, kind: press_kind, consumed });
        if !consumed {
            let args = vec![json!(button), json!(x.round() as i64), json!(y.round() as i64)];
            for id in self.listeners(app, &hit, &chain, x, y, "click") {
                self.out.event("click", Some(id), args.clone());
            }
        }
        self.request_redraw(app);
    }

    /// Who hears a press (`api` "click") or release ("release") that no control or link took, in
    /// the order they hear it. First the slots whose `click` blocks run, the window's first, then
    /// inner slots, the topmost of two side by side first; then the drawable with a click block
    /// of its own (pointer_owner). Shoes 3 runs a slot's block as the press walks down the canvas
    /// and the block of the shape it lands on after that (shoes_canvas_send_click2), so a card's
    /// click runs before a backdrop's under it that closes the card.
    pub(crate) fn listeners(&self, app: Id, hit: &Hit, chain: &[Id], x: f32, y: f32, api: &str) -> Vec<Id> {
        let mut slots: Vec<(Vec<usize>, Id)> = self
            .subscriptions(app, api)
            .into_iter()
            .filter(|(_, parent)| Self::inside(parent, x, y))
            .map(|(item, _)| (self.doc.get(item).and_then(|n| n.parent).map(|slot| self.walk_down_to(slot)).unwrap_or_default(), item))
            .collect();
        // Stable, so two blocks on one slot run in the order they were given.
        slots.sort_by(|a, b| a.0.cmp(&b.0));
        let block = if api == "release" { "has_release" } else { "has_click" };
        let owner = self.pointer_owner(app, hit, chain, x, y, block);
        slots.into_iter().map(|(_, item)| item).chain(owner).collect()
    }

    /// The way down to `slot` from the window's root, as a sort key: each step's place among
    /// its siblings counted from the top of the paint order, so a slot sorts after its
    /// ancestors and before a slot drawn under it.
    fn walk_down_to(&self, slot: Id) -> Vec<usize> {
        let mut path = vec![slot];
        path.extend(self.doc.ancestors(slot));
        path.windows(2)
            .rev()
            .map(|pair| {
                let siblings = self.doc.children(pair[1]);
                siblings.len() - siblings.iter().position(|c| *c == pair[0]).unwrap_or(0)
            })
            .collect()
    }

    /// Who hears a press or release that no control took (`block` is `has_click` or
    /// `has_release`): a text fragment under the pointer with a block for it, else the topmost
    /// drawable under the pointer that has one (DESIGN 4.3, ledger E8), so a label or an icon
    /// drawn over a clickable shape passes the press on, as Shoes 3's shoes_canvas_send_click2
    /// skips what has no click block. A control on top keeps the press to itself and its slots.
    /// Last come the ancestors of what was hit, for a drawable that spills out of its slot.
    fn pointer_owner(&self, app: Id, hit: &Hit, chain: &[Id], x: f32, y: f32, block: &str) -> Option<Id> {
        let listens = |id: &Id| self.doc.get(*id).is_some_and(|n| n.props.truthy(block));
        let on_a_control = self.doc.get(hit.node).is_some_and(|n| n.kind.consumes_press());
        let beneath = match self.views.get(&app).and_then(|v| v.layout.as_ref()) {
            Some(layout) if !on_a_control => under(&self.doc, layout, x, y),
            _ => Vec::new(),
        };
        hit.spans.iter().chain(&beneath).chain(chain).copied().find(listens)
    }

    /// Whether a press on `hit` is one a control or link keeps to itself (press_on).
    pub(crate) fn press_consumed(&self, hit: &Hit) -> bool {
        let kind = match self.doc.get(hit.node) {
            Some(n) if crate::elements::disabled(n) => Kind::Unknown("disabled".into()),
            Some(n) => n.kind.clone(),
            None => Kind::Unknown(String::new()),
        };
        press_on(&kind, hit.link.is_some()).1
    }

    pub fn pointer_up(&mut self, app: Id, button: u8) {
        let Some((x, y)) = self.views.get(&app).and_then(|v| v.ui.pointer) else { return };
        self.views.get_mut(&app).expect("view").ui.buttons &= !(1 << (button - 1));
        self.send_mouse_state(app);
        if self.modal_pointer(app, x, y, crate::dialogs::PointerPhase::Up) {
            return;
        }
        let press = self.views.get_mut(&app).expect("view").ui.pressed.take();
        if let Some(p) = press.as_ref().filter(|p| p.kind == PressKind::Field) {
            if let Some(field) = self.views.get_mut(&app).and_then(|v| v.ui.fields.get_mut(&p.target)) {
                field.drop_empty_selection();
            }
        }
        let hit = self.hit(app, x, y);
        let chain = hit.as_ref().map(|h| chain(&self.doc, h)).unwrap_or_default();
        if let Some(press) = &press {
            if press.kind == PressKind::Click && chain.contains(&press.target) {
                self.out.event("click", Some(press.target), vec![]);
                self.follow_link(press.target);
            }
        }
        if !press.as_ref().is_some_and(|p| p.consumed) {
            let args = vec![json!(button), json!(x.round() as i64), json!(y.round() as i64)];
            let listeners = match &hit {
                Some(hit) => self.listeners(app, hit, &chain, x, y, "release"),
                None => Vec::new(),
            };
            for id in listeners {
                self.out.event("release", Some(id), args.clone());
            }
        }
        self.request_redraw(app);
    }

    /// A link with a URL and no block: the display opens it (never when headless).
    pub(crate) fn follow_link(&mut self, id: Id) {
        let Some(node) = self.doc.get(id).filter(|n| n.kind == Kind::Link) else { return };
        if node.props.truthy("has_block") {
            return;
        }
        if let Some(url) = node.props.str("click").filter(|u| u.starts_with("http://") || u.starts_with("https://")) {
            if !self.opts.headless {
                self.effects.push(Effect::OpenUrl(url.to_string()));
            }
        }
    }

    fn focus_field_at(&mut self, app: Id, id: Id, x: f32, y: f32, clicks: u32, extend: bool) {
        let Some(node) = self.doc.get(id) else { return };
        let rect = self.views.get(&app).and_then(|v| v.layout.as_ref()).and_then(|l| l.rect(id));
        let view = self.views.get_mut(&app).expect("view");
        let field = text_field::ensure(&mut view.ui.fields, node, &mut self.text.fonts);
        if let Some(r) = rect {
            let inner = if node.kind == Kind::EditBox {
                crate::elements::edit_box::inner_rect(r)
            } else {
                crate::elements::edit_line::inner_rect(r, field.line_height())
            };
            field.fit(&mut self.text.fonts.system, inner);
        }
        field.press(&mut self.text.fonts.system, x, y, clicks, extend && view.ui.focus == Some(id));
    }

    pub fn set_focus(&mut self, app: Id, id: Option<Id>) {
        let Some(view) = self.views.get_mut(&app) else { return };
        if view.ui.focus != id {
            view.ui.focus = id;
            if let Some(node) = id.and_then(|i| self.doc.get(i)).filter(|n| n.kind.is_text_input()) {
                text_field::ensure(&mut view.ui.fields, node, &mut self.text.fonts);
            }
            self.request_redraw(app);
        }
    }

    pub(crate) fn open_popup(&mut self, app: Id, id: Id) {
        let (Some(node), Some(view)) = (self.doc.get(id), self.views.get_mut(&app)) else { return };
        let Some(anchor) = view.layout.as_ref().and_then(|l| l.rect(id)) else { return };
        if list_box::items(node).is_empty() {
            return;
        }
        view.ui.popup = Some(Popup::open(node, anchor, view.size, &mut self.text));
        self.request_redraw(app);
    }

    fn popup_press(&mut self, app: Id, x: f32, y: f32) {
        let view = self.views.get_mut(&app).expect("view");
        let Some(popup) = view.ui.popup.take() else { return };
        if let Some(i) = popup.item_at(x, y) {
            self.choose(popup.list_box, &popup.items[i]);
        }
        self.request_redraw(app);
    }

    pub(crate) fn choose(&mut self, list_box: Id, item: &str) {
        self.out.event("change", Some(list_box), vec![Value::String(item.to_string())]);
    }

    pub fn wheel(&mut self, app: Id, dy: f32, at: Option<(f32, f32)>) {
        self.ensure_layout(app);
        let Some(view) = self.views.get_mut(&app) else { return };
        let (x, y) = at.or(view.ui.pointer).unwrap_or((0.0, 0.0));
        if let Some(popup) = view.ui.popup.as_mut() {
            popup.scroll_by(dy);
            self.request_redraw(app);
            return;
        }
        let hit = self.hit(app, x, y);
        if let Some(field) = hit.as_ref().and_then(|h| self.views.get_mut(&app).and_then(|v| v.ui.fields.get_mut(&h.node))) {
            if field.scroll_by(dy) {
                self.request_redraw(app);
                return;
            }
        }
        let chain = hit.as_ref().map(|h| chain(&self.doc, h)).unwrap_or_default();
        let view = self.views.get_mut(&app).expect("view");
        let layout = view.layout.as_ref().expect("layout");
        let scroller = chain
            .iter()
            .find(|id| layout.scrollers.get(id).is_some_and(|s| s.max_top() > 0.0 && (dy > 0.0 && s.top < s.max_top() || dy < 0.0 && s.top > 0.0)))
            .and_then(|id| layout.scrollers.get(id).map(|s| (*id, s.top, s.max_top())));
        if let Some((id, top, max)) = scroller {
            let new_top = (top + dy).clamp(0.0, max);
            if new_top != top {
                self.out.send(Outgoing::Scroll { id, top: new_top.round() as i64 });
                self.scroll_slot(app, id, new_top);
            }
        }
        for (item, parent) in self.subscriptions(app, "wheel") {
            if Self::inside(&parent, x, y) {
                self.out.event("wheel", Some(item), vec![json!(-dy), json!(x.round() as i64), json!(y.round() as i64)]);
            }
        }
        if let Some((px, py)) = self.views.get(&app).and_then(|v| v.ui.pointer) {
            let hit = self.hit(app, px, py);
            self.update_hover(app, hit, px, py, false);
        }
    }

    pub fn type_text(&mut self, app: Id, text: &str) {
        for c in text.chars() {
            self.key_input(app, KeyInput::char(c));
        }
    }

    /// The focused text field, if it takes edits.
    fn editable_focus(&self, app: Id) -> Option<Id> {
        let id = self.views.get(&app)?.ui.focus?;
        let node = self.doc.get(id).filter(|n| n.kind.is_text_input())?;
        (!crate::elements::readonly(node) && !crate::elements::disabled(node)).then_some(id)
    }

    /// Text an input method committed (a dead key's accent, a word of Japanese): into the
    /// focused text field as one edit and one `change`, else as typed characters.
    pub fn ime_commit(&mut self, app: Id, text: &str) {
        if !self.views.contains_key(&app) {
            return;
        }
        self.ensure_layout(app);
        let Some(id) = self.editable_focus(app) else {
            let focus_is_a_field = self.views[&app].ui.focus.and_then(|id| self.doc.get(id)).is_some_and(|n| n.kind.is_text_input());
            if !focus_is_a_field {
                self.type_text(app, text);
            }
            return;
        };
        let Some(node) = self.doc.get(id) else { return };
        let view = self.views.get_mut(&app).expect("view");
        let field = text_field::ensure(&mut view.ui.fields, node, &mut self.text.fonts);
        if field.type_in(&mut self.text.fonts.system, text) {
            let text = field.reported();
            self.out.event("change", Some(id), vec![Value::String(text)]);
        }
        self.request_redraw(app);
    }

    /// Where an input method should show its candidates: the caret of the focused text field,
    /// in window coordinates. None when no field that takes text has focus; a secret field
    /// takes keys only, as a Mac's secure text field does.
    pub fn text_input_area(&self, app: Id) -> Option<crate::layout::Rect> {
        let id = self.editable_focus(app)?;
        let view = self.views.get(&app)?;
        if self.doc.get(id).is_some_and(|n| n.props.truthy("secret")) {
            return None;
        }
        view.ui.fields.get(&id).and_then(|f| f.caret()).or_else(|| view.layout.as_ref()?.rect(id))
    }

    pub fn key_input(&mut self, app: Id, key: KeyInput) {
        if !self.views.contains_key(&app) {
            return;
        }
        self.ensure_layout(app);
        // Alt-/ is Shoes' own (manual 2239-2240): it opens the console, and neither a field nor
        // the app hears it, as Shoes 3's shoes_app_keypress runs Shoes.show_log for it first
        // (s3_app.c:773-776, ledger H10). On a Mac it is Cmd-/, named alt_/ (Q5).
        if key.shoes_name().as_deref() == Some(":alt_/") {
            self.out.send(crate::protocol::Outgoing::Console { app });
            return;
        }
        if self.modal_key(app, &key) {
            return;
        }
        if self.popup_key(app, &key) {
            return;
        }
        let focus = self.views[&app].ui.focus.filter(|id| self.doc.get(*id).is_some_and(|n| !crate::elements::disabled(n)));
        let focus_kind = focus.and_then(|id| self.doc.get(id)).map(|n| n.kind.clone());
        let tab = key.key == Key::Named(Named::Tab) && !key.modified();
        // A button, check, radio or list box takes keys only while it shows its focus ring,
        // that is when focus came from the keyboard (tab, or the app's `focus`). One the mouse
        // pressed leaves Space, Return and the arrows to the app, as a Mac's controls do.
        let keyboard_focus = self.views[&app].ui.focus_visible;
        let mut send_keypress = true;
        match (focus, focus_kind) {
            (Some(id), Some(Kind::EditLine)) | (Some(id), Some(Kind::EditBox)) => {
                if tab {
                    self.focus_step(app, key.shift);
                    return;
                }
                let edited = {
                    let view = self.views.get_mut(&app).expect("view");
                    let node = self.doc.get(id).expect("focused node");
                    let locked = crate::elements::readonly(node) || crate::elements::disabled(node);
                    let field = text_field::ensure(&mut view.ui.fields, node, &mut self.text.fonts);
                    let edited = if locked && text_field::edits(&key) {
                        text_field::Edited { handled: true, changed: false }
                    } else {
                        field.key(&mut self.text.fonts.system, &key, &mut self.clipboard)
                    };
                    let text = if edited.changed { field.reported() } else { String::new() };
                    (edited, text)
                };
                if edited.0.changed {
                    self.out.event("change", Some(id), vec![Value::String(edited.1)]);
                }
                // Return in a one-line field runs its `finish` block (Shoes 3.2.15's
                // `edit_line.finish = proc`, ledger G16).
                if self.doc.get(id).is_some_and(|n| n.kind == Kind::EditLine) && key.key == Key::Named(Named::Enter) && !(key.modified() || key.shift) {
                    self.out.event("finish", Some(id), vec![]);
                }
                self.request_redraw(app);
                send_keypress = key.key == Key::Named(Named::Escape) || key.modified();
            }
            (Some(id), Some(Kind::Button)) if keyboard_focus && button::activates(&key) => {
                self.out.event("click", Some(id), vec![]);
                send_keypress = false;
            }
            (Some(id), Some(Kind::Check)) | (Some(id), Some(Kind::Radio)) if keyboard_focus && check::activates(&key) => {
                self.out.event("click", Some(id), vec![]);
                send_keypress = false;
            }
            (Some(id), Some(Kind::ListBox)) if keyboard_focus && matches!(key.key, Key::Named(Named::Up) | Key::Named(Named::Down)) && !key.modified() => {
                if let Some(item) = self.doc.get(id).and_then(|n| list_box::stepped(n, &key)) {
                    self.choose(id, &item);
                }
                send_keypress = false;
            }
            (Some(id), Some(Kind::ListBox)) if keyboard_focus && list_box::opens(&key) => {
                self.open_popup(app, id);
                send_keypress = false;
            }
            _ => {}
        }
        if tab && self.focus_step(app, key.shift) {
            return;
        }
        if send_keypress {
            if let Some(name) = key.shoes_name() {
                for (item, _) in self.subscriptions(app, "keypress") {
                    self.out.event("keypress", Some(item), vec![Value::String(name.clone())]);
                }
            }
        }
    }

    fn popup_key(&mut self, app: Id, key: &KeyInput) -> bool {
        let view = self.views.get_mut(&app).expect("view");
        let Some(popup) = view.ui.popup.as_mut() else { return false };
        match list_box::popup_key(popup, key) {
            PopupKey::Choose(i) => {
                let (id, item) = (popup.list_box, popup.items[i].clone());
                view.ui.popup = None;
                self.choose(id, &item);
            }
            PopupKey::Close => view.ui.popup = None,
            PopupKey::Moved => {}
            PopupKey::Ignored => return true,
        }
        self.request_redraw(app);
        true
    }

    /// Moves focus along the tab order (paint order). Returns false when
    /// nothing can take focus.
    pub fn focus_step(&mut self, app: Id, backwards: bool) -> bool {
        let Some(layout) = self.views.get(&app).and_then(|v| v.layout.as_ref()) else { return false };
        let order: Vec<Id> = layout
            .order
            .iter()
            .copied()
            .filter(|id| self.doc.get(*id).is_some_and(|n| n.kind.is_focusable() && !crate::elements::disabled(n)) && layout.visible_rect(*id).is_some())
            .collect();
        if order.is_empty() {
            return false;
        }
        let current = self.views[&app].ui.focus.and_then(|f| order.iter().position(|id| *id == f));
        let next = match (current, backwards) {
            (None, false) => 0,
            (None, true) => order.len() - 1,
            (Some(i), false) => (i + 1) % order.len(),
            (Some(i), true) => (i + order.len() - 1) % order.len(),
        };
        let id = order[next];
        self.set_focus(app, Some(id));
        self.views.get_mut(&app).expect("view").ui.focus_visible = true;
        if let Some(field) = self.views.get_mut(&app).and_then(|v| v.ui.fields.get_mut(&id)) {
            field.select_all();
        }
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// SCARPE_CLIPBOARD_FILE's stand-in: what another program puts in the file is what a paste
    /// sees, and a copy is in the file for it to read.
    #[test]
    fn a_file_backed_clipboard_reads_and_writes_the_file() {
        let file = std::env::temp_dir().join(format!("scarpe-clipboard-{}.txt", std::process::id()));
        let _ = std::fs::remove_file(&file);
        let mut clipboard = Clipboard::backed_by(file.clone());
        assert_eq!(clipboard.get(), "", "no file yet is an empty clipboard");
        std::fs::write(&file, "from another program ✓").unwrap();
        assert_eq!(clipboard.get(), "from another program ✓");
        clipboard.set("from Shoes".into());
        assert_eq!(std::fs::read_to_string(&file).unwrap(), "from Shoes");
        let _ = std::fs::remove_file(&file);
    }

    #[test]
    fn key_names_follow_the_manual() {
        assert_eq!(KeyInput::char('a').shoes_name().as_deref(), Some("a"));
        assert_eq!(KeyInput::char('\n').shoes_name().as_deref(), Some("\n"));
        assert_eq!(KeyInput::named(Named::Left).shoes_name().as_deref(), Some(":left"));
        assert_eq!(KeyInput::named(Named::F(5)).shoes_name().as_deref(), Some(":f5"));
        let mut k = KeyInput::char('a');
        k.ctrl = true;
        assert_eq!(k.shoes_name().as_deref(), Some(":control_a"));
        let mut k = KeyInput::named(Named::PageUp);
        k.ctrl = true;
        k.shift = true;
        k.alt = true;
        assert_eq!(k.shoes_name().as_deref(), Some(":control_shift_alt_page_up"));
        let mut k = KeyInput::named(Named::Enter);
        k.ctrl = true;
        assert_eq!(k.shoes_name().as_deref(), Some(":control_enter"));
        let mut k = KeyInput::char('&');
        k.shift = true;
        assert_eq!(k.shoes_name().as_deref(), Some("&"));
    }

    /// manual 2223-2227 (spec events.keypress.shift_absorbed*): on a US keyboard Shift-7 is
    /// "&" and Shift-Alt-7 is :alt_&. Shift only shows on the special keys.
    #[test]
    fn shift_folds_into_the_character() {
        let name = |k: &str| KeyInput::parse(k).and_then(|k| k.shoes_name());
        assert_eq!(name(":shift_7").as_deref(), Some("&"));
        assert_eq!(name(":shift_alt_7").as_deref(), Some(":alt_&"));
        assert_eq!(name(":shift_a").as_deref(), Some("A"));
        assert_eq!(name(":control_shift_a").as_deref(), Some(":control_A"));
        assert_eq!(name(":shift_control_alt_page_up").as_deref(), Some(":control_shift_alt_page_up"));
        assert_eq!(name(":shift_f1").as_deref(), Some(":shift_f1"));
        assert_eq!(us_shifted("/"), "?");
    }

    /// Q5 (27 Sep 2026): Command is named alt_, as in Shoes 3 on macOS, and edits like Control.
    #[test]
    fn command_is_alt_by_name_and_control_in_fields() {
        let k = KeyInput::parse(":command_q").unwrap();
        assert_eq!(k.shoes_name().as_deref(), Some(":alt_q"));
        assert!(k.shortcut());
        assert!(!KeyInput::parse(":alt_q").unwrap().shortcut());
    }

    #[test]
    fn parses_shoes_key_names() {
        assert_eq!(KeyInput::parse("left"), Some(KeyInput::named(Named::Left)));
        assert_eq!(KeyInput::parse(":left"), Some(KeyInput::named(Named::Left)));
        assert_eq!(KeyInput::parse("\n"), Some(KeyInput::named(Named::Enter)));
        assert_eq!(KeyInput::parse("a"), Some(KeyInput::char('a')));
        let k = KeyInput::parse(":control_a").unwrap();
        assert!(k.ctrl && k.key == Key::Char("a".into()) && k.text.is_none());
        let k = KeyInput::parse("shift_tab").unwrap();
        assert!(k.shift && k.key == Key::Named(Named::Tab));
        assert_eq!(KeyInput::parse("f12"), Some(KeyInput::named(Named::F(12))));
        assert_eq!(KeyInput::parse("nonsense"), None);
    }
}
