//! Paragraph selection uses the real shaped text and a private headless clipboard.
mod common;

use common::{app, create, events, named, Harness};
use scarpe_native::input::{CursorShape, Modifiers};
use serde_json::{json, Value};

fn scene(text: &str) -> Harness {
    let mut h = Harness::new();
    h.feed(&app(
        500,
        320,
        &[
            create(3, "Para", 2, json!({"left":20,"top":20,"width":400,"text_items":[text],"selectable":true,"size":20})),
            create(4, "EditLine", 2, json!({"left":20,"top":250,"text":"paste here"})),
            create(5, "SubscriptionItem", 2, json!({"shoes_api_name":"keypress"})),
        ],
    ));
    h
}

fn key(h: &mut Harness, key: &str) -> Vec<Value> {
    let (events, reply) = h.req(json!({"op":"key","key":key}));
    assert_eq!(reply["error"], Value::Null);
    events
}

fn mouse(h: &mut Harness, action: &str, point: (f32, f32), button: u8) {
    h.value(json!({"op":"mouse","action":action,"x":point.0,"y":point.1,"button":button}));
}

fn point(h: &mut Harness, index: usize) -> (f32, f32) {
    let layout = h.rt.layout_of(1).unwrap();
    let bounds = layout.rect(3).unwrap();
    let tb = &layout.texts[&3];
    let (x, y, height) = scarpe_native::paint::text::caret_position(&tb.shaped.buffer, tb.shaped.cursor_at(index)).unwrap();
    // The first RTL caret is on the paragraph's right edge; press just inside it.
    ((tb.x + x + 0.1).clamp(bounds.x + 0.5, bounds.right() - 0.5), tb.y + y + height / 2.0)
}

fn click(h: &mut Harness, point: (f32, f32)) {
    mouse(h, "down", point, 1);
    mouse(h, "up", point, 1);
}

fn selected(h: &Harness) -> Option<String> {
    h.rt.views[&1].ui.selection.as_ref().and_then(|s| s.text())
}

fn props(h: &mut Harness, id: i64, props: Value) {
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t":"props","id":id,"props":props})));
}

#[test]
fn selection_queries_preserve_unicode_focus_and_clipboard() {
    let text = "العِلْم نورٌ — e\u{301} and 👩‍💻\nsecond line";
    let mut h = scene(text);
    h.rt.clipboard.set("sentinel".into());
    assert_eq!(h.value(json!({"op":"para_selection","id":3})), Value::Null);
    key(&mut h, "tab");
    key(&mut h, "command_a");
    assert_eq!(h.value(json!({"op":"para_selection","id":3})), json!(text));
    assert_eq!(h.rt.views[&1].ui.focus, Some(3), "reading keeps keyboard focus");
    let at = point(&mut h, 2);
    mouse(&mut h, "down", at, 3);
    mouse(&mut h, "up", at, 3);
    let focus = h.rt.views[&1].ui.focus;
    assert_eq!(h.value(json!({"op":"para_selection","id":3})), json!(text));
    assert_eq!(h.value(json!({"op":"para_selection","id":4})), Value::Null);
    assert_eq!(selected(&h).as_deref(), Some(text));
    assert_eq!(h.rt.views[&1].ui.focus, focus, "reading after a context click keeps its focus state");
    assert_eq!(h.rt.clipboard.get(), "sentinel");
    // No explicit flush: the query must first apply the pending text replacement.
    h.feed(&json!({"t":"props","id":3,"props":{"text_items":["A new page"]}}).to_string());
    assert_eq!(h.value(json!({"op":"para_selection","id":3})), Value::Null);
    assert_eq!(h.rt.clipboard.get(), "sentinel");
}

#[test]
fn selection_queries_observe_pending_visibility_and_selection_changes() {
    for changes in [json!({"selectable":false}), json!({"hidden":true}), json!({"state":"disabled"})] {
        let mut h = scene("Selected text");
        key(&mut h, "tab");
        key(&mut h, "control_a");
        assert_eq!(h.value(json!({"op":"para_selection","id":3})), json!("Selected text"));
        h.feed(&json!({"t":"props","id":3,"props":changes}).to_string());
        assert_eq!(h.value(json!({"op":"para_selection","id":3})), Value::Null);
    }
}

