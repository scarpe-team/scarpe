//! video: a placeholder player (dark frame, play button). Playback is not
//! implemented in the native display.

use crate::layout::{LBox, Rect};
use crate::paint::{shapes, Canvas};
use crate::style::Color;
use tiny_skia::PathBuilder;

pub fn paint(canvas: &mut Canvas, lbox: &LBox) {
    let r = lbox.rect;
    canvas.fill_rounded(r, 8.0, Color::rgb(0x1c, 0x1c, 0x1e), lbox.clip);
    let d = r.w.min(r.h) * 0.36;
    let (cx, cy) = r.center();
    if let Some(circle) = shapes::ellipse(Rect::new(cx - d / 2.0, cy - d / 2.0, d, d)) {
        canvas.fill(&circle, Color::rgba(255, 255, 255, 40), lbox.clip);
    }
    let t = d * 0.28;
    let mut pb = PathBuilder::new();
    pb.move_to(cx - t * 0.7, cy - t);
    pb.line_to(cx + t, cy);
    pb.line_to(cx - t * 0.7, cy + t);
    pb.close();
    if let Some(tri) = pb.finish() {
        canvas.fill(&tri, Color::WHITE, lbox.clip);
    }
}
