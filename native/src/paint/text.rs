//! Drawing shaped text: highlights, glyphs, decorations, para cursor.

use super::Canvas;
use crate::doc::Node;
use crate::layout::{Rect, TextBox};
use crate::props::Id;
use crate::style::Color;
use crate::text::raster::blit;
use crate::text::rich::{Underline, INK, LINK_HOVER};
use crate::text::{ShapedText, SpanMeta, TextEngine};
use cosmic_text::{Buffer, Cursor, DecorationSpan, LayoutGlyph, LayoutRun};
use tiny_skia::PathBuilder;

pub const SELECTION: Color = Color::rgba(0x0a, 0x84, 0xff, 64);

pub fn draw_shaped(canvas: &mut Canvas, text: &mut TextEngine, shaped: &ShapedText, x: f32, y: f32, clip: Option<Rect>, hover_link: Option<Id>) {
    let style = RunStyle { default: INK, metas: &shaped.metas, hover_link, half_leading: -shaped.top };
    draw_runs(canvas, text, &shaped.buffer, x, y, clip, &style);
}

/// How to colour and box the runs of one buffer.
struct RunStyle<'a> {
    default: Color,
    metas: &'a [SpanMeta],
    hover_link: Option<Id>,
    /// Leading cosmic-text centred in each line, which highlights leave out.
    half_leading: f32,
}

fn meta_of(metas: &[SpanMeta], metadata: usize) -> Option<&SpanMeta> {
    metadata.checked_sub(1).and_then(|i| metas.get(i))
}

fn from_cosmic(c: cosmic_text::Color) -> Color {
    Color::rgba(c.r(), c.g(), c.b(), c.a())
}

/// Draws a buffer laid out in logical px with its top-left at (x, y).
#[allow(clippy::too_many_arguments)]
pub fn draw_buffer(
    canvas: &mut Canvas,
    text: &mut TextEngine,
    buffer: &Buffer,
    x: f32,
    y: f32,
    default: Color,
    clip: Option<Rect>,
    metas: &[SpanMeta],
    hover_link: Option<Id>,
) {
    draw_runs(canvas, text, buffer, x, y, clip, &RunStyle { default, metas, hover_link, half_leading: 0.0 });
}

fn draw_runs(canvas: &mut Canvas, text: &mut TextEngine, buffer: &Buffer, x: f32, y: f32, clip: Option<Rect>, style: &RunStyle) {
    let RunStyle { default, metas, hover_link, half_leading } = *style;
    let s = canvas.scale;
    let px_clip = canvas.px_clip(clip);
    let visible = clip.unwrap_or(Rect::new(0.0, 0.0, canvas.pm.width() as f32 / s, canvas.pm.height() as f32 / s));
    for run in buffer.layout_runs() {
        if y + run.line_top > visible.bottom() || y + run.line_top + run.line_height < visible.y {
            continue;
        }
        draw_highlights(canvas, &run, x, y + half_leading, metas, clip, half_leading);
        for glyph in run.glyphs {
            let meta = meta_of(metas, glyph.metadata);
            let rise = meta.map(|m| m.rise).unwrap_or(0.0);
            let mut color = glyph.color_opt.map(from_cosmic).unwrap_or(default);
            if let (Some(m), Some(hovered)) = (meta, hover_link) {
                if m.link == Some(hovered) && !m.explicit_color {
                    color = LINK_HOVER;
                }
            }
            let pg = glyph.physical((x * s, (y + run.line_y - rise) * s), s);
            let fonts = &mut text.fonts.system;
            if let Some(img) = text.raster.image(fonts, pg.cache_key) {
                blit(canvas.pm, img, pg.x, pg.y, color, px_clip);
            }
        }
        draw_decorations(canvas, &run, x, y, default, metas, hover_link, px_clip);
    }
}

fn draw_highlights(canvas: &mut Canvas, run: &LayoutRun, x: f32, y: f32, metas: &[SpanMeta], clip: Option<Rect>, half_leading: f32) {
    let mut current: Option<(Color, f32, f32)> = None;
    let height = (run.line_height - 2.0 * half_leading).max(0.0);
    let flush = |canvas: &mut Canvas, span: Option<(Color, f32, f32)>| {
        if let Some((color, x0, x1)) = span {
            canvas.fill_rect(Rect::new(x + x0, y + run.line_top, x1 - x0, height), color, clip);
        }
    };
    for glyph in run.glyphs {
        let highlight = meta_of(metas, glyph.metadata).and_then(|m| m.highlight);
        match (highlight, current) {
            (Some(c), Some((cur, x0, _))) if c == cur => current = Some((cur, x0, glyph.x + glyph.w)),
            (Some(c), _) => {
                flush(canvas, current.take());
                current = Some((c, glyph.x, glyph.x + glyph.w));
            }
            (None, _) => flush(canvas, current.take()),
        }
    }
    flush(canvas, current);
}

