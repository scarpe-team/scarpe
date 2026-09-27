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
