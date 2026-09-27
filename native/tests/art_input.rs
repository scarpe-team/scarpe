//! Art and input (the M2 art-input lane): transforms, shape groups, image canvases,
//! masks, keys, coordinates, windows, tooltips and cursors, through the protocol.

mod common;

use common::{app, create, events, named, Harness};
use serde_json::{json, Value};

const WHITE: [i64; 3] = [255, 255, 255];
const RED: [i64; 3] = [255, 0, 0];
const BLACK: [i64; 3] = [0, 0, 0];

fn pixel(h: &mut Harness, x: f64, y: f64) -> [i64; 4] {
    let v = h.value(json!({"op": "pixel", "x": x, "y": y}));
    let c: Vec<i64> = v.as_array().unwrap().iter().map(|c| c.as_i64().unwrap()).collect();
    [c[0], c[1], c[2], c[3]]
}

fn rgb(h: &mut Harness, x: f64, y: f64) -> [i64; 3] {
    let [r, g, b, _] = pixel(h, x, y);
    [r, g, b]
}

fn near(a: [i64; 3], b: [i64; 3]) -> bool {
    a.iter().zip(b).all(|(x, y)| (x - y).abs() <= 20)
}

fn art(id: i64, kind: &str, parent: i64, props: Value) -> Value {
    create(id, kind, parent, props)
}

// ---- Transforms and caps (ledger E10, contract b) ----

/// `fill red; nostroke; rotate 90; rect 100, 100, 60, 20` (spec art.transform).
#[test]
fn rotate_turns_a_shape_about_its_corner() {
    let mut h = Harness::new();
    let dc = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "rotate": 90});
    h.feed(&app(300, 300, &[art(3, "Rect", 2, json!({"left": 100, "top": 100, "width": 60, "height": 20, "draw_context": dc}))]));
    assert_eq!(rgb(&mut h, 130.0, 110.0), WHITE, "the bar left where it was drawn");
    assert_eq!(rgb(&mut h, 130.0, 85.0), WHITE, "it did not turn about its centre");
    assert_eq!(rgb(&mut h, 110.0, 70.0), RED, "it turned counter-clockwise about (100, 100)");
}

#[test]
fn transform_center_turns_a_shape_about_its_middle() {
    let mut h = Harness::new();
    let dc = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "rotate": 90, "transform": "center"});
    h.feed(&app(300, 300, &[art(3, "Rect", 2, json!({"left": 100, "top": 100, "width": 60, "height": 20, "draw_context": dc}))]));
    assert_eq!(rgb(&mut h, 130.0, 85.0), RED);
    assert_eq!(rgb(&mut h, 130.0, 135.0), RED);
    assert_eq!(rgb(&mut h, 105.0, 110.0), WHITE);
    let rect = h.node(|n| n["id"] == 3);
    assert_eq!((rect["x"].as_f64(), rect["y"].as_f64(), rect["w"].as_f64(), rect["h"].as_f64()), (Some(120.0), Some(80.0), Some(20.0), Some(60.0)), "the layout box follows the turn");
}

/// manual 1862-1868 (spec art.translate): a shape drawn at (50, 60) after translate(10, 20).
#[test]
fn translate_moves_shapes_and_their_boxes() {
    let mut h = Harness::new();
    let dc = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "translate": [10, 20]});
    h.feed(&app(200, 200, &[art(3, "Rect", 2, json!({"left": 50, "top": 60, "width": 20, "height": 20, "draw_context": dc}))]));
    assert_eq!(rgb(&mut h, 75.0, 95.0), RED);
    assert_eq!(rgb(&mut h, 55.0, 65.0), WHITE);
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 75, "y": 95}}));
    assert!(named(&events(&evs), "click").is_empty());
    assert_eq!(h.node(|n| n["id"] == 3)["x"], json!(60.0), "hit-testing sees it where it is drawn");
}

fn capped_line(cap: &str) -> Harness {
    let mut h = Harness::new();
    let dc = json!({"stroke": {"rgba": [0, 0, 0, 255]}, "strokewidth": 20, "cap": cap});
    h.feed(&app(300, 200, &[art(3, "Line", 2, json!({"left": 50, "top": 100, "x2": 150, "y2": 100, "draw_context": dc}))]));
    h
}

