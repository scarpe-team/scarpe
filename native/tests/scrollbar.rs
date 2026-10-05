//! Scrollbars use the same pointer path as window events and automation, without a window.

mod common;

use common::{app, create, events, Harness};
use scarpe_native::input::CursorShape;
use scarpe_native::protocol::DialogRequest;
use serde_json::{json, Value};

fn scene(extra: &[Value]) -> Harness {
    let mut h = Harness::new();
    let mut body = vec![
        create(3, "Stack", 2, json!({"left":20,"top":20,"width":100,"height":100,"scroll":true})),
        create(4, "Stack", 3, json!({"height":500})),
        create(10, "SubscriptionItem", 2, json!({"shoes_api_name":"click"})),
        create(11, "SubscriptionItem", 2, json!({"shoes_api_name":"release"})),
        create(12, "SubscriptionItem", 3, json!({"shoes_api_name":"click"})),
        create(13, "SubscriptionItem", 3, json!({"shoes_api_name":"release"})),
    ];
    body.extend_from_slice(extra);
    h.feed(&app(400, 260, &body));
    h
}

fn mouse(h: &mut Harness, action: &str, x: f32, y: f32) -> Vec<Value> {
    h.req(json!({"op":"mouse","action":action,"x":x,"y":y})).0
}

fn top(h: &Harness, id: i64) -> f32 {
    h.rt.views[&1].layout.as_ref().unwrap().scrollers[&id].top
}

fn scrolls(msgs: &[Value]) -> Vec<(i64, i64)> {
    msgs.iter().filter(|m| m["t"] == "scroll").map(|m| (m["id"].as_i64().unwrap(), m["top"].as_i64().unwrap())).collect()
}

fn no_clicks(msgs: &[Value]) {
    assert!(events(msgs).iter().all(|e| e.0 != "click" && e.0 != "release"), "{msgs:?}");
}

