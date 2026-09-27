//! Shaped text keyed by content, style and width, so an unchanged para is
//! shaped once no matter how often the tree is laid out again.

use super::rich::{Align, RichText, Underline, WrapMode};
use crate::props::Id;
use crate::style::Color;
use cosmic_text::{Attrs, Buffer, Ellipsize, EllipsizeHeightLimit, Family, FontSystem, Metrics, Shaping, Style, UnderlineStyle, Weight, Wrap};
use std::collections::HashMap;
use std::rc::Rc;

/// What paint and hit-testing need to know about one styled run, found
/// through `LayoutGlyph::metadata - 1`.
#[derive(Clone, Debug, PartialEq)]
pub struct SpanMeta {
    pub node: Id,
    /// The span fragments the text sits in, innermost first.
    pub spans: Vec<Id>,
    pub link: Option<Id>,
    pub rise: f32,
    pub highlight: Option<Color>,
    pub explicit_color: bool,
    pub underline: Underline,
    pub strike: bool,
    pub color: Color,
}

impl SpanMeta {
    pub fn decorated(&self) -> bool {
        self.underline != Underline::None || self.strike
    }
}

#[derive(Clone)]
pub struct ShapedText {
    pub buffer: Rc<Buffer>,
    pub width: f32,
    pub height: f32,
    pub metas: Rc<Vec<SpanMeta>>,
    pub fill: Option<Color>,
}

impl ShapedText {
    pub fn meta(&self, metadata: usize) -> Option<&SpanMeta> {
        metadata.checked_sub(1).and_then(|i| self.metas.get(i))
    }
}

#[derive(Default)]
pub struct ShapeCache {
    entries: HashMap<u64, (ShapedText, u64)>,
    generation: u64,
}

impl ShapeCache {
    /// `optical_tracking`: the sans face is San Francisco, which cosmic-text
    /// always renders at its display optical size; small text gets the extra
    /// tracking its text optical size would have had.
    pub fn get(&mut self, fs: &mut FontSystem, rich: &RichText, width: Option<f32>, optical_tracking: bool) -> ShapedText {
        let key = rich.cache_key(width);
        let generation = self.generation;
        if let Some((shaped, used)) = self.entries.get_mut(&key) {
            *used = generation;
            return shaped.clone();
        }
        let shaped = shape(fs, rich, width, optical_tracking);
        self.entries.insert(key, (shaped.clone(), generation));
        shaped
    }

