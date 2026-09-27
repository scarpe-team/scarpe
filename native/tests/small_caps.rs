//! `variant: "smallcaps"` (manual 1511-1519, ledger F4): lower-case letters as small capitals.

mod common;

use common::{app, create, Harness};
use serde_json::{json, Value};

/// How far below its box's top a para's lowest dark pixel is, at 1x.
fn bottom_of_ink(h: &mut Harness, id: i64) -> u32 {
    let node = h.node(|n| n["id"] == id);
    let [x, y, w, hgt] = ["x", "y", "w", "h"].map(|k| node[k].as_f64().unwrap());
    let pm = h.rt.picture(1, 1.0).expect("a picture");
    let rows = (y as u32..(y + hgt).ceil() as u32).filter(|&row| {
        (x as u32..(x + w) as u32).any(|col| pm.pixel(col, row).is_some_and(|p| (p.red() as u32 + p.green() as u32 + p.blue() as u32) < 384))
    });
    rows.max().expect("ink") - y as u32
}

/// Bundled Inter has no small capitals of its own (no `smcp`), so they are drawn as capitals
/// a size smaller: nothing hangs below the baseline, where a lower-case p does.
#[test]
fn small_capitals_sit_on_the_baseline_and_read_as_written() {
    let mut h = Harness::new();
    h.feed(&app(400, 200, &[
        create(3, "Stack", 2, json!({})),
        create(4, "Para", 3, json!({"text_items": ["pppp"], "size": 30})),
        create(5, "Para", 3, json!({"text_items": ["pppp"], "size": 30, "variant": "smallcaps"})),
    ]));
    let (plain, small) = (bottom_of_ink(&mut h, 4), bottom_of_ink(&mut h, 5));
    assert!(small + 3 < plain, "small capitals end at the baseline ({small}), a p hangs below it ({plain})");
    assert_eq!(h.node(|n| n["id"] == 5)["text"], json!("pppp"), "the para still reads as the app wrote it");
    assert!(h.value(json!({"op": "click", "target": {"text": "pppp"}}))["hit"] != Value::Null);

    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 5, "props": {"variant": "normal"}})));
    assert_eq!(bottom_of_ink(&mut h, 5), plain, "variant: normal brings the lower-case letters back");
}
