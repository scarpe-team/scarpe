//! Art placed by its far edges (`right:`, `bottom:`, ledger C10), and shape blocks whose
//! members carry transforms of their own: the layout box, and so hit-testing, follows
//! what paint draws.

mod common;

use common::{app, create, events, named, Harness};
use serde_json::{json, Value};

fn red() -> Value {
    json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}})
}

fn rgb(h: &mut Harness, x: f64, y: f64) -> Vec<i64> {
    let v = h.value(json!({"op": "pixel", "x": x, "y": y}));
    v.as_array().unwrap()[..3].iter().map(|c| c.as_i64().unwrap()).collect()
}

fn rect_of(h: &mut Harness, id: i64) -> [f64; 4] {
    let n = h.node(|n| n["id"] == id);
    ["x", "y", "w", "h"].map(|k| n[k].as_f64().unwrap())
}

fn clicked(h: &mut Harness, x: f64, y: f64) -> Vec<Value> {
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": x, "y": y}}));
    named(&events(&evs), "click").iter().map(|e| e.1.clone()).collect()
}

// ---- right: and bottom: on art (ledger C10) ----

/// `right: 10, bottom: 10` put a 40x20 rect's far edges 10 px in from the slot's far edges,
/// as the manual says of every element (manual 1100-1106, 1356-1364).
#[test]
fn right_and_bottom_place_art_from_the_slots_far_edges() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Rect", 2, json!({"right": 10, "bottom": 10, "width": 40, "height": 20, "draw_context": red()}))]));
    assert_eq!(rect_of(&mut h, 3), [250.0, 170.0, 40.0, 20.0]);
    assert_eq!(rgb(&mut h, 285.0, 185.0), [255, 0, 0]);
    assert_eq!(rgb(&mut h, 20.0, 15.0), [255, 255, 255], "not at the top left, where left and top would put it");
}

/// Art that names both edges and no size runs from one to the other: `left: 20, right: 20`
/// in a 300 px slot is 260 wide.
#[test]
fn art_between_near_and_far_edges_stretches_to_both() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Rect", 2, json!({"left": 20, "top": 30, "right": 20, "bottom": 50, "draw_context": red()})),
        create(4, "Oval", 2, json!({"left": 100, "right": 100, "top": 160, "height": 30, "draw_context": red()})),
    ]));
    assert_eq!(rect_of(&mut h, 3), [20.0, 30.0, 260.0, 120.0]);
    assert_eq!(rect_of(&mut h, 4), [100.0, 160.0, 100.0, 30.0]);
    assert_eq!(rgb(&mut h, 275.0, 145.0), [255, 0, 0]);
}

/// A size of its own wins: with `left` and `width`, `right` changes nothing (DESIGN 6:
/// left and top win when both are given).
#[test]
fn a_size_and_a_near_edge_win_over_the_far_edge() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Rect", 2, json!({"left": 20, "top": 30, "width": 50, "height": 40, "right": 20, "bottom": 20, "draw_context": red()}))]));
    assert_eq!(rect_of(&mut h, 3), [20.0, 30.0, 50.0, 40.0]);
}

/// Centred art (an arrow, a star) keeps its own size and hugs the far edge.
#[test]
fn a_star_with_right_hugs_the_far_edge() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Star", 2, json!({"right": 0, "top": 100, "outer": 30, "inner": 15, "draw_context": red()}))]));
    let [x, _, w, _] = rect_of(&mut h, 3);
    assert_eq!((x + w, w), (300.0, 60.0));
}

// ---- Shape blocks whose members carry their own transforms ----

/// `shape(100, 100) { rotate 90; rect 0, 0, 60, 20 }`: the member joins the group
/// untransformed (DESIGN 12), so it draws as a bar along the top, and its box and the
/// shape's must be that bar too, not the bar turned about its own corner.
#[test]
fn a_member_with_its_own_rotation_is_hit_where_it_is_drawn() {
    let turned = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "rotate": 90});
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Shape", 2, json!({"left": 100, "top": 100, "shape_commands": [], "has_click": true, "draw_context": red()})),
        create(4, "Rect", 3, json!({"left": 0, "top": 0, "width": 60, "height": 20, "draw_context": turned})),
    ]));
    assert_eq!(rgb(&mut h, 150.0, 110.0), [255, 0, 0], "drawn as a bar along the top");
    assert_eq!(rgb(&mut h, 110.0, 70.0), [255, 255, 255], "not turned up about its corner");
    assert_eq!(rect_of(&mut h, 4), [100.0, 100.0, 60.0, 20.0]);
    assert_eq!(rect_of(&mut h, 3), [100.0, 100.0, 60.0, 20.0]);
    assert_eq!(clicked(&mut h, 150.0, 110.0), vec![json!(3)], "a click on the bar reaches the shape");
    assert!(clicked(&mut h, 110.0, 70.0).is_empty(), "a click where nothing is drawn does not");
}

