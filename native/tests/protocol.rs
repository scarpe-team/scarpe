//! Protocol fixtures: feed NDJSON to a headless Runtime, assert layout and events.

mod common;

use common::{app, create, events, named, Harness};
use serde_json::{json, Value};

#[test]
fn hello_world_lays_out_a_para() {
    let mut h = Harness::new();
    let msgs = h.fixture("hello");
    assert_eq!(msgs[0]["t"], "ready");
    let para = h.node(|n| n["kind"] == "Para");
    assert_eq!(para["text"], "Hello, World!");
    // Text blocks sit inside Shoes 3's 4 px margins (ledger C9).
    assert_eq!((para["x"].as_f64(), para["y"].as_f64(), para["h"].as_f64()), (Some(4.0), Some(4.0), Some(14.4)));
    assert_eq!(para["visible"], true);
}

#[test]
fn clicking_a_button_sends_click_before_the_reply() {
    let mut h = Harness::new();
    h.scene("button_para");
    let button = h.id_of_kind("Button");
    let (evs, reply) = h.req(json!({"op": "click", "target": {"id": button}}));
    assert_eq!(reply["value"]["hit"], json!(button));
    let evs = events(&evs);
    let clicks = named(&evs, "click");
    assert_eq!(clicks.len(), 1);
    assert_eq!(clicks[0].1, json!(button));
    assert_eq!(clicks[0].2, json!([]));
    assert!(named(&evs, "hover").iter().any(|e| e.1 == json!(button)), "{evs:?}");
}

#[test]
fn click_by_text_finds_the_button_label() {
    let mut h = Harness::new();
    h.fixture("button_para");
    let button = h.id_of_kind("Button");
    let (evs, reply) = h.req(json!({"op": "click", "target": {"text": "Push me"}}));
    assert_eq!(reply["value"]["hit"], json!(button));
    assert_eq!(named(&events(&evs), "click").len(), 1);
}

#[test]
fn clicking_something_hidden_is_an_error() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Button", 2, json!({"text": "Gone", "hidden": true}))]));
    let (evs, reply) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert!(reply["error"].as_str().unwrap().contains("not visible"));
    assert!(named(&events(&evs), "click").is_empty());
    let (_, reply) = h.req(json!({"op": "click", "target": {"text": "Nowhere"}}));
    assert!(reply["error"].is_string());
}

#[test]
fn a_covered_target_reports_what_is_on_top() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[
        create(3, "Button", 2, json!({"text": "Under", "width": 100, "height": 40})),
        create(4, "Rect", 2, json!({"left": 0, "top": 0, "width": 150, "height": 60})),
    ]));
    let (evs, reply) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert!(reply["error"].as_str().unwrap().contains("covered by Rect 4"), "{reply}");
    assert_eq!(reply["value"]["hit"], json!(4));
    assert!(named(&events(&evs), "click").is_empty());
}

