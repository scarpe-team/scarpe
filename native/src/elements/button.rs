//! button: a rounded push button with a soft gradient, border and shadow, and
//! Shoes 3.3's optional `icon:` beside its label (`icon_pos:` left, right, top, bottom).

use super::image::{self, ImageCache};
use super::{focus_ring, text_on, Label, WidgetState, CONTROL_TEXT_SIZE};
use std::path::Path;
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
const ICON: f32 = 16.0;
/// The soft shadow's share of the button's box, below its face.
const SHADOW: f32 = 1.5;

/// The button's face: its box less the shadow, which stays inside the box.
fn face(r: Rect) -> Rect {
    Rect::new(r.x + 0.5, r.y, r.w - 1.0, r.h - SHADOW)
}
const ICON_GAP: f32 = 6.0;

#[derive(Clone, Copy, PartialEq)]
enum IconPos {
    Left,
    Right,
    Top,
    Bottom,
}

fn icon_path(node: &Node) -> Option<&str> {
    node.props.str("icon").filter(|p| !p.is_empty())
}

fn icon_pos(node: &Node) -> Option<IconPos> {
    icon_path(node)?;
    Some(match node.props.str("icon_pos").map(|p| p.trim_start_matches(':')) {
        Some("right") => IconPos::Right,
        Some("top") => IconPos::Top,
        Some("bottom") => IconPos::Bottom,
        _ => IconPos::Left,
    })
}

/// Where the label goes inside a (w, h) button, and the icon's box, both from its corner.
fn arrange(node: &Node, w: f32, h: f32, label: (f32, f32)) -> ((f32, f32), Option<Rect>) {
    let centred = ((w - label.0) / 2.0, (h - label.1) / 2.0);
    let Some(pos) = icon_pos(node) else { return (centred, None) };
    let gap = if label.0 > 0.0 { ICON_GAP } else { 0.0 };
    match pos {
        IconPos::Left | IconPos::Right => {
            let start = (w - (ICON + gap + label.0)) / 2.0;
            let (icon_x, text_x) = if pos == IconPos::Left { (start, start + ICON + gap) } else { (start + label.0 + gap, start) };
            ((text_x, centred.1), Some(Rect::new(icon_x, (h - ICON) / 2.0, ICON, ICON)))
        }
        IconPos::Top | IconPos::Bottom => {
            let start = (h - (ICON + gap + label.1)) / 2.0;
            let (icon_y, text_y) = if pos == IconPos::Top { (start, start + ICON + gap) } else { (start + label.1 + gap, start) };
            ((centred.0, text_y), Some(Rect::new((w - ICON) / 2.0, icon_y, ICON, ICON)))
        }
    }
}

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
    let text_w = engine.shape(&rich, None).width;
    let gap = if text_w > 0.0 { ICON_GAP } else { 0.0 };
    let (content_w, content_h) = match icon_pos(node) {
        None => (text_w, rich.line_height),
        Some(IconPos::Left | IconPos::Right) => (text_w + gap + ICON, rich.line_height.max(ICON)),
        Some(IconPos::Top | IconPos::Bottom) => (text_w.max(ICON), rich.line_height + ICON_GAP + ICON),
    };
    let w = (content_w + PAD_X * 2.0).ceil().max(MIN_HEIGHT);
    let h = (content_h + 12.0).ceil().max(MIN_HEIGHT);
    (w, h)
}

pub fn label(node: &Node, w: f32, h: f32, engine: &mut TextEngine) -> Label {
    let rich = rich(node, engine);
    let shaped = engine.shape(&rich, None);
    let ((dx, dy), _) = arrange(node, w, h - SHADOW, (shaped.width, shaped.height));
    Label { shaped, dx, dy }
}

/// Space and Return press a focused button.
pub fn activates(key: &KeyInput) -> bool {
    !key.modified() && (key.key == Key::Named(Named::Enter) || key.key == Key::Char(" ".into()))
}

pub fn paint(
    canvas: &mut Canvas,
    node: &Node,
    lbox: &LBox,
    label: Option<&TextBox>,
    state: WidgetState,
    engine: &mut TextEngine,
    images: &mut ImageCache,
) {
    let (bx, r) = (lbox.rect, face(lbox.rect));
    let clip = lbox.clip;
    if state.focused {
        focus_ring(canvas, r, RADIUS, clip);
    }
    canvas.fill_rounded(Rect::new(bx.x, bx.y + 0.5, bx.w, bx.h - 0.5), RADIUS + 0.5, Color::rgba(0, 0, 0, 14), clip);
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
    let inner = Rect::new(r.x + 2.0, r.y, r.w - 4.0, r.h);
    let inner_clip = clip.and_then(|c| c.intersect(&inner)).or(Some(inner));
    if let Some(tb) = label {
        text::draw_shaped(canvas, engine, &tb.shaped, tb.x, tb.y, inner_clip, None);
    }
    let label_size = label.map_or((0.0, 0.0), |tb| (tb.shaped.width, tb.shaped.height));
    if let (Some(icon), Some(img)) = (arrange(node, bx.w, bx.h - SHADOW, label_size).1, icon_path(node).and_then(|p| images.get(Path::new(p)))) {
        image::draw_fitted(canvas, &img, icon.translate(bx.x, bx.y), inner_clip);
    }
}

fn tint(c: Color, factor: f32) -> Color {
    let f = |v: u8| ((v as f32) * factor).round().clamp(0.0, 255.0) as u8;
    Color::rgba(f(c.r), f(c.g), f(c.b), c.a)
}
