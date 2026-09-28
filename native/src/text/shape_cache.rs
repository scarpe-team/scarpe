//! Shaped text keyed by content, style and width, so an unchanged para is
//! shaped once no matter how often the tree is laid out again.

use super::rich::{Align, RichText, Underline, WrapMode};
use crate::props::Id;
use crate::style::Color;
use cosmic_text::{
    Attrs, Buffer, Cursor, Ellipsize, EllipsizeHeightLimit, Family, FeatureTag, FontFeatures, FontSystem, Metrics, Shaping, Style, UnderlineStyle,
    Weight, Wrap,
};
use std::borrow::Cow;
use std::collections::{HashMap, HashSet};
use std::rc::Rc;

/// Synthesised small capitals are capitals this much smaller than the text: about the height of
/// its lower-case letters.
const SMALL_CAPS_SCALE: f32 = 0.78;

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
    /// From the top of the first line to the bottom of the last: leading only between lines.
    pub height: f32,
    /// Where the buffer's origin sits against the text's top edge. cosmic-text centres a
    /// line's leading in the line, so the first line would otherwise start half of it low.
    pub top: f32,
    pub metas: Rc<Vec<SpanMeta>>,
    /// The first-line indent, in px, of text that continues a line in a flow; 0 otherwise.
    pub indent: f32,
    /// How far left and right the glyphs' boxes reach, in buffer coordinates. Tight negative
    /// `kerning` pulls glyphs left of 0 and past `width`.
    pub ink: (f32, f32),
    /// The app's own text, when the buffer shapes other letters for it (synthesised small
    /// capitals shape capitals for lower-case letters, one for one).
    written: Option<Rc<str>>,
    /// The text ends in a newline that cosmic-text keeps no line for. Pango lays out an empty
    /// line under it, and a caret after it sits at that line's start (s3t_textblock.c:217-228).
    pub closing_newline: bool,
}

/// The metadata of the blank that makes a first-line indent. It maps to no SpanMeta, so the
/// indent carries no colour, decoration or link, and paint skips it.
pub const INDENT_META: usize = usize::MAX;

/// cosmic-text has no first-line indent, so an indented buffer starts with one blank this
/// small whose letter spacing makes it exactly as wide as the indent. At this size it adds
/// nothing to the line's ascent, and the line may still break after it.
const INDENT_SIZE: f32 = 0.001;

impl ShapedText {
    pub fn meta(&self, metadata: usize) -> Option<&SpanMeta> {
        metadata.checked_sub(1).and_then(|i| self.metas.get(i))
    }

    /// Characters the buffer holds before the text itself: the indent's blank.
    fn lead(&self) -> usize {
        usize::from(self.indent > 0.0)
    }

    /// Whether the first line kept its indent. cosmic-text drops the blank when not even the
    /// first word fits after it, and then the text cannot continue the line it started on.
    pub fn indent_holds(&self) -> bool {
        self.buffer.layout_runs().next().and_then(|run| run.glyphs.first()).is_some_and(|g| g.metadata == INDENT_META)
    }

    /// The text as the app gave it, lines joined by newlines.
    pub fn text(&self) -> String {
        if let Some(written) = &self.written {
            return written.to_string();
        }
        let text = self.buffer.lines.iter().map(|l| l.text()).collect::<Vec<_>>().join("\n");
        let mut text: String = text.chars().skip(self.lead()).collect();
        if self.closing_newline {
            text.push('\n');
        }
        text
    }

    /// The empty line under a closing newline, `(top, height)` in buffer coordinates.
    pub fn line_after_end(&self) -> Option<(f32, f32)> {
        if !self.closing_newline {
            return None;
        }
        let line_height = self.buffer.metrics().line_height;
        let top = self.buffer.layout_runs().last().map_or(0.0, |run| run.line_top + run.line_height);
        Some((top, line_height))
    }

    /// A buffer position as an index into `text()`, in characters.
    pub fn char_index(&self, cursor: Cursor) -> usize {
        let lines = &self.buffer.lines;
        let before: usize = lines.iter().take(cursor.line).map(|l| l.text().chars().count() + 1).sum();
        let text = lines.get(cursor.line).map(|l| l.text()).unwrap_or("");
        let within = text[..cursor.index.min(text.len())].chars().count();
        (before + within).saturating_sub(self.lead())
    }

    /// The buffer position of a character index into `text()`; past the end is the end.
    pub fn cursor_at(&self, index: usize) -> Cursor {
        let mut remaining = index + self.lead();
        for (line_i, line) in self.buffer.lines.iter().enumerate() {
            let text = line.text();
            let chars = text.chars().count();
            if remaining <= chars {
                let byte = text.char_indices().nth(remaining).map(|(b, _)| b).unwrap_or(text.len());
                return Cursor::new(line_i, byte);
            }
            remaining -= chars + 1;
        }
        let last = self.buffer.lines.len().saturating_sub(1);
        Cursor::new(last, self.buffer.lines.get(last).map(|l| l.text().len()).unwrap_or(0))
    }

