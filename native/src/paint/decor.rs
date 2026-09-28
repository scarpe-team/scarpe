//! Backgrounds, borders and the overlay scrollbar.

use super::{with_shader, Canvas};
use crate::doc::Node;
use crate::elements::image::ImageCache;
use crate::layout::{LBox, Layout, Rect};
use crate::style::{Color, Paint};
use tiny_skia::{FillRule, LineJoin, Stroke, Transform};

/// Fills the slot's box (or the background's own width/height), rounded by `curve`.
pub fn background(canvas: &mut Canvas, node: &Node, lbox: &LBox, images: &mut ImageCache) {
    let Some(paint) = node.props.paint("fill") else { return };
    if !paint.is_visible() {
        return;
    }
    let curve = node.props.f32("curve").unwrap_or(0.0);
    let Some(path) = canvas.rect_path(lbox.rect, curve, 0.0) else { return };
    with_shader(&paint, lbox.rect, images, |shader| {
        canvas.fill_path(&path, shader, FillRule::Winding, Transform::identity(), lbox.clip);
    });
}

/// Strokes inside the slot's box, so a 4px border stays within the slot.
pub fn border(canvas: &mut Canvas, node: &Node, lbox: &LBox, images: &mut ImageCache) {
    let paint = node.props.paint("stroke").unwrap_or(Paint::Solid(Color::BLACK));
    let width = node.props.f32("strokewidth").unwrap_or(1.0);
    if !paint.is_visible() || width <= 0.0 {
        return;
    }
    let r = lbox.rect;
    let half = width / 2.0;
    let inner = Rect::new(r.x + half, r.y + half, (r.w - width).max(0.0), (r.h - width).max(0.0));
    let curve = (node.props.f32("curve").unwrap_or(0.0) - half).max(0.0);
    let Some(path) = canvas.rect_path(inner, curve, width) else { return };
    let stroke = Stroke { width, line_join: LineJoin::Round, ..Stroke::default() };
    with_shader(&paint, r, images, |shader| {
        canvas.stroke_path(&path, shader, &stroke, Transform::identity(), lbox.clip);
    });
}

const SCROLLBAR: Color = Color::rgba(0, 0, 0, 90);

/// A thin overlay thumb on every slot whose content overflows it.
pub fn scrollbars(canvas: &mut Canvas, layout: &Layout) {
    for (id, s) in &layout.scrollers {
        if s.max_top() <= 0.5 {
            continue;
        }
        let v = s.viewport;
        let clip = layout.boxes.get(id).and_then(|b| b.clip);
        let track = v.h - 4.0;
        let thumb = (track * v.h / s.content_height).max(24.0).min(track);
        let y = v.y + 2.0 + (track - thumb) * (s.top / s.max_top());
        let bar = Rect::new(v.right() - 8.0, y, 5.0, thumb);
        canvas.fill_rounded(bar, 2.5, SCROLLBAR, clip.or(Some(v)));
    }
}