fn props(h: &mut Harness, id: i64, props: Value) {
    h.feed(&json!({"t":"props","id":id,"props":props}).to_string());
    h.feed(r#"{"t":"flush"}"#);
}

#[test]
fn thumb_drag_reports_scroll_and_moves_content_without_relayout() {
    let mut h = scene(&[]);
    let layouts = h.rt.stats.to_json()["phases"]["layout"]["n"].clone();
    let before = h.rt.picture(1, 1.0).unwrap();
    assert!(before.pixel(114, 30).unwrap().red() < 255, "the painted thumb is the target");
    no_clicks(&mouse(&mut h, "down", 114.0, 30.0));
    assert_eq!(top(&h, 3), 0.0, "grabbing preserves the offset within the thumb");
    let msgs = mouse(&mut h, "move", 114.0, 66.0);
    assert_eq!(scrolls(&msgs), vec![(3, 200)]);
    assert!(msgs.iter().any(|m| m["t"] == "layout"), "Ruby hears the moved rects");
    assert_eq!(h.node(|n| n["id"] == 4)["y"], -180.0);
    assert_eq!(h.rt.stats.to_json()["phases"]["layout"]["n"], layouts);
    let after = h.rt.picture(1, 1.0).unwrap();
    assert_eq!(after.pixel(114, 30).unwrap().red(), 255);
    assert!(after.pixel(114, 66).unwrap().red() < 255);
    let msgs = mouse(&mut h, "up", 114.0, 66.0);
    no_clicks(&msgs);
    assert!(scrolls(&msgs).is_empty(), "automation's release must not drag twice");
    assert!(scrolls(&mouse(&mut h, "move", 114.0, 100.0)).is_empty());
    assert_eq!(top(&h, 3), 200.0);
}

#[test]
fn dragging_outside_the_viewport_and_window_clamps_at_both_ends() {
    let mut h = scene(&[]);
    mouse(&mut h, "down", 114.0, 30.0);
    assert_eq!(scrolls(&mouse(&mut h, "move", 500.0, 500.0)), vec![(3, 400)]);
    assert!(scrolls(&mouse(&mut h, "move", 600.0, 600.0)).is_empty());
    assert_eq!(scrolls(&mouse(&mut h, "move", -50.0, -50.0)), vec![(3, 0)]);
    mouse(&mut h, "up", -50.0, -50.0);
    assert_eq!(h.rt.views[&1].ui.buttons, 0);
}

#[test]
fn track_click_pages_once_and_does_not_turn_into_a_drag() {
    let mut h = scene(&[]);
    let msgs = mouse(&mut h, "down", 114.0, 105.0);
    assert_eq!(scrolls(&msgs), vec![(3, 90)]);
    no_clicks(&msgs);
    assert!(scrolls(&mouse(&mut h, "move", 114.0, 110.0)).is_empty());
    no_clicks(&mouse(&mut h, "up", 114.0, 110.0));
    assert_eq!(scrolls(&mouse(&mut h, "down", 114.0, 25.0)), vec![(3, 0)]);
    no_clicks(&mouse(&mut h, "up", 114.0, 25.0));
    h.feed(r#"{"t":"scroll_to","id":3,"top":380}"#);
    assert_eq!(scrolls(&mouse(&mut h, "down", 114.0, 117.0)), vec![(3, 400)]);
}

#[test]
fn scrollbar_preserves_focus_and_does_not_activate_a_control_under_it() {
    let mut h = scene(&[
        create(5, "Button", 4, json!({"text":"Under the thumb","width":100,"height":28})),
        create(6, "EditLine", 2, json!({"left":150,"top":20,"width":100,"text":""})),
    ]);
    h.rt.set_focus(1, Some(6));
    h.rt.views.get_mut(&1).unwrap().ui.focus_visible = true;
    no_clicks(&mouse(&mut h, "down", 114.0, 30.0));
    no_clicks(&mouse(&mut h, "up", 114.0, 30.0));
    assert_eq!(h.rt.views[&1].ui.focus, Some(6));
    assert!(h.rt.views[&1].ui.focus_visible);
    h.value(json!({"op":"type","text":"still focused"}));
    assert_eq!(h.rt.views[&1].ui.fields[&6].text(), "still focused");
    let (msgs, _) = h.req(json!({"op":"click","target":{"x":50,"y":30}}));
    assert!(events(&msgs).iter().any(|e| e.0 == "click" && e.1 == 5), "ordinary control clicks still work");
}

#[test]
fn scrollbar_cursor_overrides_the_field_beneath_it() {
    let mut h = scene(&[create(5, "EditBox", 4, json!({"width":100,"height":100}))]);
    mouse(&mut h, "move", 50.0, 30.0);
    assert_eq!(h.rt.views[&1].ui.cursor, CursorShape::Text);
    mouse(&mut h, "move", 114.0, 30.0);
    assert_eq!(h.rt.views[&1].ui.cursor, CursorShape::default());
}

#[test]
fn only_primary_presses_scroll_and_other_buttons_do_not_end_a_drag() {
    let mut h = scene(&[]);
    for button in [2, 3] {
        h.req(json!({"op":"mouse","action":"down","x":114,"y":105,"button":button}));
        let (msgs, _) = h.req(json!({"op":"mouse","action":"up","x":114,"y":105,"button":button}));
        assert_eq!(top(&h, 3), 0.0);
        assert!(events(&msgs).iter().any(|e| e.0 == "release"));
    }
    mouse(&mut h, "down", 114.0, 30.0);
    for button in [2, 3] {
        for action in ["down", "up"] {
            let (msgs, _) = h.req(json!({"op":"mouse","action":action,"x":114,"y":30,"button":button}));
            no_clicks(&msgs);
        }
    }
    assert_eq!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)), vec![(3, 200)]);
}

