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
    // has_click on the stack and the slot's click item: both in window coordinates (Q4).
    assert!(clicks.iter().any(|e| e.1 == json!(3) && e.2 == json!([1, 100, 70])), "{clicks:?}");
    assert!(clicks.iter().any(|e| e.1 == json!(6) && e.2 == json!([1, 100, 70])), "{clicks:?}");
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

/// Alt-/ (Cmd-/ on a Mac, which Shoes names alt_/, ledger Q5) opens the Shoes console, and the
/// app never hears the key: Shoes 3's shoes_app_keypress runs Shoes.show_log for it before any
/// keypress block (s3_app.c:773-776; manual 721-722, 2239-2240; ledger H10).
#[test]
fn alt_slash_asks_for_the_console_and_the_app_never_hears_it() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        create(3, "EditLine", 2, json!({"text": ""})),
        json!({"t": "create", "id": 4, "kind": "SubscriptionItem", "parent": 2, "props": {"shoes_api_name": "keypress"}}),
    ]));
    let console = |msgs: &[Value]| msgs.iter().filter(|m| m["t"] == "console").map(|m| m["app"].clone()).collect::<Vec<_>>();
    for key in [":alt_/", ":command_/"] {
        let (msgs, _) = h.req(json!({"op": "key", "key": key}));
        assert_eq!(console(&msgs), vec![json!(1)], "{key} asks for the console: {msgs:?}");
        assert!(named(&events(&msgs), "keypress").is_empty(), "{key} never reaches the app: {msgs:?}");
    }
    h.value(json!({"op": "click", "target": {"id": 3}}));
    let (msgs, _) = h.req(json!({"op": "key", "key": ":alt_/"}));
    assert_eq!(console(&msgs), vec![json!(1)], "a focused field does not keep it");
    assert!(named(&events(&msgs), "change").is_empty(), "or type it");
    let (msgs, _) = h.req(json!({"op": "key", "key": ":alt_q"}));
    assert!(console(&msgs).is_empty());
    assert_eq!(named(&events(&msgs), "keypress").len(), 1, "other Alt keys reach the app as before");
}

/// A list box or button the mouse pressed takes focus without a ring, and so leaves Space,
/// Return and the arrows to the app, as a Mac's pop-up buttons and push buttons do. Space
/// reopened the popup and the app's keypress never heard it (Bloop Sequencer met this).
/// Focus from the keyboard or the app's `focus` still takes them (ledger G9, G13).
#[test]
fn a_control_the_mouse_pressed_leaves_keys_to_the_app() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "ListBox", 2, json!({"items": ["One", "Two", "Three"], "chosen": "Two"})),
        create(4, "Button", 2, json!({"text": "Go"})),
        json!({"t": "create", "id": 5, "kind": "SubscriptionItem", "parent": 2, "props": {"shoes_api_name": "keypress"}}),
    ]));
    let keyed = |h: &mut Harness, key: &str| {
        let (evs, _) = h.req(json!({"op": "key", "key": key}));
        let evs = events(&evs);
        let names = |name: &str| named(&evs, name).iter().map(|e| e.1.clone()).collect::<Vec<_>>();
        (names("keypress"), names("change"), names("click"))
    };
    h.value(json!({"op": "click", "target": {"id": 3}}));
    h.value(json!({"op": "click", "target": {"text": "Three"}}));
    assert_eq!(h.value(json!({"op": "focused"})), json!(3), "the list box has focus");
    assert_eq!(keyed(&mut h, " "), (vec![json!(5)], vec![], vec![]), "Space reaches the app");
    assert_eq!(keyed(&mut h, "down"), (vec![json!(5)], vec![], vec![]), "and so does Down");
    h.value(json!({"op": "key", "key": "escape"}));
    h.value(json!({"op": "click", "target": {"id": 4}}));
    assert_eq!(keyed(&mut h, " "), (vec![json!(5)], vec![], vec![]), "a pressed button leaves Space too");
    h.feed(&json!({"t": "focus", "id": 3}).to_string());
    assert_eq!(keyed(&mut h, "down").1, vec![json!(3)], "focus from the app takes the arrows");
    h.feed(&json!({"t": "focus", "id": 4}).to_string());
    assert_eq!(keyed(&mut h, " ").2, vec![json!(4)], "and Space presses the focused button");
}