#[test]
fn typing_into_an_edit_line_sends_change_per_edit() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "EditLine", 2, json!({"text": ""}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(3));
    let (evs, _) = h.req(json!({"op": "type", "text": "abc"}));
    let changes: Vec<Value> = named(&events(&evs), "change").iter().map(|e| e.2.clone()).collect();
    assert_eq!(changes, vec![json!(["a"]), json!(["ab"]), json!(["abc"])]);
    // Lacci echoes the text back; that must not move the caret or fire again.
    let echo = h.feed(&json!({"t":"props","id":3,"props":{"text":"abc"}}).to_string());
    assert!(named(&events(&echo), "change").is_empty());
    let (evs, _) = h.req(json!({"op": "key", "key": "backspace"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["ab"]));
    h.req(json!({"op": "key", "key": "left"}));
    let (evs, _) = h.req(json!({"op": "type", "text": "X"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["aXb"]));
    h.req(json!({"op": "key", "key": ":control_a"}));
    let (evs, _) = h.req(json!({"op": "type", "text": "z"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["z"]));
}

#[test]
fn programmatic_text_replaces_the_field() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "EditLine", 2, json!({"text": "one"}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    h.feed(&json!({"t":"props","id":3,"props":{"text":"two"}}).to_string());
    let (evs, _) = h.req(json!({"op": "type", "text": "!"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["two!"]));
    assert_eq!(h.node(|n| n["id"] == 3)["text"], "two!");
}

#[test]
fn edit_box_takes_newlines() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "EditBox", 2, json!({"text": ""}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    let (evs, _) = h.req(json!({"op": "type", "text": "a\nb"}));
    assert_eq!(named(&events(&evs), "change").last().unwrap().2, json!(["a\nb"]));
}

#[test]
fn tab_moves_focus_through_inputs_in_order() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "EditLine", 2, json!({"text": ""})),
        create(4, "EditLine", 2, json!({"text": ""})),
        create(5, "Button", 2, json!({"text": "Go"})),
    ]));
    assert_eq!(h.value(json!({"op": "focused"})), Value::Null);
    let (evs, _) = h.req(json!({"op": "key", "key": "tab"}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(3));
    assert!(named(&events(&evs), "keypress").is_empty());
    h.req(json!({"op": "key", "key": "tab"}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(4));
    h.req(json!({"op": "key", "key": "tab"}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(5));
    let (evs, _) = h.req(json!({"op": "key", "key": "\n"}));
    assert_eq!(named(&events(&evs), "click")[0].1, json!(5), "return presses a focused button");
    h.req(json!({"op": "key", "key": "shift_tab"}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(4));
    h.feed(&json!({"t":"focus","id":3}).to_string());
    assert_eq!(h.value(json!({"op": "focused"})), json!(3));
}

#[test]
fn list_box_popup_picks_an_item() {
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[create(3, "ListBox", 2, json!({"items": ["Apple", "Banana", 3], "chosen": "Apple"}))]));
    assert_eq!(h.node(|n| n["id"] == 3)["text"], "Apple");
    let (evs, _) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert!(named(&events(&evs), "change").is_empty(), "opening the popup changes nothing");
    let (evs, reply) = h.req(json!({"op": "click", "target": {"text": "Banana"}}));
    assert_eq!(reply["value"]["hit"], json!(3));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["Banana"]));
    h.feed(&json!({"t":"props","id":3,"props":{"chosen":"Banana"}}).to_string());
    assert_eq!(h.node(|n| n["id"] == 3)["text"], "Banana");
    // Keyboard: open, move down, choose.
    h.value(json!({"op": "click", "target": {"id": 3}}));
    h.req(json!({"op": "key", "key": "down"}));
    let (evs, _) = h.req(json!({"op": "key", "key": "\n"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["3"]));
}

#[test]
fn check_and_radio_send_click_and_draw_the_echo() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Check", 2, json!({"checked": false})), create(4, "Radio", 2, json!({"group": "g"}))]));
    let (evs, _) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert_eq!(named(&events(&evs), "click")[0], &("click".to_string(), json!(3), json!([])));
    let before = h.value(json!({"op": "pixel", "x": 9, "y": 9}));
    h.feed(&json!({"t":"props","id":3,"props":{"checked":true}}).to_string());
    let after = h.value(json!({"op": "pixel", "x": 9, "y": 9}));
    assert_ne!(before, after, "the echoed checked state is drawn");
    let (evs, _) = h.req(json!({"op": "click", "target": {"id": 4}}));
    assert_eq!(named(&events(&evs), "click")[0].1, json!(4));
}

#[test]
fn links_are_hit_inside_their_para() {
    let mut h = Harness::new();
    h.scene("rich_text");
    let link = h.node(|n| n["kind"] == "Link");
    assert_eq!(link["text"], "a link");
    let (evs, reply) = h.req(json!({"op": "click", "target": {"text": "a link"}}));
    assert_eq!(reply["value"]["hit"], link["id"]);
    let evs = events(&evs);
    assert_eq!(named(&evs, "click")[0].1, link["id"]);
    assert!(named(&evs, "hover").iter().any(|e| e.1 == link["id"]));
}

