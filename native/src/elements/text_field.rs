//! The editing core shared by edit_line and edit_box: a cosmic-text Editor
//! plus the things it leaves to us (selection on shift, clipboard, secret
//! masking, undo and redo, keeping the caret in view).

use crate::input::{Clipboard, Key, KeyInput, Named};
use crate::layout::Rect;
use crate::paint::text::{caret_position, selection_rects};
use crate::style::Color;
use crate::text::FamilyName;
use cosmic_text::{Action, Attrs, Buffer, Cursor, Edit, Editor, FontSystem, Metrics, Motion, Selection, Shaping, Style, Weight, Wrap};
use std::collections::VecDeque;

pub const BULLET: char = '\u{2022}';

/// Undo steps a field keeps.
const MAX_UNDO: usize = 200;

/// Changes a field remembers while it waits for Lacci's echoes of them.
const MAX_UNECHOED: usize = 64;

/// What an edit did, for undo: a run of typing, or of deleting, undoes as one step, as in a
/// Mac or GTK text field. A paste, a cut or a caret move ends the run.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EditKind {
    Typing,
    Deleting,
    Other,
}

/// A state a field can go back to.
#[derive(Clone, Debug, PartialEq)]
struct Snapshot {
    text: String,
    cursor: Cursor,
    selection: Selection,
}

/// Undo and redo: Cmd-Z and Cmd-Shift-Z (`:alt_z` by Shoes' name, Q5), Control-Z,
/// Control-Shift-Z and Control-Y elsewhere.
#[derive(Default)]
struct History {
    undo: Vec<Snapshot>,
    redo: Vec<Snapshot>,
    /// The kind of the last edit while the next one of the same kind can still join it.
    run: Option<EditKind>,
}

impl History {
    /// `before` is the state an edit of `kind` just changed.
    fn record(&mut self, before: Snapshot, kind: EditKind) {
        self.redo.clear();
        if kind != EditKind::Other && self.run == Some(kind) {
            return;
        }
        if self.undo.len() == MAX_UNDO {
            self.undo.remove(0);
        }
        self.undo.push(before);
        self.run = Some(kind);
    }

    fn end_run(&mut self) {
        self.run = None;
    }
}

pub struct TextField {
    pub editor: Editor<'static>,
    pub multiline: bool,
    pub secret: bool,
    /// How far the text is scrolled inside the field, to keep the caret visible.
    pub offset: (f32, f32),
    /// The text area in window coordinates, as last painted.
    pub inner: Rect,
    pub size: f32,
    pub color: Color,
    face: Face,
    bullet_w: f32,
    history: History,
    /// Texts sent in `change` events that Lacci has not echoed back yet. Echoes can trail
    /// the keys (a `type` request types a whole word before Ruby sees its first change), so
    /// an older one must not be mistaken for text the app set.
    unechoed: VecDeque<String>,
}

/// The face a field's text is set in: a family, and the weight and slant its `font:` names
/// ("bold 16px", "Georgia italic"), as a para with the same string would draw them.
#[derive(Clone, Debug, PartialEq)]
pub struct Face {
    pub family: FamilyName,
    pub weight: u16,
    pub italic: bool,
}

impl Face {
    pub fn plain(family: FamilyName) -> Face {
        Face { family, weight: 400, italic: false }
    }

    fn attrs(&self) -> Attrs<'_> {
        let style = if self.italic { Style::Italic } else { Style::Normal };
        Attrs::new().family(self.family.as_family()).weight(Weight(self.weight)).style(style)
    }
}

/// What a key did to a field.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Edited {
    pub handled: bool,
    pub changed: bool,
}

