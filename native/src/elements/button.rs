//! button: a rounded push button with a soft gradient, border and shadow.

use super::{focus_ring, text_on, Label, WidgetState, CONTROL_TEXT_SIZE};
use crate::doc::Node;
use crate::input::{Key, KeyInput, Named};
use crate::layout::{LBox, Rect, TextBox};
use crate::paint::{text, Canvas};
use crate::style::font::parse_size;
use crate::style::Color;
use crate::text::rich::{TextStyle, INK};
use crate::text::{RichText, TextEngine};

const PAD_X: f32 = 14.0;
const MIN_HEIGHT: f32 = 28.0;
const RADIUS: f32 = 6.0;

fn rich(node: &Node, engine: &TextEngine) -> RichText {
    let p = &node.props;
    let size = p
        .get("size")
        .or_else(|| p.get("font_size"))
        .and_then(|v| parse_size(v, CONTROL_TEXT_SIZE))
        .unwrap_or(CONTROL_TEXT_SIZE);
    let mut style = TextStyle::new(size, label_color(node));
    if let Some(font) = p.str("font") {
        let spec = crate::style::font::parse_font(font);
        if let Some(family) = spec.family {
            style.family = engine.fonts.resolve_family(&family);
        }
        if let Some(weight) = spec.weight {
            style.weight = weight;
        }
        if let Some(size) = spec.size {
            style.size = size;
        }
        style.italic = spec.italic;
    }
    RichText::plain(&p.text("text").unwrap_or_default(), style)
}

fn surface(node: &Node) -> Option<Color> {
    node.props.color("color").filter(|c| !c.is_invisible())
}

fn label_color(node: &Node) -> Color {
    let p = &node.props;
    p.color("text_color")
        .or_else(|| p.color("stroke"))
        .filter(|c| !c.is_invisible())
        .unwrap_or_else(|| surface(node).map(text_on).unwrap_or(INK))
}

pub fn size(node: &Node, engine: &mut TextEngine) -> (f32, f32) {
    let rich = rich(node, engine);
    let shaped = engine.shape(&rich, None);
    let w = (shaped.width + PAD_X * 2.0).ceil().max(MIN_HEIGHT);
    let h = (rich.line_height + 12.0).ceil().max(MIN_HEIGHT);
    (w, h)
}

pub fn label(node: &Node, w: f32, h: f32, engine: &mut TextEngine) -> Label {
    let rich = rich(node, engine);
    let shaped = engine.shape(&rich, None);
    let dx = (w - shaped.width) / 2.0;
    let dy = (h - shaped.height) / 2.0;
    Label { shaped, dx, dy }
}

/// Space and Return press a focused button.
pub fn activates(key: &KeyInput) -> bool {
    !key.modified() && (key.key == Key::Named(Named::Enter) || key.key == Key::Char(" ".into()))
}

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox, label: Option<&TextBox>, state: WidgetState, engine: &mut TextEngine) {
    let r = lbox.rect;
    let clip = lbox.clip;
    if state.focused {
        focus_ring(canvas, r, RADIUS, clip);
    }
    canvas.fill_rounded(Rect::new(r.x - 0.5, r.y + 0.5, r.w + 1.0, r.h + 1.5), RADIUS + 1.0, Color::rgba(0, 0, 0, 14), clip);
    canvas.fill_rounded(Rect::new(r.x, r.y + 1.0, r.w, r.h), RADIUS, Color::rgba(0, 0, 0, 22), clip);
    let (top, bottom) = match surface(node) {
        Some(c) => {
            let shade = if state.pressed { 0.82 } else if state.hovered { 1.04 } else { 1.0 };
            (tint(c, shade * 1.06), tint(c, shade * 0.96))
        }
        None if state.pressed => (Color::rgb(0xdc, 0xdc, 0xe2), Color::rgb(0xd0, 0xd0, 0xd8)),
        None if state.hovered => (Color::WHITE, Color::rgb(0xf2, 0xf2, 0xf6)),
        None => (Color::WHITE, Color::rgb(0xee, 0xee, 0xf1)),
    };
    canvas.fill_gradient(r, RADIUS, top, bottom, clip);
    canvas.stroke_rounded(r, RADIUS, Color::rgba(0, 0, 0, 38), 1.0, clip);
    if let Some(tb) = label {
        let inner = Rect::new(r.x + 2.0, r.y, r.w - 4.0, r.h);
        let text_clip = clip.and_then(|c| c.intersect(&inner)).or(Some(inner));
        text::draw_shaped(canvas, engine, &tb.shaped, tb.x, tb.y, text_clip, None);
    }
}

fn tint(c: Color, factor: f32) -> Color {
    let f = |v: u8| ((v as f32) * factor).round().clamp(0.0, 255.0) as u8;
    Color::rgba(f(c.r), f(c.g), f(c.b), c.a)
}
