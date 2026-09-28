//! radio: a circle with an accent fill and white dot when on. Lacci keeps one
//! radio per group checked and echoes `checked`.

use super::{check::box_rect, focus_ring, WidgetState, ACCENT};
use crate::doc::Node;
use crate::layout::LBox;
use crate::paint::{shapes, Canvas};
use crate::style::Color;

pub use super::check::activates;

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox, state: WidgetState) {
    let b = box_rect(lbox.rect);
    let clip = lbox.clip;
    if state.focused {
        focus_ring(canvas, b, b.w / 2.0, clip);
    }
    let Some(circle) = shapes::ellipse(b) else { return };
    if node.props.truthy("checked") {
        let fill = if state.pressed { Color::rgb(0x00, 0x6a, 0xd6) } else { ACCENT };
        canvas.fill(&circle, fill, clip);
        let (cx, cy) = b.center();
        if let Some(dot) = shapes::ellipse(crate::layout::Rect::new(cx - 3.0, cy - 3.0, 6.0, 6.0)) {
            canvas.fill(&dot, Color::WHITE, clip);
        }
    } else {
        let fill = if state.pressed { Color::rgb(0xe5, 0xe5, 0xea) } else { Color::WHITE };
        canvas.fill(&circle, fill, clip);
        let border = if state.hovered { Color::rgb(0x8e, 0x8e, 0x93) } else { Color::rgb(0xae, 0xae, 0xb2) };
        if let Some(ring) = shapes::ellipse(crate::layout::Rect::new(b.x + 0.5, b.y + 0.5, b.w - 1.0, b.h - 1.0)) {
            canvas.stroke(&ring, border, 1.0, clip);
        }
    }
}