/// Return in an edit line sends `finish`, for Shoes 3.2.15's `edit_line.finish = proc`
/// (ledger G16); an edit box takes it as a new line instead.
#[test]
fn return_in_an_edit_line_finishes_it() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "EditLine", 2, json!({"text": ""})), create(4, "EditBox", 2, json!({"text": ""}))]));
    let finished = |h: &mut Harness, key: &str| {
        let (evs, _) = h.req(json!({"op": "key", "key": key}));
        named(&events(&evs), "finish").iter().map(|e| e.1.clone()).collect::<Vec<_>>()
    };
    h.value(json!({"op": "click", "target": {"id": 3}}));
    h.req(json!({"op": "type", "text": "tea"}));
    assert_eq!(finished(&mut h, "\n"), vec![json!(3)]);
    assert!(finished(&mut h, "a").is_empty(), "only Return");
    assert!(finished(&mut h, ":control_enter").is_empty(), "a modified Return is a keypress");
    h.value(json!({"op": "click", "target": {"id": 4}}));
    assert!(finished(&mut h, "\n").is_empty(), "an edit box has no finish");
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
    assert_eq!(named(&evs, "motion")[0].2, json!([60, 70, false, false]), "window coordinates (Q4)");
    let (evs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 250, "y": 190}));
    let evs = events(&evs);
    assert!(named(&evs, "leave").iter().any(|e| e.1 == json!(5)));
    assert!(named(&evs, "motion").is_empty());
}

/// A press through automation moves the pointer to the press first; when it is already there,
/// no motion fires (spec path-animation drew the last point of a drag twice).
#[test]
fn a_press_where_the_pointer_already_is_is_not_motion() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(4, "SubscriptionItem", 2, json!({"shoes_api_name": "motion"}))]));
    let (evs, _) = h.req(json!({"op": "mouse", "action": "move", "x": 60, "y": 70}));
    assert_eq!(named(&events(&evs), "motion").len(), 1);
    for action in ["down", "up", "move"] {
        let (evs, _) = h.req(json!({"op": "mouse", "action": action, "x": 60, "y": 70}));
        assert!(named(&events(&evs), "motion").is_empty(), "{action} where the pointer is");
    }
    let (evs, _) = h.req(json!({"op": "mouse", "action": "up", "x": 61, "y": 70}));
    assert_eq!(named(&events(&evs), "motion").len(), 1, "a release elsewhere moves it first");
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