#[test]
fn slot_clicks_carry_button_and_coordinates() {
    let mut h = Harness::new();
    h.fixture("events");
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 100, "y": 70}}));
    let evs = events(&evs);
    let clicks = named(&evs, "click");
    // has_click on the stack: window coordinates. The slot's click item: slot-relative.
    assert!(clicks.iter().any(|e| e.1 == json!(3) && e.2 == json!([1, 100, 70])), "{clicks:?}");
    assert!(clicks.iter().any(|e| e.1 == json!(6) && e.2 == json!([1, 80, 50])), "{clicks:?}");
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 300, "y": 180}, "button": 3}));
    assert!(named(&events(&evs), "click").iter().all(|e| e.1 != json!(3) && e.1 != json!(6)), "outside the slot");
}

#[test]
fn keypress_names_follow_the_manual() {
    let mut h = Harness::new();
    h.fixture("events");
    let keys = |h: &mut Harness, key: &str| -> Vec<Value> {
        let (evs, _) = h.req(json!({"op": "key", "key": key}));
        named(&events(&evs), "keypress").iter().map(|e| e.2[0].clone()).collect()
    };
    assert_eq!(keys(&mut h, "left"), vec![json!(":left")]);
    assert_eq!(keys(&mut h, "a"), vec![json!("a")]);
    assert_eq!(keys(&mut h, "\n"), vec![json!("\n")]);
    assert_eq!(keys(&mut h, ":control_q"), vec![json!(":control_q")]);
    assert_eq!(keys(&mut h, "shift_page_down"), vec![json!(":shift_page_down")]);
    let (evs, _) = h.req(json!({"op": "type", "text": "Hi"}));
    let typed: Vec<Value> = named(&events(&evs), "keypress").iter().map(|e| e.2[0].clone()).collect();
    assert_eq!(typed, vec![json!("H"), json!("i")]);
}

#[test]
fn a_focused_text_input_keeps_plain_keys_to_itself() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        create(3, "EditLine", 2, json!({"text": ""})),
        create(4, "SubscriptionItem", 2, json!({"shoes_api_name": "keypress", "args": []})),
    ]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    let (evs, _) = h.req(json!({"op": "type", "text": "q"}));
    assert!(named(&events(&evs), "keypress").is_empty());
    let (evs, _) = h.req(json!({"op": "key", "key": "escape"}));
    assert_eq!(named(&events(&evs), "keypress")[0].2, json!([":escape"]));
    let (evs, _) = h.req(json!({"op": "key", "key": ":control_s"}));
    assert_eq!(named(&events(&evs), "keypress")[0].2, json!([":control_s"]));
}

#[test]
fn stopped_subscriptions_are_silent() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(4, "SubscriptionItem", 2, json!({"shoes_api_name": "keypress", "args": [], "stopped": true}))]));
    let (evs, _) = h.req(json!({"op": "key", "key": "a"}));
    assert!(named(&events(&evs), "keypress").is_empty());
}

#[test]
fn hover_and_leave_fire_on_transitions_only() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "Button", 2, json!({"text": "B", "width": 100, "height": 30}))]));
    let (evs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 10, "y": 10}));
    let evs = events(&evs);
    assert!(named(&evs, "hover").iter().any(|e| e.1 == json!(3)));
    let (evs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 20, "y": 12}));
    assert!(named(&events(&evs), "hover").is_empty(), "no repeat while inside");
    let (evs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 200, "y": 80}));
    let evs = events(&evs);
    assert_eq!(named(&evs, "leave").len(), 1);
    assert_eq!(named(&evs, "leave")[0].1, json!(3));
}

#[test]
fn slot_hover_leave_and_motion_items() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Stack", 2, json!({"left": 50, "top": 50, "width": 100, "height": 100})),
        create(4, "SubscriptionItem", 3, json!({"shoes_api_name": "hover"})),
        create(5, "SubscriptionItem", 3, json!({"shoes_api_name": "leave"})),
        create(6, "SubscriptionItem", 3, json!({"shoes_api_name": "motion"})),
    ]));
    let (evs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 60, "y": 70}));
    let evs = events(&evs);
    assert!(named(&evs, "hover").iter().any(|e| e.1 == json!(4)));
    assert_eq!(named(&evs, "motion")[0].2, json!([10, 20, false, false]));
    let (evs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 250, "y": 190}));
    let evs = events(&evs);
    assert!(named(&evs, "leave").iter().any(|e| e.1 == json!(5)));
    assert!(named(&evs, "motion").is_empty());
}

