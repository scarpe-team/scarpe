//! Screen readers (src/a11y.rs): the AccessKit tree an app gives VoiceOver, read back through
//! AccessKit's own consumer by the `a11y` op, the actions a screen reader asks for, and the
//! incremental updates a window sends once a screen reader is listening.

mod common;

use accesskit::TreeUpdate;
use accesskit_consumer::{Node as SeenNode, Tree, TreeChangeHandler};
use common::{app, create, events, named, Harness};
use scarpe_native::a11y::{self, Mirror};
use scarpe_native::protocol::DialogRequest;
use serde_json::{json, Value};

/// Every node of the read-back tree, depth first.
fn flatten(node: &Value, out: &mut Vec<Value>) {
    out.push(node.clone());
    for child in node["children"].as_array().into_iter().flatten() {
        flatten(child, out);
    }
}

fn tree(h: &mut Harness) -> Value {
    h.value(json!({"op": "a11y"}))
}

fn nodes(h: &mut Harness) -> Vec<Value> {
    let mut out = Vec::new();
    flatten(&tree(h), &mut out);
    out
}

fn with_role(h: &mut Harness, role: &str) -> Vec<Value> {
    nodes(h).into_iter().filter(|n| n["role"] == role).collect()
}

/// What Ruby sends for an `ask` or `ask_color` (DESIGN 4.1 `dialog`).
fn asking(kind: &str, message: &str, default: Value) -> DialogRequest {
    DialogRequest { kind: kind.into(), message: message.into(), default, title: None, secret: false }
}

fn one(h: &mut Harness, role: &str) -> Value {
    let found = with_role(h, role);
    assert_eq!(found.len(), 1, "one {role} in {found:?}");
    found[0].clone()
}

fn act(h: &mut Harness, id: &Value, action: &str, value: Option<&str>) -> (Vec<(String, Value, Value)>, Value) {
    let (msgs, reply) = h.req(json!({"op": "a11y_action", "id": id, "action": action, "value": value}));
    (events(&msgs), reply)
}

fn para(id: i64, parent: i64, items: Value) -> Value {
    create(id, "Para", parent, json!({ "text_items": items }))
}

/// A text fragment: Lacci creates spans and links with no parent, inside a para's text_items.
fn span(id: i64, kind: &str, props: Value) -> Value {
    json!({"t": "create", "id": id, "kind": kind, "parent": null, "props": props})
}

#[test]
fn the_window_is_named_by_its_title_and_holds_the_app() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[para(3, 2, json!(["Hello"]))]));
    let root = tree(&mut h);
    assert_eq!((root["role"].as_str(), root["name"].as_str(), root["id"].as_i64()), (Some("window"), Some("test"), Some(1)));
    assert_eq!(root["bounds"], json!([0.0, 0.0, 300.0, 200.0]));
    assert_eq!(root["focused"], json!(true), "with nothing focused the window has the focus");
    // The document root and its slots are containers a screen reader looks straight through.
    assert_eq!(root["children"][0]["value"], json!("Hello"));
}

#[test]
fn a_button_is_named_by_its_label() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Button", 2, json!({"text": "Save", "tooltip": "Writes the file"}))]));
    let button = one(&mut h, "button");
    assert_eq!(button["name"], json!("Save"));
    assert_eq!(button["description"], json!("Writes the file"), "the tooltip is read after the name");
    assert_eq!(button["actions"], json!(["click", "focus"]));
    let laid = h.node(|n| n["id"] == 3);
    assert_eq!(button["bounds"], json!([laid["x"], laid["y"], laid["w"], laid["h"]]), "where the layout put it");
}

