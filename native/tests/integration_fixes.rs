//! Regressions found by running real Lacci apps (examples/) through the shim.

mod common;

use common::{app, create, Harness};
use serde_json::{json, Value};

const WHITE: [i64; 4] = [255, 255, 255, 255];

fn fragment(id: i64, kind: &str, text: &str) -> Value {
    json!({"t":"create","id":id,"kind":kind,"parent":null,"index":null,"widget":false,"props":{"text_items":[text]}})
}

fn pixel(h: &mut Harness, x: f64, y: f64) -> [i64; 4] {
    let v = h.value(json!({"op": "pixel", "x": x, "y": y}));
    let c: Vec<i64> = v.as_array().unwrap().iter().map(|c| c.as_i64().unwrap()).collect();
    [c[0], c[1], c[2], c[3]]
}

fn rect(node: &Value) -> (f64, f64, f64, f64) {
    let f = |k: &str| node[k].as_f64().unwrap();
    (f("x"), f("y"), f("w"), f("h"))
}

/// examples/link.rb: `link("Learn more"), " ", link("(show less)")`.
#[test]
fn plain_text_between_two_links_is_not_underlined() {
    let mut h = Harness::new();
    h.feed(&app(400, 100, &[
        fragment(4, "Link", "Learn more"),
        fragment(5, "Link", "show less"),
        create(3, "Para", 2, json!({"text_items": [4, "      ", 5], "size": 24})),
    ]));
    let first = h.node(|n| n["id"] == 4);
    let second = h.node(|n| n["id"] == 5);
    let (x1, y, w1, height) = rect(&first);
    let (x2, _, _, _) = rect(&second);
    let gap = (x1 + w1 + 2.0) as i64..(x2 - 2.0) as i64;
    assert!(gap.clone().count() >= 10, "a gap to look at: {gap:?}");
    for x in gap {
        for dy in 0..height as i64 {
            assert_eq!(pixel(&mut h, x as f64 + 0.5, y + dy as f64 + 0.5), WHITE, "ink in the gap at {x},{}", y + dy as f64);
        }
    }
}

/// philippe/minimal_editor.rb: a two-character selection on line two lit up lines one and three.
#[test]
fn a_para_selection_only_highlights_its_own_lines() {
    let mut h = Harness::new();
    // Flush with the window, lines one pitch apart, so a third of the height is a line.
    h.feed(&app(300, 100, &[create(3, "Para", 2, json!({"text_items": ["one\ntwo\nthree"], "text_marker": 4, "text_cursor": 6, "margin": 0, "leading": 0}))]));
    let (_, _, _, height) = rect(&h.node(|n| n["id"] == 3));
    let line = height / 3.0;
    assert_eq!(pixel(&mut h, 1.0, 1.0), WHITE, "line one is not selected");
    assert_eq!(pixel(&mut h, 1.0, 2.0 * line + 1.0), WHITE, "line three is not selected");
    let selected = pixel(&mut h, 3.0, line + 1.0);
    assert!(selected[2] == 255 && selected[0] < 250, "the selection itself shows: {selected:?}");
}

/// para_cursor_demo.rb: `wrap: "trim"` text ran past its para's box to the window edge.
#[test]
fn trimmed_text_stops_at_its_own_box() {
    let mut h = Harness::new();
    let long = "The quick brown fox jumps over the lazy dog, again and again";
    h.feed(&app(400, 60, &[create(3, "Para", 2, json!({"text_items": [long], "width": 150, "wrap": "trim", "margin": 0}))]));
    let (x, y, w, height) = rect(&h.node(|n| n["id"] == 3));
    assert_eq!((x, w, height), (0.0, 150.0, 14.4), "one line, 150 wide");
    let mid = y + height / 2.0;
    let inked = (0..150).filter(|&px| pixel(&mut h, px as f64 + 0.5, mid)[0] < 128).count();
    assert!(inked > 10, "text inside the box");
    for px in 151..400 {
        assert_eq!(pixel(&mut h, px as f64 + 0.5, mid), WHITE, "ink outside the box at x={px}");
    }
}