    /// Drops text nobody asked for in the last two layouts.
    pub fn sweep(&mut self) {
        let keep_from = self.generation.saturating_sub(1);
        self.entries.retain(|_, (_, used)| *used >= keep_from);
        self.generation += 1;
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}

fn shape(fs: &mut FontSystem, rich: &RichText, width: Option<f32>, optical_tracking: bool) -> ShapedText {
    let mut buffer = Buffer::new(fs, Metrics::new(rich.size.max(1.0), rich.line_height));
    buffer.set_wrap(match rich.wrap {
        WrapMode::Word => Wrap::WordOrGlyph,
        WrapMode::Char => Wrap::Glyph,
        WrapMode::Trim => Wrap::None,
    });
    // "trim": cut the line off with an ellipsis if it goes too long (manual 1552-1556).
    if rich.wrap == WrapMode::Trim {
        buffer.set_ellipsize(Ellipsize::End(EllipsizeHeightLimit::Lines(1)));
    }
    buffer.set_size(width.map(|w| w.max(1.0)), None);
    let align = match rich.align {
        Align::Left => cosmic_text::Align::Left,
        Align::Center => cosmic_text::Align::Center,
        Align::Right => cosmic_text::Align::Right,
        Align::Justify => cosmic_text::Align::Justified,
    };
    let metas: Vec<SpanMeta> = rich
        .runs
        .iter()
        .map(|run| SpanMeta {
            node: run.node,
            spans: run.spans.clone(),
            link: run.style.link,
            rise: run.style.rise,
            highlight: run.style.highlight,
            explicit_color: run.style.explicit_color,
            underline: run.style.underline,
            strike: run.style.strike,
            color: run.style.color,
        })
        .collect();
    let spans: Vec<(&str, Attrs)> = rich
        .runs
        .iter()
        .enumerate()
        .map(|(i, run)| (run.text.as_str(), attrs_for(run, i + 1, rich, optical_tracking)))
        .collect();
    let defaults = Attrs::new().family(Family::SansSerif);
    buffer.set_rich_text(spans, &defaults, Shaping::Advanced, Some(align));
    buffer.shape_until_scroll(fs, false);
    let (mut w, mut h) = (0.0f32, 0.0f32);
    for run in buffer.layout_runs() {
        w = w.max(run.line_w);
        h = h.max(run.line_top + run.line_height);
    }
    if h == 0.0 {
        h = rich.line_height;
    }
    ShapedText { buffer: Rc::new(buffer), width: w, height: h, metas: Rc::new(metas), fill: rich.fill }
}

/// Every run names its line height: cosmic-text sizes a line by the runs that do, so a
/// lone small `sub` would otherwise shrink its whole line. Text a `rise` moves out of its
/// line makes room for itself, on both sides, since cosmic-text centres glyphs in a line.
fn run_line_height(s: &super::rich::TextStyle, rich: &RichText) -> f32 {
    let own = s.size * super::rich::LINE_HEIGHT + (rich.line_height - rich.size * super::rich::LINE_HEIGHT);
    (own.max(rich.line_height) + 2.0 * rise_overhang(s.size, s.rise, rich.size)).max(1.0)
}

/// How far text of `size`, moved by `rise`, pokes out of a line of `line_size` text.
/// Ascent and descent are taken as 0.9 and 0.25 em, near enough for Inter and San Francisco.
fn rise_overhang(size: f32, rise: f32, line_size: f32) -> f32 {
    if rise > 0.0 {
        (rise + 0.9 * (size - line_size)).max(0.0)
    } else {
        (-rise + 0.25 * (size - line_size)).max(0.0)
    }
}

/// Extra tracking (em) for San Francisco below 20px, approximating SF Text.
fn optical_tracking_em(size: f32) -> f32 {
    ((20.0 - size) * 0.0035).clamp(0.0, 0.035)
}

fn attrs_for<'a>(run: &'a super::rich::Run, metadata: usize, rich: &RichText, optical_tracking: bool) -> Attrs<'a> {
    let s = &run.style;
    let mut attrs = Attrs::new()
        .family(s.family.as_family())
        .weight(Weight(s.weight))
        .style(if s.italic { Style::Italic } else { Style::Normal })
        .color(s.color.to_cosmic())
        .metadata(metadata);
    attrs = attrs.metrics(Metrics::new(s.size.max(1.0), run_line_height(s, rich)));
    let tracking = if optical_tracking && s.family == super::fonts::FamilyName::Sans { optical_tracking_em(s.size) } else { 0.0 };
    if (s.letter_spacing != 0.0 || tracking != 0.0) && s.size > 0.0 {
        attrs = attrs.letter_spacing(s.letter_spacing / s.size + tracking);
    }
    match s.underline {
        Underline::None => {}
        Underline::Double => attrs = attrs.underline(UnderlineStyle::Double),
        // Low and error lines are drawn by paint; cosmic-text only needs to know one exists.
        Underline::Single | Underline::Low | Underline::Error => attrs = attrs.underline(UnderlineStyle::Single),
    }
    if let Some(c) = s.underline_color {
        attrs = attrs.underline_color(c.to_cosmic());
    }
    if s.strike {
        attrs = attrs.strikethrough();
        if let Some(c) = s.strike_color {
            attrs = attrs.strikethrough_color(c.to_cosmic());
        }
    }
    attrs
}
