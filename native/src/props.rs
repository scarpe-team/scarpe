//! Typed getters over a node's raw property map.
//!
//! Values arrive as whatever Lacci had, lightly normalised by the shim, so every
//! getter is lenient: a missing key, a null and an unparseable value all read as
//! "not set".

use crate::style::color::{parse_color, parse_paint};
use crate::style::dim::{parse_dim, parse_number};
use crate::style::{Color, Dim, Paint};
use serde_json::{Map, Value};

pub type Id = i64;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Props(pub Map<String, Value>);

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Edges {
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}

impl Edges {
    pub fn horizontal(&self) -> f32 {
        self.left + self.right
    }

    pub fn vertical(&self) -> f32 {
        self.top + self.bottom
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum TextItem {
    Str(String),
    Ref(Id),
}

impl Props {
    pub fn new(map: Map<String, Value>) -> Self {
        Props(map)
    }

    pub fn merge(&mut self, changes: Map<String, Value>) {
        for (k, v) in changes {
            self.0.insert(k, v);
        }
    }

    pub fn get(&self, key: &str) -> Option<&Value> {
        self.0.get(key).filter(|v| !v.is_null())
    }

    pub fn has(&self, key: &str) -> bool {
        self.get(key).is_some()
    }

    pub fn str(&self, key: &str) -> Option<&str> {
        self.get(key).and_then(Value::as_str)
    }

    /// Any scalar as display text (labels and list items may be numbers or symbols).
    pub fn text(&self, key: &str) -> Option<String> {
        self.get(key).map(value_text)
    }

    pub fn f32(&self, key: &str) -> Option<f32> {
        self.get(key).and_then(parse_number)
    }

    /// Ruby truthiness: anything but nil and false is true.
    pub fn truthy(&self, key: &str) -> bool {
        !matches!(self.get(key), None | Some(Value::Bool(false)))
    }

    pub fn id(&self, key: &str) -> Option<Id> {
        self.get(key).and_then(Value::as_i64)
    }

    pub fn dim(&self, key: &str) -> Option<Dim> {
        self.get(key).and_then(parse_dim)
    }

    /// A `left`, `top`, `right` or `bottom` offset in pixels against a slot `basis` wide or
    /// high; a negative one lies past the slot's edge it counts from (crate::style::dim::position).
    pub fn position(&self, key: &str, basis: f32) -> Option<f32> {
        self.get(key).and_then(|v| crate::style::dim::position(v, basis))
    }

    pub fn paint(&self, key: &str) -> Option<Paint> {
        self.get(key).and_then(parse_paint)
    }

    pub fn color(&self, key: &str) -> Option<Color> {
        self.get(key).and_then(parse_color)
    }

    pub fn draw_context(&self) -> Option<&Map<String, Value>> {
        self.get("draw_context").and_then(Value::as_object)
    }

    /// An art style: the element's own prop, else the inherited draw context.
    pub fn art(&self, key: &str) -> Option<&Value> {
        self.get(key).or_else(|| self.draw_context().and_then(|dc| dc.get(key)).filter(|v| !v.is_null()))
    }

    pub fn art_paint(&self, key: &str) -> Option<Paint> {
        self.art(key).and_then(parse_paint)
    }

    pub fn art_f32(&self, key: &str) -> Option<f32> {
        self.art(key).and_then(parse_number)
    }

    pub fn text_items(&self) -> Vec<TextItem> {
        match self.get("text_items") {
            Some(Value::Array(items)) => items
                .iter()
                .filter_map(|v| match v {
                    Value::String(s) => Some(TextItem::Str(s.clone())),
                    Value::Number(n) => n.as_i64().map(TextItem::Ref),
                    Value::Null => None,
                    other => Some(TextItem::Str(value_text(other))),
                })
                .collect(),
            Some(Value::String(s)) => vec![TextItem::Str(s.clone())],
            _ => Vec::new(),
        }
    }

    /// `margin` (number, [l,t,r,b], "l t r b" or {left:..}) overridden by `margin_<side>`.
    pub fn margins(&self, parent_w: f32) -> Edges {
        self.margins_or(parent_w, Edges::default())
    }

    /// Margins over an element's own defaults: sides that neither `margin` nor
    /// `margin_<side>` names keep them (Shoes 3's ATTR_MARGINS, ledger C3).
    pub fn margins_or(&self, parent_w: f32, defaults: Edges) -> Edges {
        let mut edges = self.get("margin").map(|v| edges_from(v, parent_w, MARGIN_ORDER, defaults)).unwrap_or(defaults);
        override_sides(self, "margin_", parent_w, &mut edges);
        edges
    }

    /// Scarpe's `padding`; arrays use Calzini's [left, right, top, bottom] order.
    pub fn padding(&self, parent_w: f32) -> Edges {
        let mut edges = self.get("padding").map(|v| edges_from(v, parent_w, PADDING_ORDER, Edges::default())).unwrap_or_default();
        override_sides(self, "padding_", parent_w, &mut edges);
        edges
    }
}

pub fn value_text(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        Value::Null => String::new(),
        other => other.to_string(),
    }
}

#[derive(Clone, Copy)]
enum Side {
    Left,
    Top,
    Right,
    Bottom,
}

const MARGIN_ORDER: [Side; 4] = [Side::Left, Side::Top, Side::Right, Side::Bottom];
const PADDING_ORDER: [Side; 4] = [Side::Left, Side::Right, Side::Top, Side::Bottom];

fn set_side(edges: &mut Edges, side: Side, v: f32) {
    match side {
        Side::Left => edges.left = v,
        Side::Top => edges.top = v,
        Side::Right => edges.right = v,
        Side::Bottom => edges.bottom = v,
    }
}

fn px_of(v: &Value, parent_w: f32) -> Option<f32> {
    parse_dim(v).map(|d| d.resolve(parent_w))
}

fn edges_from(v: &Value, parent_w: f32, order: [Side; 4], defaults: Edges) -> Edges {
    let mut edges = defaults;
    let list: Vec<Value> = match v {
        Value::Array(items) => items.clone(),
        Value::String(s) if s.contains(|c: char| c.is_whitespace() || c == ',') => s
            .split(|c: char| c.is_whitespace() || c == ',')
            .filter(|p| !p.is_empty())
            .map(|p| Value::String(p.to_string()))
            .collect(),
        Value::Object(map) => {
            for (key, side) in [("left", Side::Left), ("top", Side::Top), ("right", Side::Right), ("bottom", Side::Bottom)] {
                if let Some(px) = map.get(key).and_then(|v| px_of(v, parent_w)) {
                    set_side(&mut edges, side, px);
                }
            }
            return edges;
        }
        scalar => vec![scalar.clone()],
    };
    if list.len() == 1 {
        let px = px_of(&list[0], parent_w).unwrap_or(0.0);
        return Edges { left: px, top: px, right: px, bottom: px };
    }
    for (i, side) in order.iter().enumerate() {
        if let Some(px) = list.get(i).and_then(|v| px_of(v, parent_w)) {
            set_side(&mut edges, *side, px);
        }
    }
    edges
}

fn override_sides(props: &Props, prefix: &str, parent_w: f32, edges: &mut Edges) {
    for (name, side) in [("left", Side::Left), ("top", Side::Top), ("right", Side::Right), ("bottom", Side::Bottom)] {
        if let Some(px) = props.get(&format!("{prefix}{name}")).and_then(|v| px_of(v, parent_w)) {
            set_side(edges, side, px);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn props(v: Value) -> Props {
        Props(v.as_object().unwrap().clone())
    }

    #[test]
    fn margin_forms() {
        assert_eq!(props(json!({"margin": 8})).margins(480.0), Edges { left: 8.0, top: 8.0, right: 8.0, bottom: 8.0 });
        assert_eq!(
            props(json!({"margin": [1, 2, 3, 4]})).margins(480.0),
            Edges { left: 1.0, top: 2.0, right: 3.0, bottom: 4.0 }
        );
        assert_eq!(
            props(json!({"margin": [5, 6]})).margins(480.0),
            Edges { left: 5.0, top: 6.0, right: 0.0, bottom: 0.0 }
        );
        assert_eq!(
            props(json!({"margin": "1 2 3 4"})).margins(480.0),
            Edges { left: 1.0, top: 2.0, right: 3.0, bottom: 4.0 }
        );
        assert_eq!(
            props(json!({"margin_top": 2, "margin_bottom": 4, "margin_left": 1, "margin_right": 3})).margins(480.0),
            Edges { left: 1.0, top: 2.0, right: 3.0, bottom: 4.0 }
        );
        assert_eq!(props(json!({"margin": 10, "margin_left": 0})).margins(480.0).left, 0.0);
        assert_eq!(props(json!({"margin_left": "10%"})).margins(200.0).left, 20.0);
    }

    #[test]
    fn short_margin_arrays_keep_the_default_for_missing_sides() {
        // Ledger C3: Shoes 3 reads missing array entries as the element's default margin.
        let four = Edges { left: 4.0, top: 4.0, right: 4.0, bottom: 4.0 };
        assert_eq!(props(json!({"margin": [10, 20]})).margins_or(480.0, four), Edges { left: 10.0, top: 20.0, right: 4.0, bottom: 4.0 });
        assert_eq!(props(json!({"margin": 0})).margins_or(480.0, four), Edges::default());
        assert_eq!(props(json!({})).margins_or(480.0, four), four);
        assert_eq!(props(json!({"margin_left": 9})).margins_or(480.0, four).left, 9.0);
        assert_eq!(props(json!({"margin": {"top": 2}})).margins_or(480.0, four), Edges { left: 4.0, top: 2.0, right: 4.0, bottom: 4.0 });
    }

    #[test]
    fn padding_uses_calzini_order() {
        assert_eq!(
            props(json!({"padding": [1, 2, 3, 4]})).padding(480.0),
            Edges { left: 1.0, right: 2.0, top: 3.0, bottom: 4.0 }
        );
    }

    #[test]
    fn text_items_mix_strings_and_ids() {
        assert_eq!(
            props(json!({"text_items": ["Hello ", 5, "!"]})).text_items(),
            vec![TextItem::Str("Hello ".into()), TextItem::Ref(5), TextItem::Str("!".into())]
        );
    }

    #[test]
    fn art_styles_fall_back_to_draw_context() {
        let p = props(json!({"draw_context": {"fill": [255, 0, 0, 255], "strokewidth": 3}, "stroke": "#00f"}));
        assert_eq!(p.art_paint("fill"), Some(Paint::Solid(Color::rgb(255, 0, 0))));
        assert_eq!(p.art_paint("stroke"), Some(Paint::Solid(Color::rgb(0, 0, 255))));
        assert_eq!(p.art_f32("strokewidth"), Some(3.0));
    }

    #[test]
    fn truthiness() {
        let p = props(json!({"a": true, "b": false, "c": null, "d": "yes", "e": 0}));
        assert!(p.truthy("a"));
        assert!(!p.truthy("b"));
        assert!(!p.truthy("c"));
        assert!(p.truthy("d"));
        assert!(p.truthy("e"));
        assert!(!p.truthy("missing"));
    }
}
