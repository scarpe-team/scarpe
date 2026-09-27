//! The editing core shared by edit_line and edit_box: a cosmic-text Editor
//! plus the things it leaves to us (selection on shift, clipboard, secret
//! masking, keeping the caret in view).

use crate::input::{Clipboard, Key, KeyInput, Named};
use crate::layout::Rect;
use crate::paint::text::{caret_position, selection_rects};
use crate::style::Color;
use crate::text::FamilyName;
use cosmic_text::{Action, Attrs, Buffer, Cursor, Edit, Editor, FontSystem, Metrics, Motion, Selection, Shaping, Wrap};

pub const BULLET: char = '\u{2022}';

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
    family: FamilyName,
    bullet_w: f32,
}

/// What a key did to a field.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Edited {
    pub handled: bool,
    pub changed: bool,
}

impl TextField {
    pub fn new(fs: &mut FontSystem, text: &str, multiline: bool, secret: bool, family: FamilyName, size: f32, color: Color) -> Self {
        let mut buffer = Buffer::new(fs, Metrics::new(size, line_height(size)));
        buffer.set_wrap(if multiline { Wrap::WordOrGlyph } else { Wrap::None });
        buffer.set_size(None, None);
        buffer.set_text(text, &Attrs::new().family(family.as_family()).color(color.to_cosmic()), Shaping::Advanced, None);
        let mut bullet = Buffer::new(fs, Metrics::new(size, line_height(size)));
        bullet.set_text(&BULLET.to_string(), &Attrs::new().family(family.as_family()), Shaping::Advanced, None);
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
            family,
            bullet_w,
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

    /// Applies text from Lacci. Its echo of our own edit is a no-op, so the caret stays.
    pub fn set_text(&mut self, fs: &mut FontSystem, text: &str) {
        if self.text() == text {
            return;
        }
        let attrs = Attrs::new().family(self.family.as_family()).color(self.color.to_cosmic());
        self.editor.with_buffer_mut(|b| b.set_text(text, &attrs, Shaping::Advanced, None));
        self.editor.set_selection(Selection::None);
        self.move_to_end();
        self.editor.shape_as_needed(fs, false);
        self.scroll_to_caret();
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
        let text = self.text();
        let chars = text.chars().count();
        let index = ((lx / self.bullet_w).round().max(0.0) as usize).min(chars);
        let byte = text.char_indices().nth(index).map(|(b, _)| b).unwrap_or(text.len());
        Cursor::new(0, byte)
    }

    pub fn select_all(&mut self) {
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
                    self.motion(fs, *named, key);
                    done(false)
                }
                Named::Backspace | Named::Delete => {
                    self.drop_empty_selection();
                    if !self.has_selection() && key.alt {
                        self.anchor_selection();
                        let word = if *named == Named::Backspace { Motion::LeftWord } else { Motion::RightWord };
                        self.editor.action(fs, Action::Motion(word));
                    }
                    let changed = if self.editor.delete_selection() {
                        true
                    } else {
                        let before = self.text();
                        self.editor.action(fs, if *named == Named::Backspace { Action::Backspace } else { Action::Delete });
                        self.text() != before
                    };
                    self.editor.set_selection(Selection::None);
                    done(changed)
                }
                Named::Enter if self.multiline => done(self.insert(fs, "\n")),
                Named::Escape => {
                    self.editor.set_selection(Selection::None);
                    done(false)
                }
                _ => Edited::default(),
            },
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
                "x" => {
                    if let Some(s) = self.copyable() {
                        clipboard.set(s);
                    }
                    done(self.has_selection() && self.editor.delete_selection())
                }
                "v" => {
                    let pasted = clipboard.get();
                    done(self.insert(fs, &pasted))
                }
                _ => Edited::default(),
            },
            Key::Char(c) => {
                let typed = key.text.clone().unwrap_or_else(|| c.clone());
                if typed.chars().all(|ch| !ch.is_control()) && !typed.is_empty() {
                    done(self.insert(fs, &typed))
                } else {
                    Edited::default()
                }
            }
        };
        self.editor.shape_as_needed(fs, false);
        self.scroll_to_caret();
        result
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
            let chars = self.editor.with_buffer(|b| b.lines.first().map(|l| l.text()[..cursor.index.min(l.text().len())].chars().count()).unwrap_or(0));
            return Some((chars as f32 * self.bullet_w, 0.0, self.line_height()));
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
            let text = self.text();
            let chars_to = |c: Cursor| text[..c.index.min(text.len())].chars().count() as f32;
            let (a, b) = (chars_to(start) * self.bullet_w, chars_to(end) * self.bullet_w);
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
        Key::Char(c) if key.shortcut() => matches!(c.to_lowercase().as_str(), "x" | "v"),
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
        let mut family = FamilyName::Sans;
        let mut size = super::CONTROL_TEXT_SIZE;
        if let Some(font) = p.str("font") {
            let spec = crate::style::font::parse_font(font);
            if let Some(f) = spec.family {
                family = fonts.resolve_family(&f);
            }
            if let Some(s) = spec.size {
                size = s;
            }
        }
        let color = p.color("stroke").filter(|c| !c.is_invisible()).unwrap_or(crate::text::rich::INK);
        let multiline = node.kind == crate::doc::Kind::EditBox;
        let text = p.text("text").unwrap_or_default();
        TextField::new(&mut fonts.system, &text, multiline, p.truthy("secret"), family, size, color)
    })
}