#[test]
fn mouse_state_is_reported() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[]));
    let (msgs, _) = h.req(json!({"op": "mouse", "action": "down", "x": 12, "y": 34}));
    assert!(msgs.iter().any(|m| m["t"] == "mouse" && m["state"] == json!([1, 12, 34])), "{msgs:?}");
    let (msgs, _) = h.req(json!({"op": "mouse", "action": "up", "x": 12, "y": 34}));
    assert!(msgs.iter().any(|m| m["t"] == "mouse" && m["state"] == json!([0, 12, 34])));
}

#[test]
fn para_hit_reports_the_character_under_the_pointer() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "Para", 2, json!({"text_items": ["Hello"]}))]));
    let (msgs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 5, "y": 9}));
    assert!(msgs.iter().any(|m| m["t"] == "para_hit" && m["id"] == 3 && m["value"] == 0), "{msgs:?}");
    let (msgs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 250, "y": 80}));
    assert!(msgs.iter().any(|m| m["t"] == "para_hit" && m["id"] == 3 && m["value"].is_null()));
}

#[test]
fn wheel_scrolls_the_window_and_reports_it() {
    let mut h = Harness::new();
    h.scene("scroll");
    let before = h.node(|n| n["text"] == "Line 1 of a document taller than its window")["y"].as_f64().unwrap();
    let (msgs, _) = h.req(json!({"op": "wheel", "dy": 100, "x": 100, "y": 100}));
    assert!(msgs.iter().any(|m| m["t"] == "scroll" && m["id"] == 2 && m["top"] == 100), "{msgs:?}");
    let after = h.node(|n| n["text"] == "Line 1 of a document taller than its window")["y"].as_f64().unwrap();
    assert_eq!(before - after, 100.0);
    h.req(json!({"op": "wheel", "dy": 10000, "x": 100, "y": 100}));
    let last = h.node(|n| n["text"] == "Line 30 of a document taller than its window");
    let bottom = last["y"].as_f64().unwrap() + last["h"].as_f64().unwrap();
    assert!(bottom <= 240.0 && bottom > 200.0, "scrolled to the end, not past it: {bottom}");
    h.feed(&json!({"t":"scroll_to","id":2,"top":0}).to_string());
    let top = h.node(|n| n["text"] == "Line 1 of a document taller than its window")["y"].as_f64().unwrap();
    assert_eq!(top, before);
}

#[test]
fn wheel_items_get_delta_up_positive() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(4, "SubscriptionItem", 2, json!({"shoes_api_name": "wheel"}))]));
    let (evs, _) = h.req(json!({"op": "wheel", "dy": -30, "x": 10, "y": 20}));
    assert_eq!(named(&events(&evs), "wheel")[0].2, json!([30.0, 10, 20]));
}

#[test]
fn headless_dialogs_answer_without_opening() {
    let mut h = Harness::new();
    h.feed(&app(100, 100, &[]));
    for (kind, value, cancelled) in [
        ("alert", Value::Null, false),
        ("confirm", json!(false), true),
        ("ask", json!(""), true),
        ("ask_color", Value::Null, true),
        ("ask_open_file", Value::Null, true),
        ("ask_save_folder", Value::Null, true),
    ] {
        let (_, reply) = h.req(json!({"op": "dialog", "kind": kind, "message": "?", "default": null}));
        assert_eq!(reply["value"], value, "{kind}");
        assert_eq!(reply["cancelled"], json!(cancelled), "{kind}");
        assert_eq!(reply["error"], Value::Null);
    }
}