#[test]
fn checks_and_radios_carry_their_state_and_the_text_after_them() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Flow", 2, json!({})),
        create(4, "Check", 3, json!({"checked": true})),
        para(5, 3, json!(["Remember me"])),
        create(6, "Flow", 2, json!({})),
        create(7, "Radio", 6, json!({})),
        para(8, 6, json!(["Tea"])),
        create(9, "Check", 2, json!({})),
    ]));
    let checks = with_role(&mut h, "check_box");
    assert_eq!(checks[0]["name"], json!("Remember me"), "named by the text after it");
    assert_eq!(checks[0]["toggled"], json!(true));
    assert_eq!(checks[1]["toggled"], json!(false));
    assert!(checks[1].get("name").is_none(), "a check with no text after it has no name");
    let radio = one(&mut h, "radio_button");
    assert_eq!((radio["name"].as_str(), &radio["toggled"]), (Some("Tea"), &json!(false)));
    // Lacci toggles and echoes `checked`; the tree follows the echo.
    h.feed(&format!("{}\n{}\n", json!({"t":"props","id":4,"props":{"checked":false}}), json!({"t":"flush"})));
    assert_eq!(with_role(&mut h, "check_box")[0]["toggled"], json!(false));
}

#[test]
fn fields_show_their_text_named_by_the_text_before_them() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[
        para(3, 2, json!(["Name"])),
        create(4, "EditLine", 2, json!({"text": "Nick"})),
        create(5, "EditBox", 2, json!({"text": "two\nlines", "state": "readonly"})),
    ]));
    let line = one(&mut h, "text_input");
    assert_eq!((line["name"].as_str(), line["value"].as_str()), (Some("Name"), Some("Nick")));
    assert_eq!(line["actions"], json!(["click", "focus", "set_value"]));
    let bx = one(&mut h, "multiline_text_input");
    assert_eq!((bx["value"].as_str(), &bx["read_only"]), (Some("two\nlines"), &json!(true)));
    assert_eq!(bx["actions"], json!(["click", "focus"]), "a readonly field takes no new value");
    // Typing shows at once, before Lacci's echo.
    h.value(json!({"op": "click", "target": {"id": 4}}));
    h.value(json!({"op": "type", "text": "!"}));
    let line = one(&mut h, "text_input");
    assert_eq!((line["value"].as_str(), &line["focused"]), (Some("Nick!"), &json!(true)));
}

#[test]
fn a_secret_field_reads_as_bullets_and_its_text_never_leaves() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "EditLine", 2, json!({"text": "hunter2", "secret": true}))]));
    let field = one(&mut h, "password_input");
    assert_eq!(field["value"], json!("\u{2022}".repeat(7)));
    assert!(!tree(&mut h).to_string().contains("hunter2"), "the secret is nowhere in the tree");
}

#[test]
fn a_list_box_is_a_popup_button_holding_its_items() {
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[
        para(3, 2, json!(["Drink"])),
        create(4, "ListBox", 2, json!({"items": ["Tea", "Coffee"], "chosen": "Tea"})),
    ]));
    let combo = one(&mut h, "combo_box");
    assert_eq!((combo["name"].as_str(), combo["value"].as_str(), &combo["expanded"]), (Some("Drink"), Some("Tea"), &json!(false)));
    let items: Vec<(Value, Value)> = combo["children"].as_array().unwrap().iter().map(|o| (o["name"].clone(), o["selected"].clone())).collect();
    assert_eq!(items, vec![(json!("Tea"), json!(true)), (json!("Coffee"), json!(false))]);
    assert!(combo["children"][0].get("bounds").is_none(), "a closed popup's items are nowhere on screen");

    h.value(json!({"op": "click", "target": {"id": 4}}));
    let combo = one(&mut h, "combo_box");
    assert_eq!(combo["expanded"], json!(true));
    assert!(combo["children"][1]["bounds"].is_array(), "an open popup's items sit where it draws them");
    assert_eq!(combo["children"][0]["focused"], json!(true), "focus follows the popup's highlighted item");
}