impl TextField {
    pub fn new(fs: &mut FontSystem, text: &str, multiline: bool, secret: bool, face: Face, size: f32, color: Color) -> Self {
        let mut buffer = Buffer::new(fs, Metrics::new(size, line_height(size)));
        buffer.set_wrap(if multiline { Wrap::WordOrGlyph } else { Wrap::None });
        buffer.set_size(None, None);
        buffer.set_text(text, &face.attrs().color(color.to_cosmic()), Shaping::Advanced, None);
        let mut bullet = Buffer::new(fs, Metrics::new(size, line_height(size)));
        bullet.set_text(&BULLET.to_string(), &face.attrs(), Shaping::Advanced, None);
        bullet.shape_until_scroll(fs, false);
        let bullet_w = bullet.layout_runs().map(|r| r.line_w).fold(0.0, f32::max).max(size * 0.5);
        let mut field = TextField {
            editor: Editor::new(buffer),
            multiline,
            secret,
            offset: (0.0, 0.0),
            inner: Rect::default(),
            size,
            color,
            face,
            bullet_w,
            history: History::default(),
            unechoed: VecDeque::new(),
        };
        field.move_to_end();
        field.editor.shape_as_needed(fs, false);
        field
    }

    pub fn line_height(&self) -> f32 {
        line_height(self.size)
    }

    pub fn editor_buffer<R>(&self, f: impl FnOnce(&Buffer) -> R) -> R {
        self.editor.with_buffer(f)
    }

    pub fn text(&self) -> String {
        self.editor.with_buffer(|b| b.lines.iter().map(|l| l.text()).collect::<Vec<_>>().join("\n"))
    }

    /// The text after an edit, remembered as sent in a `change` event, so its echo is known.
    pub fn reported(&mut self) -> String {
        let text = self.text();
        if self.unechoed.len() == MAX_UNECHOED {
            self.unechoed.pop_front();
        }
        self.unechoed.push_back(text.clone());
        text
    }

    /// Applies text from Lacci. Its echo of our own edit, however late, is a no-op, so the caret
    /// and the undo history stay; text the app sets itself starts a new history, as a
    /// browser's field does.
    pub fn set_text(&mut self, fs: &mut FontSystem, text: &str) {
        if let Some(echoed) = self.unechoed.iter().position(|sent| sent == text) {
            self.unechoed.drain(..=echoed);
            return;
        }
        if self.text() == text {
            return;
        }
        self.unechoed.clear();
        self.replace_text(text);
        self.editor.set_selection(Selection::None);
        self.move_to_end();
        self.editor.shape_as_needed(fs, false);
        self.scroll_to_caret();
        self.history = History::default();
    }

    fn replace_text(&mut self, text: &str) {
        let attrs = self.face.attrs().color(self.color.to_cosmic());
        self.editor.with_buffer_mut(|b| b.set_text(text, &attrs, Shaping::Advanced, None));
    }

    fn snapshot(&self) -> Snapshot {
        Snapshot { text: self.text(), cursor: self.editor.cursor(), selection: self.editor.selection() }
    }

    fn restore(&mut self, fs: &mut FontSystem, state: Snapshot) {
        self.replace_text(&state.text);
        self.editor.set_cursor(state.cursor);
        self.editor.set_selection(state.selection);
        self.editor.shape_as_needed(fs, false);
        self.scroll_to_caret();
    }

    /// Goes back one step. False when there is nothing to undo.
    pub fn undo(&mut self, fs: &mut FontSystem) -> bool {
        let Some(previous) = self.history.undo.pop() else { return false };
        self.history.redo.push(self.snapshot());
        self.history.end_run();
        self.restore(fs, previous);
        true
    }

    /// Goes forward again after an undo. False when there is nothing to redo.
    pub fn redo(&mut self, fs: &mut FontSystem) -> bool {
        let Some(next) = self.history.redo.pop() else { return false };
        self.history.undo.push(self.snapshot());
        self.history.end_run();
        self.restore(fs, next);
        true
    }

    /// Runs an edit of `kind`, and remembers the state before it when it changed the text.
    fn edit(&mut self, kind: EditKind, change: impl FnOnce(&mut Self) -> bool) -> bool {
        let before = self.snapshot();
        let reported = change(self);
        let changed = self.text() != before.text;
        if changed {
            self.history.record(before, kind);
        }
        reported && changed
    }

    /// Text typed or committed by an input method, over the selection, as one undo step
    /// with the typing around it.
    pub fn type_in(&mut self, fs: &mut FontSystem, text: &str) -> bool {
        self.edit(EditKind::Typing, |field| field.insert(fs, text))
    }