/// `rotate 90` before a shape block turns the whole group about the group's corner, and the
/// boxes of the shape and of each member turn with it.
#[test]
fn a_turned_shape_block_is_hit_where_the_group_is_drawn() {
    let turned = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "rotate": 90});
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[
        create(3, "Shape", 2, json!({"left": 100, "top": 200, "shape_commands": [], "has_click": true, "draw_context": turned.clone()})),
        create(4, "Rect", 3, json!({"left": 0, "top": 0, "width": 20, "height": 20, "draw_context": turned.clone()})),
        create(5, "Rect", 3, json!({"left": 80, "top": 0, "width": 20, "height": 20, "draw_context": turned})),
    ]));
    // The group spans (100, 200)..(200, 220); a quarter turn counter-clockwise about
    // (100, 200) stands it on end above that corner: x 100..120, y 100..200.
    assert_eq!(rgb(&mut h, 110.0, 190.0), [255, 0, 0], "the first member, just above the corner");
    assert_eq!(rgb(&mut h, 110.0, 110.0), [255, 0, 0], "the second, 80 px higher");
    assert_eq!(rect_of(&mut h, 3), [100.0, 100.0, 20.0, 100.0]);
    assert_eq!(rect_of(&mut h, 5), [100.0, 100.0, 20.0, 20.0]);
    assert_eq!(clicked(&mut h, 110.0, 110.0), vec![json!(3)]);
    assert!(clicked(&mut h, 190.0, 210.0).is_empty(), "the unturned second member's place is empty");
}

/// Ruled 27 Sep 2026: a negative left or top on art is a plain coordinate, as in Shoes 3
/// (shoes_place_exact, s3_ruby.c:385-392), so art can move off the left and top edges. It
/// read as "the slot less 30", and anything animated past the left edge jumped to the right.
#[test]
fn negative_art_coordinates_are_plain_coordinates() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Oval", 2, json!({"left": -30, "top": 50, "width": 100})),
        create(4, "Rect", 2, json!({"left": -30, "top": -10, "width": 100, "height": 20})),
        create(5, "Line", 2, json!({"left": 10, "top": 10, "x2": -20, "y2": -40})),
        create(6, "Star", 2, json!({"left": -5, "top": -5, "outer": 20, "inner": 10})),
    ]));
    let at = |h: &mut Harness, id: i64| {
        let n = h.node(|n| n["id"] == id);
        (n["x"].as_f64().unwrap(), n["y"].as_f64().unwrap())
    };
    assert_eq!(at(&mut h, 3), (-30.0, 50.0));
    assert_eq!(at(&mut h, 4), (-30.0, -10.0));
    assert_eq!(at(&mut h, 5), (-20.5, -40.5), "a line runs to its end point, half its stroke round it");
    assert_eq!(at(&mut h, 6), (-25.0, -25.0), "a star centred on (-5, -5)");
    assert_eq!(h.value(json!({"op": "pixel", "x": 10, "y": 100})), json!([0, 0, 0, 255]), "the oval's right part shows");
}

/// A Float between 0 and 1 on art is pixels too (ledger C15, extended 28 Sep 2026): the manual
/// draws shapes "at pixel coordinates" and Shoes 3 reads them as whole pixels. It read as a
/// share of the slot, so a raindrop, a star or a bar animated through the slot's top-left
/// corner jumped across the window for a frame, and a 0.8 px star became 80% of the slot.
/// A percentage still reads as a share.
#[test]
fn float_art_coordinates_under_one_are_pixels() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Oval", 2, json!({"left": 0.5, "top": 0.5, "width": 12, "center": true, "draw_context": red()})),
        create(4, "Line", 2, json!({"left": 10, "top": 10, "x2": 0.5, "y2": 100})),
        create(5, "Rect", 2, json!({"left": 200, "top": 150, "width": 0.8, "height": 0.8})),
        create(6, "Rect", 2, json!({"left": "10%", "top": 0, "width": "50%", "height": 10})),
    ]));
    let box_of = |h: &mut Harness, id: i64| rect_of(h, id);
    assert_eq!(box_of(&mut h, 3), [-5.5, -5.5, 12.0, 12.0], "centred on (0.5, 0.5), not the middle of the slot");
    assert_eq!(rgb(&mut h, 2.0, 2.0), [255, 0, 0], "so it shows in the corner");
    assert_eq!(rgb(&mut h, 150.0, 100.0), [255, 255, 255], "and nothing in the middle");
    let line = box_of(&mut h, 4);
    assert!(line[2] < 11.0, "the line ends a hair right of the left edge, not at x = 150: {line:?}");
    assert!(box_of(&mut h, 5)[2] < 1.0, "a 0.8 px rect stays under a pixel");
    assert_eq!(box_of(&mut h, 6), [30.0, 0.0, 150.0, 10.0], "percentages are of the slot");
}
