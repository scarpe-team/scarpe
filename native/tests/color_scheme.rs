mod common;

use common::Harness;
use serde_json::json;

#[test]
fn color_scheme_can_be_queried_before_any_window_exists() {
    let mut h = Harness::new();
    for _ in 0..2 {
        let value = h.value(json!({"op":"preferred_color_scheme"}));
        assert!(value.is_null() || value == "light" || value == "dark", "{value}");
        assert!(h.rt.views.is_empty());
        assert!(h.rt.effects.is_empty());
    }
}
