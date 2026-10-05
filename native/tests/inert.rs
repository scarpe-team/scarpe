//! Inert content stays laid out and painted, but its whole subtree stops taking input.

mod common;

use common::{app, create, events, named, Harness};
use serde_json::{json, Value};

fn props(h: &mut Harness, id: i64, values: Value) {
    h.feed(&format!("{}\n{}\n", json!({"t":"props","id":id,"props":values}), json!({"t":"flush"})));
}

fn focus(h: &mut Harness, id: i64) {
    h.feed(&json!({"t":"focus","id":id}).to_string());
}

fn mouse(h: &mut Harness, action: &str, x: f64, y: f64) -> Vec<Value> {
    let (messages, reply) = h.req(json!({"op":"mouse","action":action,"x":x,"y":y,"button":1}));
    assert_eq!(reply["error"], Value::Null, "{reply}");
    messages
}

#[test]
fn nested_inert_content_keeps_its_pixels_and_geometry_and_cannot_opt_out() {
    let mut h = Harness::new();
    h.feed(&app(400, 200, &[
        create(3, "Stack", 2, json!({"width":180,"height":100,"inert":true})),
        create(4, "Stack", 3, json!({"inert":false})),
        create(5, "Button", 4, json!({"text":"Behind"})),
        create(6, "Button", 2, json!({"text":"Dialog","left":220,"top":20})),
    ]));
    let layout = h.layout();
    let pixels = h.rt.picture(1, 1.0).unwrap().data().to_vec();
    let (messages, reply) = h.req(json!({"op":"click","target":{"id":5}}));
    assert!(reply["error"].is_string());
    assert!(named(&events(&messages), "click").is_empty());
    props(&mut h, 3, json!({"inert":false}));
    assert_eq!(h.layout(), layout);
    assert_eq!(h.rt.picture(1, 1.0).unwrap().data(), pixels);
    let (messages, _) = h.req(json!({"op":"click","target":{"id":5}}));
    assert_eq!(named(&events(&messages), "click")[0].1, json!(5));

    props(&mut h, 4, json!({"inert":true}));
    props(&mut h, 3, json!({"inert":true}));
    props(&mut h, 3, json!({"inert":null}));
    focus(&mut h, 5);
    assert_eq!(h.value(json!({"op":"focused"})), Value::Null, "the inner slot is still inert");
    props(&mut h, 4, json!({"inert":null}));
    focus(&mut h, 5);
    assert_eq!(h.value(json!({"op":"focused"})), json!(5));
}

#[test]
fn becoming_inert_clears_focus_skips_tab_and_preserves_text_and_undo() {
    let mut h = Harness::new();
    h.feed(&app(400, 200, &[
        create(3, "Stack", 2, json!({"width":180,"height":100})),
        create(4, "EditLine", 3, json!({"text":"kept","width":140})),
        create(5, "Button", 3, json!({"text":"Behind"})),
        create(6, "Button", 2, json!({"text":"Dialog","left":220,"top":20})),
    ]));
    focus(&mut h, 4);
    h.value(json!({"op":"key","key":"end"}));
    h.value(json!({"op":"type","text":"!"}));
    props(&mut h, 3, json!({"inert":true}));
    assert_eq!(h.value(json!({"op":"focused"})), Value::Null);
    assert!(h.rt.text_input_area(1).is_none());
    h.value(json!({"op":"type","text":"ignored"}));
    h.rt.ime_commit(1, "متجاهل");
    assert_eq!(h.node(|n| n["id"] == 4)["text"], json!("kept!"));
    for key in ["tab", "tab", "shift_tab"] {
        h.value(json!({"op":"key","key":key}));
        assert_eq!(h.value(json!({"op":"focused"})), json!(6));
    }
    h.value(json!({"op":"click","target":{"id":6}}));
    assert!(!h.rt.views[&1].ui.focus_visible);
    focus(&mut h, 4);
    assert_eq!(h.value(json!({"op":"focused"})), json!(6), "an inert focus request leaves the active control alone");
    assert!(!h.rt.views[&1].ui.focus_visible, "a rejected focus request does not change the active control's keyboard behavior");
    props(&mut h, 3, json!({"inert":false}));
    assert_eq!(h.value(json!({"op":"focused"})), json!(6), "restoring interaction does not take focus");
    focus(&mut h, 4);
    h.value(json!({"op":"key","key":"control_z"}));
    assert_eq!(h.node(|n| n["id"] == 4)["text"], json!("kept"), "the field and its undo history survived");
}

