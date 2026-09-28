//! edit_box: a multi-line text field that wraps and scrolls to its caret.

use super::edit_line::{draw_field, frame, Colors};
use super::text_field;
use super::WidgetState;
use crate::doc::Node;
use crate::input::ViewState;
use crate::layout::{LBox, Rect};
use crate::paint::Canvas;
use crate::style::Color;
use crate::text::TextEngine;

pub fn inner_rect(r: Rect) -> Rect {
    Rect::new(r.x + 8.0, r.y + 6.0, (r.w - 16.0).max(1.0), (r.h - 12.0).max(1.0))
}

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox, state: WidgetState, view: &mut ViewState, text: &mut TextEngine) {
    let r = lbox.rect;
    let colors = Colors::of(node);
    frame(canvas, &colors, r, lbox.clip, state.focused);
    let field = text_field::ensure(&mut view.fields, node, &mut text.fonts);
    let inner = inner_rect(r);
    field.fit(&mut text.fonts.system, inner);
    draw_field(canvas, field, Rect::new(r.x + 3.0, r.y + 3.0, r.w - 6.0, r.h - 6.0), lbox.clip, state.focused, colors.accent, text);
    let (_, content_h) = field.content_size();
    if content_h > inner.h + 0.5 {
        let track = inner.h;
        let thumb = (track * inner.h / content_h).max(16.0);
        let max = content_h - inner.h;
        let y = inner.y + (track - thumb) * (field.offset.1 / max).clamp(0.0, 1.0);
        canvas.fill_rounded(Rect::new(r.right() - 7.0, y, 4.0, thumb), 2.0, Color::rgba(0, 0, 0, 70), lbox.clip);
    }
}
