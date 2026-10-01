//! slider: a track with a knob at `fraction` (Shoes 3 only; Lacci has no class
//! yet, so this draws whatever arrives).

use super::{WidgetState, ACCENT};
use crate::doc::Node;
use crate::layout::{LBox, Rect};
use crate::paint::{shapes, Canvas};
use crate::style::Color;

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox, state: WidgetState) {
    let r = lbox.rect;
    let f = node.props.f32("fraction").unwrap_or(0.0).clamp(0.0, 1.0);
    let knob = 16.0f32.min(r.h);
    let usable = (r.w - knob).max(0.0);
    let cy = r.y + r.h / 2.0;
    let track = Rect::new(r.x + knob / 2.0, cy - 2.0, usable, 4.0);
    canvas.fill_rounded(track, 2.0, Color::rgb(0xd1, 0xd1, 0xd6), lbox.clip);
    canvas.fill_rounded(Rect::new(track.x, track.y, usable * f, 4.0), 2.0, ACCENT, lbox.clip);
    let k = Rect::new(r.x + usable * f, cy - knob / 2.0, knob, knob);
    if let Some(shadow) = shapes::ellipse(k.translate(0.0, 0.8)) {
        canvas.fill(&shadow, Color::rgba(0, 0, 0, 40), lbox.clip);
    }
    if let Some(circle) = shapes::ellipse(k) {
        canvas.fill(&circle, if state.pressed { Color::rgb(0xf0, 0xf0, 0xf2) } else { Color::WHITE }, lbox.clip);
        canvas.stroke(&circle, Color::rgba(0, 0, 0, 50), 0.8, lbox.clip);
    }
}
