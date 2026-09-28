//! Resolving a Para's text_items tree (Strings and ids of span nodes) into
//! styled runs that cosmic-text can shape.

use super::fonts::{FamilyName, Fonts};
use crate::doc::{Doc, Kind};
use crate::props::{Id, Props, TextItem};
use crate::style::color::Color;
use crate::style::font::{named_size, parse_font, parse_weight, text_size, X_SMALL};
use std::hash::{Hash, Hasher};

pub const INK: Color = Color::rgb(0x1d, 0x1d, 0x1f);
pub const LINK: Color = Color::rgb(0x00, 0x66, 0xee);
pub const LINK_HOVER: Color = Color::rgb(0x00, 0x33, 0x99);
pub const DEFAULT_SIZE: f32 = 12.0;
pub const LINE_HEIGHT: f32 = 1.2;
/// Space between the lines of a text block unless it says otherwise (manual 1286, Shoes 3).
pub const DEFAULT_LEADING: f32 = 4.0;
/// How far sub and sup move their baseline, in pixels.
pub const SCRIPT_RISE: f32 = 10.0;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Underline {
    None,
    Single,
    Double,
    Low,
    Error,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Align {
    Left,
    Center,
    Right,
    Justify,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum WrapMode {
    Word,
    Char,
    Trim,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TextStyle {
    pub family: FamilyName,
    pub weight: u16,
    pub italic: bool,
    pub size: f32,
    pub color: Color,
    pub underline: Underline,
    pub underline_color: Option<Color>,
    pub strike: bool,
    pub strike_color: Option<Color>,
    pub letter_spacing: f32,
    pub rise: f32,
    pub highlight: Option<Color>,
    pub link: Option<Id>,
    /// Links recolour on hover unless the app gave them a colour.
    pub explicit_color: bool,
    /// `variant: "smallcaps"` (manual 1511-1519, ledger F4): lower-case letters as small capitals.
    pub small_caps: bool,
}

impl TextStyle {
    pub fn new(size: f32, color: Color) -> Self {
        TextStyle {
            family: FamilyName::Sans,
            weight: 400,
            italic: false,
            size,
            color,
            underline: Underline::None,
            underline_color: None,
            strike: false,
            strike_color: None,
            letter_spacing: 0.0,
            rise: 0.0,
            highlight: None,
            link: None,
            explicit_color: false,
            small_caps: false,
        }
    }

    fn hash_into<H: Hasher>(&self, h: &mut H) {
        self.family.hash(h);
        self.weight.hash(h);
        self.italic.hash(h);
        self.size.to_bits().hash(h);
        self.color.hash(h);
        self.underline.hash(h);
        self.underline_color.hash(h);
        self.strike.hash(h);
        self.strike_color.hash(h);
        self.letter_spacing.to_bits().hash(h);
        self.rise.to_bits().hash(h);
        self.highlight.hash(h);
        self.link.hash(h);
        self.explicit_color.hash(h);
        self.small_caps.hash(h);
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Run {
    pub text: String,
    pub style: TextStyle,
    /// The node whose text_items held this string (the para or a span).
    pub node: Id,
    /// The span fragments this text sits in, innermost first (empty for the para's own text).
    pub spans: Vec<Id>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RichText {
    pub runs: Vec<Run>,
    pub size: f32,
    /// The distance from one line to the next: 1.2 x size plus `leading`.
    pub line_height: f32,
    /// Extra space between lines (manual 1286); none above the first or below the last.
    pub leading: f32,
    pub align: Align,
    pub wrap: WrapMode,
    /// Each line as tall as its own text, as Pango sets lines (Shoes 3's text mode): a line of
    /// small text under a big title is short. Otherwise a line is never shorter than the
    /// block's own line height, so a lone `sub` cannot shrink it.
    pub own_line_heights: bool,
}

impl RichText {
    pub fn plain(text: &str, style: TextStyle) -> Self {
        let size = style.size;
        RichText {
            runs: vec![Run { text: text.to_string(), style, node: 0, spans: Vec::new() }],
            size,
            line_height: (size * LINE_HEIGHT).max(1.0),
            leading: 0.0,
            align: Align::Left,
            wrap: WrapMode::Word,
            own_line_heights: false,
        }
    }

    pub fn plain_text(&self) -> String {
        self.runs.iter().map(|r| r.text.as_str()).collect()
    }

    pub fn cache_key(&self, width: Option<f32>) -> u64 {
        let mut h = std::collections::hash_map::DefaultHasher::new();
        // Ids are part of the key: the shaped text carries them back for hit-testing.
        for run in &self.runs {
            run.text.hash(&mut h);
            run.style.hash_into(&mut h);
            run.node.hash(&mut h);
            run.spans.hash(&mut h);
        }
        self.size.to_bits().hash(&mut h);
        self.line_height.to_bits().hash(&mut h);
        self.leading.to_bits().hash(&mut h);
        self.align.hash(&mut h);
        self.wrap.hash(&mut h);
        self.own_line_heights.hash(&mut h);
        width.map(f32::to_bits).hash(&mut h);
        h.finish()
    }
}

/// The default size of a text block by the class Lacci sent.
pub fn class_size(class: &str) -> f32 {
    named_size(&class.to_ascii_lowercase()).unwrap_or(DEFAULT_SIZE)
}

/// A Para (or a standalone TextDrawable) as styled runs.
pub fn resolve_block(doc: &Doc, fonts: &Fonts, id: Id) -> Option<RichText> {
    let node = doc.get(id)?;
    let mut style = TextStyle::new(fonts.text_mode.px(class_size(&node.class)), INK);
    style.family = fonts.text_face();
    apply_text_props(&mut style, &node.props, fonts);
    // A block's fill is a highlighter over its text, not paint over its box (manual 1208-1210;
    // Shoes 3 makes it a Pango background, s3t_textblock.c:258, 477).
    style.highlight = node.props.color("fill").filter(|c| !c.is_invisible());
    let mut runs = Vec::new();
    collect(doc, fonts, &node.props, &style, id, &[], &mut runs);
    let leading = node.props.f32("leading").unwrap_or(DEFAULT_LEADING).max(0.0);
    let align = if node.props.truthy("justify") {
        Align::Justify
    } else {
        match node.props.str("align") {
            Some("center") => Align::Center,
            Some("right") => Align::Right,
            _ => Align::Left,
        }
    };
    let wrap = match node.props.str("wrap") {
        Some("trim") => WrapMode::Trim,
        Some("char") => WrapMode::Char,
        _ => WrapMode::Word,
    };
    Some(RichText {
        runs,
        size: style.size,
        line_height: (style.size * LINE_HEIGHT + leading).max(1.0),
        leading,
        align,
        wrap,
        own_line_heights: fonts.text_mode == super::fonts::TextMode::Shoes3,
    })
}

fn collect(doc: &Doc, fonts: &Fonts, props: &Props, style: &TextStyle, owner: Id, spans: &[Id], runs: &mut Vec<Run>) {
    if spans.len() > 32 {
        return;
    }
    for item in props.text_items() {
        match item {
            TextItem::Str(text) => {
                if !text.is_empty() {
                    runs.push(Run { text, style: style.clone(), node: owner, spans: spans.to_vec() });
                }
            }
            TextItem::Ref(span_id) => {
                let Some(span) = doc.get(span_id) else { continue };
                if spans.contains(&span_id) {
                    continue;
                }
                if !(span.kind.is_span() || span.kind == Kind::TextDrawable) || span.props.truthy("hidden") {
                    continue;
                }
                let mut inner = style.clone();
                inner.highlight = None;
                apply_span_kind(&mut inner, &span.kind, span_id, style.size);
                apply_text_props(&mut inner, &span.props, fonts);
                if let Some(fill) = span.props.color("fill").filter(|c| !c.is_invisible()) {
                    inner.highlight = Some(fill);
                } else {
                    inner.highlight = style.highlight;
                }
                let mut path = Vec::with_capacity(spans.len() + 1);
                path.push(span_id);
                path.extend_from_slice(spans);
                collect(doc, fonts, &span.props, &inner, span_id, &path, runs);
            }
        }
    }
}

fn apply_span_kind(style: &mut TextStyle, kind: &Kind, id: Id, parent_size: f32) {
    match kind {
        Kind::Strong => style.weight = 700,
        Kind::Em => style.italic = true,
        Kind::Code => style.family = FamilyName::Mono,
        Kind::Del => style.strike = true,
        Kind::Ins => style.underline = Underline::Single,
        // Manual 2093-2105: "x-small", lowered or raised by 10 pixels.
        Kind::Sub => {
            style.size = parent_size * X_SMALL;
            style.rise = -SCRIPT_RISE;
        }
        Kind::Sup => {
            style.size = parent_size * X_SMALL;
            style.rise = SCRIPT_RISE;
        }
        Kind::Link => {
            style.color = LINK;
            style.underline = Underline::Single;
            style.link = Some(id);
        }
        _ => {}
    }
}

/// The text styles shared by Para and every span (manual "Styles" section).
pub fn apply_text_props(style: &mut TextStyle, props: &Props, fonts: &Fonts) {
    if let Some(font) = props.str("font") {
        let spec = parse_font(font);
        if let Some(family) = spec.family {
            style.family = fonts.resolve_family(&family);
        }
        if let Some(weight) = spec.weight {
            style.weight = weight;
        }
        if spec.italic {
            style.italic = true;
        }
        if let Some(size) = spec.size {
            style.size = if spec.size_px { size } else { fonts.text_mode.px(size) };
        }
    }
    if let Some(size) = props.get("size").and_then(|v| text_size(v, style.size, fonts.text_mode)) {
        style.size = size;
    }
    if let Some(family) = props.str("family") {
        style.family = fonts.resolve_family(family);
    }
    if let Some(weight) = props.get("weight").or_else(|| props.get("font_weight")).and_then(parse_weight) {
        style.weight = weight;
    }
    match props.str("emphasis") {
        Some("italic") | Some("oblique") => style.italic = true,
        Some("normal") => style.italic = false,
        _ => {}
    }
    // A see-through stroke is the end of a fade: the text goes, it does not fall back to black.
    if let Some(color) = props.color("stroke") {
        style.color = color;
        style.explicit_color = true;
    }
    if let Some(underline) = props.get("underline") {
        style.underline = match underline {
            serde_json::Value::Bool(true) => Underline::Single,
            serde_json::Value::String(s) => match s.as_str() {
                "single" => Underline::Single,
                "double" => Underline::Double,
                "low" => Underline::Low,
                "error" => Underline::Error,
                _ => Underline::None,
            },
            _ => Underline::None,
        };
    }
    if let Some(strike) = props.get("strikethrough") {
        style.strike = matches!(strike, serde_json::Value::Bool(true))
            || matches!(strike.as_str(), Some("single") | Some("double"));
    }
    if let Some(c) = props.color("undercolor") {
        style.underline_color = Some(c);
    }
    if let Some(c) = props.color("strikecolor") {
        style.strike_color = Some(c);
    }
    if let Some(k) = props.f32("kerning") {
        style.letter_spacing = k;
    }
    if let Some(r) = props.f32("rise") {
        style.rise = r;
    }
    if let Some(variant) = props.str("variant").or_else(|| props.str("font_variant")) {
        style.small_caps = matches!(variant.to_ascii_lowercase().as_str(), "smallcaps" | "small-caps" | "small_caps");
    }
    // A face the machine does not have falls back to the text's own default face.
    if style.family == FamilyName::Sans {
        style.family = fonts.text_face();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::doc::NewNode;
    use crate::text::fonts::{FontMode, TextMode};
    use serde_json::json;

    fn node(doc: &mut Doc, id: Id, class: &str, parent: Option<Id>, props: serde_json::Value) {
        doc.create(NewNode {
            id,
            class: class.into(),
            parent,
            index: None,
            widget: false,
            props: props.as_object().unwrap().clone(),
            doc_root: None,
            owner: None,
        });
    }

    #[test]
    fn nested_spans_resolve_recursively() {
        let fonts = Fonts::new(FontMode::Bundled);
        let mut doc = Doc::default();
        node(&mut doc, 2, "DocumentRoot", None, json!({}));
        node(&mut doc, 5, "Em", None, json!({"text_items": ["deep"]}));
        node(&mut doc, 6, "Strong", None, json!({"text_items": ["bold ", 5]}));
        node(&mut doc, 7, "Link", None, json!({"text_items": ["here"], "click": "http://x"}));
        node(&mut doc, 8, "Para", Some(2), json!({"text_items": ["Hi ", 6, " ", 7], "size": "para"}));
        let rich = resolve_block(&doc, &fonts, 8).unwrap();
        let texts: Vec<&str> = rich.runs.iter().map(|r| r.text.as_str()).collect();
        assert_eq!(texts, vec!["Hi ", "bold ", "deep", " ", "here"]);
        assert_eq!(rich.runs[1].style.weight, 700);
        assert!(!rich.runs[1].style.italic);
        assert_eq!(rich.runs[2].style.weight, 700);
        assert!(rich.runs[2].style.italic);
        assert_eq!(rich.runs[4].style.link, Some(7));
        assert_eq!(rich.runs[4].style.color, LINK);
        assert_eq!(rich.size, 12.0);
    }

    #[test]
    fn sub_and_sup_are_x_small_and_move_ten_pixels() {
        // Manual 2093-2105: x-small (64%), lowered or raised by 10 pixels.
        let fonts = Fonts::new(FontMode::Bundled);
        let mut doc = Doc::default();
        node(&mut doc, 2, "DocumentRoot", None, json!({}));
        node(&mut doc, 5, "Sub", None, json!({"text_items": ["2"]}));
        node(&mut doc, 6, "Sup", None, json!({"text_items": ["3"]}));
        node(&mut doc, 7, "Para", Some(2), json!({"text_items": ["x", 5, "y", 6], "size": 30}));
        let rich = resolve_block(&doc, &fonts, 7).unwrap();
        let (sub, sup) = (&rich.runs[1].style, &rich.runs[3].style);
        assert!((sub.size - 19.2).abs() < 0.01 && (sup.size - 19.2).abs() < 0.01, "{} {}", sub.size, sup.size);
        assert_eq!((sub.rise, sup.rise), (-10.0, 10.0));
    }

    #[test]
    fn none_turns_a_default_decoration_off() {
        // Contract (d): Lacci sends "none" when a style sets underline or strikethrough to nil/false,
        // as `style(Shoes::Link, underline: nil)` does in the accordion samples.
        let fonts = Fonts::new(FontMode::Bundled);
        let mut doc = Doc::default();
        node(&mut doc, 2, "DocumentRoot", None, json!({}));
        node(&mut doc, 5, "Link", None, json!({"text_items": ["plain link"], "underline": "none"}));
        node(&mut doc, 6, "Del", None, json!({"text_items": ["kept"], "strikethrough": "none"}));
        node(&mut doc, 7, "Link", None, json!({"text_items": ["usual"]}));
        node(&mut doc, 8, "Para", Some(2), json!({"text_items": [5, 6, 7]}));
        let rich = resolve_block(&doc, &fonts, 8).unwrap();
        assert_eq!(rich.runs[0].style.underline, Underline::None);
        assert!(!rich.runs[1].style.strike);
        assert_eq!(rich.runs[2].style.underline, Underline::Single, "a link keeps its underline otherwise");
    }

    #[test]
    fn a_see_through_stroke_stays_see_through() {
        // The last frame of a fade out is a stroke with alpha 0. It fell back to the default
        // black ink, which flashed the whole word black (_repros/key_splash_2.rb).
        let fonts = Fonts::new(FontMode::Bundled);
        let mut doc = Doc::default();
        node(&mut doc, 2, "DocumentRoot", None, json!({}));
        node(&mut doc, 3, "Para", Some(2), json!({"text_items": ["B"], "stroke": [255, 152, 48, 0]}));
        node(&mut doc, 4, "Em", None, json!({"text_items": ["i"], "stroke": [255, 152, 48, 0]}));
        node(&mut doc, 5, "Para", Some(2), json!({"text_items": [4], "stroke": [0, 0, 255, 255]}));
        let faded = resolve_block(&doc, &fonts, 3).unwrap();
        assert_eq!(faded.runs[0].style.color.a, 0, "{:?}", faded.runs[0].style.color);
        let span = resolve_block(&doc, &fonts, 5).unwrap();
        assert_eq!(span.runs[0].style.color.a, 0, "a see-through span inside blue text");
    }

    #[test]
    fn class_sizes_and_props() {
        let fonts = Fonts::new(FontMode::Bundled);
        let mut doc = Doc::default();
        node(&mut doc, 2, "DocumentRoot", None, json!({}));
        node(&mut doc, 3, "Para", Some(2), json!({"text_items": ["T"], "size": "title", "stroke": [255, 0, 0, 255], "align": "center"}));
        let rich = resolve_block(&doc, &fonts, 3).unwrap();
        assert_eq!(rich.size, 34.0);
        assert_eq!(rich.runs[0].style.color, Color::rgb(255, 0, 0));
        assert_eq!(rich.align, Align::Center);
        assert!((rich.line_height - 44.8).abs() < 0.01, "1.2 x 34 plus the default leading");
    }

    /// Shoes 3's text mode (ledger M14): a size is points at 96 dpi, as Shoes 3 hands Pango
    /// `size * 96/72` (s3t_textblock.c:293), so Hackety Hack's para is 16 px and its 10 point
    /// code 13.3. A relative word still scales the present size, and a font string's `px` is
    /// pixels, as Pango reads it.
    #[test]
    fn shoes3_text_is_sized_in_points() {
        let mut fonts = Fonts::new(FontMode::Bundled);
        let mut doc = Doc::default();
        node(&mut doc, 2, "DocumentRoot", None, json!({}));
        node(&mut doc, 3, "Para", Some(2), json!({"text_items": ["plain"]}));
        node(&mut doc, 4, "Para", Some(2), json!({"text_items": ["code"], "font": "Liberation Mono", "size": 10}));
        node(&mut doc, 5, "Para", Some(2), json!({"text_items": ["t"], "size": "title"}));
        node(&mut doc, 6, "Para", Some(2), json!({"text_items": ["big"], "size": "large"}));
        node(&mut doc, 7, "Para", Some(2), json!({"text_items": ["pt"], "font": "Monospace 12"}));
        node(&mut doc, 8, "Para", Some(2), json!({"text_items": ["px"], "font": "Monospace 18px"}));
        let sizes = |fonts: &Fonts| [3, 4, 5, 6, 7, 8].map(|id| resolve_block(&doc, fonts, id).unwrap().size);
        assert_eq!(sizes(&fonts), [12.0, 10.0, 34.0, 12.0 * 1.2, 12.0, 18.0], "Scarpe's pixels");
        fonts.text_mode = TextMode::Shoes3;
        let pt = 96.0 / 72.0;
        let want = [12.0 * pt, 10.0 * pt, 34.0 * pt, 12.0 * pt * 1.2, 12.0 * pt, 18.0];
        for (got, want) in sizes(&fonts).iter().zip(want) {
            assert!((got - want).abs() < 0.01, "{:?} against {want:?}", sizes(&fonts));
        }
    }
}
