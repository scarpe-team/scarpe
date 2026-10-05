//! Browser keys and mouse thumb buttons share the app's navigation keypress path.
mod common;

use common::{app, create, events, named, Harness};
use serde_json::json;

fn scene(kind: &str) -> Harness {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, kind, 2, json!({"text":"Unchanged", "items":["One","Two"], "chosen":"One", "width":150, "height":40})),
        create(4, "SubscriptionItem", 2, json!({"shoes_api_name":"keypress"})),
        create(5, "SubscriptionItem", 2, json!({"shoes_api_name":"release"})),
    ]));
    h
}

#[test]
fn browser_keys_reach_the_app_with_or_without_a_focused_edit_field() {
    for kind in ["Para", "EditLine", "EditBox"] {
        let mut h = scene(kind);
        if kind != "Para" { h.value(json!({"op":"click", "target":{"id":3}})); }
        let focus = h.value(json!({"op":"focused"}));
        for key in ["browser_back", "browser_forward", "shift_browser_back"] {
            let (msgs, reply) = h.req(json!({"op":"key", "key":key}));
            assert!(reply["error"].is_null(), "{reply}");
            let evs = events(&msgs);
            assert_eq!(named(&evs, "keypress")[0].2, json!([format!(":{key}")]));
            assert_eq!(named(&evs, "keypress").len(), 1);
            assert!(named(&evs, "change").is_empty());
            assert_eq!(h.value(json!({"op":"focused"})), focus);
        }
    }
}

#[test]
fn thumb_buttons_emit_one_keypress_without_clicking_or_releasing_a_control() {
    let mut h = scene("Button");
    for (button, key) in [(4, ":browser_back"), (5, ":browser_forward")] {
        let (msgs, _) = h.req(json!({"op":"click", "target":{"id":3}, "button":button}));
        let evs = events(&msgs);
        assert_eq!(named(&evs, "keypress").len(), 1);
        assert_eq!(named(&evs, "keypress")[0].2, json!([key]));
        assert!(named(&evs, "click").is_empty());
        assert!(named(&evs, "release").is_empty());
        assert!(h.value(json!({"op":"focused"})).is_null());
    }
}

#[test]
fn thumb_button_release_preserves_a_primary_button_press() {
    let mut h = scene("Button");
    h.value(json!({"op":"mouse", "action":"down", "x":30, "y":20, "button":1}));
    for button in [4, 5] {
        h.value(json!({"op":"mouse", "action":"down", "x":30, "y":20, "button":button}));
        let (msgs, _) = h.req(json!({"op":"mouse", "action":"up", "x":30, "y":20, "button":button}));
        assert!(events(&msgs).is_empty(), "a navigation release must not end the primary press");
    }
    let (msgs, _) = h.req(json!({"op":"mouse", "action":"up", "x":30, "y":20, "button":1}));
    assert_eq!(named(&events(&msgs), "click").len(), 1);
}

#[test]
fn back_closes_a_list_menu_before_navigating() {
    for mouse in [false, true] {
        let mut h = scene("ListBox");
        h.value(json!({"op":"click", "target":{"id":3}}));
        assert!(h.rt.views[&1].ui.popup.is_some());
        let op = if mouse { json!({"op":"click", "target":{"x":30,"y":20}, "button":4}) }
            else { json!({"op":"key", "key":"browser_back"}) };
        let (msgs, _) = h.req(op.clone());
        assert!(h.rt.views[&1].ui.popup.is_none());
        assert!(named(&events(&msgs), "keypress").is_empty());
        assert!(named(&events(&msgs), "change").is_empty());
        let (msgs, _) = h.req(op);
        assert_eq!(named(&events(&msgs), "keypress")[0].2, json!([":browser_back"]));
    }
}