/// Shoes' app.clipboard and app.clipboard= (the `clipboard` req) share the clipboard that text
/// fields cut and paste through.
#[test]
fn the_clipboard_req_shares_the_clipboard_text_fields_use() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "EditLine", 2, json!({"text": ""}))]));
    assert_eq!(h.value(json!({"op": "clipboard"})), json!(""));
    assert_eq!(h.value(json!({"op": "clipboard", "text": "from Ruby"})), Value::Null);
    h.value(json!({"op": "click", "target": {"id": 3}}));
    let (evs, _) = h.req(json!({"op": "key", "key": ":control_v"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["from Ruby"]));
    for _ in 0..4 {
        h.req(json!({"op": "key", "key": "shift_left"}));
    }
    h.req(json!({"op": "key", "key": ":control_x"}));
    assert_eq!(h.value(json!({"op": "clipboard"})), json!("Ruby"));
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

/// A press on a drawable with no click block goes on to the topmost drawable under the
/// pointer that has one (DESIGN 4.3, ledger E8), as Shoes 3's shoes_canvas_send_click2 skips
/// elements without a click: a label drawn over a clickable oval passes the press, and the
/// release, to the oval. It went only up the label's own slots, and nothing heard it.
/// A button on top keeps its press.
#[test]
fn a_press_passes_through_what_has_no_click_block() {
    let mut h = Harness::new();
    h.feed(&app(200, 120, &[
        create(3, "Oval", 2, json!({"left": 60, "top": 20, "width": 80, "height": 80, "has_click": true, "has_release": true})),
        create(4, "Stack", 2, json!({"left": 60, "top": 53, "width": 80})),
        create(5, "Para", 4, json!({"text_items": ["click me"], "margin": 0})),
        create(6, "Button", 2, json!({"text": "Go", "left": 70, "top": 75})),
    ]));
    let ids = |evs: &[Value], name: &str| named(&events(evs), name).iter().map(|e| e.1.clone()).collect::<Vec<_>>();
    let (evs, reply) = h.req(json!({"op": "click", "target": {"x": 100, "y": 58}}));
    assert_eq!(reply["value"]["hit"], json!(3), "the reply names the oval, whose block runs, not the label on top");
    assert_eq!(ids(&evs, "click"), vec![json!(3)], "the label passes the press to the oval");
    assert_eq!(ids(&evs, "release"), vec![json!(3)], "and the release");
    let (evs, _) = h.req(json!({"op": "click", "target": {"id": 6}}));
    assert_eq!(ids(&evs, "click"), vec![json!(6)], "a button on the oval keeps its press");
}

/// An image with a click block is heard like a shape (ledger E8): on the press, once, with the
/// button and the window coordinates, and through an empty slot laid over it, as Hackety
/// Hack's side tabs sit under a window-sized stack. Images took a button's release-time click
/// as well, so one on top heard two.
#[test]
fn an_image_hears_its_press_once_even_under_an_empty_slot() {
    let mut h = Harness::new();
    h.feed(&app(200, 120, &[
        create(3, "Image", 2, json!({"url": "", "left": 20, "top": 20, "width": 40, "height": 30, "has_click": true})),
        create(4, "Image", 2, json!({"url": "", "left": 120, "top": 20, "width": 40, "height": 30, "has_click": true})),
        create(5, "Stack", 2, json!({"left": 0, "top": 0, "width": 100, "height": 120})),
    ]));
    let clicks = |evs: &[Value]| named(&events(evs), "click").iter().map(|e| (e.1.clone(), e.2.clone())).collect::<Vec<_>>();
    let (evs, reply) = h.req(json!({"op": "click", "target": {"x": 40, "y": 35}}));
    assert_eq!(reply["value"]["hit"], json!(3), "the press goes through the empty stack on top");
    assert_eq!(clicks(&evs), vec![(json!(3), json!([1, 40, 35]))], "and the image beneath hears it");
    let (evs, reply) = h.req(json!({"op": "click", "target": {"x": 140, "y": 35}}));
    assert_eq!(reply["value"]["hit"], json!(4), "nothing covers the second image");
    assert_eq!(clicks(&evs), vec![(json!(4), json!([1, 140, 35]))], "and it hears one click, not two");
}

/// Para#hit (ledger F14): the character under a point, as Pango's xy_to_index gives it to
/// Shoes 3, past the end of a line the last one, and nil off the text block.
#[test]
fn a_para_answers_which_character_is_under_a_point() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Stack", 2, json!({"width": 280})),
        create(4, "Para", 3, json!({"text_items": ["Hackety Hack"], "size": 20})),
    ]));
    let para = h.node(|n| n["id"] == 4);
    let (x, y, w) = (para["x"].as_f64().unwrap(), para["y"].as_f64().unwrap(), para["w"].as_f64().unwrap());
    let mut hit = |x: f64, y: f64| h.value(json!({"op": "para_hit", "id": 4, "x": x, "y": y}));
    assert_eq!(hit(x + 1.0, y + 10.0), json!(0), "the first letter");
    assert_eq!(hit(x + w - 2.0, y + 10.0), json!(11), "past the end of the line: the last letter");
    assert_eq!(hit(x + 1.0, y + 200.0), Value::Null, "below the block");
}

/// Para#cursor_top (ledger F14): the caret's top in the frame of the slot that scrolls the
/// para, so scrolling leaves it where it is, as Hackety Hack's editor needs.
#[test]
fn a_paras_caret_is_measured_in_the_slot_that_scrolls_it() {
    let mut h = Harness::new();
    let lines: Vec<String> = (1..=20).map(|n| format!("line {n}")).collect();
    h.feed(&app(300, 200, &[
        create(3, "Flow", 2, json!({"width": 280, "height": 80, "scroll": true})),
        create(4, "Para", 3, json!({"text_items": [lines.join("\n")], "size": 10})),
    ]));
    assert_eq!(h.value(json!({"op": "para_caret", "id": 4})), Value::Null, "no caret, no answer");
    h.feed(&json!({"t": "props", "id": 4, "props": {"text_cursor": 0}}).to_string());
    let first = h.value(json!({"op": "para_caret", "id": 4}))["top"].as_i64().unwrap();
    let tenth = "line 1\n".len() + (2..10).map(|n| format!("line {n}\n").len()).sum::<usize>();
    h.feed(&json!({"t": "props", "id": 4, "props": {"text_cursor": tenth}}).to_string());
    let lower = h.value(json!({"op": "para_caret", "id": 4}))["top"].as_i64().unwrap();
    assert!(lower - first > 9 * 10, "nine lines down: {first} then {lower}");
    h.feed(&json!({"t": "scroll_to", "id": 3, "top": 40}).to_string());
    assert_eq!(h.value(json!({"op": "para_caret", "id": 4}))["top"].as_i64().unwrap(), lower, "scrolling does not move it");
}