    /// The part of a line its text fills, `(top, height)` in buffer coordinates: the line
    /// less the half of the leading cosmic-text puts above and below it.
    pub fn line_box(&self, line_top: f32, line_height: f32) -> (f32, f32) {
        (line_top - self.top, (line_height + 2.0 * self.top).max(0.0))
    }
}

#[derive(Default)]
pub struct ShapeCache {
    entries: HashMap<u64, (ShapedText, u64)>,
    generation: u64,
    /// The layout in progress: whose it is (an app's document root) and the text it asked for.
    layout: Option<(Id, HashSet<u64>)>,
    /// The text each app's last layout used. It stays while that layout does, however many
    /// other apps lay out in between.
    in_use: HashMap<Id, HashSet<u64>>,
    /// How many texts have been shaped, cache misses all.
    shaped: u64,
}

impl ShapeCache {
    /// `optical_tracking`: the sans face is San Francisco, which cosmic-text
    /// always renders at its display optical size; small text gets the extra
    /// tracking its text optical size would have had.
    pub fn get(&mut self, fs: &mut FontSystem, rich: &RichText, width: Option<f32>, indent: f32, optical_tracking: bool) -> ShapedText {
        let key = rich.cache_key(width) ^ indent.to_bits().rotate_left(17) as u64;
        if let Some((_, used)) = self.layout.as_mut() {
            used.insert(key);
        }
        let generation = self.generation;
        if let Some((shaped, used)) = self.entries.get_mut(&key) {
            *used = generation;
            return shaped.clone();
        }
        let shaped = shape(fs, rich, width, indent, optical_tracking);
        self.shaped += 1;
        self.entries.insert(key, (shaped.clone(), generation));
        shaped
    }

    /// A layout of the app whose document root is `owner` begins.
    pub fn begin_layout(&mut self, owner: Id) {
        self.layout = Some((owner, HashSet::new()));
    }

    /// A layout ended: what it used is kept for as long as its app's layout stands. Text no
    /// app's layout uses, and nobody asked for in the last two layouts (paint shapes some of
    /// its own), goes.
    pub fn sweep(&mut self) {
        if let Some((owner, used)) = self.layout.take() {
            self.in_use.insert(owner, used);
        }
        let keep_from = self.generation.saturating_sub(1);
        let in_use = &self.in_use;
        self.entries.retain(|key, (_, used)| *used >= keep_from || in_use.values().any(|keys| keys.contains(key)));
        self.generation += 1;
    }

