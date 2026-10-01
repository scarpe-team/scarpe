//! list_box: a popup button showing the chosen item. A press opens a popup
//! overlay; picking an item sends `change [item]` and Lacci echoes `chosen`.

use super::{focus_ring, Label, WidgetState, ACCENT, CONTROL_TEXT_SIZE};
use crate::doc::Node;
use crate::input::{Key, KeyInput, Named, ViewState};
use crate::layout::{LBox, Rect, TextBox};
use crate::paint::text::draw_shaped;
use crate::paint::Canvas;
use crate::props::{value_text, Id};
use crate::style::Color;
use crate::text::rich::{TextStyle, INK};
use crate::text::{RichText, TextEngine};
use serde_json::Value;
use tiny_skia::{LineCap, LineJoin, PathBuilder, Shader, Stroke, Transform};

const RADIUS: f32 = 6.0;
const PAD_X: f32 = 10.0;
const BADGE: f32 = 16.0;
const SHADOW: f32 = 1.0;
pub const ITEM_H: f32 = 22.0;

pub fn items(node: &Node) -> Vec<String> {
    match node.props.get("items") {
        Some(Value::Array(items)) => items.iter().map(value_text).collect(),
        _ => Vec::new(),
    }
}

pub fn chosen(node: &Node) -> Option<String> {
    node.props.text("chosen").or_else(|| node.props.text("choose"))
}

fn style(node: &Node) -> TextStyle {
    let color = node.props.color("stroke").filter(|c| !c.is_invisible()).unwrap_or(INK);
    TextStyle::new(CONTROL_TEXT_SIZE, color)
}

pub fn label(node: &Node, _w: f32, h: f32, engine: &mut TextEngine) -> Option<Label> {
    let text = chosen(node)?;
    let shaped = engine.shape(&RichText::plain(&text, style(node)), None);
    let dy = (h - SHADOW - shaped.height) / 2.0;
    Some(Label { shaped, dx: PAD_X, dy })
}

pub fn paint(canvas: &mut Canvas, _node: &Node, lbox: &LBox, label: Option<&TextBox>, state: WidgetState, engine: &mut TextEngine) {
    // The face sits above a one-pixel shadow, both inside the box.
    let r = Rect::new(lbox.rect.x, lbox.rect.y, lbox.rect.w, lbox.rect.h - SHADOW);
    let clip = lbox.clip;
    if state.focused {
        focus_ring(canvas, r, RADIUS, clip);
    }
    canvas.fill_rounded(Rect::new(r.x, r.y + SHADOW, r.w, r.h), RADIUS, Color::rgba(0, 0, 0, 20), clip);
    let (top, bottom) = if state.pressed {
        (Color::rgb(0xe6, 0xe6, 0xeb), Color::rgb(0xdc, 0xdc, 0xe2))
    } else {
        (Color::WHITE, Color::rgb(0xf3, 0xf3, 0xf6))
    };
    canvas.fill_gradient(r, RADIUS, top, bottom, clip);
    canvas.stroke_rounded(r, RADIUS, Color::rgba(0, 0, 0, 38), 1.0, clip);
    let badge = Rect::new(r.right() - BADGE - 6.0, r.y + (r.h - BADGE) / 2.0, BADGE, BADGE);
    canvas.fill_rounded(badge, 4.0, ACCENT, clip);
    chevrons(canvas, badge, clip);
    if let Some(tb) = label {
        let area = Rect::new(r.x + 2.0, r.y, badge.x - r.x - 6.0, r.h);
        let text_clip = clip.and_then(|c| c.intersect(&area)).or(Some(area));
        draw_shaped(canvas, engine, &tb.shaped, tb.x, tb.y, text_clip, None);
    }
}

fn chevrons(canvas: &mut Canvas, b: Rect, clip: Option<Rect>) {
    let (cx, cy) = b.center();
    let stroke = Stroke { width: 1.5, line_cap: LineCap::Round, line_join: LineJoin::Round, ..Stroke::default() };
    let mut pb = PathBuilder::new();
    pb.move_to(cx - 3.0, cy - 1.5);
    pb.line_to(cx, cy - 4.5);
    pb.line_to(cx + 3.0, cy - 1.5);
    pb.move_to(cx - 3.0, cy + 1.5);
    pb.line_to(cx, cy + 4.5);
    pb.line_to(cx + 3.0, cy + 1.5);
    if let Some(path) = pb.finish() {
        canvas.stroke_path(&path, Shader::SolidColor(Color::WHITE.to_skia()), &stroke, Transform::identity(), clip);
    }
}

/// The open item list of a list_box.
#[derive(Clone, Debug, PartialEq)]
pub struct Popup {
    pub list_box: Id,
    pub items: Vec<String>,
    pub rect: Rect,
    pub chosen: Option<usize>,
    pub hovered: Option<usize>,
    pub scroll: f32,
}

impl Popup {
    pub fn open(node: &Node, anchor: Rect, window: (f32, f32), engine: &mut TextEngine) -> Popup {
        let items = items(node);
        let chosen_text = chosen(node);
        let chosen = items.iter().position(|i| Some(i) == chosen_text.as_ref());
        let widest = items
            .iter()
            .map(|i| engine.shape(&RichText::plain(i, style(node)), None).width)
            .fold(0.0f32, f32::max);
        let w = anchor.w.max(widest + 44.0).min(window.0 - 8.0);
        let full = items.len().max(1) as f32 * ITEM_H + 8.0;
        let below = window.1 - anchor.bottom() - 8.0;
        let above = anchor.y - 8.0;
        let (y, h) = if full <= below || below >= above {
            (anchor.bottom() + 4.0, full.min(below.max(ITEM_H + 8.0)))
        } else {
            let h = full.min(above);
            (anchor.y - 4.0 - h, h)
        };
        let x = anchor.x.min(window.0 - w - 4.0).max(4.0);
        Popup { list_box: node.id, items, rect: Rect::new(x, y, w, h), chosen, hovered: chosen, scroll: 0.0 }
    }