/// `Shoes.text_mode = :shoes3` (ledger M14) arrives as `text_mode`: from then on text is sized
/// in points at 96 dpi, so a para of the default size draws 16 px tall where it drew 12, and the
/// window is laid out again with it.
#[test]
fn text_mode_shoes3_sizes_text_in_points() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Para", 2, json!({"text_items": ["Hackety Hack"], "margin": 0}))]));
    let (w, hgt) = { let p = h.node(|n| n["id"] == 3); (p["w"].as_f64().unwrap(), p["h"].as_f64().unwrap()) };
    h.feed(&json!({"t": "text_mode", "mode": "shoes3"}).to_string());
    let p = h.node(|n| n["id"] == 3);
    let (w3, h3) = (p["w"].as_f64().unwrap(), p["h"].as_f64().unwrap());
    assert!((w3 / w - 4.0 / 3.0).abs() < 0.05, "a third wider: {w} then {w3}");
    assert!((h3 / hgt - 4.0 / 3.0).abs() < 0.05, "and a third taller: {hgt} then {h3}");
    h.feed(&json!({"t": "text_mode", "mode": "scarpe"}).to_string());
    assert_eq!(h.node(|n| n["id"] == 3)["w"].as_f64().unwrap(), w, "and back");
}

/// Pango makes each line as tall as its own text, so Hackety Hack's intro title, a 15 point
/// " Welcome to" line over a 34 point "Hackety Hack", keeps its small line short and the Ready
/// button under it clear. Shoes 3's text mode sets lines that way; otherwise every line of a
/// block is at least the block's line height.
#[test]
fn shoes3_text_keeps_a_line_of_small_text_short() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[
        create(3, "Span", 0, json!({"text_items": [" Welcome to\n"], "size": 15})),
        create(4, "Para", 2, json!({"text_items": [3, "Hackety Hack"], "size": "title", "margin": 0})),
    ]));
    let tall = h.node(|n| n["id"] == 4)["h"].as_f64().unwrap();
    h.feed(&json!({"t": "text_mode", "mode": "shoes3"}).to_string());
    let para = h.node(|n| n["id"] == 4)["h"].as_f64().unwrap();
    let (small, big) = (15.0 * 4.0 / 3.0, 34.0 * 4.0 / 3.0);
    assert!((para - (small * 1.2 + 4.0 + big * 1.2)).abs() < 1.5, "one short line and one tall: {para}");
    assert!(tall > 2.0 * 34.0 * 1.2, "without the mode both lines are title lines: {tall}");
}

/// After Return at the end of the text the caret sits at the start of the new, empty line under
/// it, where Pango puts it and where the next letter goes (Hackety Hack's editor, the fidelity
/// lane's caret strip). cosmic-text keeps no line for a closing newline, so the caret was drawn
/// at the end of the line above.
#[test]
fn a_caret_after_a_closing_newline_sits_at_the_start_of_the_next_line() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Stack", 2, json!({"width": 280})),
        create(4, "Para", 3, json!({"text_items": ["x = [1, 2]\n"], "size": 10, "text_cursor": 0})),
    ]));
    let at = |h: &mut Harness| {
        let c = h.value(json!({"op": "para_caret", "id": 4}));
        (c["left"].as_i64().unwrap(), c["top"].as_i64().unwrap(), c["height"].as_i64().unwrap())
    };
    let (left, top, height) = at(&mut h);
    h.feed(&json!({"t": "props", "id": 4, "props": {"text_cursor": 10}}).to_string());
    let (end_left, end_top, _) = at(&mut h);
    assert!(end_left > left + 30 && end_top == top, "before the newline, the end of the first line: {end_left},{end_top}");
    h.feed(&json!({"t": "props", "id": 4, "props": {"text_cursor": 11}}).to_string());
    let (next_left, next_top, next_height) = at(&mut h);
    assert_eq!(next_left, left, "after it, back at the start of a line");
    assert!(next_top >= top + height, "on the line below: {next_top} under {top}+{height}");
    assert_eq!(next_height, height, "a line as tall as the first");
    let para = h.node(|n| n["id"] == 4);
    let (x, y) = (para["x"].as_f64().unwrap(), para["y"].as_f64().unwrap());
    let hit = h.value(json!({"op": "para_hit", "id": 4, "x": x + 2.0, "y": y + height as f64 + 4.0}));
    assert_eq!(hit, json!(11), "and a point on that empty line names the place after the newline");
}