#[test]
fn keyboard_focus_selects_and_copies_mixed_scripts_without_editing_or_swallowing_find() {
    let text = "العِلْم نورٌ — e\u{301} and 👩‍💻\nsecond line";
    let mut h = scene(text);
    key(&mut h, "tab");
    assert_eq!(h.rt.views[&1].ui.focus, Some(3));
    key(&mut h, "command_a");
    key(&mut h, "command_c");
    assert_eq!(h.rt.clipboard.get(), text);
    for name in ["backspace", "delete", "enter", "control_x", "control_v", "control_z", "control_y", "x"] {
        assert!(named(&events(&key(&mut h, name)), "keypress").is_empty(), "{name} must not edit or trigger app actions");
    }
    assert_eq!(selected(&h).as_deref(), Some(text));
    let find = events(&key(&mut h, "control_f"));
    assert_eq!(named(&find, "keypress")[0].2, json!([":control_f"]));
    key(&mut h, "tab");
    assert_eq!(h.rt.views[&1].ui.focus, Some(4));
    key(&mut h, "shift_tab");
    assert_eq!(h.rt.views[&1].ui.focus, Some(3));
    key(&mut h, "escape");
    assert_eq!(selected(&h), None);
    assert_eq!(named(&events(&key(&mut h, "escape")), "keypress").len(), 1, "a second Escape reaches the app");
}

#[test]
fn shift_arrows_keep_combining_characters_together_and_plain_arrows_collapse() {
    let mut h = scene("e\u{301}xy");
    key(&mut h, "tab");
    key(&mut h, "home");
    key(&mut h, "shift_right");
    assert_eq!(selected(&h).as_deref(), Some("e\u{301}"));
    key(&mut h, "shift_right");
    assert_eq!(selected(&h).as_deref(), Some("e\u{301}x"));
    key(&mut h, "left");
    key(&mut h, "shift_right");
    assert_eq!(selected(&h).as_deref(), Some("e\u{301}"), "Left first collapses to the beginning");
}

#[test]
fn drag_shift_click_and_release_select_only_the_passage() {
    let mut h = scene("one two three");
    let start = point(&mut h, 4);
    let end = point(&mut h, 7);
    mouse(&mut h, "down", start, 1);
    mouse(&mut h, "move", end, 1);
    mouse(&mut h, "up", end, 3);
    assert!(h.rt.views[&1].ui.pressed.is_some(), "a secondary release does not end the primary drag");
    mouse(&mut h, "up", end, 1);
    key(&mut h, "control_c");
    assert_eq!(h.rt.clipboard.get(), "two");
    mouse(&mut h, "move", start, 1);
    assert_eq!(selected(&h).as_deref(), Some("two"), "movement after release leaves selection alone");
    h.rt.set_modifiers(1, Modifiers { shift: true, ..Modifiers::default() });
    let end = point(&mut h, 13);
    click(&mut h, end);
    assert_eq!(selected(&h).as_deref(), Some("two three"));
}

#[test]
fn double_click_selects_a_word_and_triple_click_selects_a_line() {
    let mut h = scene("one two three\nnext line");
    let p = point(&mut h, 5);
    click(&mut h, p);
    click(&mut h, p);
    assert_eq!(selected(&h).as_deref(), Some("two"));
    click(&mut h, p);
    assert_eq!(selected(&h).as_deref(), Some("one two three"));
}

#[test]
fn a_right_aligned_arabic_drag_copies_logical_text_with_diacritics() {
    let text = "العِلْم نورٌ";
    let mut h = scene(text);
    props(&mut h, 3, json!({"align":"right"}));
    let start = point(&mut h, 0);
    let end_index = text.chars().position(|c| c == ' ').unwrap();
    let end = point(&mut h, end_index);
    mouse(&mut h, "down", start, 1);
    mouse(&mut h, "move", end, 1);
    mouse(&mut h, "up", end, 1);
    key(&mut h, "control_c");
    assert_eq!(h.rt.clipboard.get(), "العِلْم");
}