#[test]
fn every_req_gets_exactly_one_reply() {
    let mut h = Harness::new();
    h.feed(&app(100, 100, &[]));
    let (_, reply) = h.req(json!({"op": "teleport"}));
    assert!(reply["error"].as_str().unwrap().contains("unknown op"));
    let (_, reply) = h.req(json!({"op": "click"}));
    assert!(reply["error"].is_string());
    let (_, reply) = h.req(json!({"op": "key", "key": "hyperspace"}));
    assert!(reply["error"].as_str().unwrap().contains("unknown key"));
    assert_eq!(h.value(json!({"op": "ping"})), json!("pong"));
    let frames = h.value(json!({"op": "frames", "n": 2}));
    assert!(frames.as_u64().unwrap() >= 2);
    let msgs = h.feed(r#"{"t":"req","req":77,"op":"layout","app":999}"#);
    assert_eq!(msgs.iter().filter(|m| m["req"] == 77).count(), 1);
}

#[test]
fn bad_lines_are_logged_not_fatal() {
    let mut h = Harness::new();
    let msgs = h.feed("this is not json\n{\"t\":\"warp\"}\n");
    assert_eq!(msgs.iter().filter(|m| m["t"] == "log").count(), 2);
    h.feed(&app(100, 100, &[]));
    assert_eq!(h.value(json!({"op": "ping"})), json!("pong"));
}

#[test]
fn props_for_unknown_ids_are_ignored_and_destroy_takes_the_subtree() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        json!({"t":"props","id":5,"props":{"text_items":["early"]}}),
        create(3, "Stack", 2, json!({})),
        create(4, "Para", 3, json!({"text_items": ["inside"]})),
    ]));
    assert_eq!(h.layout().len(), 3);
    h.feed(&json!({"t":"destroy","id":3}).to_string());
    h.feed(&json!({"t":"destroy","id":3}).to_string());
    let kinds: Vec<Value> = h.layout().iter().map(|n| n["kind"].clone()).collect();
    assert_eq!(kinds, vec![json!("DocumentRoot")]);
}

#[test]
fn span_changes_reach_their_para() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        json!({"t":"create","id":5,"kind":"Strong","parent":null,"props":{"text_items":["bold"]}}),
        create(6, "Para", 2, json!({"text_items": ["a ", 5]})),
    ]));
    assert_eq!(h.node(|n| n["id"] == 6)["text"], "a bold");
    h.feed(&json!({"t":"props","id":5,"props":{"text_items":["BOLD"]}}).to_string());
    assert_eq!(h.node(|n| n["id"] == 6)["text"], "a BOLD");
}

#[test]
fn index_places_prepended_children_first() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Para", 2, json!({"text_items": ["second"]})),
        json!({"t":"create","id":4,"kind":"Para","parent":2,"index":0,"props":{"text_items":["first"]}}),
    ]));
    let texts: Vec<Value> = h.layout().iter().filter(|n| n["kind"] == "Para").map(|n| n["text"].clone()).collect();
    assert_eq!(texts, vec![json!("first"), json!("second")]);
}

#[test]
fn quit_ends_the_run() {
    let mut h = Harness::new();
    h.feed(&app(100, 100, &[]));
    assert_eq!(h.rt.exit, None);
    h.feed(r#"{"t":"quit","app":null}"#);
    assert_eq!(h.rt.exit, Some(0));
}

#[test]
fn snapshot_and_pixel_see_what_was_drawn() {
    let mut h = Harness::new();
    h.feed(&app(100, 60, &[
        create(3, "Background", 2, json!({"fill": {"rgba": [255, 0, 0, 255]}})),
        create(4, "Rect", 2, json!({"left": 10, "top": 10, "width": 20, "height": 20, "fill": {"rgba": [0, 0, 255, 255]}, "stroke": {"rgba": [0, 0, 255, 255]}})),
    ]));
    assert_eq!(h.value(json!({"op": "pixel", "x": 50, "y": 50})), json!([255, 0, 0, 255]));
    assert_eq!(h.value(json!({"op": "pixel", "x": 20, "y": 20})), json!([0, 0, 255, 255]));
    let path = std::env::temp_dir().join(format!("scarpe-native-snap-{}.png", std::process::id()));
    let shot = h.value(json!({"op": "snapshot", "path": path.to_string_lossy(), "scale": 2}));
    assert_eq!((shot["w"].as_u64(), shot["h"].as_u64()), (Some(200), Some(120)));
    let img = image::open(&path).unwrap().to_rgba8();
    assert_eq!(img.get_pixel(100, 100).0, [255, 0, 0, 255]);
    let _ = std::fs::remove_file(path);
}

#[test]
fn resize_relayouts_and_tells_ruby() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Flow", 2, json!({"height": 10}))]));
    assert_eq!(h.node(|n| n["id"] == 3)["w"], json!(200.0));
    let (msgs, _) = h.req(json!({"op": "resize", "w": 300, "h": 150}));
    assert!(msgs.iter().any(|m| m["t"] == "resize" && m["w"] == 300 && m["h"] == 150));
    assert_eq!(h.node(|n| n["id"] == 3)["w"], json!(300.0));
}