#[test]
fn text_is_static_text_and_a_link_is_a_link_in_its_paragraph() {
    let mut h = Harness::new();
    h.feed(&app(400, 200, &[
        para(3, 2, json!(["Just text"])),
        span(5, "Link", json!({"text_items": ["the docs"], "click": "https://example.com/"})),
        span(6, "Strong", json!({"text_items": ["Read "]})),
        para(4, 2, json!([6, 5, " first."])),
        para(7, 2, json!(["   "])),
    ]));
    let root = tree(&mut h);
    let texts: Vec<Value> = root["children"].as_array().unwrap().clone();
    assert_eq!(texts.len(), 2, "blank text says nothing: {texts:?}");
    assert_eq!((texts[0]["role"].as_str(), texts[0]["value"].as_str()), (Some("label"), Some("Just text")));
    let paragraph = &texts[1];
    assert_eq!(paragraph["role"], json!("paragraph"));
    let read = |r: &Value| if r.get("name").is_some() { r["name"].clone() } else { r["value"].clone() };
    let runs: Vec<(Value, Value)> = paragraph["children"].as_array().unwrap().iter().map(|r| (r["role"].clone(), read(r))).collect();
    assert_eq!(runs, vec![(json!("label"), json!("Read ")), (json!("link"), json!("the docs")), (json!("label"), json!(" first."))]);
    let link = &paragraph["children"][1];
    assert_eq!((link["id"].as_i64(), link["url"].as_str()), (Some(5), Some("https://example.com/")));
    let laid = h.node(|n| n["id"] == 5);
    assert_eq!(link["bounds"], json!([laid["x"], laid["y"], laid["w"], laid["h"]]), "the link's own glyphs");
}

#[test]
fn big_text_is_a_heading_as_the_webview_theme_tags_it() {
    let mut h = Harness::new();
    h.feed(&app(600, 400, &[
        create(3, "Para", 2, json!({"text_items": ["Welcome"], "size": "banner"})),
        create(4, "Para", 2, json!({"text_items": ["Chapter"], "size": "title"})),
        create(5, "Para", 2, json!({"text_items": ["Section"], "size": "subtitle"})),
        create(6, "Para", 2, json!({"text_items": ["Aside"], "size": "tagline"})),
    ]));
    let root = tree(&mut h);
    let read: Vec<(Value, Value, Value)> = root["children"].as_array().unwrap().iter().map(|n| (n["role"].clone(), n["name"].clone(), n["level"].clone())).collect();
    assert_eq!(read, vec![
        (json!("heading"), json!("Welcome"), json!(1)),
        (json!("heading"), json!("Chapter"), json!(2)),
        (json!("heading"), json!("Section"), json!(3)),
        (json!("label"), Value::Null, Value::Null),
    ]);
}

#[test]
fn progress_and_images() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[
        create(3, "Progress", 2, json!({"fraction": 0.4})),
        create(4, "Progress", 2, json!({})),
        create(5, "Image", 2, json!({"width": 20, "height": 20, "alt": "A red square", "has_block": true})),
        create(6, "Image", 2, json!({"width": 20, "height": 20})),
    ]));
    let bars = with_role(&mut h, "progress_indicator");
    assert_eq!(bars[0]["numeric"], json!({"value": 0.4, "min": 0.0, "max": 1.0}), "exactly the fraction Lacci sent");
    assert!(bars[1].get("numeric").is_none(), "no fraction reads as a bar with no end in sight");
    let images = with_role(&mut h, "image");
    assert_eq!((images[0]["name"].as_str(), &images[0]["actions"]), (Some("A red square"), &json!(["click"])));
    assert!(images[1].get("name").is_none() && images[1].get("actions").is_none());
}

#[test]
fn decoration_hidden_things_and_timers_stay_out() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Background", 2, json!({"fill": [255, 0, 0, 255]})),
        create(4, "Rect", 2, json!({"left": 0, "top": 0, "width": 10, "height": 10})),
        create(5, "Button", 2, json!({"text": "Hidden", "hidden": true})),
        create(6, "SubscriptionItem", 2, json!({"shoes_api_name": "animate"})),
        create(7, "Mask", 2, json!({})),
        para(8, 7, json!(["masked"])),
        create(9, "Button", 2, json!({"text": "Shown"})),
    ]));
    let all = nodes(&mut h);
    let ids: Vec<i64> = all.iter().filter_map(|n| n["id"].as_i64()).collect();
    assert_eq!(ids, vec![1, 9], "only the window and the one shown button: {all:?}");
}

#[test]
fn disabled_controls_are_dimmed_and_do_nothing() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Button", 2, json!({"text": "Off", "state": "disabled"}))]));
    let button = one(&mut h, "button");
    assert_eq!(button["disabled"], json!(true));
    assert!(button.get("actions").is_none());
    let (evs, reply) = act(&mut h, &json!(3), "click", None);
    assert!(reply["error"].as_str().unwrap().contains("disabled"), "{reply}");
    assert!(named(&evs, "click").is_empty());
}

