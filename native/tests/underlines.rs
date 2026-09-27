//! The error underline (`underline: "error"`, a red squiggle) keeps to what its text keeps to.

mod common;

use common::{app, create, Harness};
use serde_json::json;
use std::time::Duration;

/// Ink (anything not white) in the rows from `y0` down, at 1x.
fn ink_below(h: &mut Harness, y0: u32) -> usize {
    let pm = h.rt.picture(1, 1.0).expect("a picture");
    (y0..pm.height()).flat_map(|y| (0..pm.width()).map(move |x| (x, y))).filter(|(x, y)| pm.pixel(*x, *y).is_some_and(|p| p.red() < 250 || p.green() < 250 || p.blue() < 250)).count()
}

/// A fixed-height slot cuts its text off at its edge (ledger C13). The glyphs and straight
/// underlines were cut there, but the squiggle was drawn unclipped, so it showed through the
/// slot's edge, and a partial repaint never painted those pixels again.
#[test]
fn an_error_underline_stops_at_its_slots_edge() {
    let mut body = vec![create(3, "Stack", 2, json!({"height": 40, "width": 200}))];
    for i in 0..6 {
        body.push(create(10 + i, "Para", 3, json!({"text_items": [format!("misspeled wurds here {i}")], "underline": "error", "size": 16})));
    }
    let mut h = Harness::new();
    h.feed(&app(300, 200, &body));
    assert_eq!(ink_below(&mut h, 41), 0, "nothing shows below the 40 px stack");
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 3, "props": {"height": 200}})));
    assert!(ink_below(&mut h, 41) > 0, "the same squiggles show once the stack is tall enough");
}

/// A squiggle is built from waves as wide as its amplitude, stepped in f32. Under a span
/// miles wide (`kerning` of 40 million), x stopped growing past 2^25 and the loop never ended.
#[test]
fn an_error_underline_miles_wide_is_drawn_in_moments() {
    let (done, finished) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let mut h = Harness::new();
        h.feed(&app(300, 200, &[create(3, "Para", 2, json!({"text_items": ["ab"], "underline": "error", "kerning": 40_000_000}))]));
        let _ = done.send(h.value(json!({"op": "pixel", "x": 10, "y": 10})));
    });
    assert!(finished.recv_timeout(Duration::from_secs(20)).is_ok(), "the display painted and answered");
}