#[test]
fn an_app_without_a_size_opens_at_600_by_500() {
    // Ledger A1 (Q1): Shoes 3 and Shoes 4 both default to 600x500.
    let mut h = Harness::new();
    let lines = [
        json!({"t":"hello","v":1,"pid":1}),
        json!({"t":"create","id":2,"kind":"DocumentRoot","parent":null,"props":{}}),
        json!({"t":"create","id":1,"kind":"App","parent":null,"props":{},"doc_root":2}),
        json!({"t":"run","app":1}),
        json!({"t":"flush"}),
    ];
    h.feed(&lines.iter().map(|l| format!("{l}\n")).collect::<String>());
    let root = h.node(|n| n["kind"] == "DocumentRoot");
    assert_eq!((root["w"].clone(), root["h"].clone()), (json!(600.0), json!(500.0)));
}

#[test]
fn a_para_fill_highlights_its_text_not_its_box() {
    // Manual 1208-1210: text's fill is "painted in the background (as if marked with a
    // highlighter pen)"; Shoes 3 makes it a Pango background over the text.
    let mut h = Harness::new();
    let yellow = json!({"rgba": [255, 255, 0, 255]});
    h.feed(&app(300, 100, &[create(4, "Stack", 2, json!({})), create(3, "Para", 4, json!({"text_items": ["Hi"], "fill": yellow}))]));
    let para = h.node(|n| n["id"] == 3);
    let (x, y, w, ht) = (para["x"].as_f64().unwrap(), para["y"].as_f64().unwrap(), para["w"].as_f64().unwrap(), para["h"].as_f64().unwrap());
    assert!(w > 250.0, "a para in a stack has a box as wide as the stack: {para}");
    // Just inside the line's top, above the letters.
    let at = |h: &mut Harness, px: f64| h.value(json!({"op": "pixel", "x": px, "y": y + 1.0}));
    assert_eq!(at(&mut h, x + 2.0), json!([255, 255, 0, 255]), "behind the text is yellow");
    assert_eq!(at(&mut h, x + w - 2.0), json!([255, 255, 255, 255]), "the rest of the box is not");
    assert!(ht < 20.0, "{ht}");
}

/// The `layout` messages Rust pushed, as {id: [x, y, w, h, scroll_h]} per message.
fn pushed(msgs: &[Value]) -> Vec<std::collections::BTreeMap<i64, Vec<f64>>> {
    msgs.iter()
        .filter(|m| m["t"] == "layout")
        .map(|m| {
            m["rects"]
                .as_array()
                .unwrap()
                .iter()
                .map(|r| {
                    let r = r.as_array().unwrap();
                    (r[0].as_i64().unwrap(), r[1..].iter().map(|v| v.as_f64().unwrap()).collect())
                })
                .collect()
        })
        .collect()
}