/// Shoes 3 runs a slot's click block as the press walks down the canvas to what it lands on,
/// and the block of the shape that takes the press after that (shoes_canvas_send_click2): a
/// press on a clickable stack over a clickable rect runs the stack's, then the rect's. Rust
/// sent the rect's first, so a backdrop that closed a card on click left the card's own click
/// unheard (_repros/key_splash_1.rb). Releases go the same way.
#[test]
fn a_slots_click_comes_before_the_shape_beneath_it() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Rect", 2, json!({"left": 0, "top": 0, "width": 300, "height": 200, "has_click": true, "has_release": true})),
        create(4, "Stack", 2, json!({"left": 50, "top": 40, "width": 200, "height": 80})),
        create(5, "Para", 4, json!({"text_items": ["Click me"], "margin": 0})),
        create(6, "SubscriptionItem", 4, json!({"shoes_api_name": "click"})),
        create(7, "SubscriptionItem", 4, json!({"shoes_api_name": "release"})),
        create(8, "SubscriptionItem", 2, json!({"shoes_api_name": "click"})),
    ]));
    let ids = |evs: &[Value], name: &str| named(&events(evs), name).iter().map(|e| e.1.clone()).collect::<Vec<_>>();
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 150, "y": 80}}));
    assert_eq!(ids(&evs, "click"), vec![json!(8), json!(6), json!(3)], "the window's, the stack's, then the rect's");
    assert_eq!(ids(&evs, "release"), vec![json!(7), json!(3)]);
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 20, "y": 180}}));
    assert_eq!(ids(&evs, "click"), vec![json!(8), json!(3)], "off the stack, only the window's and the rect's");
}