#[test]
fn a_screen_reader_presses_buttons_checks_and_links_as_the_keyboard_does() {
    let mut h = Harness::new();
    h.feed(&app(400, 200, &[
        create(3, "Button", 2, json!({"text": "Go"})),
        create(4, "Check", 2, json!({})),
        span(6, "Link", json!({"text_items": ["here"], "has_block": true})),
        para(5, 2, json!(["Click ", 6])),
    ]));
    for id in [3, 4, 6] {
        let (evs, reply) = act(&mut h, &json!(id), "click", None);
        assert_eq!(reply["error"], Value::Null, "{reply}");
        let clicks = named(&evs, "click");
        assert_eq!((clicks.len(), &clicks[0].1, &clicks[0].2), (1, &json!(id), &json!([])), "one click on {id}, no pointer");
    }
    let (_, reply) = act(&mut h, &json!(3), "set_value", Some("x"));
    assert!(reply["error"].as_str().unwrap().contains("cannot"), "a button takes no value: {reply}");
    let (_, reply) = act(&mut h, &json!(3), "fly", None);
    assert!(reply["error"].as_str().unwrap().contains("unknown"), "{reply}");
}

#[test]
fn a_run_of_text_takes_no_action_and_says_so() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[span(4, "Link", json!({"text_items": ["here"]})), para(3, 2, json!(["Go ", 4]))]));
    let run = one(&mut h, "paragraph")["children"][0]["id"].clone();
    let (evs, reply) = act(&mut h, &run, "click", None);
    assert_eq!(reply["error"], json!("part 0 of 3 takes no action"));
    assert!(evs.is_empty());
}

/// The platform tree is AppKit's, read from a window; a headless run has none and says so.
#[test]
fn a_headless_run_has_no_platform_tree() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Button", 2, json!({"text": "Go"}))]));
    let (_, reply) = h.req(json!({"op": "a11y", "platform": true}));
    assert!(reply["error"].as_str().unwrap().contains("headless"), "{reply}");
    let (evs, reply) = h.req(json!({"op": "a11y_action", "platform": true, "name": "Go", "action": "click"}));
    assert!(reply["error"].as_str().unwrap().contains("headless"), "{reply}");
    assert!(named(&events(&evs), "click").is_empty());
}

#[test]
fn focus_moves_where_a_screen_reader_asks() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Button", 2, json!({"text": "A"})), create(4, "EditLine", 2, json!({}))]));
    let (_, reply) = act(&mut h, &json!(4), "focus", None);
    assert_eq!(reply["error"], Value::Null);
    assert_eq!(h.value(json!({"op": "focused"})), json!(4));
    assert_eq!(one(&mut h, "text_input")["focused"], json!(true));
    act(&mut h, &json!(3), "focus", None);
    assert_eq!(one(&mut h, "button")["focused"], json!(true));
}

#[test]
fn a_new_value_for_a_field_is_one_edit_and_one_change() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "EditLine", 2, json!({"text": "old"})),
        create(4, "EditLine", 2, json!({"text": "fixed", "state": "readonly"})),
    ]));
    let (evs, reply) = act(&mut h, &json!(3), "set_value", Some("Noah"));
    assert_eq!(reply["error"], Value::Null, "{reply}");
    let changes: Vec<Value> = named(&evs, "change").iter().map(|e| e.2.clone()).collect();
    assert_eq!(changes, vec![json!(["Noah"])]);
    assert_eq!(with_role(&mut h, "text_input")[0]["value"], json!("Noah"));
    // Lacci's echo keeps it, and Cmd-Z takes the whole new value back.
    let echo = h.feed(&format!("{}\n", json!({"t":"props","id":3,"props":{"text":"Noah"}})));
    assert!(named(&events(&echo), "change").is_empty());
    h.value(json!({"op": "click", "target": {"id": 3}}));
    let (evs, _) = h.req(json!({"op": "key", "key": ":control_z"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["old"]));

    let (evs, reply) = act(&mut h, &json!(4), "set_value", Some("changed"));
    assert!(reply["error"].is_string(), "a readonly field refuses: {reply}");
    assert!(named(&evs, "change").is_empty());
}

