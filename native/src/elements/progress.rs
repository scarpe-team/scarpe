//! progress: a rounded track filled to `fraction` (nil draws an idle segment).

use super::ACCENT;
use crate::doc::Node;
use crate::layout::{LBox, Rect};
use crate::paint::Canvas;
use crate::style::Color;

const TRACK: Color = Color::rgb(0xe5, 0xe5, 0xea);

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox) {
    let r = lbox.rect;
    let h = r.h.min(8.0);
    let track = Rect::new(r.x, r.y + (r.h - h) / 2.0, r.w, h);
    canvas.fill_rounded(track, h / 2.0, TRACK, lbox.clip);
    match node.props.f32("fraction") {
        Some(f) => {
            let w = (r.w * f.clamp(0.0, 1.0)).max(if f > 0.0 { h } else { 0.0 });
            if w > 0.0 {
                canvas.fill_rounded(Rect::new(track.x, track.y, w, h), h / 2.0, ACCENT, lbox.clip);
            }
        }
        None => canvas.fill_rounded(Rect::new(track.x + r.w * 0.1, track.y, r.w * 0.35, h), h / 2.0, ACCENT.fade(0.55), lbox.clip),
    }
}
