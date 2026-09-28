//! Shaped text is cached across frames (text::shape_cache); nothing that changes how a para
//! looks may come back stale from that cache.

mod common;

use common::{app, create, Harness};
use serde_json::json;

fn pixel(h: &mut Harness, x: f32, y: f32) -> Vec<u64> {
    h.value(json!({"op": "pixel", "x": x, "y": y})).as_array().unwrap().iter().map(|v| v.as_u64().unwrap()).collect()
}

#[test]
fn a_new_fill_behind_a_para_is_painted_not_the_cached_one() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Para", 2, json!({"text_items": ["   "], "fill": {"rgba": [255, 0, 0, 255]}}))]));
    // The fill highlights the text itself, which starts inside the para's 4 px margins
    // (manual 1208-1210, ledger C9), so look at a point under the first space.
    assert_eq!(pixel(&mut h, 6.0, 10.0), vec![255, 0, 0, 255]);
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 3, "props": {"fill": {"rgba": [0, 0, 255, 255]}}})));
    assert_eq!(pixel(&mut h, 6.0, 10.0), vec![0, 0, 255, 255], "the same words with a new fill");
}

/// Three windows of 20 paras each (`window` blocks, dialogs, several Shoes.app).
fn three_apps(h: &mut Harness) {
    let mut lines = vec![json!({"t": "hello", "v": 1, "pid": 1})];
    for a in 0..3i64 {
        let (app, root) = (10 * (a + 1), 10 * (a + 1) + 1);
        lines.push(json!({"t": "create", "id": root, "kind": "DocumentRoot", "parent": null, "props": {}}));
        lines.push(json!({"t": "create", "id": app, "kind": "App", "parent": null, "props": {"width": 300, "height": 400}, "doc_root": root}));
        // A stack, so each para has a line of its own and no neighbour follows its end.
        let stack = 900 + a;
        lines.push(create(stack, "Stack", root, json!({})));
        for i in 0..20 {
            lines.push(create(1000 + a * 100 + i, "Para", stack, json!({"text_items": [format!("window {a}, line {i}: the quick brown fox")]})));
        }
        lines.push(json!({"t": "run", "app": app}));
    }
    lines.push(json!({"t": "flush"}));
    h.feed(&lines.iter().map(|l| format!("{l}\n")).collect::<String>());
}

/// Every app lays out again after any change, and the cache swept after each layout, keeping
/// only what the last two had used. With three apps, a change in one threw away the others'
/// text before they laid out again, so every change reshaped all three windows (the review
/// measured about 50 times slower).
#[test]
fn a_change_in_one_window_reshapes_no_other_window_text() {
    let mut h = Harness::new();
    three_apps(&mut h);
    let before = h.rt.text.texts_shaped();
    for k in 0..5 {
        h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 1000, "props": {"text_items": [format!("changed {k}")]}})));
    }
    let shaped = h.rt.text.texts_shaped() - before;
    assert!(shaped <= 5, "5 changes to one para shaped {shaped} texts");
}

/// A change can only move things in the window it is drawn in, so the others keep their
/// layout. A text span has no parent (its paras list it in their text), so a change to one
/// still reaches the window showing it.
#[test]
fn a_change_lays_out_only_its_own_window_again() {
    let mut h = Harness::new();
    three_apps(&mut h);
    h.feed(&format!("{}\n", json!({"t": "props", "id": 1000, "props": {"text_items": ["changed"]}})));
    assert!(h.rt.views[&10].layout.is_none(), "the changed window lays out again");
    assert!(h.rt.views[&20].layout.is_some() && h.rt.views[&30].layout.is_some(), "the other two keep theirs");

    let span_in_window_3 = [
        json!({"t": "create", "id": 5000, "kind": "Strong", "parent": null, "props": {"text_items": ["bold"]}}),
        json!({"t": "props", "id": 1200, "props": {"text_items": ["see ", 5000]}}),
        json!({"t": "flush"}),
        json!({"t": "props", "id": 5000, "props": {"text_items": ["BOLDER"]}}),
        json!({"t": "flush"}),
    ];
    h.feed(&span_in_window_3.iter().map(|l| format!("{l}\n")).collect::<String>());
    let text = h.value(json!({"op": "layout", "app": 30})).as_array().unwrap().iter().find(|n| n["id"] == 1200).unwrap()["text"].clone();
    assert_eq!(text, json!("see BOLDER"));
}