#[test]
fn a_list_box_takes_an_item_by_value_or_by_its_option() {
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[create(3, "ListBox", 2, json!({"items": ["Tea", "Coffee"], "chosen": "Tea"}))]));
    let (evs, _) = act(&mut h, &json!(3), "set_value", Some("Coffee"));
    assert_eq!(named(&evs, "change")[0].2, json!(["Coffee"]));
    let (evs, reply) = act(&mut h, &json!(3), "set_value", Some("Milk"));
    assert!(reply["error"].as_str().unwrap().contains("no item"), "{reply}");
    assert!(named(&evs, "change").is_empty());

    act(&mut h, &json!(3), "expand", None);
    assert_eq!(one(&mut h, "combo_box")["expanded"], json!(true));
    let coffee = one(&mut h, "combo_box")["children"][1]["id"].clone();
    let (evs, reply) = act(&mut h, &coffee, "click", None);
    assert_eq!(reply["error"], Value::Null, "{reply}");
    assert_eq!(named(&evs, "change")[0].2, json!(["Coffee"]));
    assert_eq!(one(&mut h, "combo_box")["expanded"], json!(false), "picking an item closes the popup");
}

#[test]
fn an_ask_dialog_is_modal_holds_the_focus_and_answers() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[create(3, "Button", 2, json!({"text": "Behind"}))]));
    h.rt.open_modal(1, 77, &asking("ask", "Your name?", json!("Nick")));
    let dialog = one(&mut h, "dialog");
    assert_eq!((dialog["name"].as_str(), &dialog["modal"]), (Some("Your name?"), &json!(true)));
    let parts: Vec<Value> = dialog["children"].as_array().unwrap().iter().map(|p| p["role"].clone()).collect();
    assert_eq!(parts, vec![json!("label"), json!("text_input"), json!("button"), json!("default_button")]);
    let field = &dialog["children"][1];
    assert_eq!((field["value"].as_str(), &field["focused"]), (Some("Nick"), &json!(true)));

    act(&mut h, &field["id"], "set_value", Some("Noah"));
    let ok = dialog["children"][3]["id"].clone();
    let (msgs, _) = h.req(json!({"op": "a11y_action", "id": ok, "action": "click"}));
    let answer = msgs.iter().find(|m| m["t"] == "reply" && m["req"] == json!(77)).expect("the dialog answered");
    assert_eq!((answer["value"].as_str(), &answer["cancelled"]), (Some("Noah"), &json!(false)));
    assert!(with_role(&mut h, "dialog").is_empty(), "and closed");
}

/// `ask(..., secret: true)` masks its field; the tree must never give the answer away either.
#[test]
fn a_secret_ask_reads_as_bullets() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[]));
    h.rt.open_modal(1, 79, &DialogRequest { secret: true, ..asking("ask", "Your PIN?", json!("1234")) });
    assert_eq!(one(&mut h, "password_input")["value"], json!("\u{2022}".repeat(4)));
    assert!(!tree(&mut h).to_string().contains("1234"), "the answer is nowhere in the tree");
}

#[test]
fn an_ask_color_dialog_offers_named_swatches() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[]));
    h.rt.open_modal(1, 78, &asking("ask_color", "Pick one", Value::Null));
    let dialog = one(&mut h, "dialog");
    let swatches: Vec<Value> = dialog["children"].as_array().unwrap().iter().filter(|p| p["role"] == "radio_button").cloned().collect();
    assert_eq!(swatches.len(), 12);
    assert_eq!((swatches[5]["name"].as_str(), &swatches[5]["toggled"], &swatches[5]["focused"]), (Some("Blue"), &json!(true), &json!(true)));
    act(&mut h, &swatches[0]["id"], "click", None);
    let cancel = one(&mut h, "dialog")["children"].as_array().unwrap().iter().find(|p| p["name"] == "Cancel").unwrap()["id"].clone();
    let red = one(&mut h, "dialog")["children"].as_array().unwrap().iter().find(|p| p["name"] == "Red").unwrap().clone();
    assert_eq!(red["toggled"], json!(true));
    let (msgs, _) = h.req(json!({"op": "a11y_action", "id": cancel, "action": "click"}));
    let answer = msgs.iter().find(|m| m["t"] == "reply" && m["req"] == json!(78)).expect("the dialog answered");
    assert_eq!((&answer["value"], &answer["cancelled"]), (&Value::Null, &json!(true)));
}

