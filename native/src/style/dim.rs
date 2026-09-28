//! Shoes dimensions: widths, heights, positions and margins.
//!
//! Integer = px, negative Integer = parent minus |v|, Float in (0, 1] = a
//! fraction of the parent, "N%" = percent, "Npx" or "N" = px. Floats outside
//! that range are px, because Ruby code often computes widths like `w / 2.0`.
//! Positions (`left`, `top`, `right`, `bottom`) keep their sign instead: see `position`.

use serde_json::Value;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Dim {
    Px(f32),
    Fraction(f32),
    Minus(f32),
}

impl Dim {
    pub fn resolve(self, parent: f32) -> f32 {
        match self {
            Dim::Px(px) => px,
            Dim::Fraction(f) => parent * f,
            Dim::Minus(px) => (parent - px).max(0.0),
        }
    }

    /// True when the value depends on the parent's size.
    pub fn is_relative(self) -> bool {
        !matches!(self, Dim::Px(_))
    }
}

pub fn parse_dim(value: &Value) -> Option<Dim> {
    parse_any_dim(value).filter(|d| match *d {
        Dim::Px(v) | Dim::Fraction(v) | Dim::Minus(v) => v.is_finite(),
    })
}

fn parse_any_dim(value: &Value) -> Option<Dim> {
    match value {
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Some(integer_dim(i as f64))
            } else {
                n.as_f64().map(float_dim)
            }
        }
        Value::String(s) => parse_dim_str(s),
        _ => None,
    }
}

fn integer_dim(v: f64) -> Dim {
    if v < 0.0 {
        Dim::Minus(-v as f32)
    } else {
        Dim::Px(v as f32)
    }
}

fn float_dim(v: f64) -> Dim {
    if v > 0.0 && v <= 1.0 {
        Dim::Fraction(v as f32)
    } else if v < 0.0 && v > -1.0 {
        Dim::Fraction((1.0 + v) as f32)
    } else {
        integer_dim(v)
    }
}

fn parse_dim_str(s: &str) -> Option<Dim> {
    let s = s.trim();
    if let Some(pct) = s.strip_suffix('%') {
        let v: f64 = pct.trim().parse().ok()?;
        return Some(if v < 0.0 { Dim::Fraction((1.0 + v / 100.0) as f32) } else { Dim::Fraction((v / 100.0) as f32) });
    }
    let number = s.strip_suffix("px").unwrap_or(s).trim();
    number.parse::<f64>().ok().map(integer_dim)
}

/// A `left`, `top`, `right` or `bottom` offset, as Shoes 3 reads a position: shoes_px2 passes
/// nv 0 to shoes_px (s3_ruby.c:298-337), so a negative number stays negative and puts the
/// element past the slot's edge it counts from, where a size counts back from the slot. A
/// Float up to 1 or a percentage is still that share of the slot, and a negative share lies
/// past the edge too (ledger C10, Q10).
pub fn position(value: &Value, parent: f32) -> Option<f32> {
    let dim = parse_dim(value)?;
    let negative_share = match value {
        Value::Number(n) if !n.is_i64() => n.as_f64().filter(|v| *v < 0.0 && *v > -1.0),
        Value::String(s) => s.trim().strip_suffix('%').and_then(|v| v.trim().parse::<f64>().ok()).filter(|v| *v < 0.0).map(|v| v / 100.0),
        _ => None,
    };
    Some(match (negative_share, dim) {
        (Some(share), _) => (share * f64::from(parent)) as f32,
        (None, Dim::Minus(px)) => -px,
        (None, d) => d.resolve(parent),
    })
}

/// A plain number (px) from a Value that may be an Integer, Float or numeric String.
pub fn parse_number(value: &Value) -> Option<f32> {
    let n: Option<f32> = match value {
        Value::Number(n) => n.as_f64().map(|v| v as f32),
        Value::String(s) => s.trim().strip_suffix("px").unwrap_or(s.trim()).trim().parse().ok(),
        _ => None,
    };
    n.filter(|v| v.is_finite())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn px(v: Value, parent: f32) -> f32 {
        parse_dim(&v).unwrap().resolve(parent)
    }

    #[test]
    fn integers() {
        assert_eq!(px(json!(120), 480.0), 120.0);
        assert_eq!(px(json!(-100), 480.0), 380.0);
        assert_eq!(px(json!(0), 480.0), 0.0);
    }

    #[test]
    fn floats_are_fractions_up_to_one() {
        assert_eq!(px(json!(0.5), 480.0), 240.0);
        assert_eq!(px(json!(1.0), 480.0), 480.0);
        assert_eq!(px(json!(-0.25), 400.0), 300.0);
        assert_eq!(px(json!(240.0), 480.0), 240.0);
        assert_eq!(px(json!(-20.0), 480.0), 460.0);
    }

    #[test]
    fn strings() {
        assert_eq!(px(json!("50%"), 480.0), 240.0);
        assert_eq!(px(json!("100%"), 300.0), 300.0);
        assert_eq!(px(json!("18px"), 480.0), 18.0);
        assert_eq!(px(json!("10"), 480.0), 10.0);
        assert_eq!(px(json!("-10"), 480.0), 470.0);
        assert_eq!(parse_dim(&json!("wide")), None);
        assert_eq!(parse_dim(&json!("inf")), None);
        assert_eq!(parse_number(&json!("NaN")), None);
        assert_eq!(parse_dim(&json!(null)), None);
        assert_eq!(parse_dim(&json!(true)), None);
    }

    #[test]
    fn positions_keep_their_sign() {
        let at = |v: Value, parent: f32| position(&v, parent).unwrap();
        assert_eq!(at(json!(-3), 300.0), -3.0, "past the edge, not the slot less 3");
        assert_eq!(at(json!("-12px"), 400.0), -12.0);
        assert_eq!(at(json!("-10%"), 400.0), -40.0);
        assert_eq!(at(json!(-0.25), 400.0), -100.0);
        assert_eq!(at(json!(20), 300.0), 20.0);
        assert_eq!(at(json!(0.5), 400.0), 200.0);
        assert_eq!(position(&json!(null), 400.0), None);
    }
}