    /// An app closed: its text no longer has to stay.
    pub fn forget_layout(&mut self, owner: Id) {
        self.in_use.remove(&owner);
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn shaped(&self) -> u64 {
        self.shaped
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}

fn shape(fs: &mut FontSystem, rich: &RichText, width: Option<f32>, indent: f32, optical_tracking: bool) -> ShapedText {
    let indent = if rich.runs.is_empty() { 0.0 } else { indent.max(0.0) };
    let mut buffer = Buffer::new(fs, Metrics::new(rich.size.max(1.0), rich.line_height));
    buffer.set_wrap(match rich.wrap {
        // "word" breaks at word breaks only; a word too long for its line runs past it, as
        // under Shoes 3's default PANGO_WRAP_WORD (manual 1552-1556).
        WrapMode::Word => Wrap::Word,
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
    let mut pieces: Vec<(Cow<str>, Attrs)> = Vec::with_capacity(rich.runs.len() + 1);
    if indent > 0.0 {
        pieces.push((Cow::Borrowed(" "), indent_attrs(&rich.runs[0], indent, rich)));
    }
    for (i, run) in rich.runs.iter().enumerate() {
        let attrs = attrs_for(run, i + 1, rich, optical_tracking);
        if run.style.small_caps {
            small_caps(fs, run, attrs, rich, &mut pieces);
        } else {
            pieces.push((Cow::Borrowed(run.text.as_str()), attrs));
        }
    }
    let written = pieces.iter().any(|(text, _)| matches!(text, Cow::Owned(_))).then(|| Rc::from(rich.plain_text()));
    let spans: Vec<(&str, Attrs)> = pieces.iter().map(|(text, attrs)| (text.as_ref(), attrs.clone())).collect();
    let defaults = Attrs::new().family(Family::SansSerif);
    buffer.set_rich_text(spans, &defaults, Shaping::Advanced, Some(align));
    buffer.shape_until_scroll(fs, false);
    let (mut w, mut h) = (0.0f32, 0.0f32);
    let mut ink = (0.0f32, 0.0f32);
    for run in buffer.layout_runs() {
        w = w.max(run.line_w);
        h = h.max(run.line_top + run.line_height);
        for glyph in run.glyphs {
            ink = (ink.0.min(glyph.x), ink.1.max(glyph.x + glyph.w));
        }
    }
    if h == 0.0 {
        h = rich.line_height;
    }
    let newlines: usize = rich.runs.iter().map(|run| run.text.matches('\n').count()).sum();
    let closing_newline = rich.runs.last().is_some_and(|run| run.text.ends_with('\n')) && buffer.lines.len() <= newlines;
    if closing_newline {
        // The empty line Pango keeps under a closing newline is part of the text's height.
        h += rich.line_height;
    }
    let height = (h - rich.leading).max(1.0);
    ShapedText { buffer: Rc::new(buffer), width: w, height, top: -rich.leading / 2.0, metas: Rc::new(metas), indent, ink, written, closing_newline }
}

/// A run in small capitals (`variant: "smallcaps"`, manual 1511-1519): the face's own when it has
/// them (OpenType `smcp`), else lower-case letters drawn as capitals SMALL_CAPS_SCALE of the size.
/// A letter keeps one character either way, so indexes into the text still hold.
fn small_caps<'a>(fs: &mut FontSystem, run: &'a super::rich::Run, attrs: Attrs<'a>, rich: &RichText, pieces: &mut Vec<(Cow<'a, str>, Attrs<'a>)>) {
    if has_small_caps(fs, &attrs) {
        let mut features = FontFeatures::new();
        features.enable(FeatureTag::SMALL_CAPS);
        pieces.push((Cow::Borrowed(run.text.as_str()), attrs.font_features(features)));
        return;
    }
    let smaller = attrs.clone().metrics(Metrics::new((run.style.size * SMALL_CAPS_SCALE).max(1.0), run_line_height(&run.style, rich)));
    let mut lowered: Option<(String, bool)> = None;
    for c in run.text.chars() {
        let mut upper = c.to_uppercase();
        let (shown, small) = match (upper.next(), upper.next()) {
            (Some(capital), None) if c.is_lowercase() => (capital, true),
            _ => (c, false),
        };
        match lowered.as_mut() {
            Some((text, was_small)) if *was_small == small => text.push(shown),
            _ => {
                if let Some((text, was_small)) = lowered.replace((shown.to_string(), small)) {
                    pieces.push((Cow::Owned(text), if was_small { smaller.clone() } else { attrs.clone() }));
                }
            }
        }
    }
    if let Some((text, small)) = lowered {
        pieces.push((Cow::Owned(text), if small { smaller } else { attrs }));
    }
}

/// Whether the face `attrs` asks for has small capitals of its own (OpenType `smcp`).
fn has_small_caps(fs: &mut FontSystem, attrs: &Attrs) -> bool {
    let query = cosmic_text::fontdb::Query { families: &[attrs.family], weight: attrs.weight, stretch: attrs.stretch, style: attrs.style };
    let Some(id) = fs.db().query(&query) else { return false };
    let Some(font) = fs.get_font(id, attrs.weight) else { return false };
    let smcp = swash::tag_from_bytes(b"smcp");
    let has = font.as_swash().writing_systems().any(|system| system.features().any(|feature| feature.tag() == smcp));
    has
}

/// The blank that stands in for a first-line indent: the first run's face, so no font
/// fallback, the text's own line height, and letter spacing (in em) for the width.
fn indent_attrs<'a>(first: &'a super::rich::Run, indent: f32, rich: &RichText) -> Attrs<'a> {
    let s = &first.style;
    Attrs::new()
        .family(s.family.as_family())
        .weight(Weight(s.weight))
        .style(if s.italic { Style::Italic } else { Style::Normal })
        .metrics(Metrics::new(INDENT_SIZE, rich.line_height))
        .letter_spacing(indent / INDENT_SIZE)
        .metadata(INDENT_META)
}

/// Every run names its line height: cosmic-text sizes a line by the runs that do, so a
/// lone small `sub` would otherwise shrink its whole line. Text a `rise` moves out of its
/// line makes room for itself, on both sides, since cosmic-text centres glyphs in a line.
fn run_line_height(s: &super::rich::TextStyle, rich: &RichText) -> f32 {
    let own = s.size * super::rich::LINE_HEIGHT + (rich.line_height - rich.size * super::rich::LINE_HEIGHT);
    let own = if rich.own_line_heights { own } else { own.max(rich.line_height) };
    (own + 2.0 * rise_overhang(s.size, s.rise, rich.size)).max(1.0)
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