#[test]
fn layout_pushes_every_rect_first_then_only_what_moved() {
    // Cross-lane contract (a): Rust tells Ruby where things landed (ledger A4, C5).
    let mut h = Harness::new();
    let msgs = h.feed(&app(300, 200, &[
        create(3, "Stack", 2, json!({"height": 50, "scroll": true})),
        create(4, "Button", 3, json!({"text": "a", "width": 40, "height": 80})),
        create(5, "Button", 2, json!({"text": "b", "width": 40, "height": 20})),
    ]));
    let first = pushed(&msgs);
    assert_eq!(first.len(), 1, "one message for the first layout: {msgs:?}");
    let first = &first[0];
    assert_eq!(first.keys().copied().collect::<Vec<_>>(), vec![2, 3, 4, 5], "every laid-out node");
    assert_eq!(first[&3], vec![0.0, 0.0, 300.0, 50.0, 80.0], "a slot's scroll height is its content's");
    assert_eq!(first[&4], vec![0.0, 0.0, 40.0, 80.0, 80.0], "anything else reports its own height");
    assert_eq!(msgs.iter().position(|m| m["t"] == "layout"), Some(1), "right after ready, before anything else");

    let msgs = h.feed(&json!({"t":"props","id":5,"props":{"width":60}}).to_string());
    assert!(pushed(&msgs).is_empty(), "nothing is pushed before the batch's flush");
    let msgs = h.feed(&json!({"t":"flush"}).to_string());
    let moved = pushed(&msgs);
    assert_eq!(moved.len(), 1);
    assert_eq!(moved[0].keys().copied().collect::<Vec<_>>(), vec![5], "only the node whose rect changed");
    assert_eq!(moved[0][&5], vec![0.0, 50.0, 60.0, 20.0, 20.0]);

    h.feed(&json!({"t":"destroy","id":5}).to_string());
    let msgs = h.feed(&format!("{}\n{}", json!({"t":"create","id":6,"kind":"Button","parent":2,"index":null,"widget":false,"props":{"text":"c","width":10,"height":20}}), json!({"t":"flush"})));
    let later = pushed(&msgs);
    assert_eq!(later.len(), 1);
    assert_eq!(later[0].keys().copied().collect::<Vec<_>>(), vec![6], "destroyed ids are not sent again");
    assert!(pushed(&h.feed(&json!({"t":"flush"}).to_string())).is_empty(), "no layout, no message");
}

#[test]
fn app_title_and_size_props() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[]));
    h.feed(&json!({"t":"props","id":1,"props":{"width":320,"height":240}}).to_string());
    assert_eq!(h.node(|n| n["kind"] == "DocumentRoot")["w"], json!(320.0));
}

#[test]
fn the_widgets_fixture_runs_its_interactions() {
    let mut h = Harness::new();
    let msgs = h.fixture("widgets");
    let evs = events(&msgs);
    let edit = h.node(|n| n["kind"] == "EditLine")["id"].clone();
    assert_eq!(named(&evs, "change").iter().rfind(|e| e.1 == edit).unwrap().2, json!(["Hello, Shoes world"]));
    let list = h.id_of_kind("ListBox");
    assert!(named(&evs, "change").iter().any(|e| e.1 == json!(list) && e.2 == json!(["Cherry"])));
    let errors: Vec<&Value> = msgs.iter().filter(|m| m["t"] == "reply" && !m["error"].is_null()).collect();
    assert!(errors.is_empty(), "{errors:?}");
}

#[test]
fn readonly_fields_take_focus_but_not_edits() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "EditLine", 2, json!({"text": "fixed", "state": "readonly"}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(3));
    let (evs, _) = h.req(json!({"op": "type", "text": "xyz"}));
    assert!(named(&events(&evs), "change").is_empty());
    h.req(json!({"op": "key", "key": "backspace"}));
    assert_eq!(h.node(|n| n["id"] == 3)["text"], "fixed");
}

#[test]
fn disabled_controls_ignore_the_pointer_and_tab() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        create(3, "Button", 2, json!({"text": "Off", "state": "disabled"})),
        create(4, "Button", 2, json!({"text": "On"})),
    ]));
    let (evs, _) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert!(named(&events(&evs), "click").is_empty());
    h.req(json!({"op": "key", "key": "tab"}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(4));
}

#[test]
fn the_wheel_scrolls_an_edit_box_before_the_page() {
    let mut h = Harness::new();
    let long: String = (1..=30).map(|i| format!("line {i}\n")).collect();
    h.feed(&app(300, 200, &[create(3, "EditBox", 2, json!({"text": long, "height": 80}))]));
    let before = h.value(json!({"op": "pixel", "x": 40, "y": 20}));
    let (msgs, _) = h.req(json!({"op": "wheel", "dy": 60, "x": 40, "y": 40}));
    assert!(msgs.iter().all(|m| m["t"] != "scroll"), "the page did not move");
    let after = h.value(json!({"op": "pixel", "x": 40, "y": 20}));
    let snapshot_differs = before != after || {
        // The same pixel can match by chance; compare a whole row instead.
        let row = |h: &mut Harness| (10..120).map(|x| h.value(json!({"op": "pixel", "x": x, "y": 14}))).collect::<Vec<_>>();
        let a = row(&mut h);
        h.req(json!({"op": "wheel", "dy": -60, "x": 40, "y": 40}));
        let b = row(&mut h);
        a != b
    };
    assert!(snapshot_differs, "the field's text moved");
}

