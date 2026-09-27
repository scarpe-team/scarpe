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
