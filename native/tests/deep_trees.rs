//! Deep trees and loops from stdin: the layout and paint recursions are bounded
//! (limits::MAX_DEPTH, MAX_MASK_DEPTH), so no document can overflow the stack.

mod common;

use common::{app, create, snapshot_path, still_answers, Harness};
use serde_json::json;

/// 10,000 stacks, each inside the last. Layout recursion stops at limits::MAX_DEPTH, so the
/// 2 MB stack of a test thread (the display's own is 8 MB) never overflows; what lies deeper
/// is not laid out, so it neither draws nor takes clicks.
#[test]
fn ten_thousand_nested_slots_never_overflow_the_stack() {
    let mut body = vec![create(3, "Stack", 2, json!({}))];
    for id in 4..10_003 {
        body.push(create(id, "Stack", id - 1, json!({})));
    }
    body.push(create(10_003, "Para", 10_002, json!({"text_items": ["deep"]})));
    body.push(create(10_004, "Para", 5, json!({"text_items": ["shallow"]})));
    let mut h = Harness::new();
    h.feed(&app(200, 100, &body));
    let layout = h.layout();
    let laid_out = |id: i64| layout.iter().any(|n| n["id"] == id);
    assert!(laid_out(10_004), "text near the top still lays out");
    assert!(!laid_out(10_003), "text past the depth limit does not");
    assert!(laid_out(3 + scarpe_native::limits::MAX_DEPTH as i64 - 2), "slots down to the limit do");
    h.value(json!({"op": "snapshot", "path": snapshot_path(), "scale": 2}));
    still_answers(&mut h);
}

/// A shape block inside a shape block, 10,000 deep: the same limit holds for art.
#[test]
fn ten_thousand_nested_shape_blocks_never_overflow_the_stack() {
    let mut body = vec![create(3, "Shape", 2, json!({"shape_commands": []}))];
    for id in 4..10_003 {
        body.push(create(id, "Shape", id - 1, json!({"shape_commands": [["move_to", 0, 0], ["line_to", 10, 10]]})));
    }
    let mut h = Harness::new();
    h.feed(&app(200, 100, &body));
    h.value(json!({"op": "snapshot", "path": snapshot_path(), "scale": 1}));
    still_answers(&mut h);
}

/// Each masked slot paints through two frame-sized layers, so masks nested past
/// limits::MAX_MASK_DEPTH stop masking rather than pile up layers (50 deep at 2x was
/// 100 layers of 80 KB here, and of 4.8 MB in a 600x500 window). Every level's mask lets its
/// slot show, except the innermost, which draws nothing: under a limit it no longer hides.
#[test]
fn masks_nested_past_the_limit_stop_masking() {
    let white = json!({"fill": {"rgba": [255, 255, 255, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let levels = 50_i64;
    let mut body = vec![create(3, "Stack", 2, json!({}))];
    for level in 0..levels {
        let (slot, mask, inner) = (3 + level * 3, 4 + level * 3, 6 + level * 3);
        body.push(create(mask, "Mask", slot, json!({})));
        if level < levels - 1 {
            body.push(create(5 + level * 3, "Rect", mask, json!({"left": 0, "top": 0, "width": 200, "height": 100, "draw_context": white})));
            body.push(create(inner, "Stack", slot, json!({})));
        } else {
            body.push(create(inner, "Rect", slot, json!({"left": 50, "top": 20, "width": 40, "height": 40, "draw_context": red})));
        }
    }
    let mut h = Harness::new();
    h.feed(&app(200, 100, &body));
    assert_eq!(h.value(json!({"op": "pixel", "x": 70, "y": 40})), json!([255, 0, 0, 255]));
    h.value(json!({"op": "snapshot", "path": snapshot_path(), "scale": 2}));
    still_answers(&mut h);
}
