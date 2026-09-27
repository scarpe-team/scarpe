//! Colours and paints as they arrive on the wire.
//!
//! The shim normalises to `{"rgba":[..]}`, `{"gradient":[c1,c2],"angle":a}` or
//! `{"image":path}`, but Lacci leaks raw values through `style(...)`, so every
//! form Shoes knows is accepted here too.

use serde_json::Value;
use std::path::PathBuf;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

impl Color {
    pub const BLACK: Color = Color::rgb(0, 0, 0);
    pub const WHITE: Color = Color::rgb(255, 255, 255);
    pub const TRANSPARENT: Color = Color::rgba(0, 0, 0, 0);

    pub const fn rgba(r: u8, g: u8, b: u8, a: u8) -> Self {
        Color { r, g, b, a }
    }

    pub const fn rgb(r: u8, g: u8, b: u8) -> Self {
        Color { r, g, b, a: 255 }
    }

    pub fn is_invisible(&self) -> bool {
        self.a == 0
    }

    pub fn with_alpha(self, a: u8) -> Self {
        Color { a, ..self }
    }

    pub fn fade(self, factor: f32) -> Self {
        self.with_alpha((self.a as f32 * factor).round().clamp(0.0, 255.0) as u8)
    }

    pub fn to_array(&self) -> [u8; 4] {
        [self.r, self.g, self.b, self.a]
    }

    pub fn to_skia(&self) -> tiny_skia::Color {
        tiny_skia::Color::from_rgba8(self.r, self.g, self.b, self.a)
    }

    pub fn to_cosmic(&self) -> cosmic_text::Color {
        cosmic_text::Color::rgba(self.r, self.g, self.b, self.a)
    }

    pub fn luminance(&self) -> f32 {
        (0.2126 * self.r as f32 + 0.7152 * self.g as f32 + 0.0722 * self.b as f32) / 255.0
    }
}

/// What a fill, stroke or background can be.
#[derive(Clone, Debug, PartialEq)]
pub enum Paint {
    Solid(Color),
    /// Shoes angle: 0 runs top to bottom, 90 runs left to right.
    Linear { from: Color, to: Color, angle: f32 },
    Image(PathBuf),
}

impl Paint {
    /// `nofill`/`nostroke` arrive as an alpha-0 colour: they mean "paint nothing".
    pub fn is_visible(&self) -> bool {
        match self {
            Paint::Solid(c) => !c.is_invisible(),
            Paint::Linear { from, to, .. } => !(from.is_invisible() && to.is_invisible()),
            Paint::Image(_) => true,
        }
    }

    /// A representative colour, for places that cannot draw a gradient (text).
    pub fn primary(&self) -> Option<Color> {
        match self {
            Paint::Solid(c) => Some(*c),
            Paint::Linear { from, .. } => Some(*from),
            Paint::Image(_) => None,
        }
    }
}

pub fn parse_paint(value: &Value) -> Option<Paint> {
    match value {
        Value::Null => None,
        Value::Object(map) => {
            if let Some(rgba) = map.get("rgba") {
                return parse_color(rgba).map(Paint::Solid);
            }
            if let Some(Value::Array(ends)) = map.get("gradient") {
                let from = ends.first().and_then(parse_color)?;
                let to = ends.get(1).and_then(parse_color).unwrap_or(from);
                let angle = map.get("angle").and_then(Value::as_f64).unwrap_or(0.0) as f32;
                return Some(Paint::Linear { from, to, angle });
            }
            if let Some(Value::String(path)) = map.get("image") {
                return Some(Paint::Image(PathBuf::from(path)));
            }
            None
        }
        Value::String(s) => parse_paint_str(s),
        _ => parse_color(value).map(Paint::Solid),
    }
}

fn parse_paint_str(s: &str) -> Option<Paint> {
    let s = s.trim();
    if let Some(color) = parse_color_str(s) {
        return Some(Paint::Solid(color));
    }
    // A colour Range after JSON: "#fff..#000".
    if let Some((a, b)) = s.split_once("..") {
        let from = parse_color_str(a)?;
        let to = parse_color_str(b.trim_start_matches('.'))?;
        return Some(Paint::Linear { from, to, angle: 0.0 });
    }
    // A Shoes::Colors::Gradient after JSON: "rgb(255,0,0)-rgb(0,0,255)".
    if let Some(idx) = s.find(")-") {
        let from = parse_color_str(&s[..=idx])?;
        let to = parse_color_str(&s[idx + 2..])?;
        return Some(Paint::Linear { from, to, angle: 45.0 });
    }
    if looks_like_image(s) {
        return Some(Paint::Image(PathBuf::from(s)));
    }
    None
}