#[test]
fn release_after_cursor_left_clears_capture_and_mouse_state_without_coordinates() {
    let mut h = scene(&[]);
    mouse(&mut h, "down", 114.0, 30.0);
    h.rt.pointer_left(1);
    h.rt.pointer_up(1, 1);
    let msgs = h.rt.out.take_captured();
    no_clicks(&msgs);
    assert!(msgs.iter().any(|m| m["t"] == "mouse" && m["state"][0] == 0));
    assert_eq!(h.rt.views[&1].ui.buttons, 0);
    mouse(&mut h, "move", 114.0, 100.0);
    assert_eq!(top(&h, 3), 0.0);
}

#[test]
fn nested_scrollbars_choose_the_innermost_hit_then_the_outer_track() {
    let mut h = Harness::new();
    h.feed(&app(400, 260, &[
        create(3, "Stack", 2, json!({"left":20,"top":20,"width":100,"height":150,"scroll":true})),
        create(4, "Stack", 3, json!({"height":600})),
        create(5, "Stack", 4, json!({"top":10,"left":0,"width":100,"height":100,"scroll":true})),
        create(6, "Stack", 5, json!({"height":500})),
    ]));
    mouse(&mut h, "down", 114.0, 40.0);
    assert_eq!(scrolls(&mouse(&mut h, "move", 114.0, 76.0)), vec![(5, 200)]);
    mouse(&mut h, "up", 114.0, 76.0);
    assert_eq!(top(&h, 3), 0.0);
    assert_eq!(scrolls(&mouse(&mut h, "down", 114.0, 155.0)), vec![(3, 135)]);
    assert_eq!(top(&h, 5), 200.0);
}

#[test]
fn ancestor_clip_and_covering_sibling_block_scrollbar_hits() {
    let mut h = Harness::new();
    h.feed(&app(400, 260, &[
        create(3, "Stack", 2, json!({"left":20,"top":20,"width":100,"height":60})),
        create(5, "Stack", 3, json!({"top":20,"left":0,"width":100,"height":100,"scroll":true})),
        create(6, "Stack", 5, json!({"height":500})),
    ]));
    mouse(&mut h, "down", 114.0, 105.0);
    mouse(&mut h, "up", 114.0, 105.0);
    assert_eq!(top(&h, 5), 0.0);
    assert_eq!(h.rt.picture(1, 1.0).unwrap().pixel(114, 105).unwrap().red(), 255);
    assert_eq!(scrolls(&mouse(&mut h, "down", 114.0, 75.0)), vec![(5, 90)]);
    mouse(&mut h, "up", 114.0, 75.0);

    let mut h = scene(&[create(5, "Button", 2, json!({"left":100,"top":20,"width":30,"height":100,"text":"Cover"}))]);
    mouse(&mut h, "down", 114.0, 30.0);
    mouse(&mut h, "move", 114.0, 66.0);
    let msgs = mouse(&mut h, "up", 114.0, 66.0);
    assert_eq!(top(&h, 3), 0.0);
    assert!(events(&msgs).iter().any(|e| e.0 == "click" && e.1 == 5));
}

#[test]
fn content_without_overflow_and_tiny_viewports_never_start_a_drag() {
    for (height, content) in [(100, 100), (4, 500), (20, 500)] {
        let mut h = scene(&[]);
        props(&mut h, 3, json!({"height":height}));
        props(&mut h, 4, json!({"height":content}));
        mouse(&mut h, "down", 114.0, 23.0);
        mouse(&mut h, "move", 114.0, 100.0);
        mouse(&mut h, "up", 114.0, 100.0);
        assert_eq!(top(&h, 3), 0.0);
        h.rt.picture(1, 1.0).expect("tiny scrollbars paint safely");
    }
}

#[test]
fn root_scrollbar_uses_the_window_viewport() {
    let mut h = Harness::new();
    h.feed(&app(100, 100, &[create(3, "Stack", 2, json!({"height":500}))]));
    mouse(&mut h, "down", 94.0, 10.0);
    assert_eq!(scrolls(&mouse(&mut h, "move", 94.0, 46.0)), vec![(2, 200)]);
    mouse(&mut h, "up", 94.0, 46.0);
}

