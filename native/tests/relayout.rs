//! A props change that alters only how a node looks keeps the layout (runtime.rs,
//! changes_only_looks). The kept layout must equal one laid out from scratch, nothing may be
//! laid out again, and the picture must still change.

mod common;

use common::{app, create, Harness};
use scarpe_native::layout::LBox;
use serde_json::{json, Value};
use std::collections::HashMap;

const APP: i64 = 1;

fn scene(h: &mut Harness) {
    let body = vec![
        create(3, "Stack", 2, json!({"margin": 10})),
        create(4, "Background", 3, json!({"fill": {"rgba": [240, 240, 250, 255]}})),
        create(5, "Para", 3, json!({"text_items": ["Some words to put a caret in"]})),
        create(6, "Check", 3, json!({})),
        create(7, "Progress", 3, json!({"fraction": 0.2})),
        create(8, "EditLine", 3, json!({"text": "old words"})),
        create(9, "Oval", 2, json!({"left": 300, "top": 40, "width": 60, "height": 60, "fill": {"rgba": [200, 0, 0, 255]}})),
        create(10, "Line", 2, json!({"left": 300, "top": 150, "x2": 400, "y2": 170, "strokewidth": 2})),
    ];
    h.feed(&app(480, 320, &body));
}

fn props(h: &mut Harness, id: i64, changes: Value) {
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": id, "props": changes})));
}

fn layouts_so_far(h: &Harness) -> u64 {
    h.rt.stats.to_json()["phases"]["layout"]["n"].as_u64().unwrap()
}

fn boxes(h: &mut Harness) -> HashMap<i64, LBox> {
    h.rt.layout_of(APP).expect("a layout").boxes.clone()
}

fn picture(h: &mut Harness) -> Vec<u8> {
    h.rt.picture(APP, 1.0).unwrap().data().to_vec()
}

#[test]
fn looks_only_changes_keep_a_layout_equal_to_a_fresh_one() {
    let changes = [
        (9, json!({"fill": {"rgba": [0, 120, 255, 255]}})),
        (10, json!({"stroke": {"rgba": [0, 150, 0, 255]}, "cap": "curve"})),
        (4, json!({"fill": {"rgba": [255, 230, 200, 255]}, "strokewidth": 3, "curve": 8})),
        (6, json!({"checked": true})),
        (7, json!({"fraction": 0.8})),
        (8, json!({"text": "new words typed"})),
        (5, json!({"text_cursor": 4, "text_marker": 0})),
    ];
    for (id, change) in changes {
        let mut h = Harness::new();
        scene(&mut h);
        let before_picture = picture(&mut h);
        let laid_out = layouts_so_far(&h);
        props(&mut h, id, change.clone());
        let after_picture = picture(&mut h);
        assert_eq!(layouts_so_far(&h), laid_out, "{change}: laid out again");
        assert_ne!(before_picture, after_picture, "{change}: the picture shows it");
        let kept = boxes(&mut h);
        h.rt.invalidate();
        assert_eq!(kept, boxes(&mut h), "{change}: the kept layout differs from a fresh one");
    }
}

#[test]
fn changes_that_move_or_resize_anything_still_lay_out() {
    let changes = [
        (10, json!({"strokewidth": 12})), // a line's box includes its stroke
        (9, json!({"left": 10})),
        (5, json!({"text_items": ["Now long enough to wrap: ".repeat(8)]})),
        (6, json!({"hidden": true})),
    ];
    for (id, change) in changes {
        let mut h = Harness::new();
        scene(&mut h);
        let before = boxes(&mut h);
        let laid_out = layouts_so_far(&h);
        props(&mut h, id, change.clone());
        assert!(layouts_so_far(&h) > laid_out, "{change}: not laid out again");
        assert_ne!(before, boxes(&mut h), "{change}: nothing moved");
    }
}

/// A scrolling stack holding paras, a background that stays put, a fixed-height slot that
/// clips, art, an image canvas and a scroller of its own; and more below it, so the window
/// scrolls too.
fn scrolling_scene(h: &mut Harness) {
    let mut body = vec![
        create(3, "Stack", 2, json!({"height": 200, "scroll": true})),
        create(4, "Background", 3, json!({"fill": {"rgba": [240, 240, 250, 255]}})),
        create(5, "Stack", 3, json!({"height": 40})),
        create(6, "Para", 5, json!({"text_items": ["clipped by its slot, far too long to fit on one line of it so it wraps"]})),
        create(7, "Oval", 3, json!({"left": 200, "top": 120, "width": 40})),
        create(8, "Image", 3, json!({"width": 60, "height": 30})),
        create(9, "Rect", 8, json!({"left": 5, "top": 5, "width": 80, "height": 10})),
        create(10, "Stack", 3, json!({"height": 60, "scroll": true})),
    ];
    body.extend((100..130).map(|id| create(id, "Para", 3, json!({"text_items": [format!("row {id}")]}))));
    body.extend((200..210).map(|id| create(id, "Para", 10, json!({"text_items": [format!("inner {id}")]}))));
    body.extend((300..330).map(|id| create(id, "Para", 2, json!({"text_items": [format!("below {id}")]}))));
    h.feed(&app(400, 300, &body));
}

