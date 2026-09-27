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
