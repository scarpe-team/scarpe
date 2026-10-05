//! Button focus notifications through the same paths as mouse, keyboard and app input.

mod common;

use common::{app, create, events, Harness};
use serde_json::{json, Value};

fn focus_changes(messages: &[Value]) -> Vec<(Value, Value)> {
    events(messages).into_iter().filter(|(name, _, _)| name == "focus_changed").map(|(_, id, args)| (id, args)).collect()
}

fn buttons() -> Harness {
    let mut h = Harness::new();
    h.feed(&app(300, 240, &[
        create(3, "Button", 2, json!({"text": "Close", "left": 10, "top": 10, "width": 100})),
        create(4, "Button", 2, json!({"text": "Retry", "left": 10, "top": 50, "width": 100})),
        create(5, "Check", 2, json!({"left": 10, "top": 90})),
        create(6, "Button", 2, json!({"text": "Disabled", "left": 10, "top": 130, "state": "disabled"})),
        create(7, "Button", 2, json!({"text": "Hidden", "hidden": true})),
    ]));
    h
}

#[test]
fn buttons_report_mouse_focus_gain_transfer_and_blur_once() {
    let mut h = buttons();
    let (messages, _) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert_eq!(focus_changes(&messages), vec![(json!(3), json!([true]))]);
    let (messages, _) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert!(focus_changes(&messages).is_empty(), "clicking the focused button is not a focus change");
    let (messages, _) = h.req(json!({"op": "click", "target": {"id": 4}}));
    assert_eq!(focus_changes(&messages), vec![(json!(3), json!([false])), (json!(4), json!([true]))]);
    let (messages, _) = h.req(json!({"op": "click", "target": {"x": 280, "y": 220}}));
    assert_eq!(focus_changes(&messages), vec![(json!(4), json!([false]))]);
    assert_eq!(h.value(json!({"op": "focused"})), Value::Null);
    let (messages, _) = h.req(json!({"op": "click", "target": {"x": 280, "y": 220}}));
    assert!(focus_changes(&messages).is_empty(), "blur is only reported once");
}

#[test]
fn buttons_report_tab_and_shift_tab_focus_in_order() {
    let mut h = buttons();
    for (key, focused, expected) in [
        ("tab", 3, vec![(json!(3), json!([true]))]),
        ("tab", 4, vec![(json!(3), json!([false])), (json!(4), json!([true]))]),
        ("shift_tab", 3, vec![(json!(4), json!([false])), (json!(3), json!([true]))]),
        ("shift_tab", 5, vec![(json!(3), json!([false]))]),
        ("tab", 3, vec![(json!(3), json!([true]))]),
    ] {
        let (messages, _) = h.req(json!({"op": "key", "key": key}));
        assert_eq!(focus_changes(&messages), expected, "key: {key}, focus target: {focused}");
        assert_eq!(h.value(json!({"op": "focused"})), json!(focused), "disabled and hidden buttons are skipped");
    }
}

#[test]
fn buttons_report_programmatic_focus_without_duplicates() {
    let mut h = buttons();
    for (target, expected) in [
        (3, vec![(json!(3), json!([true]))]),
        (3, vec![]),
        (4, vec![(json!(3), json!([false])), (json!(4), json!([true]))]),
        (5, vec![(json!(4), json!([false]))]),
        (3, vec![(json!(3), json!([true]))]),
    ] {
        let messages = h.feed(&json!({"t": "focus", "id": target}).to_string());
        assert_eq!(focus_changes(&messages), expected, "focus target: {target}");
        assert_eq!(h.value(json!({"op": "focused"})), json!(target));
    }
}