/// A layout laid out from scratch at the scroll offsets the view holds now.
fn fresh_layout(h: &mut Harness) -> scarpe_native::layout::Layout {
    h.rt.invalidate();
    h.rt.layout_of(APP).expect("a layout").clone()
}

/// Equal to a thousandth of a pixel: a layout moved in place and one laid out afresh round
/// their sums apart in f32's last bits.
fn same_layout(kept: &scarpe_native::layout::Layout, fresh: &scarpe_native::layout::Layout, what: &str) {
    use scarpe_native::layout::Rect;
    let near = |a: f32, b: f32| (a - b).abs() < 1e-3;
    let same_rect = |a: &Rect, b: &Rect| near(a.x, b.x) && near(a.y, b.y) && near(a.w, b.w) && near(a.h, b.h);
    assert_eq!(kept.boxes.len(), fresh.boxes.len(), "{what}: boxes");
    for (id, f) in &fresh.boxes {
        let k = &kept.boxes[id];
        let clips = match (&k.clip, &f.clip) {
            (Some(a), Some(b)) => same_rect(a, b),
            (None, None) => true,
            _ => false,
        };
        assert!(same_rect(&k.rect, &f.rect) && clips && near(k.origin.1, f.origin.1), "{what}: node {id} kept {k:?}, fresh {f:?}");
    }
    for (id, f) in &fresh.scrollers {
        let k = &kept.scrollers[id];
        assert!(same_rect(&k.viewport, &f.viewport) && near(k.top, f.top) && near(k.content_height, f.content_height), "{what}: scroller {id}");
    }
    for (id, tb) in &fresh.texts {
        let k = &kept.texts[id];
        assert!(near(k.x, tb.x) && near(k.y, tb.y), "{what}: text of {id}");
    }
}

/// A wheel step moves what the slot holds in the layout that stands. It used to throw the
/// layout away and lay the whole window out again: 9 ms, and a push of every rect, per tick
/// on a 5000-row list. What it leaves equals a layout made from scratch at that scroll.
#[test]
fn a_wheel_step_scrolls_without_laying_out_again() {
    let mut h = Harness::new();
    scrolling_scene(&mut h);
    h.rt.layout_of(APP);
    for (dy, at) in [(40.0, (50.0, 50.0)), (40.0, (50.0, 50.0)), (-25.0, (50.0, 50.0)), (600.0, (50.0, 50.0)), (-1000.0, (50.0, 50.0)), (90.0, (50.0, 250.0)), (-30.0, (50.0, 250.0))] {
        let laid_out = layouts_so_far(&h);
        let (evs, _) = h.req(json!({"op": "wheel", "dy": dy, "x": at.0, "y": at.1}));
        assert_eq!(layouts_so_far(&h), laid_out, "a wheel of {dy} laid nothing out");
        if evs.iter().any(|m| m["t"] == "scroll") {
            assert!(evs.iter().any(|m| m["t"] == "layout"), "Ruby hears the rects that moved");
        }
        let kept = h.rt.views[&APP].layout.clone().expect("the layout stands");
        same_layout(&kept, &fresh_layout(&mut h), &format!("after a wheel of {dy} at {at:?}"));
    }
}

/// `scroll_to` (Lacci's scroll_top=) moves the slot the same way, clamped to its content.
#[test]
fn scroll_to_moves_the_slot_in_place_too() {
    let mut h = Harness::new();
    scrolling_scene(&mut h);
    h.rt.layout_of(APP);
    for top in [70.0, 9999.0, 0.0] {
        let laid_out = layouts_so_far(&h);
        h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "scroll_to", "id": 3, "top": top})));
        assert_eq!(layouts_so_far(&h), laid_out, "scroll_to {top} laid nothing out");
        let kept = h.rt.views[&APP].layout.clone().expect("the layout stands");
        same_layout(&kept, &fresh_layout(&mut h), &format!("after scroll_to {top}"));
    }
}

/// Thousands of wheel steps each way leave things where a fresh layout puts them: positions
/// come from where they were laid out each time, so rounding never adds up.
#[test]
fn scrolling_back_and_forth_does_not_drift() {
    let mut h = Harness::new();
    scrolling_scene(&mut h);
    h.rt.layout_of(APP);
    for i in 0..3000 {
        let dy = [37.3, -91.1, 58.7, -4.9][i % 4];
        let at = if i % 3 == 0 { (50.0, 250.0) } else { (50.0, 50.0) };
        h.rt.pointer_move(APP, at.0, at.1);
        h.rt.wheel(APP, dy, Some(at));
    }
    h.rt.out.take_captured();
    let kept = h.rt.views[&APP].layout.clone().expect("the layout stands");
    same_layout(&kept, &fresh_layout(&mut h), "after 3000 wheel steps");
}