#[test]
fn scrolling_an_ancestor_out_of_view_cancels_capture_without_a_layout_pass() {
    let mut h = scene(&[]);
    h.feed(&create(5, "Stack", 4, json!({"width":80,"height":100,"scroll":true})).to_string());
    h.feed(&create(6, "Stack", 5, json!({"height":500})).to_string());
    mouse(&mut h, "down", 94.0, 30.0);
    let layouts = h.rt.stats.to_json()["phases"]["layout"]["n"].clone();
    h.feed(r#"{"t":"scroll_to","id":3,"top":200}"#);
    h.feed(r#"{"t":"scroll_to","id":3,"top":0}"#);
    assert_eq!(h.rt.stats.to_json()["phases"]["layout"]["n"], layouts);
    assert!(scrolls(&mouse(&mut h, "move", 94.0, 66.0)).is_empty());
    no_clicks(&mouse(&mut h, "up", 94.0, 66.0));
    assert_eq!(top(&h, 5), 0.0);
}

#[test]
fn resizing_the_window_to_fit_content_cancels_its_scrollbar_drag() {
    let mut h = Harness::new();
    h.feed(&app(100, 100, &[create(3, "Stack", 2, json!({"height":500}))]));
    mouse(&mut h, "down", 94.0, 10.0);
    h.value(json!({"op":"resize","w":100,"h":600}));
    h.value(json!({"op":"resize","w":100,"h":100}));
    assert!(scrolls(&mouse(&mut h, "move", 94.0, 46.0)).is_empty());
    mouse(&mut h, "up", 94.0, 46.0);
    assert_eq!(top(&h, 2), 0.0);
}

#[test]
fn hiding_removing_overflow_or_clipping_cancels_permanently_and_consumes_release() {
    for (id, change, restore) in [
        (3, json!({"hidden":true}), json!({"hidden":false})),
        (4, json!({"height":50}), json!({"height":500})),
        (3, json!({"left":500}), json!({"left":20})),
        (3, json!({"height":4}), json!({"height":100})),
    ] {
        let mut h = scene(&[]);
        mouse(&mut h, "down", 114.0, 30.0);
        props(&mut h, id, change.clone());
        props(&mut h, id, restore);
        assert!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)).is_empty(), "{change}");
        no_clicks(&mouse(&mut h, "up", 114.0, 66.0));
        assert_eq!(top(&h, 3), 0.0, "{change}");
        mouse(&mut h, "down", 114.0, 30.0);
        assert_eq!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)), vec![(3, 200)], "a fresh press works");
    }
}

#[test]
fn destroying_and_reusing_the_id_does_not_revive_capture_or_leak_release() {
    let mut h = scene(&[]);
    mouse(&mut h, "down", 114.0, 30.0);
    h.feed(r#"{"t":"destroy","id":3}"#);
    h.feed(&create(3, "Stack", 2, json!({"left":20,"top":20,"width":100,"height":100,"scroll":true})).to_string());
    h.feed(&create(4, "Stack", 3, json!({"height":500})).to_string());
    mouse(&mut h, "move", 114.0, 66.0);
    no_clicks(&mouse(&mut h, "up", 114.0, 66.0));
    assert_eq!(top(&h, 3), 0.0);
}

#[test]
fn resize_during_drag_uses_new_geometry_and_clamps_the_grab_to_a_smaller_thumb() {
    let mut h = scene(&[]);
    props(&mut h, 4, json!({"height":150})); // Thumb is 64 px high.
    mouse(&mut h, "down", 114.0, 80.0); // Grab 58 px down the thumb.
    props(&mut h, 4, json!({"height":500})); // Thumb shrinks to 24 px.
    assert_eq!(scrolls(&mouse(&mut h, "move", 114.0, 82.0)), vec![(3, 200)]);
    props(&mut h, 3, json!({"height":200}));
    let msgs = mouse(&mut h, "move", 114.0, 220.0);
    assert_eq!(scrolls(&msgs), vec![(3, 300)]);
}

#[test]
fn losing_window_focus_cancels_a_drag_even_if_no_release_arrives() {
    let mut h = scene(&[create(6, "EditLine", 2, json!({"left":150,"top":20,"width":150}))]);
    mouse(&mut h, "down", 114.0, 30.0);
    h.rt.cancel_pointer_drag(1);
    assert_eq!(h.rt.views[&1].ui.buttons, 0);
    mouse(&mut h, "move", 180.0, 30.0);
    assert!(h.rt.views[&1].ui.hover_chain.contains(&6));
    assert_eq!(h.rt.views[&1].ui.cursor, CursorShape::Text, "canceled capture does not freeze hover");
    h.req(json!({"op":"mouse","action":"down","x":50,"y":80,"button":3}));
    let (msgs, _) = h.req(json!({"op":"mouse","action":"up","x":50,"y":80,"button":3}));
    assert!(events(&msgs).iter().any(|e| e.0 == "release"), "secondary presses work after focus returns");
    mouse(&mut h, "move", 114.0, 66.0);
    assert_eq!(top(&h, 3), 0.0);
    // A new primary down recovers even when the old release was delivered to another window.
    mouse(&mut h, "down", 114.0, 30.0);
    assert_eq!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)), vec![(3, 200)]);
}