fn looks_like_image(s: &str) -> bool {
    let lower = s.to_ascii_lowercase();
    [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"].iter().any(|ext| lower.ends_with(ext))
}

/// A solid colour from any wire form. Gradients give their first colour.
pub fn parse_color(value: &Value) -> Option<Color> {
    match value {
        Value::Object(map) => {
            if let Some(rgba) = map.get("rgba") {
                return parse_color(rgba);
            }
            if let Some(Value::Array(ends)) = map.get("gradient") {
                return ends.first().and_then(parse_color);
            }
            None
        }
        Value::Array(parts) => parse_components(parts),
        Value::String(s) => parse_color_str(s),
        _ => None,
    }
}

/// `[r,g,b,a]`: each component is an Integer 0-255 or a Float 0.0-1.0, decided
/// per component, like Shoes 3's `NUM2RGBINT`.
fn parse_components(parts: &[Value]) -> Option<Color> {
    if parts.len() < 3 {
        return None;
    }
    let channel = |v: &Value| -> Option<u8> {
        if let Some(i) = v.as_i64() {
            Some(i.clamp(0, 255) as u8)
        } else {
            v.as_f64().map(|f| (f * 255.0).round().clamp(0.0, 255.0) as u8)
        }
    };
    let r = channel(&parts[0])?;
    let g = channel(&parts[1])?;
    let b = channel(&parts[2])?;
    let a = match parts.get(3) {
        Some(v) => channel(v)?,
        None => 255,
    };
    Some(Color::rgba(r, g, b, a))
}

pub fn parse_color_str(s: &str) -> Option<Color> {
    let s = s.trim();
    if let Some(hex) = s.strip_prefix('#') {
        return parse_hex(hex);
    }
    let lower = s.to_ascii_lowercase();
    if lower.starts_with("rgb") {
        return parse_css_rgb(&lower);
    }
    named(lower.trim_start_matches(':'))
}

fn parse_hex(hex: &str) -> Option<Color> {
    let nibble = |c: u8| (c as char).to_digit(16).map(|d| d as u8);
    let bytes = hex.as_bytes();
    match bytes.len() {
        3 | 4 => {
            let mut out = [255u8; 4];
            for (i, c) in bytes.iter().enumerate() {
                out[i] = nibble(*c)? * 17;
            }
            Some(Color::rgba(out[0], out[1], out[2], out[3]))
        }
        6 | 8 => {
            let mut out = [255u8; 4];
            for i in 0..bytes.len() / 2 {
                out[i] = nibble(bytes[2 * i])? * 16 + nibble(bytes[2 * i + 1])?;
            }
            Some(Color::rgba(out[0], out[1], out[2], out[3]))
        }
        _ => None,
    }
}

/// `rgb(255,0,0)`, `rgba(255, 200, 0, 0.5)`, `rgb(0.5, 0.2, 0.1)`.
fn parse_css_rgb(s: &str) -> Option<Color> {
    let open = s.find('(')?;
    let close = s.rfind(')')?;
    let parts: Vec<Value> = s[open + 1..close]
        .split(',')
        .map(|p| {
            let p = p.trim();
            if p.contains('.') {
                p.parse::<f64>().map(Value::from).unwrap_or(Value::Null)
            } else {
                p.parse::<i64>().map(Value::from).unwrap_or(Value::Null)
            }
        })
        .collect();
    parse_components(&parts)
}

pub fn named(name: &str) -> Option<Color> {
    let name = name.trim();
    NAMED
        .iter()
        .find(|(n, ..)| n.eq_ignore_ascii_case(name))
        .map(|&(_, r, g, b)| Color::rgb(r, g, b))
}

/// `Shoes::COLORS`, the X11 table Lacci uses (`lacci/lib/shoes/colors.rb`).
const NAMED: &[(&str, u8, u8, u8)] = &[
    ("aliceblue", 240, 248, 255),
    ("antiquewhite", 250, 235, 215),
    ("aqua", 0, 255, 255),
    ("aquamarine", 127, 255, 212),
    ("azure", 240, 255, 255),
    ("beige", 245, 245, 220),
    ("bisque", 255, 228, 196),
    ("black", 0, 0, 0),
    ("blanchedalmond", 255, 235, 205),
    ("blue", 0, 0, 255),
    ("blueviolet", 138, 43, 226),
    ("brown", 165, 42, 42),
    ("burlywood", 222, 184, 135),
    ("cadetblue", 95, 158, 160),
    ("chartreuse", 127, 255, 0),
    ("chocolate", 210, 105, 30),
    ("coral", 255, 127, 80),
    ("cornflowerblue", 100, 149, 237),
    ("cornsilk", 255, 248, 220),
    ("crimson", 220, 20, 60),
    ("cyan", 0, 255, 255),
    ("darkblue", 0, 0, 139),
    ("darkcyan", 0, 139, 139),
    ("darkgoldenrod", 184, 134, 11),
    ("darkgray", 169, 169, 169),
    ("darkgreen", 0, 100, 0),
    ("darkkhaki", 189, 183, 107),
    ("darkmagenta", 139, 0, 139),
    ("darkolivegreen", 85, 107, 47),
    ("darkorange", 255, 140, 0),
    ("darkorchid", 153, 50, 204),
    ("darkred", 139, 0, 0),
    ("darksalmon", 233, 150, 122),
    ("darkseagreen", 143, 188, 143),
    ("darkslateblue", 72, 61, 139),
    ("darkslategray", 47, 79, 79),
    ("darkturquoise", 0, 206, 209),
    ("darkviolet", 148, 0, 211),
    ("deeppink", 255, 20, 147),
    ("deepskyblue", 0, 191, 255),
    ("dimgray", 105, 105, 105),
    ("dodgerblue", 30, 144, 255),
    ("firebrick", 178, 34, 34),
    ("floralwhite", 255, 250, 240),
    ("forestgreen", 34, 139, 34),
    ("fuchsia", 255, 0, 255),
    ("gainsboro", 220, 220, 220),
    ("ghostwhite", 248, 248, 255),
    ("gold", 255, 215, 0),
    ("goldenrod", 218, 165, 32),
    ("green", 0, 128, 0),
    ("greenyellow", 173, 255, 47),
    ("honeydew", 240, 255, 240),
    ("hotpink", 255, 105, 180),
    ("indianred", 205, 92, 92),
    ("indigo", 75, 0, 130),
    ("ivory", 255, 255, 240),
    ("khaki", 240, 230, 140),
    ("lavender", 230, 230, 250),
    ("lavenderblush", 255, 240, 245),
    ("lawngreen", 124, 252, 0),
    ("lemonchiffon", 255, 250, 205),
    ("lightblue", 173, 216, 230),
    ("lightcoral", 240, 128, 128),
    ("lightcyan", 224, 255, 255),
    ("lightgoldenrodyellow", 250, 250, 210),
    ("lightgreen", 144, 238, 144),
    ("lightgrey", 211, 211, 211),
    ("lightpink", 255, 182, 193),
    ("lightsalmon", 255, 160, 122),
    ("lightseagreen", 32, 178, 170),
    ("lightskyblue", 135, 206, 250),
    ("lightslategray", 119, 136, 153),
    ("lightsteelblue", 176, 196, 222),
    ("lightyellow", 255, 255, 224),
    ("lime", 0, 255, 0),
    ("limegreen", 50, 205, 50),
    ("linen", 250, 240, 230),
    ("magenta", 255, 0, 255),
    ("maroon", 128, 0, 0),
    ("mediumaquamarine", 102, 205, 170),
    ("mediumblue", 0, 0, 205),
    ("mediumorchid", 186, 85, 211),
    ("mediumpurple", 147, 112, 219),
    ("mediumseagreen", 60, 179, 113),
    ("mediumslateblue", 123, 104, 238),
    ("mediumspringgreen", 0, 250, 154),
    ("mediumturquoise", 72, 209, 204),
    ("mediumvioletred", 199, 21, 133),
    ("midnightblue", 25, 25, 112),
    ("mintcream", 245, 255, 250),
    ("mistyrose", 255, 228, 225),
    ("moccasin", 255, 228, 181),
    ("navajowhite", 255, 222, 173),
    ("navy", 0, 0, 128),
    ("oldlace", 253, 245, 230),
    ("olive", 128, 128, 0),
    ("olivedrab", 107, 142, 35),
    ("orange", 255, 165, 0),
    ("orangered", 255, 69, 0),
    ("orchid", 218, 112, 214),
    ("palegoldenrod", 238, 232, 170),
    ("palegreen", 152, 251, 152),
    ("paleturquoise", 175, 238, 238),
    ("palevioletred", 219, 112, 147),
    ("papayawhip", 255, 239, 213),
    ("peachpuff", 255, 218, 185),
    ("peru", 205, 133, 63),
    ("pink", 255, 192, 203),
    ("plum", 221, 160, 221),
    ("powderblue", 176, 224, 230),
    ("purple", 128, 0, 128),
    ("red", 255, 0, 0),
    ("rosybrown", 188, 143, 143),
    ("royalblue", 65, 105, 225),
    ("saddlebrown", 139, 69, 19),
    ("salmon", 250, 128, 114),
    ("sandybrown", 244, 164, 96),
    ("seagreen", 46, 139, 87),
    ("seashell", 255, 245, 238),
    ("sienna", 160, 82, 45),
    ("silver", 192, 192, 192),
    ("skyblue", 135, 206, 235),
    ("slateblue", 106, 90, 205),
    ("slategray", 112, 128, 144),
    ("snow", 255, 250, 250),
    ("springgreen", 0, 255, 127),
    ("steelblue", 70, 130, 180),
    ("tan", 210, 180, 140),
    ("teal", 0, 128, 128),
    ("thistle", 216, 191, 216),
    ("tomato", 255, 99, 71),
    ("turquoise", 64, 224, 208),
    ("violet", 238, 130, 238),
    ("wheat", 245, 222, 179),
    ("white", 255, 255, 255),
    ("whitesmoke", 245, 245, 245),
    ("yellow", 255, 255, 0),
    ("yellowgreen", 154, 205, 50),
];

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn wire_rgba() {
        assert_eq!(parse_color(&json!({"rgba": [255, 0, 0, 128]})), Some(Color::rgba(255, 0, 0, 128)));
    }

    #[test]
    fn raw_arrays_decide_per_component() {
        assert_eq!(parse_color(&json!([255, 0, 0, 255])), Some(Color::rgb(255, 0, 0)));
        assert_eq!(parse_color(&json!([0.5, 0.2, 0.1, 1.0])), Some(Color::rgba(128, 51, 26, 255)));
        assert_eq!(parse_color(&json!([0, 0.4, 0])), Some(Color::rgb(0, 102, 0)));
        assert_eq!(parse_color(&json!([255, 0, 0, 0.5])), Some(Color::rgba(255, 0, 0, 128)));
    }

    #[test]
    fn hex_forms() {
        assert_eq!(parse_color_str("#abc"), Some(Color::rgb(170, 187, 204)));
        assert_eq!(parse_color_str("#DFA"), Some(Color::rgb(0xdd, 0xff, 0xaa)));
        assert_eq!(parse_color_str("#102030"), Some(Color::rgb(16, 32, 48)));
        assert_eq!(parse_color_str("#10203040"), Some(Color::rgba(16, 32, 48, 64)));
        assert_eq!(parse_color_str("#12"), None);
    }

    #[test]
    fn names_and_css() {
        assert_eq!(parse_color_str("red"), Some(Color::rgb(255, 0, 0)));
        assert_eq!(parse_color_str("DarkBlue"), Some(Color::rgb(0, 0, 139)));
        assert_eq!(parse_color_str(":black"), Some(Color::BLACK));
        assert_eq!(parse_color_str("rgb(255,0,0)"), Some(Color::rgb(255, 0, 0)));
        assert_eq!(parse_color_str("rgba(255, 200, 0, 0.5)"), Some(Color::rgba(255, 200, 0, 128)));
    }

    #[test]
    fn paints() {
        assert_eq!(
            parse_paint(&json!({"gradient": [{"rgba": [255, 0, 0, 255]}, "#00f"], "angle": 90})),
            Some(Paint::Linear { from: Color::rgb(255, 0, 0), to: Color::rgb(0, 0, 255), angle: 90.0 })
        );
        assert_eq!(
            parse_paint(&json!("#fff..#000")),
            Some(Paint::Linear { from: Color::WHITE, to: Color::BLACK, angle: 0.0 })
        );
        assert_eq!(
            parse_paint(&json!("rgb(255,0,0)-rgb(0,0,255)")),
            Some(Paint::Linear { from: Color::rgb(255, 0, 0), to: Color::rgb(0, 0, 255), angle: 45.0 })
        );
        assert_eq!(parse_paint(&json!({"image": "/tmp/a.png"})), Some(Paint::Image("/tmp/a.png".into())));
        assert_eq!(parse_paint(&json!("bg.png")), Some(Paint::Image("bg.png".into())));
        assert!(!parse_paint(&json!([0, 0, 0, 0])).unwrap().is_visible());
        assert_eq!(parse_paint(&json!(null)), None);
    }
}