/// An `ask` before `run` gets a window of its own (dialogs::open_standalone): a view with no
/// document and a negative id. A screen reader in that window must meet the dialog under its
/// title and be able to answer it, since the app shows nothing until it has the answer.
#[test]
fn a_dialogs_own_window_reads_as_the_dialog_and_answers() {
    let mut h = Harness::new();
    let being_built: String = app(400, 300, &[]).lines().filter(|l| !l.contains(r#""t":"run""#)).map(|l| format!("{l}\n")).collect();
    h.feed(&being_built);
    let own = h.rt.open_standalone(9, &DialogRequest { title: Some("Bank".into()), ..asking("ask", "Your PIN?", Value::Null) });

    let window = h.value(json!({"op": "a11y", "app": own}));
    assert_eq!((window["role"].as_str(), window["name"].as_str()), (Some("window"), Some("Bank")));
    let dialog = window["children"][0].clone();
    assert_eq!((dialog["role"].as_str(), dialog["name"].as_str(), &dialog["modal"]), (Some("dialog"), Some("Bank"), &json!(true)));
    assert_eq!(dialog["children"][0]["value"].as_str(), Some("Your PIN?"));
    let field = &dialog["children"][1];
    assert_eq!((field["role"].as_str(), &field["focused"]), (Some("text_input"), &json!(true)));

    let (_, reply) = act(&mut h, &field["id"], "set_value", Some("1234"));
    assert_eq!(reply["error"], Value::Null, "{reply}");
    let (msgs, reply) = h.req(json!({"op": "a11y_action", "id": dialog["children"][3]["id"], "action": "click"}));
    assert_eq!(reply["error"], Value::Null, "{reply}");
    let answer = msgs.iter().find(|m| m["t"] == "reply" && m["req"] == json!(9)).expect("the dialog answered");
    assert_eq!((answer["value"].as_str(), &answer["cancelled"]), (Some("1234"), &json!(false)));
    assert!(!h.rt.is_standalone(own), "the dialog's view goes with its answer");
}

#[test]
fn parts_never_collide_with_drawables() {
    let id = a11y::part(9, 3);
    assert_eq!(a11y::part_of(id), Some((9, 3)));
    assert_eq!(a11y::part_of(accesskit::NodeId(9)), None);
    assert_ne!(a11y::part(9, 3), a11y::part(9, 4));
    assert_ne!(a11y::part(9, 3), a11y::part(10, 3));
    assert_eq!(a11y::part_of(a11y::part(-10, 2)), Some((-10, 2)), "a dialog's own window has a negative id");
}

struct Quiet;

impl TreeChangeHandler for Quiet {
    fn node_added(&mut self, _: &SeenNode) {}
    fn node_updated(&mut self, _: &SeenNode, _: &SeenNode) {}
    fn focus_moved(&mut self, _: Option<&SeenNode>, _: Option<&SeenNode>) {}
    fn node_removed(&mut self, _: &SeenNode) {}
}

/// A platform adapter's side: the whole tree once, then each update the Mirror makes.
struct Adapter {
    mirror: Mirror,
    tree: Option<Tree>,
    sent: usize,
}

impl Adapter {
    fn new() -> Self {
        Adapter { mirror: Mirror::default(), tree: None, sent: 0 }
    }

    fn push(&mut self, h: &mut Harness) -> TreeUpdate {
        let update = self.mirror.update(h.rt.a11y_tree(1, 2.0));
        self.sent = update.nodes.len();
        match &mut self.tree {
            Some(tree) => tree.update_and_process_changes(update.clone(), &mut Quiet),
            None => self.tree = Some(Tree::new(update.clone(), true)),
        }
        update
    }

    /// What the adapter holds now equals a fresh tree built from scratch.
    fn in_step(&self, h: &mut Harness) {
        let fresh = a11y::read_back(h.rt.a11y_tree(1, 2.0));
        assert_eq!(a11y::read(self.tree.as_ref().unwrap()), fresh);
    }
}

#[test]
fn after_the_first_update_a_window_sends_only_what_changed() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        para(3, 2, json!(["Hello"])),
        create(4, "Check", 2, json!({})),
        create(5, "Button", 2, json!({"text": "Go"})),
    ]));
    let mut adapter = Adapter::new();
    let first = adapter.push(&mut h);
    assert!(first.tree.is_some(), "the first update is the whole tree");
    assert_eq!(first.nodes.len(), 5, "window, document, text, check, button");
    assert_eq!(adapter.push(&mut h).nodes.len(), 0, "nothing changed, nothing sent");
    h.feed(&format!("{}\n{}\n", json!({"t":"props","id":4,"props":{"checked":true}}), json!({"t":"flush"})));
    let update = adapter.push(&mut h);
    assert_eq!(update.nodes.iter().map(|(id, _)| id.0).collect::<Vec<_>>(), vec![4], "only the check");
    assert!(update.tree.is_none());
    adapter.in_step(&mut h);
}