    fn move_to_end(&mut self) {
        let end = self.editor.with_buffer(|b| {
            let last = b.lines.len().saturating_sub(1);
            Cursor::new(last, b.lines.get(last).map(|l| l.text().len()).unwrap_or(0))
        });
        self.editor.set_cursor(end);
    }

    /// Lays the text out for a text area at `inner` (window coordinates).
    pub fn fit(&mut self, fs: &mut FontSystem, inner: Rect) {
        self.inner = inner;
        let width = self.multiline.then_some(inner.w.max(1.0));
        self.editor.with_buffer_mut(|b| {
            if b.size().0 != width {
                b.set_size(width, None);
            }
        });
        self.editor.shape_as_needed(fs, false);
        self.clamp_offset();
    }

    /// Keeps the scroll offset inside the text, without chasing the caret
    /// (the wheel may have scrolled away from it).
    fn clamp_offset(&mut self) {
        let (cw, ch) = self.content_size();
        self.offset.0 = self.offset.0.clamp(0.0, (cw - (self.inner.w - 2.0)).max(0.0));
        self.offset.1 = self.offset.1.clamp(0.0, (ch - self.inner.h).max(0.0));
    }

    fn local(&self, x: f32, y: f32) -> (f32, f32) {
        (x - self.inner.x + self.offset.0, y - self.inner.y + self.offset.1)
    }

    /// A press in the field: click places the caret, a double click selects a
    /// word, a triple click the line, shift extends the selection.
    pub fn press(&mut self, fs: &mut FontSystem, x: f32, y: f32, clicks: u32, extend: bool) {
        self.history.end_run();
        let (lx, ly) = self.local(x, y);
        if self.secret {
            let cursor = self.secret_cursor(lx);
            if extend {
                self.anchor_selection();
            } else {
                self.editor.set_selection(if clicks >= 2 { Selection::Normal(Cursor::new(0, 0)) } else { Selection::None });
            }
            self.editor.set_cursor(if clicks >= 2 && !extend { self.end_cursor() } else { cursor });
            return;
        }
        if extend {
            self.anchor_selection();
            self.editor.action(fs, Action::Drag { x: lx as i32, y: ly as i32 });
            return;
        }
        match clicks {
            1 => {
                self.editor.set_selection(Selection::None);
                self.editor.action(fs, Action::Click { x: lx as i32, y: ly as i32 });
            }
            2 => self.editor.action(fs, Action::DoubleClick { x: lx as i32, y: ly as i32 }),
            _ => self.editor.action(fs, Action::TripleClick { x: lx as i32, y: ly as i32 }),
        }
        self.scroll_to_caret();
    }

    pub fn drag(&mut self, fs: &mut FontSystem, x: f32, y: f32) {
        let (lx, ly) = self.local(x, y);
        if self.secret {
            self.anchor_selection();
            let cursor = self.secret_cursor(lx);
            self.editor.set_cursor(cursor);
            return;
        }
        self.anchor_selection();
        self.editor.action(fs, Action::Drag { x: lx as i32, y: ly as i32 });
        self.scroll_to_caret();
    }

    /// A click that did not drag leaves no selection behind.
    pub fn drop_empty_selection(&mut self) {
        if self.editor.selection_bounds().is_some_and(|(a, b)| a == b) {
            self.editor.set_selection(Selection::None);
        }
    }

    fn has_selection(&self) -> bool {
        self.editor.selection_bounds().is_some_and(|(a, b)| a != b)
    }

    fn anchor_selection(&mut self) {
        if self.editor.selection() == Selection::None {
            self.editor.set_selection(Selection::Normal(self.editor.cursor()));
        }
    }

    fn end_cursor(&self) -> Cursor {
        self.editor.with_buffer(|b| {
            let last = b.lines.len().saturating_sub(1);
            Cursor::new(last, b.lines.get(last).map(|l| l.text().len()).unwrap_or(0))
        })
    }

