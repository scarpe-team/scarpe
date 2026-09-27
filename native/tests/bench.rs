//! Layout + paint timing for a 50-element scene at 2x.
//!   cargo test --release --test bench -- --ignored --nocapture

mod common;

use common::{app, create, Harness};
use serde_json::json;
use std::time::Instant;

fn fifty_elements() -> String {
    let mut body = vec![create(3, "Background", 2, json!({"fill": {"gradient": ["#fefce8", "#e0f2fe"], "angle": 0}}))];
    let mut id = 4;
    let mut next = || {
        id += 1;
        id
    };
    let stack = next();
    body.push(create(stack, "Stack", 2, json!({"margin": 12})));
    for i in 0..10 {
        let flow = next();
        body.push(create(flow, "Flow", stack, json!({"margin_bottom": 4})));
        body.push(create(next(), "Para", flow, json!({"text_items": [format!("Row {i}: some text that wraps in a flow")], "margin_right": 6})));
        body.push(create(next(), "Button", flow, json!({"text": format!("Button {i}")})));
        body.push(create(next(), "EditLine", flow, json!({"text": "edit me", "width": 120})));
        body.push(create(next(), "Oval", flow, json!({"left": 400, "top": i * 30, "width": 20, "height": 20, "fill": {"rgba": [255, 99, 71, 200]}})));
    }
    app(480, 420, &body)
}

#[test]
#[ignore]
fn layout_and_paint_a_fifty_element_scene_at_2x() {
    let mut h = Harness::new();
    let t = Instant::now();
    h.feed(&fifty_elements());
    let cold_layout = t.elapsed();
    let app = 1;
    let nodes = h.rt.doc.len();
    let mut pm = tiny_skia::Pixmap::new(960, 840).unwrap();
    let t = Instant::now();
    h.rt.render(app, &mut pm, 2.0);
    let cold_paint = t.elapsed();
    let n = 50;
    let (mut layout_total, mut paint_total) = (std::time::Duration::ZERO, std::time::Duration::ZERO);
    let mut worst = std::time::Duration::ZERO;
    for _ in 0..n {
        h.rt.invalidate();
        let t0 = Instant::now();
        h.rt.ensure_layout(app);
        let t1 = Instant::now();
        h.rt.render(app, &mut pm, 2.0);
        let t2 = Instant::now();
        layout_total += t1 - t0;
        paint_total += t2 - t1;
        worst = worst.max(t2 - t0);
    }
    let (layout, paint) = (layout_total / n, paint_total / n);
    println!(
        "{nodes} nodes: parse + cold layout {cold_layout:?}, cold paint {cold_paint:?}; warm avg layout {layout:?} + paint@2x {paint:?} = {:?} (worst {worst:?})",
        layout + paint
    );
    assert!(layout + paint < std::time::Duration::from_millis(5), "layout + paint should stay under 5 ms");
}