/// A Linux adapter stops and starts with the screen reader, and takes the tree whole again: its
/// handlers raise the Mirror's flag as it does, and the next update is whole whatever came before.
#[test]
fn a_screen_reader_that_starts_again_gets_the_whole_tree() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[para(3, 2, json!(["Hello"])), create(4, "Check", 2, json!({}))]));
    let mut mirror = Mirror::default();
    assert!(mirror.update(h.rt.a11y_tree(1, 1.0)).tree.is_some(), "the first update is whole");
    assert!(mirror.update(h.rt.a11y_tree(1, 1.0)).nodes.is_empty());
    mirror.restarts().store(true, std::sync::atomic::Ordering::SeqCst);
    let again = mirror.update(h.rt.a11y_tree(1, 1.0));
    assert_eq!((again.nodes.len(), again.tree.is_some()), (4, true), "whole again, tree and all");
    // A fresh AccessKit tree takes it, as an adapter that just started does.
    assert_eq!(a11y::read(&Tree::new(again, true))["children"][0]["value"], json!("Hello"));
    assert!(mirror.update(h.rt.a11y_tree(1, 1.0)).nodes.is_empty(), "and the flag is spent");
}

#[test]
fn incremental_updates_keep_a_screen_reader_in_step_with_the_document() {
    let mut h = Harness::new();
    h.feed(&app(300, 400, &[
        create(3, "Stack", 2, json!({})),
        create(4, "Flow", 2, json!({})),
        para(5, 3, json!(["One"])),
        create(6, "Button", 3, json!({"text": "Two"})),
    ]));
    let mut adapter = Adapter::new();
    adapter.push(&mut h);
    let steps = [
        vec![create(7, "Check", 4, json!({})), para(8, 4, json!(["Seven"]))],
        vec![json!({"t":"reparent","id":6,"parent":4,"index":0})],
        vec![json!({"t":"props","id":5,"props":{"hidden":true}})],
        vec![json!({"t":"props","id":5,"props":{"hidden":false,"text_items":["One again"]}})],
        vec![json!({"t":"destroy","id":4})],
        vec![create(9, "ListBox", 3, json!({"items": ["a", "b"]})), json!({"t":"focus","id":9})],
        vec![json!({"t":"props","id":9,"props":{"items":["a"]}})],
        vec![create(4, "Flow", 2, json!({})), json!({"t":"reparent","id":9,"parent":4,"index":null})],
    ];
    for step in steps {
        let lines: String = step.iter().chain([&json!({"t":"flush"})]).map(|l| format!("{l}\n")).collect();
        h.feed(&lines);
        adapter.push(&mut h);
        adapter.in_step(&mut h);
    }
}

#[test]
fn a_window_scale_turns_bounds_into_device_pixels() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Button", 2, json!({"text": "Go"}))]));
    let at_2x = a11y::read_back(h.rt.a11y_tree(1, 2.0));
    let at_1x = tree(&mut h);
    let bounds = |t: &Value| t["children"][0]["bounds"].as_array().unwrap().iter().map(|v| v.as_f64().unwrap()).collect::<Vec<_>>();
    let (b2, b1) = (bounds(&at_2x), bounds(&at_1x));
    assert_eq!(b2, b1.iter().map(|v| v * 2.0).collect::<Vec<_>>(), "AccessKit counts device pixels");
}