    fn secret_cursor(&self, lx: f32) -> Cursor {
        let chars = self.text().chars().count();
        self.cursor_at_char(((lx / self.bullet_w).round().max(0.0) as usize).min(chars))
    }

    /// How many characters of `text()` come before `cursor`, the newlines between lines
    /// included (a single-line field can still be given text with a newline in it).
    fn chars_before(&self, cursor: Cursor) -> usize {
        self.editor.with_buffer(|b| {
            let earlier: usize = b.lines.iter().take(cursor.line).map(|l| l.text().chars().count() + 1).sum();
            let line = b.lines.get(cursor.line).map(|l| l.text()).unwrap_or("");
            let mut end = cursor.index.min(line.len());
            while !line.is_char_boundary(end) {
                end -= 1;
            }
            earlier + line[..end].chars().count()
        })
    }

    /// The buffer position of the `index`th character of `text()`.
    fn cursor_at_char(&self, index: usize) -> Cursor {
        self.editor.with_buffer(|b| {
            let mut remaining = index;
            for (i, line) in b.lines.iter().enumerate() {
                let text = line.text();
                let chars = text.chars().count();
                if remaining <= chars {
                    return Cursor::new(i, text.char_indices().nth(remaining).map(|(byte, _)| byte).unwrap_or(text.len()));
                }
                remaining -= chars + 1;
            }
            let last = b.lines.len().saturating_sub(1);
            Cursor::new(last, b.lines.get(last).map(|l| l.text().len()).unwrap_or(0))
        })
    }

    pub fn select_all(&mut self) {
        self.history.end_run();
        self.editor.set_selection(Selection::Normal(Cursor::new(0, 0)));
        let end = self.end_cursor();
        self.editor.set_cursor(end);
    }

    /// Inserts typed or pasted text over the selection. Single-line fields
    /// keep only the first line.
    pub fn insert(&mut self, fs: &mut FontSystem, text: &str) -> bool {
        let text = if self.multiline { text.to_string() } else { text.lines().next().unwrap_or("").to_string() };
        self.drop_empty_selection();
        let removed = self.editor.delete_selection();
        if text.is_empty() {
            return removed;
        }
        self.editor.insert_string(&text, None);
        self.editor.shape_as_needed(fs, false);
        self.scroll_to_caret();
        true
    }

    pub fn key(&mut self, fs: &mut FontSystem, key: &KeyInput, clipboard: &mut Clipboard) -> Edited {
        let done = |changed: bool| Edited { handled: true, changed };
        let result = match &key.key {
            Key::Named(named) => match named {
                Named::Left | Named::Right | Named::Up | Named::Down | Named::Home | Named::End | Named::PageUp | Named::PageDown => {
                    self.history.end_run();
                    self.motion(fs, *named, key);
                    done(false)
                }
                Named::Backspace | Named::Delete => done(self.edit(EditKind::Deleting, |field| field.delete(fs, *named, key.alt))),
                Named::Enter if self.multiline => done(self.type_in(fs, "\n")),
                Named::Escape => {
                    self.editor.set_selection(Selection::None);
                    done(false)
                }
                _ => Edited::default(),
            },
            // Shift is folded into the character: Cmd-Shift-Z arrives as "Z".
            Key::Char(c) if key.shortcut() && c == "z" => done(self.undo(fs)),
            Key::Char(c) if key.shortcut() && c == "Z" || key.ctrl && c.eq_ignore_ascii_case("y") => done(self.redo(fs)),
            Key::Char(c) if key.shortcut() => match c.to_lowercase().as_str() {
                "a" => {
                    self.select_all();
                    done(false)
                }
                "c" => {
                    if let Some(s) = self.copyable() {
                        clipboard.set(s);
                    }
                    done(false)
                }
                // A secret field neither copies nor cuts, like a Mac's secure text field: a cut
                // would throw the text away without putting it anywhere.
                "x" => match self.copyable() {
                    Some(s) => {
                        clipboard.set(s);
                        done(self.edit(EditKind::Other, |field| field.editor.delete_selection()))
                    }
                    None => done(false),
                },
                "v" => {
                    let pasted = clipboard.get();
                    done(self.edit(EditKind::Other, |field| field.insert(fs, &pasted)))
                }
                _ => Edited::default(),
            },
            Key::Char(c) => {
                let typed = key.text.clone().unwrap_or_else(|| c.clone());
                if typed.chars().all(|ch| !ch.is_control()) && !typed.is_empty() {
                    done(self.type_in(fs, &typed))
                } else {
                    Edited::default()
                }
            }
        };
        self.editor.shape_as_needed(fs, false);
        self.scroll_to_caret();
        result
    }