    pub fn item_at(&self, x: f32, y: f32) -> Option<usize> {
        if !self.rect.contains(x, y) {
            return None;
        }
        let i = ((y - self.rect.y - 4.0 + self.scroll) / ITEM_H).floor();
        (i >= 0.0 && (i as usize) < self.items.len()).then_some(i as usize)
    }

    pub fn item_rect(&self, i: usize) -> Rect {
        Rect::new(self.rect.x + 4.0, self.rect.y + 4.0 + i as f32 * ITEM_H - self.scroll, self.rect.w - 8.0, ITEM_H)
    }

    pub fn max_scroll(&self) -> f32 {
        (self.items.len() as f32 * ITEM_H + 8.0 - self.rect.h).max(0.0)
    }

    pub fn scroll_by(&mut self, dy: f32) {
        self.scroll = (self.scroll + dy).clamp(0.0, self.max_scroll());
    }
}

/// Up and Down on a focused list box pick the item before or after the chosen one,
/// without opening the popup (manual 3221-3224). None when the key is not an arrow
/// or the choice would not move.
pub fn stepped(node: &Node, key: &KeyInput) -> Option<String> {
    let step: isize = match key.key {
        Key::Named(Named::Up) if !key.modified() => -1,
        Key::Named(Named::Down) if !key.modified() => 1,
        _ => return None,
    };
    let items = items(node);
    if items.is_empty() {
        return None;
    }
    let current = chosen(node).and_then(|c| items.iter().position(|i| *i == c));
    let next = match current {
        Some(i) => (i as isize + step).clamp(0, items.len() as isize - 1) as usize,
        None if step > 0 => 0,
        None => items.len().checked_sub(1)?,
    };
    (Some(next) != current).then(|| items[next].clone())
}

/// Return and Space open the popup of a focused list box.
pub fn opens(key: &KeyInput) -> bool {
    !key.modified() && (key.key == Key::Named(Named::Enter) || key.key == Key::Char(" ".into()))
}

pub enum PopupKey {
    Choose(usize),
    Close,
    Moved,
    Ignored,
}

pub fn popup_key(popup: &mut Popup, key: &KeyInput) -> PopupKey {
    let last = popup.items.len().saturating_sub(1);
    match &key.key {
        Key::Named(Named::Escape) | Key::Named(Named::Tab) => PopupKey::Close,
        Key::Named(Named::Up) => {
            popup.hovered = Some(popup.hovered.map(|h| h.saturating_sub(1)).unwrap_or(0));
            PopupKey::Moved
        }
        Key::Named(Named::Down) => {
            popup.hovered = Some(popup.hovered.map(|h| (h + 1).min(last)).unwrap_or(0));
            PopupKey::Moved
        }
        Key::Named(Named::Enter) => popup.hovered.map(PopupKey::Choose).unwrap_or(PopupKey::Close),
        Key::Char(c) if c == " " => popup.hovered.map(PopupKey::Choose).unwrap_or(PopupKey::Close),
        _ => PopupKey::Ignored,
    }
}

pub fn paint_popup(canvas: &mut Canvas, view: &ViewState, engine: &mut TextEngine) {
    let Some(popup) = &view.popup else { return };
    let r = popup.rect;
    // A soft shadow: three widening, fading layers.
    for (grow, alpha) in [(6.0, 8), (3.0, 14), (1.0, 26)] {
        let shadow = Rect::new(r.x - grow, r.y - grow + 3.0, r.w + grow * 2.0, r.h + grow * 2.0);
        canvas.fill_rounded(shadow, RADIUS + grow, Color::rgba(0, 0, 0, alpha), None);
    }
    canvas.fill_rounded(r, RADIUS, Color::rgb(0xfb, 0xfb, 0xfd), None);
    let inner = Rect::new(r.x + 2.0, r.y + 2.0, r.w - 4.0, r.h - 4.0);
    for (i, item) in popup.items.iter().enumerate() {
        let row = popup.item_rect(i);
        if row.bottom() < r.y || row.y > r.bottom() {
            continue;
        }
        let hot = popup.hovered == Some(i);
        if hot {
            canvas.fill_rounded(row, 4.0, ACCENT, Some(inner));
        }
        let color = if hot { Color::WHITE } else { INK };
        if popup.chosen == Some(i) {
            let mut pb = PathBuilder::new();
            let (x, cy) = (row.x + 8.0, row.y + row.h / 2.0);
            pb.move_to(x, cy);
            pb.line_to(x + 3.0, cy + 3.0);
            pb.line_to(x + 8.0, cy - 3.5);
            if let Some(tick) = pb.finish() {
                let stroke = Stroke { width: 1.6, line_cap: LineCap::Round, line_join: LineJoin::Round, ..Stroke::default() };
                canvas.stroke_path(&tick, Shader::SolidColor(color.to_skia()), &stroke, Transform::identity(), Some(inner));
            }
        }
        let shaped = engine.shape(&RichText::plain(item, TextStyle::new(CONTROL_TEXT_SIZE, color)), None);
        let y = row.y + (row.h - shaped.height) / 2.0;
        draw_shaped(canvas, engine, &shaped, row.x + 22.0, y, Some(inner), None);
    }
}