/// shoes-contrib/simple-editor.rb sets `cursor = -1` to keep the caret after the last character.
#[test]
fn a_negative_para_cursor_counts_from_the_end() {
    let row = |cursor: Value| {
        let mut h = Harness::new();
        h.feed(&app(200, 40, &[create(3, "Para", 2, json!({"text_items": ["abc"], "text_cursor": cursor}))]));
        (0..60).map(|x| pixel(&mut h, x as f64 + 0.5, 7.0)).collect::<Vec<_>>()
    };
    assert_eq!(row(json!(-1)), row(json!(3)));
    assert_ne!(row(json!(-1)), row(Value::Null), "a caret is drawn");
}

/// simple/form.rb: `background "menu-right.png", right: 0, top: 50, width: 55` sat at the left
/// edge. A picture is measured from the far edge by the size it is given; a colour with a size
/// of its own by 1 px, as Shoes 3 places a tile (ledger M19), and one with no size is inset.
#[test]
fn backgrounds_honour_right_bottom_and_run_to_the_far_edge() {
    let mut h = Harness::new();
    let red = json!({"rgba": [255, 0, 0, 255]});
    let picture = json!({"image": "/nonexistent/menu-right.png"});
    h.feed(&app(320, 420, &[
        create(3, "Background", 2, json!({"fill": red, "top": 50, "width": 55})),
        create(4, "Background", 2, json!({"fill": picture, "right": 0, "top": 50, "width": 55})),
        create(5, "Background", 2, json!({"fill": red, "bottom": 20, "height": 20})),
        create(6, "Background", 2, json!({"fill": red, "margin_left": 2, "margin_top": 2, "margin_right": 2, "margin_bottom": 2})),
        create(7, "Background", 2, json!({"fill": red, "bottom": 20})),
    ]));
    assert_eq!(rect(&h.node(|n| n["id"] == 3)), (0.0, 50.0, 55.0, 370.0));
    assert_eq!(rect(&h.node(|n| n["id"] == 4)), (265.0, 50.0, 55.0, 370.0));
    assert_eq!(rect(&h.node(|n| n["id"] == 5)), (0.0, 399.0, 320.0, 20.0));
    assert_eq!(rect(&h.node(|n| n["id"] == 6)), (2.0, 2.0, 316.0, 416.0));
    assert_eq!(rect(&h.node(|n| n["id"] == 7)), (0.0, 0.0, 320.0, 400.0));
}

/// Shoes 3 marked a text block's selection in bright yellow behind the text and drew its caret
/// black (s3t_textblock.c:187-197, 479-483), which is what Hackety Hack's editor looked like;
/// Shoes 3's text mode (ledger M14) draws them so. Otherwise the selection is a blue tint over
/// the text and the caret takes the text's colour.
#[test]
fn shoes3_text_marks_a_selection_yellow_under_a_black_caret() {
    let mut h = Harness::new();
    let grey = json!({"rgba": [120, 120, 120, 255]});
    h.feed(&app(300, 100, &[create(3, "Para", 2, json!({"text_items": ["MMMMMMMM"], "stroke": grey, "margin": 0, "text_cursor": 8, "text_marker": 4}))]));
    let para = h.node(|n| n["id"] == 3);
    let (x, y, w, _) = rect(&para);
    let tinted = pixel(&mut h, x + w * 0.75, y + 1.0);
    assert_ne!(&tinted[..3], &[255, 255, 0], "Scarpe's tint is not yellow");
    h.feed(&json!({"t": "text_mode", "mode": "shoes3"}).to_string());
    let para = h.node(|n| n["id"] == 3);
    let (x, y, w, hgt) = rect(&para);
    assert_eq!(pixel(&mut h, x + w * 0.75, y + 1.0), [255, 255, 0, 255], "yellow behind the marked letters");
    assert_ne!(pixel(&mut h, x + w * 0.25, y + 1.0), [255, 255, 0, 255], "and only there");
    let caret = h.value(json!({"op": "para_caret", "id": 3}));
    let (cx, cy) = (caret["left"].as_f64().unwrap(), caret["top"].as_f64().unwrap() + hgt / 2.0);
    assert_eq!(pixel(&mut h, cx + 0.5, cy), [0, 0, 0, 255], "a black caret after the grey text");
}