    /// Backspace or Delete: the selection, else the character (or with Option, the word)
    /// before or after the caret.
    fn delete(&mut self, fs: &mut FontSystem, named: Named, by_word: bool) -> bool {
        self.drop_empty_selection();
        if !self.has_selection() && by_word {
            self.anchor_selection();
            let word = if named == Named::Backspace { Motion::LeftWord } else { Motion::RightWord };
            self.editor.action(fs, Action::Motion(word));
        }
        if !self.editor.delete_selection() {
            self.editor.action(fs, if named == Named::Backspace { Action::Backspace } else { Action::Delete });
        }
        self.editor.set_selection(Selection::None);
        true
    }

    fn copyable(&self) -> Option<String> {
        if self.secret {
            return None;
        }
        self.editor.copy_selection().filter(|s| !s.is_empty())
    }

    fn motion(&mut self, fs: &mut FontSystem, named: Named, key: &KeyInput) {
        let motion = match named {
            Named::Left if key.shortcut() => Motion::Home,
            Named::Left if key.alt => Motion::LeftWord,
            Named::Left => Motion::Left,
            Named::Right if key.shortcut() => Motion::End,
            Named::Right if key.alt => Motion::RightWord,
            Named::Right => Motion::Right,
            Named::Up if !self.multiline => Motion::Home,
            Named::Up if key.shortcut() => Motion::BufferStart,
            Named::Up => Motion::Up,
            Named::Down if !self.multiline => Motion::End,
            Named::Down if key.shortcut() => Motion::BufferEnd,
            Named::Down => Motion::Down,
            Named::Home if key.shortcut() => Motion::BufferStart,
            Named::Home => Motion::Home,
            Named::End if key.shortcut() => Motion::BufferEnd,
            Named::End => Motion::End,
            Named::PageUp if self.multiline => Motion::PageUp,
            Named::PageUp => Motion::Home,
            Named::PageDown if self.multiline => Motion::PageDown,
            _ => Motion::End,
        };
        if key.shift {
            self.anchor_selection();
            self.editor.action(fs, Action::Motion(motion));
            return;
        }
        // Without shift, Left/Right first collapse a selection to its edge.
        self.drop_empty_selection();
        if let Some((start, end)) = self.editor.selection_bounds() {
            self.editor.set_selection(Selection::None);
            if matches!(motion, Motion::Left | Motion::Right) {
                self.editor.set_cursor(if motion == Motion::Left { start } else { end });
                return;
            }
        }
        self.editor.action(fs, Action::Motion(motion));
    }

    /// Caret (x, top, height) in the buffer's own coordinates.
    fn caret_local(&self) -> Option<(f32, f32, f32)> {
        let cursor = self.editor.cursor();
        if self.secret {
            return Some((self.chars_before(cursor) as f32 * self.bullet_w, 0.0, self.line_height()));
        }
        self.editor.with_buffer(|b| caret_position(b, cursor))
    }

    /// The caret in window coordinates.
    pub fn caret(&self) -> Option<Rect> {
        let (x, top, h) = self.caret_local()?;
        Some(Rect::new(self.inner.x + x - self.offset.0, self.inner.y + top - self.offset.1, 1.0, h))
    }

