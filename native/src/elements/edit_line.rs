//! edit_line: a single-line text field. Every edit sends `change [text]`.

use super::text_field::{self, TextField};
use super::{focus_ring_in, WidgetState, ACCENT, FIELD_BORDER};
use crate::doc::Node;
use crate::input::ViewState;
use crate::layout::{LBox, Rect};
use crate::paint::text::{draw_buffer, draw_shaped, SELECTION};
use crate::paint::Canvas;
use crate::style::Color;
use crate::text::rich::TextStyle;
use crate::text::{RichText, TextEngine};

pub const RADIUS: f32 = 6.0;

pub fn inner_rect(r: Rect, line_h: f32) -> Rect {
    Rect::new(r.x + 8.0, r.y + ((r.h - line_h) / 2.0).max(1.0), (r.w - 16.0).max(1.0), line_h)
}

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox, state: WidgetState, view: &mut ViewState, text: &mut TextEngine) {
    let r = lbox.rect;
    let colors = Colors::of(node);
    frame(canvas, &colors, r, lbox.clip, state.focused);
    let field = text_field::ensure(&mut view.fields, node, &mut text.fonts);
    let inner = inner_rect(r, field.line_height());
    field.fit(&mut text.fonts.system, inner);
    draw_field(canvas, field, Rect::new(r.x + 3.0, r.y + 1.0, r.w - 6.0, r.h - 2.0), lbox.clip, state.focused, colors.accent, text);
}

/// A field's colours (ledger G17). `fill` paints the box and `border_color` draws its edge. The
/// caret, the focused edge and the focus halo are the default blue, or the text's own colour once
/// `stroke` has given it one, the way CSS's caret-color is currentColor.
pub struct Colors {
    pub fill: Color,
    pub border: Color,
    pub accent: Color,
}

impl Colors {
    /// A field nobody styled: white, a light grey edge, a blue caret and halo.
    pub const PLAIN: Colors = Colors { fill: Color::WHITE, border: FIELD_BORDER, accent: ACCENT };

    pub fn of(node: &Node) -> Colors {
        let p = &node.props;
        Colors {
            fill: p.color("fill").unwrap_or(Color::WHITE),
            border: p.color("border_color").unwrap_or(FIELD_BORDER),
            accent: p.color("stroke").filter(|c| !c.is_invisible()).unwrap_or(ACCENT),
        }
    }
}

/// The rounded box with its border, and the focus halo round it while it has focus.
pub fn frame(canvas: &mut Canvas, colors: &Colors, r: Rect, clip: Option<Rect>, focused: bool) {
    if focused {
        focus_ring_in(canvas, r, RADIUS, colors.accent, clip);
    }
    canvas.fill_rounded(r, RADIUS, colors.fill, clip);
    canvas.stroke_rounded(r, RADIUS, if focused { colors.accent } else { colors.border }, 1.0, clip);
}

/// Selection, text (or bullets) and caret, clipped to the field's text area.
pub fn draw_field(
    canvas: &mut Canvas,
    field: &TextField,
    area: Rect,
    clip: Option<Rect>,
    focused: bool,
    caret_color: Color,
    text: &mut TextEngine,
) {
    let clip = match clip {
        Some(c) => c.intersect(&area),
        None => Some(area),
    };
    if clip.is_none() {
        return;
    }
    let selection = if focused { SELECTION } else { Color::rgba(0, 0, 0, 24) };
    for r in field.selection() {
        canvas.fill_rect(r, selection, clip);
    }
    let (x, y) = (field.inner.x - field.offset.0, field.inner.y - field.offset.1);
    if field.secret {
        let shaped = text.shape(&RichText::plain(&field.bullets(), TextStyle::new(field.size, field.color)), None);
        draw_shaped(canvas, text, &shaped, x, y, clip, None);
    } else {
        field.editor_buffer(|buffer| draw_buffer(canvas, text, buffer, x, y, field.color, clip, &[], None));
    }
    if focused {
        if let Some(caret) = field.caret() {
            let s = canvas.scale;
            let snapped = Rect::new((caret.x * s).round() / s, caret.y, 1.0, caret.h);
            canvas.fill_rect(snapped, caret_color, clip);
        }
    }
}