/// manual 1676-1680: `:curve` is round, `:project` square and longer, `:rect` flat.
#[test]
fn caps_round_project_or_stop_flat() {
    let mut h = capped_line("curve");
    assert!(near(rgb(&mut h, 156.0, 100.0), BLACK), "a round end reaches past the end point");
    assert_eq!(rgb(&mut h, 157.0, 108.0), WHITE, "but not into the corner");

    let mut h = capped_line("project");
    assert!(near(rgb(&mut h, 157.0, 107.0), BLACK), "a projecting end is square");
    assert!(near(rgb(&mut h, 43.0, 100.0), BLACK), "at both ends");
    assert_eq!(rgb(&mut h, 163.0, 100.0), WHITE, "half the stroke width and no more");

    let mut h = capped_line("rect");
    assert!(near(rgb(&mut h, 148.0, 108.0), BLACK));
    assert_eq!(rgb(&mut h, 153.0, 100.0), WHITE, "a flat end stops at the end point");
}

// ---- Shape blocks (ledger E7, M21) ----

/// A Shape (id 3) holding `members`, each created inside it the way Lacci does.
fn shape_with(shape_props: Value, members: &[(i64, &str, Value)]) -> Harness {
    let mut body = vec![art(3, "Shape", 2, shape_props)];
    body.extend(members.iter().map(|(id, kind, props)| art(*id, kind, 3, props.clone())));
    let mut h = Harness::new();
    h.feed(&app(300, 200, &body));
    h
}

/// The Rules chapter (manual 392-408): ovals combined in a shape are one shape, so a
/// translucent fill does not build up where they overlap (nested_ovals.rb went black).
#[test]
fn art_in_a_shape_block_is_filled_once() {
    let grey = json!({"fill": {"rgba": [0, 0, 0, 128]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = shape_with(json!({"shape_commands": [], "draw_context": grey}), &[
        (4, "Rect", json!({"left": 0, "top": 0, "width": 100, "height": 100, "draw_context": red})),
        (5, "Rect", json!({"left": 50, "top": 0, "width": 100, "height": 100, "draw_context": red})),
    ]);
    let single = rgb(&mut h, 25.0, 50.0);
    let overlap = rgb(&mut h, 75.0, 50.0);
    assert!(single[0] > 100 && single[0] < 160 && single[0] == single[1], "the shape's own grey, not its members' red: {single:?}");
    assert_eq!(overlap, single, "the overlap is filled once");
}

#[test]
fn a_shape_block_strokes_every_outline_it_holds() {
    let outline = json!({"fill": {"rgba": [0, 0, 0, 0]}, "stroke": {"rgba": [0, 0, 0, 255]}, "strokewidth": 2});
    let mut h = shape_with(json!({"shape_commands": [], "draw_context": outline.clone()}), &[
        (4, "Oval", json!({"left": 20, "top": 20, "width": 100, "height": 100, "draw_context": outline.clone()})),
        (5, "Oval", json!({"left": 160, "top": 20, "width": 100, "height": 100, "draw_context": outline})),
    ]);
    assert!(near(rgb(&mut h, 20.5, 70.0), BLACK), "the first outline");
    assert!(near(rgb(&mut h, 259.5, 70.0), BLACK), "the second outline");
    assert_eq!(rgb(&mut h, 70.0, 70.0), WHITE, "no fill");
    assert_eq!(rgb(&mut h, 140.0, 70.0), WHITE, "and no line joining them");
}

/// `shape(left, top) { oval 0, 0, 20 }`: the art is measured from the shape's corner,
/// and the shape's box holds it all, so clicks and culling find it.
#[test]
fn a_shape_block_box_holds_its_art_from_its_left_top() {
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = shape_with(json!({"left": 100, "top": 100, "shape_commands": [], "draw_context": red.clone()}), &[
        (4, "Oval", json!({"left": 0, "top": 0, "width": 20, "height": 20, "draw_context": red.clone()})),
        (5, "Rect", json!({"left": 50, "top": 0, "width": 10, "height": 10, "draw_context": red})),
    ]);
    assert_eq!(rgb(&mut h, 110.0, 110.0), RED);
    assert_eq!(rgb(&mut h, 155.0, 105.0), RED);
    let shape = h.node(|n| n["id"] == 3);
    assert_eq!((shape["x"].clone(), shape["y"].clone(), shape["w"].clone(), shape["h"].clone()), (json!(100.0), json!(100.0), json!(60.0), json!(20.0)));
}

// ---- image(w, h) { ... } is a canvas (ledger E9, contract c) ----

/// An image block's art arrives as children of the Image node, in image-local
/// coordinates, and is clipped to the image's box.
#[test]
fn an_image_block_draws_its_art_inside_the_image() {
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[
        create(3, "Image", 2, json!({"url": "", "left": 100, "top": 100, "width": 100, "height": 100})),
        art(4, "Oval", 3, json!({"left": 0, "top": 0, "width": 50, "height": 50, "draw_context": red.clone()})),
        art(5, "Rect", 3, json!({"left": 80, "top": 80, "width": 50, "height": 50, "draw_context": red})),
    ]));
    assert_eq!(rgb(&mut h, 125.0, 125.0), RED, "the oval sits at the image's corner");
    assert_eq!(rgb(&mut h, 25.0, 25.0), WHITE, "not at the window's");
    assert_eq!(rgb(&mut h, 190.0, 190.0), RED, "the rect shows inside the image");
    assert_eq!(rgb(&mut h, 220.0, 220.0), WHITE, "and is cut off at its edge");
}

/// shoes-contrib simple-sphere.rb nests images with only a position inside a sized one:
/// they fill it. Text in a block lays out in the image like a flow.
#[test]
fn a_blank_image_inside_an_image_block_fills_it() {
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[
        create(3, "Image", 2, json!({"url": "", "left": 50, "top": 30, "width": 200, "height": 150})),
        create(4, "Image", 3, json!({"url": "", "left": 0, "top": 100})),
        art(5, "Rect", 4, json!({"left": 0, "top": 0, "width": 300, "height": 300, "draw_context": red})),
        create(6, "Para", 3, json!({"text_items": ["inside"]})),
    ]));
    let inner = h.node(|n| n["id"] == 4);
    assert_eq!((inner["x"].clone(), inner["y"].clone(), inner["w"].clone()), (json!(50.0), json!(130.0), json!(200.0)));
    assert_eq!(rgb(&mut h, 60.0, 170.0), RED, "the nested image's art shows");
    assert_eq!(rgb(&mut h, 60.0, 190.0), WHITE, "clipped by the outer image's bottom edge");
    let para = h.node(|n| n["id"] == 6);
    assert_eq!((para["x"].clone(), para["y"].clone()), (json!(50.0), json!(30.0)), "text starts at the image's corner");
}