#[allow(clippy::too_many_arguments)]
fn draw_decorations(
    canvas: &mut Canvas,
    run: &LayoutRun,
    x: f32,
    y: f32,
    default: Color,
    metas: &[SpanMeta],
    hover_link: Option<Id>,
    px_clip: Option<crate::text::raster::PxClip>,
) {
    let decorated = |g: &LayoutGlyph| meta_of(metas, g.metadata).is_none_or(|m| m.decorated());
    for span in run.decorations {
        // cosmic-text joins two alike decorations across the plain text between them
        // (`link("a"), " ", link("b")` underlines the space), so split them again.
        for glyphs in run.glyphs[span.glyph_range.clone()].split(|g| !decorated(g)) {
            draw_decoration(canvas, span, glyphs, x, y + run.line_y, default, metas, hover_link, px_clip);
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn draw_decoration(
    canvas: &mut Canvas,
    span: &DecorationSpan,
    glyphs: &[LayoutGlyph],
    x: f32,
    line_y: f32,
    default: Color,
    metas: &[SpanMeta],
    hover_link: Option<Id>,
    px_clip: Option<crate::text::raster::PxClip>,
) {
    let s = canvas.scale;
    let Some(first) = glyphs.first() else { return };
    let meta = meta_of(metas, first.metadata);
    let (x0, x1) = glyphs.iter().fold((f32::INFINITY, f32::NEG_INFINITY), |(a, b), g| (a.min(g.x), b.max(g.x + g.w)));
    let mut color = span.color_opt.map(from_cosmic).unwrap_or(default);
    if let (Some(m), Some(h)) = (meta, hover_link) {
        if m.link == Some(h) && !m.explicit_color {
            color = LINK_HOVER;
        }
    }
    let rise = meta.map(|m| m.rise).unwrap_or(0.0);
    let baseline = line_y - rise;
    let td = &span.data.text_decoration;
    let size = span.font_size;
    let bar = |canvas: &mut Canvas, offset_em: f32, thickness_em: f32, c: Color| {
        let top = ((baseline - offset_em * size) * s).round();
        let t = (thickness_em * size * s).round().max(1.0);
        let left = ((x + x0) * s).round();
        let right = ((x + x1) * s).round();
        fill_px(canvas, left, top, right - left, t, c, px_clip);
    };
    if td.underline != cosmic_text::UnderlineStyle::None {
        let m = span.data.underline_metrics;
        let c = td.underline_color_opt.map(from_cosmic).unwrap_or(color);
        match meta.map(|m| m.underline).unwrap_or(Underline::Single) {
            Underline::Error => wavy(canvas, x + x0, x + x1, baseline + 0.12 * size, size, td.underline_color_opt.map(from_cosmic).unwrap_or(Color::rgb(0xe5, 0x39, 0x35)), px_clip),
            Underline::Low => bar(canvas, m.offset - 0.12, m.thickness, c),
            Underline::Double => {
                bar(canvas, m.offset, m.thickness, c);
                bar(canvas, m.offset - m.thickness * 2.5, m.thickness, c);
            }
            _ => {
                if td.underline == cosmic_text::UnderlineStyle::Double {
                    bar(canvas, m.offset, m.thickness, c);
                    bar(canvas, m.offset - m.thickness * 2.5, m.thickness, c);
                } else {
                    bar(canvas, m.offset, m.thickness, c);
                }
            }
        }
    }
    if td.strikethrough {
        let m = span.data.strikethrough_metrics;
        let c = td.strikethrough_color_opt.map(from_cosmic).unwrap_or(color);
        bar(canvas, m.offset, m.thickness, c);
    }
}

fn fill_px(canvas: &mut Canvas, x: f32, y: f32, w: f32, h: f32, color: Color, clip: Option<crate::text::raster::PxClip>) {
    let (mut x0, mut y0, mut x1, mut y1) = (x, y, x + w, y + h);
    if let Some(c) = clip {
        x0 = x0.max(c.x0 as f32);
        y0 = y0.max(c.y0 as f32);
        x1 = x1.min(c.x1 as f32);
        y1 = y1.min(c.y1 as f32);
    }
    if let Some(r) = tiny_skia::Rect::from_ltrb(x0, y0, x1, y1) {
        let mut paint = tiny_skia::Paint::default();
        paint.set_color(color.to_skia());
        paint.anti_alias = false;
        canvas.pm.fill_rect(r, &paint, tiny_skia::Transform::identity(), None);
    }
}

fn wavy(canvas: &mut Canvas, x0: f32, x1: f32, y: f32, size: f32, color: Color, _clip: Option<crate::text::raster::PxClip>) {
    let amp = (size * 0.08).max(1.0);
    let step = amp * 2.0;
    let mut pb = PathBuilder::new();
    pb.move_to(x0, y);
    let mut x = x0;
    let mut up = true;
    while x < x1 {
        let next = (x + step).min(x1);
        pb.quad_to((x + next) / 2.0, if up { y - amp } else { y + amp }, next, y);
        up = !up;
        x = next;
    }
    if let Some(path) = pb.finish() {
        canvas.stroke(&path, color, (size * 0.07).max(1.0), None);
    }
}

/// Char index into the buffer's text to a cosmic-text Cursor.
pub fn cursor_at_char(buffer: &Buffer, index: usize) -> Cursor {
    let mut remaining = index;
    for (line_i, line) in buffer.lines.iter().enumerate() {
        let text = line.text();
        let chars = text.chars().count();
        if remaining <= chars {
            let byte = text.char_indices().nth(remaining).map(|(b, _)| b).unwrap_or(text.len());
            return Cursor::new(line_i, byte);
        }
        remaining -= chars + 1;
    }
    let last = buffer.lines.len().saturating_sub(1);
    Cursor::new(last, buffer.lines.get(last).map(|l| l.text().len()).unwrap_or(0))
}

/// Where a cursor sits: (x, line_top, line_height) in buffer coordinates.
pub fn caret_position(buffer: &Buffer, cursor: Cursor) -> Option<(f32, f32, f32)> {
    let mut fallback = None;
    for run in buffer.layout_runs() {
        if run.line_i != cursor.line {
            continue;
        }
        if let Some(x) = run.cursor_position(&cursor) {
            return Some((x, run.line_top, run.line_height));
        }
        fallback = Some((run.line_w, run.line_top, run.line_height));
    }
    fallback
}

/// Selection rectangles between two cursors, in buffer coordinates.
/// `LayoutRun::highlight` selects every glyph of a line outside the cursors' lines, so those are skipped here.
pub fn selection_rects(buffer: &Buffer, start: Cursor, end: Cursor) -> Vec<Rect> {
    let mut out = Vec::new();
    for run in buffer.layout_runs().filter(|run| (start.line..=end.line).contains(&run.line_i)) {
        for (hx, hw) in run.highlight(start, end) {
            out.push(Rect::new(hx, run.line_top, hw, run.line_height));
        }
    }
    out
}

/// Para#cursor= and #marker=: a caret and a marked range. A negative index counts
/// from the end, so Shoes 3 editors' `cursor = -1` sits after the last character.
pub fn draw_para_cursor(canvas: &mut Canvas, node: &Node, tb: &TextBox, clip: Option<Rect>) {
    let buffer = &tb.shaped.buffer;
    let char_index = |key: &str| {
        let index = node.props.get(key)?.as_i64()?;
        let len = buffer.lines.iter().map(|l| l.text().chars().count() + 1).sum::<usize>().saturating_sub(1) as i64;
        Some(if index < 0 { (len + 1 + index).max(0) } else { index } as usize)
    };
    let Some(index) = char_index("text_cursor") else { return };
    let cursor = cursor_at_char(buffer, index);
    if let Some(marker) = char_index("text_marker") {
        let other = cursor_at_char(buffer, marker);
        let (a, b) = if (other.line, other.index) < (cursor.line, cursor.index) { (other, cursor) } else { (cursor, other) };
        for r in selection_rects(buffer, a, b) {
            let (top, h) = tb.shaped.line_box(r.y, r.h);
            canvas.fill_rect(Rect::new(tb.x + r.x, tb.y + top, r.w, h), SELECTION, clip);
        }
    }
    if let Some((cx, top, h)) = caret_position(buffer, cursor) {
        let s = canvas.scale;
        let (top, h) = tb.shaped.line_box(top, h);
        let rect = Rect::new(((tb.x + cx) * s).round() / s, tb.y + top, 1.0_f32.max(1.0 / s), h);
        // In the text's own colour, so the caret shows on dark backgrounds too.
        let color = tb.shaped.metas.first().map_or(INK, |m| m.color);
        canvas.fill_rect(rect, color, clip);
    }
}