#[test]
fn opening_a_popup_or_modal_cancels_the_drag_and_owns_no_stray_release() {
    for modal in [false, true] {
        let mut h = scene(&[create(5, "ListBox", 2, json!({"left":150,"top":20,"items":["A","B"]}))]);
        h.rt.set_focus(1, Some(5));
        h.rt.views.get_mut(&1).unwrap().ui.focus_visible = true;
        mouse(&mut h, "down", 114.0, 30.0);
        if modal {
            let dialog = DialogRequest { kind: "ask".into(), message: "Name?".into(), default: Value::Null, title: None, secret: false };
            h.rt.open_modal(1, 90, &dialog); // In-window modal state only: no OS window or dialog.
            assert!(h.rt.views[&1].ui.modal.is_some());
        } else {
            h.value(json!({"op":"key","key":"space"}));
            assert!(h.rt.views[&1].ui.popup.is_some());
        }
        h.value(json!({"op":"key","key":"escape"}));
        assert!(h.rt.views[&1].ui.modal.is_none() && h.rt.views[&1].ui.popup.is_none());
        assert!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)).is_empty());
        no_clicks(&mouse(&mut h, "up", 114.0, 66.0));
        assert_eq!(top(&h, 3), 0.0);
    }
}

#[test]
fn becoming_inert_cancels_scrollbar_capture_without_reviving_it() {
    for (inert_id, move_while_inert) in [(2, true), (3, true), (2, false), (3, false)] {
        let mut h = scene(&[]);
        mouse(&mut h, "down", 114.0, 30.0);
        props(&mut h, inert_id, json!({"inert":true}));
        if move_while_inert {
            assert!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)).is_empty());
        }
        assert_eq!(top(&h, 3), 0.0);
        props(&mut h, inert_id, json!({"inert":false}));
        assert!(scrolls(&mouse(&mut h, "move", 114.0, 80.0)).is_empty());
        no_clicks(&mouse(&mut h, "up", 114.0, 80.0));
        mouse(&mut h, "down", 114.0, 30.0);
        assert_eq!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)), vec![(3, 200)]);
    }
}

#[test]
fn reparenting_a_scroller_into_an_inert_subtree_cancels_capture() {
    let mut h = scene(&[create(20, "Stack", 2, json!({"left":0,"top":0,"width":300,"height":200,"inert":true}))]);
    mouse(&mut h, "down", 114.0, 30.0);
    h.feed(r#"{"t":"reparent","id":3,"parent":20}"#);
    props(&mut h, 20, json!({"inert":false}));
    assert!(scrolls(&mouse(&mut h, "move", 114.0, 66.0)).is_empty());
    no_clicks(&mouse(&mut h, "up", 114.0, 66.0));
}