/// An automated click goes where a real press would (DESIGN 4, ledger E8): through an empty
/// slot laid over a clickable one. It asked hit_test for the topmost node of any kind, so
/// `peek --click-at` named the empty layer while the box's block ran, and a click by id or
/// text refused as "covered" what a real press reaches (_repros/rainbow_lab_1.rb).
#[test]
fn an_automated_click_goes_where_a_real_press_would() {
    let mut h = Harness::new();
    h.feed(&app(240, 130, &[
        create(3, "Stack", 2, json!({"left": 20, "top": 20, "width": 90, "height": 90})),
        create(4, "Para", 3, json!({"text_items": ["Tap me"], "margin": [14, 34, 0, 0]})),
        create(5, "SubscriptionItem", 3, json!({"shoes_api_name": "click"})),
        create(6, "Oval", 2, json!({"left": 130, "top": 20, "width": 60, "height": 60, "has_click": true})),
        create(8, "Button", 2, json!({"text": "Under", "left": 150, "top": 95})),
        create(7, "Stack", 2, json!({"left": 0, "top": 0, "width": 240, "height": 130})),
    ]));
    let ids = |evs: &[Value]| named(&events(evs), "click").iter().map(|e| e.1.clone()).collect::<Vec<_>>();

    let (evs, reply) = h.req(json!({"op": "click", "target": {"x": 60, "y": 60}}));
    assert_eq!(ids(&evs), vec![json!(5)], "the box's click block runs");
    assert_eq!(reply["value"]["hit"], json!(3), "and the reply names the box, not the empty layer");

    let (evs, reply) = h.req(json!({"op": "click", "target": {"id": 3}}));
    assert!(reply["error"].is_null(), "the box is reachable through the empty layer: {reply}");
    assert_eq!(ids(&evs), vec![json!(5)]);
    let (evs, reply) = h.req(json!({"op": "click", "target": {"text": "Tap me"}}));
    assert!(reply["error"].is_null(), "and so is its text: {reply}");
    assert_eq!(ids(&evs), vec![json!(5)]);

    let (evs, reply) = h.req(json!({"op": "click", "target": {"id": 6}}));
    assert!(reply["error"].is_null(), "{reply}");
    assert_eq!((ids(&evs), &reply["value"]["hit"]), (vec![json!(6)], &json!(6)), "a clickable oval under it too");

    let (evs, reply) = h.req(json!({"op": "click", "target": {"id": 8}}));
    assert!(reply["error"].as_str().unwrap().contains("covered by Stack 7"), "a real press never reaches a button under it: {reply}");
    assert!(ids(&evs).is_empty());
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

/// A secondary window the user closed: Ruby hears `closed` and quits that app alone (`quit`
/// with its id). Rust frees all of it, revisions included, and the other window carries on.
#[test]
fn quitting_one_of_two_apps_frees_it_and_keeps_the_other() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Para", 2, json!({"text_items": ["first"]}))]));
    let second: Vec<Value> = [
        json!({"t": "create", "id": 11, "kind": "DocumentRoot", "parent": null, "props": {}}),
        json!({"t": "create", "id": 10, "kind": "App", "parent": null, "props": {"width": 200, "height": 100}, "doc_root": 11}),
    ]
    .into_iter()
    .chain((12..20).map(|id| create(id, "Para", 11, json!({"text_items": [format!("line {id}")]}))))
    .chain([json!({"t": "run", "app": 10}), json!({"t": "flush"})])
    .collect();
    h.feed(&second.iter().map(|l| format!("{l}\n")).collect::<String>());
    let tracked = h.rt.revisions.tracked();
    h.feed(&format!("{}\n", json!({"t": "quit", "app": 10})));
    assert!(!h.rt.views.contains_key(&10) && h.rt.doc.get(12).is_none() && h.rt.doc.get(11).is_none());
    assert_eq!(h.rt.revisions.tracked(), tracked - 10, "the app, its root and its 8 paras are forgotten");
    assert_eq!(h.rt.exit, None, "the first window is still open");
    assert_eq!(h.node(|n| n["id"] == 3)["text"], json!("first"));
}

/// `animate(10) { @t.replace strong(Time.now.to_s) }`: Lacci makes a span a tick and destroys
/// none, so Rust's document grew by a node a tick for the life of the app. Past a bound, the
/// spans no text names any more are let go, oldest first.
#[test]
fn a_clock_of_new_spans_does_not_grow_the_document_forever() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[create(3, "Para", 2, json!({"text_items": ["start"]}))]));
    let base = h.rt.doc.len();
    let mut ticks = String::new();
    for tick in 0..12_000 {
        let span = 100 + tick;
        ticks.push_str(&format!("{}\n", json!({"t": "create", "id": span, "kind": "Strong", "parent": null, "props": {"text_items": [format!("12:{tick:05}")]}})));
        ticks.push_str(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 3, "props": {"text_items": [span]}})));
    }
    h.feed(&ticks);
    assert!(h.rt.doc.len() <= base + 10_001, "{} nodes after 12,000 ticks", h.rt.doc.len());
    assert_eq!(h.node(|n| n["id"] == 3)["text"], json!("12:11999"), "the latest span still shows");
}

/// `@s.clear { para "Again ", @bold }` names a span whose only para just went: it is still
/// there (the refutation of the naive fix, review wave 4).
#[test]
fn a_span_named_again_after_its_para_went_still_shows() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        create(3, "Stack", 2, json!({})),
        json!({"t": "create", "id": 4, "kind": "Strong", "parent": null, "props": {"text_items": ["kept"]}}),
        create(6, "Para", 3, json!({"text_items": ["Hi ", 4]})),
    ]));
    h.feed(&[json!({"t": "destroy", "id": 6}), json!({"t": "flush"}), create(9, "Para", 3, json!({"text_items": ["Again ", 4]})), json!({"t": "flush"})]
        .iter()
        .map(|l| format!("{l}\n"))
        .collect::<String>());
    assert_eq!(h.node(|n| n["id"] == 9)["text"], json!("Again kept"));
}
