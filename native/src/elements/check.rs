//! check: a rounded box that fills with the accent colour and a tick when on.
//! Lacci toggles `checked` itself and echoes it; the box only draws the echo.

use super::{focus_ring, WidgetState, ACCENT};
use crate::doc::Node;
use crate::input::{Key, KeyInput};
use crate::layout::{LBox, Rect};
use crate::paint::Canvas;
use crate::style::Color;
use tiny_skia::{LineCap, LineJoin, PathBuilder, Shader, Stroke, Transform};

pub const BOX: f32 = 16.0;

pub fn box_rect(r: Rect) -> Rect {
    Rect::new(r.x + (r.w - BOX) / 2.0, r.y + (r.h - BOX) / 2.0, BOX, BOX)
}

pub fn activates(key: &KeyInput) -> bool {
    !key.modified() && key.key == Key::Char(" ".into())
}

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox, state: WidgetState) {
    let b = box_rect(lbox.rect);
    let clip = lbox.clip;
    if state.focused {
        focus_ring(canvas, b, 4.0, clip);
    }
    if node.props.truthy("checked") {
        let fill = if state.pressed { Color::rgb(0x00, 0x6a, 0xd6) } else { ACCENT };
        canvas.fill_rounded(b, 4.0, fill, clip);
        let mut pb = PathBuilder::new();
        pb.move_to(b.x + 4.0, b.y + 8.3);
        pb.line_to(b.x + 7.0, b.y + 11.2);
        pb.line_to(b.x + 12.2, b.y + 5.0);
        if let Some(tick) = pb.finish() {
            let stroke = Stroke { width: 2.0, line_cap: LineCap::Round, line_join: LineJoin::Round, ..Stroke::default() };
            canvas.stroke_path(&tick, Shader::SolidColor(Color::WHITE.to_skia()), &stroke, Transform::identity(), clip);
        }
    } else {
        let fill = if state.pressed { Color::rgb(0xe5, 0xe5, 0xea) } else { Color::WHITE };
        canvas.fill_rounded(b, 4.0, fill, clip);
        let border = if state.hovered { Color::rgb(0x8e, 0x8e, 0x93) } else { Color::rgb(0xae, 0xae, 0xb2) };
        canvas.stroke_rounded(b, 4.0, border, 1.0, clip);
    }
}