#[test]
fn inert_slots_block_handlers_and_wheel_scrolling_but_leave_the_app_active() {
    let mut h = Harness::new();
    let mut body = vec![
        create(3, "Stack", 2, json!({"width":180,"height":100,"scroll":true,"inert":true})),
        create(4, "Rect", 3, json!({"left":0,"top":0,"width":70,"height":60,"has_click":true,"has_release":true})),
        create(5, "Stack", 3, json!({"height":400})),
        create(20, "SubscriptionItem", 2, json!({"shoes_api_name":"keypress"})),
    ];
    for (i, name) in ["click", "release", "motion", "hover", "leave", "wheel", "keypress"].iter().enumerate() {
        body.push(create(6 + i as i64, "SubscriptionItem", 3, json!({"shoes_api_name":name})));
    }
    h.feed(&app(400, 200, &body));
    let mut messages = mouse(&mut h, "move", 20.0, 20.0);
    messages.extend(mouse(&mut h, "down", 20.0, 20.0));
    messages.extend(mouse(&mut h, "up", 20.0, 20.0));
    messages.extend(h.req(json!({"op":"wheel","dy":30,"x":20,"y":20})).0);
    messages.extend(h.req(json!({"op":"key","key":"a"})).0);
    assert!(!events(&messages).iter().any(|e| e.1.as_i64().is_some_and(|id| (3..=12).contains(&id))), "{messages:?}");
    assert_eq!(named(&events(&messages), "keypress")[0].1, json!(20));
    assert_eq!(h.rt.views[&1].ui.scroll.get(&3).copied().unwrap_or(0.0), 0.0);

    props(&mut h, 3, json!({"inert":false}));
    let messages = mouse(&mut h, "down", 20.0, 20.0);
    assert!(named(&events(&messages), "click").iter().any(|e| e.1 == json!(4)));
    mouse(&mut h, "up", 20.0, 20.0);
    let (messages, _) = h.req(json!({"op":"wheel","dy":30,"x":20,"y":20}));
    assert!(named(&events(&messages), "wheel").iter().any(|e| e.1 == json!(11)));
    assert_eq!(h.rt.views[&1].ui.scroll[&3], 30.0);
    props(&mut h, 3, json!({"inert":true}));
    h.value(json!({"op":"wheel","dy":30,"x":20,"y":20}));
    props(&mut h, 3, json!({"inert":false}));
    assert_eq!(h.rt.views[&1].ui.scroll[&3], 30.0, "restoring interaction keeps the scroll position");
}

#[test]
fn becoming_inert_cancels_a_press_even_if_reenabled_before_release() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Stack", 2, json!({"width":180,"height":100})),
        create(4, "Button", 3, json!({"text":"Behind","tooltip":"Do it","width":100,"height":30})),
    ]));
    mouse(&mut h, "down", 20.0, 15.0);
    assert!(h.rt.views[&1].ui.pressed.is_some());
    props(&mut h, 3, json!({"inert":true}));
    assert!(h.rt.views[&1].ui.pressed.is_none());
    assert!(h.rt.views[&1].ui.tooltip.is_none());
    assert!(!h.rt.views[&1].ui.hover_chain.contains(&4));
    props(&mut h, 3, json!({"inert":false}));
    let messages = mouse(&mut h, "up", 20.0, 15.0);
    assert!(named(&events(&messages), "click").is_empty());
}

#[test]
fn becoming_inert_cancels_field_drags_and_open_popups() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[
        create(3, "Stack", 2, json!({"width":250,"height":180})),
        create(4, "EditLine", 3, json!({"text":"some text","width":180})),
        create(5, "ListBox", 3, json!({"items":["Tea","Coffee"],"chosen":"Tea"})),
    ]));
    mouse(&mut h, "down", 8.0, 14.0);
    assert!(h.rt.views[&1].ui.pressed.is_some());
    props(&mut h, 3, json!({"inert":true}));
    assert!(h.rt.views[&1].ui.pressed.is_none(), "no selection drag can continue");
    mouse(&mut h, "move", 140.0, 14.0);
    mouse(&mut h, "up", 140.0, 14.0);
    props(&mut h, 3, json!({"inert":false}));
    h.value(json!({"op":"click","target":{"id":5}}));
    assert!(h.rt.views[&1].ui.popup.is_some());
    props(&mut h, 3, json!({"inert":true}));
    assert!(h.rt.views[&1].ui.popup.is_none(), "an inert list box cannot keep intercepting input");
    let (messages, _) = h.req(json!({"op":"key","key":"enter"}));
    assert!(named(&events(&messages), "change").is_empty());
    props(&mut h, 3, json!({"inert":false}));
    assert!(h.rt.views[&1].ui.popup.is_none());
    h.value(json!({"op":"click","target":{"id":5}}));
    let (messages, _) = h.req(json!({"op":"click","target":{"text":"Coffee"}}));
    assert_eq!(named(&events(&messages), "change")[0].2, json!(["Coffee"]));
}

#[test]
fn reparenting_under_an_inert_slot_clears_existing_focus() {
    let mut h = Harness::new();
    h.feed(&app(400, 200, &[
        create(3, "Stack", 2, json!({"width":180,"height":100,"inert":true})),
        create(4, "Stack", 2, json!({"width":180,"height":100})),
        create(5, "EditLine", 4, json!({"text":"kept"})),
    ]));
    focus(&mut h, 5);
    h.feed(&json!({"t":"reparent","id":4,"parent":3,"index":null}).to_string());
    assert_eq!(h.value(json!({"op":"focused"})), Value::Null);
    h.feed(&json!({"t":"reparent","id":4,"parent":2,"index":null}).to_string());
    assert_eq!(h.value(json!({"op":"focused"})), Value::Null);
    focus(&mut h, 5);
    assert_eq!(h.value(json!({"op":"focused"})), json!(5));
}

#[test]
fn an_inert_document_root_is_not_a_pointer_fallback() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "SubscriptionItem", 2, json!({"shoes_api_name":"click"}))]));
    props(&mut h, 2, json!({"inert":true}));
    let hit = h.value(json!({"op":"click","target":{"x":20,"y":20}}));
    assert_eq!(hit["hit"], Value::Null);
    let tree = h.value(json!({"op":"a11y"}));
    assert!(tree.get("children").is_none());
}