    /// Selection rectangles in window coordinates.
    pub fn selection(&self) -> Vec<Rect> {
        let Some((start, end)) = self.editor.selection_bounds() else { return Vec::new() };
        let shift = |r: Rect| r.translate(self.inner.x - self.offset.0, self.inner.y - self.offset.1);
        if self.secret {
            let (a, b) = (self.chars_before(start) as f32 * self.bullet_w, self.chars_before(end) as f32 * self.bullet_w);
            return vec![shift(Rect::new(a, 0.0, b - a, self.line_height()))];
        }
        self.editor.with_buffer(|b| selection_rects(b, start, end)).into_iter().map(shift).collect()
    }

    pub fn content_size(&self) -> (f32, f32) {
        if self.secret {
            return (self.text().chars().count() as f32 * self.bullet_w, self.line_height());
        }
        self.editor.with_buffer(|b| {
            let mut w = 0.0f32;
            let mut h = 0.0f32;
            for run in b.layout_runs() {
                w = w.max(run.line_w);
                h = h.max(run.line_top + run.line_height);
            }
            (w, h.max(line_height(self.size)))
        })
    }

    pub fn scroll_to_caret(&mut self) {
        let Some((x, top, h)) = self.caret_local() else { return };
        let (cw, ch) = self.content_size();
        if self.multiline {
            if top - self.offset.1 < 0.0 {
                self.offset.1 = top;
            } else if top + h - self.offset.1 > self.inner.h {
                self.offset.1 = top + h - self.inner.h;
            }
            self.offset.1 = self.offset.1.clamp(0.0, (ch - self.inner.h).max(0.0));
        } else {
            let room = (self.inner.w - 2.0).max(1.0);
            if x - self.offset.0 > room {
                self.offset.0 = x - room;
            } else if x - self.offset.0 < 0.0 {
                self.offset.0 = x;
            }
            self.offset.0 = self.offset.0.clamp(0.0, (cw - room).max(0.0));
        }
    }

    /// Scrolls a multi-line field's text by `dy`. False when it cannot move
    /// that way, so the wheel goes on to the page.
    pub fn scroll_by(&mut self, dy: f32) -> bool {
        if !self.multiline {
            return false;
        }
        let max = (self.content_size().1 - self.inner.h).max(0.0);
        let top = (self.offset.1 + dy).clamp(0.0, max);
        let moved = top != self.offset.1;
        self.offset.1 = top;
        moved
    }

    /// The masked text a secret field shows.
    pub fn bullets(&self) -> String {
        std::iter::repeat_n(BULLET, self.text().chars().count()).collect()
    }
}

/// Keys that would change a field's text (refused when it is readonly).
pub fn edits(key: &KeyInput) -> bool {
    match &key.key {
        Key::Named(Named::Backspace) | Key::Named(Named::Delete) | Key::Named(Named::Enter) => true,
        Key::Char(c) if key.shortcut() => matches!(c.to_lowercase().as_str(), "x" | "v" | "z" | "y"),
        Key::Char(_) => !key.alt,
        _ => false,
    }
}

pub fn line_height(size: f32) -> f32 {
    (size * 1.3).round()
}

/// The field for an edit_line/edit_box node, created from its props on first use.
pub fn ensure<'v>(
    fields: &'v mut std::collections::HashMap<crate::props::Id, TextField>,
    node: &crate::doc::Node,
    fonts: &mut crate::text::Fonts,
) -> &'v mut TextField {
    fields.entry(node.id).or_insert_with(|| {
        let p = &node.props;
        let mut face = Face::plain(FamilyName::Sans);
        let mut size = super::CONTROL_TEXT_SIZE;
        if let Some(font) = p.str("font") {
            let spec = crate::style::font::parse_font(font);
            if let Some(f) = spec.family {
                face.family = fonts.resolve_family(&f);
            }
            face.weight = spec.weight.unwrap_or(face.weight);
            face.italic = spec.italic;
            if let Some(s) = spec.size {
                size = s;
            }
        }
        let color = p.color("stroke").filter(|c| !c.is_invisible()).unwrap_or(crate::text::rich::INK);
        let multiline = node.kind == crate::doc::Kind::EditBox;
        let text = p.text("text").unwrap_or_default();
        TextField::new(&mut fonts.system, &text, multiline, p.truthy("secret"), face, size, color)
    })
}