// ---- Keys (ledger H1, Q5) ----

fn key(h: &mut Harness, name: &str) -> Vec<(String, Value, Value)> {
    let (evs, reply) = h.req(json!({"op": "key", "key": name}));
    assert_eq!(reply["error"], Value::Null, "{reply}");
    events(&evs)
}

/// manual 3221-3224 (spec list_box.focus): the arrows pick the other choices.
#[test]
fn arrows_on_a_focused_list_box_choose_without_the_popup() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "ListBox", 2, json!({"items": ["Grapes", "Pears", "Apricots"], "chosen": "Grapes"}))]));
    h.feed("{\"t\":\"focus\",\"id\":3}\n");
    let evs = key(&mut h, "down");
    assert_eq!(named(&evs, "change").iter().map(|e| e.2.clone()).collect::<Vec<_>>(), vec![json!(["Pears"])]);
    assert!(h.rt.views[&1].ui.popup.is_none(), "no popup");
    h.feed("{\"t\":\"props\",\"id\":3,\"props\":{\"chosen\":\"Pears\"}}\n");
    assert_eq!(named(&key(&mut h, "up"), "change")[0].2, json!(["Grapes"]));
    h.feed("{\"t\":\"props\",\"id\":3,\"props\":{\"chosen\":\"Grapes\"}}\n");
    assert!(named(&key(&mut h, "up"), "change").is_empty(), "nothing before the first");
    key(&mut h, "\n");
    assert!(h.rt.views[&1].ui.popup.is_some(), "Return still opens the popup");
}

/// Command edits like Control in a text field, while keypress names it alt_ (Q5).
#[test]
fn command_a_selects_all_in_a_field() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "EditLine", 2, json!({"text": "hello"}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    key(&mut h, ":command_a");
    let (evs, _) = h.req(json!({"op": "type", "text": "x"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["x"]), "the whole text was selected and replaced");
}

// ---- Coordinates of slot events (ledger H3, Q4) ----

/// Q4 (27 Sep 2026): a stack nested at (100, 100) hears a click at window (150, 120) as
/// (150, 120), like Shoes 3, and so do its release and motion blocks.
#[test]
fn slot_click_release_and_motion_use_window_coordinates() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[
        create(3, "Stack", 2, json!({"left": 100, "top": 100, "width": 200, "height": 100})),
        create(4, "SubscriptionItem", 3, json!({"shoes_api_name": "click"})),
        create(5, "SubscriptionItem", 3, json!({"shoes_api_name": "release"})),
        create(6, "SubscriptionItem", 3, json!({"shoes_api_name": "motion"})),
    ]));
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 150, "y": 120}}));
    let evs = events(&evs);
    assert_eq!(named(&evs, "click")[0].2, json!([1, 150, 120]));
    assert_eq!(named(&evs, "release")[0].2, json!([1, 150, 120]));
    assert_eq!(named(&evs, "motion")[0].2, json!([150, 120, false, false]));
}
