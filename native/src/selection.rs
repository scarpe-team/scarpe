//! Read-only rich paragraph selection. Cosmic-text handles bidi, grapheme and word boundaries.
use crate::doc::{Kind, Node};
use crate::input::{Clipboard, Key, KeyInput, Named};
use crate::layout::TextBox;
use crate::props::Id;
use crate::text::ShapedText;
use cosmic_text::{Action, Edit, Editor, Motion, Selection};

/// Only paragraphs that opt in participate; disabled text keeps normal event routing.
pub fn selectable(node: &Node) -> bool {
    node.kind == Kind::Para && node.props.truthy("selectable") && !crate::elements::disabled(node)
}

pub struct ParagraphSelection {
    pub id: Id,
    shaped: ShapedText,
    editor: Editor<'static>,
}

impl ParagraphSelection {
    pub fn new(id: Id, tb: &TextBox) -> Self {
        Self { id, shaped: tb.shaped.clone(), editor: Editor::new((*tb.shaped.buffer).clone()) }
    }

    pub fn sync(&mut self, tb: &TextBox) {
        if std::rc::Rc::ptr_eq(&self.shaped.buffer, &tb.shaped.buffer) {
            return;
        }
        let same_text = self.shaped.text() == tb.shaped.text();
        let (cursor, selection) = (self.editor.cursor(), self.editor.selection());
        self.editor = Editor::new((*tb.shaped.buffer).clone());
        if same_text {
            self.editor.set_cursor(cursor);
            self.editor.set_selection(selection);
        }
        self.shaped = tb.shaped.clone();
    }

    pub fn cursor(&self) -> cosmic_text::Cursor {
        self.editor.cursor()
    }

    pub fn bounds(&self) -> Option<(cosmic_text::Cursor, cosmic_text::Cursor)> {
        self.editor.selection_bounds().filter(|(a, b)| a != b)
    }

    pub fn text(&self) -> Option<String> {
        self.bounds().map(|(a, b)| {
            let (start, end) = (self.shaped.char_index(a), self.shaped.char_index(b));
            self.shaped.text().chars().skip(start).take(end - start).collect()
        })
    }

    pub fn press(&mut self, fs: &mut cosmic_text::FontSystem, tb: &TextBox, x: f32, y: f32, clicks: u32, extend: bool) {
        self.sync(tb);
        let (x, y) = ((x - tb.x) as i32, (y - tb.y) as i32);
        if extend {
            self.anchor();
            self.editor.action(fs, Action::Drag { x, y });
        } else {
            self.editor.set_selection(Selection::None);
            self.editor.action(
                fs,
                match clicks {
                    1 => Action::Click { x, y },
                    2 => Action::DoubleClick { x, y },
                    _ => Action::TripleClick { x, y },
                },
            );
        }
    }

    pub fn drag(&mut self, fs: &mut cosmic_text::FontSystem, tb: &TextBox, x: f32, y: f32) {
        self.sync(tb);
        self.anchor();
        self.editor.action(fs, Action::Drag { x: (x - tb.x) as i32, y: (y - tb.y) as i32 });
    }

    fn anchor(&mut self) {
        if self.editor.selection() == Selection::None {
            self.editor.set_selection(Selection::Normal(self.editor.cursor()));
        }
    }

    pub fn key(&mut self, fs: &mut cosmic_text::FontSystem, key: &KeyInput, clipboard: &mut Clipboard) -> bool {
        if key.shortcut() {
            if let Key::Char(c) = &key.key {
                match c.to_ascii_lowercase().as_str() {
                    "c" => {
                        if let Some(text) = self.text() {
                            clipboard.set(text);
                        }
                        return true;
                    }
                    "a" => {
                        self.editor.set_selection(Selection::Normal(self.shaped.cursor_at(0)));
                        self.editor.set_cursor(self.shaped.cursor_at(self.shaped.text().chars().count()));
                        return true;
                    }
                    // Read-only: never forward editing commands as app actions.
                    "x" | "v" | "z" | "y" => return true,
                    _ => return false,
                }
            }
        }
        if key.key == Key::Named(Named::Escape) && self.bounds().is_some() {
            self.editor.set_selection(Selection::None);
            return true;
        }
        let motion = match key.key {
            Key::Named(Named::Left) => Some(if key.ctrl || key.alt { Motion::LeftWord } else { Motion::Left }),
            Key::Named(Named::Right) => Some(if key.ctrl || key.alt { Motion::RightWord } else { Motion::Right }),
            Key::Named(Named::Up) => Some(Motion::Up),
            Key::Named(Named::Down) => Some(Motion::Down),
            Key::Named(Named::Home) => Some(if key.shortcut() { Motion::BufferStart } else { Motion::Home }),
            Key::Named(Named::End) => Some(if key.shortcut() { Motion::BufferEnd } else { Motion::End }),
            _ => None,
        };
        if let Some(motion) = motion {
            if key.shift {
                self.anchor();
            } else {
                let bounds = self.bounds();
                self.editor.set_selection(Selection::None);
                if let Some((start, end)) = bounds {
                    if matches!(motion, Motion::Left | Motion::Right) {
                        self.editor.set_cursor(if motion == Motion::Left { start } else { end });
                        return true;
                    }
                }
            }
            self.editor.action(fs, Action::Motion(motion));
            return true;
        }
        // Typing and editing keys must not become application actions while reading.
        crate::elements::text_field::edits(key)
    }
}
