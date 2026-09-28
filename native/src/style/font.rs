//! Font sizes, weights and Pango-ish font strings.

use serde_json::Value;

/// The Shoes text block sizes (manual, Calzini).
pub fn named_size(name: &str) -> Option<f32> {
    Some(match name.trim_start_matches(':') {
        "banner" => 48.0,
        "title" => 34.0,
        "subtitle" => 26.0,
        "tagline" => 18.0,
        "caption" => 14.0,
        "para" => 12.0,
        "inscription" | "ins" => 10.0,
        _ => return None,
    })
}

/// "x-small": 64% of the present size (manual 1393-1408), what sub and sup default to.
pub const X_SMALL: f32 = 0.64;

/// Relative size words from the manual, as a factor of the present size.
fn relative_size(name: &str) -> Option<f32> {
    Some(match name {
        "xx-small" => 0.57,
        "x-small" => X_SMALL,
        "small" => 0.83,
        "medium" => 1.0,
        "large" => 1.2,
        "x-large" => 1.43,
        "xx-large" => 1.73,
        _ => return None,
    })
}

/// A `size` value resolved against the size it would otherwise have.
pub fn parse_size(value: &Value, present: f32) -> Option<f32> {
    size_of(value, present).filter(|v| v.is_finite()).map(|v| v.min(1000.0))
}

/// A text block's `size` in pixels, as the app's text mode reads it: a relative word is a
/// share of the present size (already pixels), "18px" is pixels, and any other size is in the
/// mode's units. Lacci hands a `font` string's size over as `size` too, and Pango reads a
/// font string's "px" as pixels.
pub fn text_size(value: &Value, present: f32, mode: crate::text::TextMode) -> Option<f32> {
    let fixed = value.as_str().is_some_and(|s| relative_size(s.trim()).is_some() || s.trim().ends_with("px"));
    let size = parse_size(value, present)?;
    Some(if fixed { size } else { mode.px(size).min(1000.0) })
}

fn size_of(value: &Value, present: f32) -> Option<f32> {
    match value {
        Value::Number(n) => n.as_f64().map(|v| v as f32).filter(|v| *v > 0.0),
        Value::String(s) => {
            let s = s.trim();
            named_size(s)
                .or_else(|| relative_size(s).map(|f| present * f))
                .or_else(|| s.strip_suffix("px").unwrap_or(s).trim().parse::<f32>().ok().filter(|v| *v > 0.0))
        }
        _ => None,
    }
}

/// CSS/Pango weight names and numbers to a numeric weight.
pub fn parse_weight(value: &Value) -> Option<u16> {
    match value {
        Value::Number(n) => n.as_u64().map(|w| w.clamp(100, 1000) as u16),
        Value::String(s) => weight_word(s.trim()),
        Value::Bool(true) => Some(700),
        _ => None,
    }
}

fn weight_word(word: &str) -> Option<u16> {
    Some(match word.to_ascii_lowercase().as_str() {
        "thin" | "hairline" => 100,
        "ultralight" | "extralight" => 200,
        "light" => 300,
        "normal" | "regular" | "book" => 400,
        "medium" => 500,
        "semibold" | "demibold" => 600,
        "bold" | "strong" | "bolder" => 700,
        "ultrabold" | "extrabold" => 800,
        "heavy" | "black" => 900,
        "lighter" => 300,
        n => return n.parse::<u16>().ok().filter(|w| (100..=1000).contains(w)),
    })
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FontSpec {
    pub family: Option<String>,
    pub weight: Option<u16>,
    pub italic: bool,
    pub size: Option<f32>,
    /// The size was written in `px`, which Pango reads as pixels whatever else is points.
    pub size_px: bool,
}

/// "[FAMILY-LIST] [STYLE-OPTIONS] [SIZE]", e.g. "Helvetica bold 18px", "Monospace 14".
pub fn parse_font(s: &str) -> FontSpec {
    let mut spec = FontSpec::default();
    let mut family = Vec::new();
    for word in s.split_whitespace() {
        let lower = word.trim_end_matches(',').to_ascii_lowercase();
        if lower.chars().any(|c| c.is_ascii_digit()) {
            let num = lower.trim_end_matches("px").trim_end_matches("pt");
            if let Ok(v) = num.parse::<f32>() {
                if (100.0..=1000.0).contains(&v) && v % 100.0 == 0.0 && spec.weight.is_none() && !lower.ends_with("px") {
                    spec.weight = Some(v as u16);
                } else if v.is_finite() && v > 0.0 {
                    spec.size = Some(v.min(1000.0));
                    spec.size_px = lower.ends_with("px");
                }
                continue;
            }
        }
        match lower.as_str() {
            "italic" | "oblique" => spec.italic = true,
            "normal" | "small-caps" | "smallcaps" => {}
            _ => match weight_word(&lower) {
                Some(w) if lower != "black" || !family.is_empty() => spec.weight = Some(w),
                _ => family.push(word),
            },
        }
    }
    if !family.is_empty() {
        spec.family = Some(family.join(" ").trim_end_matches([',', ';']).to_string());
    }
    spec
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn sizes() {
        assert_eq!(parse_size(&json!("title"), 12.0), Some(34.0));
        assert_eq!(parse_size(&json!(":banner"), 12.0), Some(48.0));
        assert_eq!(parse_size(&json!(22), 12.0), Some(22.0));
        assert_eq!(parse_size(&json!("18px"), 12.0), Some(18.0));
        assert_eq!(parse_size(&json!("large"), 10.0), Some(12.0));
        assert_eq!(parse_size(&json!(0.5), 12.0), Some(0.5));
        assert_eq!(parse_size(&json!(null), 12.0), None);
    }

    #[test]
    fn weights() {
        assert_eq!(parse_weight(&json!("bold")), Some(700));
        assert_eq!(parse_weight(&json!("ultralight")), Some(200));
        assert_eq!(parse_weight(&json!(600)), Some(600));
        assert_eq!(parse_weight(&json!("600")), Some(600));
        assert_eq!(parse_weight(&json!("wobbly")), None);
    }

    #[test]
    fn font_strings() {
        let f = parse_font("Helvetica bold 18px");
        assert_eq!(f.family.as_deref(), Some("Helvetica"));
        assert_eq!(f.weight, Some(700));
        assert_eq!(f.size, Some(18.0));
        let f = parse_font("Monospace 14");
        assert_eq!(f.family.as_deref(), Some("Monospace"));
        assert_eq!(f.size, Some(14.0));
        let f = parse_font("Times New Roman italic");
        assert_eq!(f.family.as_deref(), Some("Times New Roman"));
        assert!(f.italic);
        let f = parse_font("italic normal bold 16px 'Times New Roman', serif;");
        assert_eq!(f.family.as_deref(), Some("'Times New Roman', serif"));
        assert_eq!((f.weight, f.size, f.italic), (Some(700), Some(16.0), true));
    }
}