#[test]
fn selection_is_opt_in_and_disabled_or_hidden_paragraphs_are_not_focusable() {
    let mut h = scene("plain");
    props(&mut h, 3, json!({"selectable":false}));
    let p = point(&mut h, 2);
    click(&mut h, p);
    assert!(h.rt.views[&1].ui.selection.is_none());
    assert_eq!(h.rt.views[&1].ui.cursor, CursorShape::Arrow);
    key(&mut h, "tab");
    assert_eq!(h.rt.views[&1].ui.focus, Some(4));
    props(&mut h, 3, json!({"selectable":true}));
    mouse(&mut h, "move", p, 1);
    assert_eq!(h.rt.views[&1].ui.cursor, CursorShape::Text);
    key(&mut h, "shift_tab");
    key(&mut h, "control_a");
    props(&mut h, 3, json!({"state":"disabled"}));
    assert!(h.rt.views[&1].ui.selection.is_none());
    key(&mut h, "tab");
    assert_eq!(h.rt.views[&1].ui.focus, Some(4));
    props(&mut h, 3, json!({"state":null}));
    key(&mut h, "shift_tab");
    props(&mut h, 3, json!({"hidden":true}));
    assert!(h.rt.views[&1].ui.selection.is_none());
    assert_eq!(h.rt.views[&1].ui.focus, None);
}

#[test]
fn resizing_preserves_selection_but_replacement_and_removal_discard_it() {
    let mut h = scene("a long paragraph wraps when its width becomes smaller");
    key(&mut h, "tab");
    key(&mut h, "control_a");
    let before = selected(&h);
    props(&mut h, 3, json!({"width":120,"size":24}));
    assert_eq!(selected(&h), before);
    props(&mut h, 3, json!({"text_items":["new"]}));
    assert_eq!(selected(&h), None);
    key(&mut h, "control_a");
    key(&mut h, "control_c");
    assert_eq!(h.rt.clipboard.get(), "new");
    h.feed("{\"t\":\"destroy\",\"id\":3}\n{\"t\":\"flush\"}\n");
    assert!(h.rt.views[&1].ui.selection.is_none());
    assert_eq!(h.rt.views[&1].ui.focus, None);
    key(&mut h, "control_c");
    assert_eq!(h.rt.clipboard.get(), "new");
}

#[test]
fn rich_text_copies_plain_words_and_links_keep_their_clicks() {
    let mut h = scene("");
    h.feed(&format!(
        "{}\n{}\n",
        create(6, "Strong", 2, json!({"text_items":["bold "]})),
        create(7, "Link", 2, json!({"text_items":["link"],"has_block":true}))
    ));
    props(&mut h, 3, json!({"text_items":["plain ",6,7]}));
    key(&mut h, "tab");
    key(&mut h, "control_a");
    key(&mut h, "control_c");
    assert_eq!(h.rt.clipboard.get(), "plain bold link");
    let (evs, reply) = h.req(json!({"op":"click","target":{"id":7}}));
    assert_eq!(reply["error"], Value::Null);
    assert!(named(&events(&evs), "click").iter().any(|e| e.1 == json!(7)));
}

#[test]
fn accessibility_focus_can_select_a_paragraph_and_explicit_markers_remain_independent() {
    let mut h = scene("select this");
    props(&mut h, 3, json!({"text_cursor":2,"text_marker":0}));
    h.value(json!({"op":"a11y_action","id":3,"action":"focus"}));
    key(&mut h, "control_a");
    key(&mut h, "control_c");
    assert_eq!(h.rt.clipboard.get(), "select this");
    let props = &h.rt.doc.get(3).unwrap().props;
    assert_eq!(props.get("text_cursor"), Some(&json!(2)));
    assert_eq!(props.get("text_marker"), Some(&json!(0)));
}