#[test]
fn shift_selection_cut_and_paste_use_a_private_clipboard_headless() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "EditLine", 2, json!({"text": ""}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    h.req(json!({"op": "type", "text": "hello world"}));
    for _ in 0..5 {
        h.req(json!({"op": "key", "key": "shift_left"}));
    }
    let (evs, _) = h.req(json!({"op": "key", "key": ":control_x"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["hello "]));
    h.req(json!({"op": "key", "key": "home"}));
    let (evs, _) = h.req(json!({"op": "key", "key": ":control_v"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["worldhello "]));
    // A plain arrow collapses a selection instead of moving past it.
    h.req(json!({"op": "key", "key": "shift_right"}));
    h.req(json!({"op": "key", "key": "left"}));
    let (evs, _) = h.req(json!({"op": "type", "text": "!"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["world!hello "]));
}

#[test]
fn twin_links_in_different_paras_keep_their_own_ids() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        json!({"t":"create","id":5,"kind":"Link","parent":null,"props":{"text_items":["same"],"has_block":true}}),
        json!({"t":"create","id":6,"kind":"Link","parent":null,"props":{"text_items":["same"],"has_block":true}}),
        create(7, "Para", 2, json!({"text_items": [5]})),
        create(8, "Para", 2, json!({"text_items": [6]})),
    ]));
    let (evs, _) = h.req(json!({"op": "click", "target": {"id": 6}}));
    assert_eq!(named(&events(&evs), "click")[0].1, json!(6));
}

#[test]
fn text_fragments_with_has_click_get_pointer_clicks() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        json!({"t":"create","id":5,"kind":"Em","parent":null,"props":{"text_items":["deep"]}}),
        json!({"t":"create","id":6,"kind":"Strong","parent":null,"props":{"text_items":["bold ", 5]}}),
        create(7, "Para", 2, json!({"text_items": ["plain ", 6]})),
        json!({"t":"props","id":6,"props":{"has_click":true}}),
    ]));
    let para = h.node(|n| n["id"] == 7);
    let (x, y) = (para["x"].as_f64().unwrap() + para["w"].as_f64().unwrap() - 4.0, para["y"].as_f64().unwrap() + 7.0);
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": x, "y": y}}));
    let evs = events(&evs);
    let clicks = named(&evs, "click");
    assert_eq!(clicks.len(), 1, "{evs:?}");
    assert_eq!(clicks[0].1, json!(6), "the strong around the em takes the click");
    assert_eq!(clicks[0].2[0], json!(1));
    let hovered: Vec<Value> = named(&evs, "hover").iter().map(|e| e.1.clone()).collect();
    assert!(hovered.contains(&json!(5)) && hovered.contains(&json!(6)), "{hovered:?}");
}

#[test]
fn fragments_appear_in_the_layout_and_take_clicks_by_id() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        json!({"t":"create","id":5,"kind":"Strong","parent":null,"props":{"text_items":["bold"]}}),
        create(7, "Para", 2, json!({"text_items": ["plain ", 5]})),
        json!({"t":"props","id":5,"props":{"has_click":true,"has_release":true}}),
    ]));
    let strong = h.node(|n| n["id"] == 5);
    assert_eq!(strong["kind"], "Strong");
    assert_eq!(strong["text"], "bold");
    assert!(strong["x"].as_f64().unwrap() > 10.0);
    let (evs, _) = h.req(json!({"op": "click", "target": {"id": 5}}));
    let evs = events(&evs);
    assert_eq!(named(&evs, "click")[0].1, json!(5));
    assert_eq!(named(&evs, "release")[0].1, json!(5));
}
