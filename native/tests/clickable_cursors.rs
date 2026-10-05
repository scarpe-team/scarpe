mod common;
use common::*;
use scarpe_native::input::CursorShape::{Arrow, Hand, Text, Wait};
use serde_json::json;

#[test]
fn clickable_drawables_show_a_hand_and_restore_the_app_cursor_when_disabled_or_cleared() {
    for kind in ["Image", "Oval", "Rect", "Stack", "Flow", "Para"] {
        let mut h = Harness::new();
        h.feed(&app(300, 200, &[
            create(3, kind, 2, json!({"left":10,"top":10,"width":100,"height":60,"text":"A clickable passage","margin":0,"has_release":true})),
        ]));
        h.feed(r#"{"t":"props","id":1,"props":{"cursor":"wait"}}"#);
        h.value(json!({"op":"mouse","action":"move","x":30,"y":20}));
        assert_eq!(h.rt.views[&1].ui.cursor, Wait, "{kind} starts without a click handler");
        h.feed(r#"{"t":"props","id":3,"props":{"has_click":true}}"#);
        assert_eq!(h.rt.views[&1].ui.cursor, Hand, "{kind}, without moving the pointer");
        h.feed(r#"{"t":"props","id":3,"props":{"state":"disabled"}}"#);
        assert_eq!(h.rt.views[&1].ui.cursor, Wait, "disabled {kind} does not claim a hand");
        h.feed(r#"{"t":"props","id":3,"props":{"state":null,"cursor":"arrow"}}"#);
        assert_eq!(h.rt.views[&1].ui.cursor, Arrow, "explicit cursor beats a click handler");
        h.feed(r#"{"t":"props","id":3,"props":{"cursor":null}}"#);
        assert_eq!(h.rt.views[&1].ui.cursor, Hand);
        h.feed(r#"{"t":"props","id":3,"props":{"has_click":false}}"#);
        assert_eq!(h.rt.views[&1].ui.cursor, Wait);
    }
}

#[test]
fn text_fields_keep_their_caret_cursor_inside_clickable_slots() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Stack", 2, json!({"width":280,"height":180,"has_click":true})),
        create(4, "EditLine", 3, json!({"width":180,"height":35,"has_click":true})),
    ]));
    h.value(json!({"op":"mouse","action":"move","x":20,"y":15}));
    assert_eq!(h.rt.views[&1].ui.cursor, Text);
    h.value(json!({"op":"mouse","action":"move","x":250,"y":120}));
    assert_eq!(h.rt.views[&1].ui.cursor, Hand);
    h.feed(r#"{"t":"props","id":3,"props":{"has_click":false}}"#);
    assert_eq!(h.rt.views[&1].ui.cursor, Arrow);
}
