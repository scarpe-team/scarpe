//! Drawable opacity is group compositing: overlapping children fade together, at every scale.
mod common;

use common::{app, create, Harness};
use serde_json::{json, Value};
use tiny_skia::Pixmap;

fn props(h: &mut Harness, id: i64, props: Value) {
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t":"props","id":id,"props":props})));
}

fn rect(id: i64, parent: i64, x: u32, color: [u8; 4]) -> Value {
    create(id, "Rect", parent, json!({"left":x,"top":0,"width":60,"height":50,"fill":{"rgba":color},"strokewidth":0}))
}

fn rgb(picture: &Pixmap, x: u32, y: u32, expected: [u8; 3]) {
    let pixel = picture.pixel(x, y).unwrap().demultiply();
    let actual = [pixel.red(), pixel.green(), pixel.blue()];
    assert!(actual.iter().zip(expected).all(|(a, b)| a.abs_diff(b) <= 1), "at {x},{y}: {actual:?}, expected {expected:?}");
    assert_eq!(pixel.alpha(), 255, "drawable opacity reveals the opaque window beneath it");
}

#[test]
fn drawable_opacity_updates_clamps_and_clears() {
    let mut h = Harness::new();
    h.feed(&app(160, 100, &[rect(3, 2, 0, [255, 0, 0, 255])]));
    let layout = h.layout();
    for (opacity, white) in [
        (json!(0.5), 127), (json!(0.25), 191), (json!(0), 255), (json!(-2), 255),
        (json!(3), 0), (Value::Null, 0), (json!("invalid"), 0), (json!("NaN"), 0),
        (json!("inf"), 0), (json!(true), 0),
    ] {
        props(&mut h, 3, json!({"opacity":opacity}));
        rgb(&h.rt.picture(1, 1.0).unwrap(), 20, 20, [255, white, white]);
        assert_eq!(h.layout(), layout, "opacity leaves geometry and visibility alone");
    }
}

#[test]
fn slots_composite_overlapping_children_once_at_each_scale() {
    for kind in ["Stack", "Flow", "Widget", "Image"] {
        let mut h = Harness::new();
        h.feed(&app(180, 100, &[
            create(3, kind, 2, json!({"url":"","left":10,"top":10,"width":100,"height":60,"opacity":0.5})),
            rect(4, 3, 0, [255, 0, 0, 255]),
            rect(5, 3, 30, [0, 0, 255, 255]),
        ]));
        for scale in [1.0, 1.25, 2.0] {
            let picture = h.rt.picture(1, scale).unwrap();
            let pixel = |x: f32| (x * scale) as u32;
            rgb(&picture, pixel(25.0), pixel(30.0), [255, 127, 127]);
            rgb(&picture, pixel(55.0), pixel(30.0), [127, 127, 255]);
            rgb(&picture, pixel(90.0), pixel(30.0), [127, 127, 255]);
            rgb(&picture, pixel(130.0), pixel(30.0), [255, 255, 255]);
        }
    }
}

#[test]
fn nested_opacity_preserves_the_outer_groups_backdrop() {
    let mut h = Harness::new();
    h.feed(&app(160, 100, &[
        create(3, "Stack", 2, json!({"width":100,"height":80,"opacity":0.5})),
        create(4, "Background", 3, json!({"fill":{"rgba":[255,0,0,255]}})),
        create(5, "Flow", 3, json!({"width":60,"height":50,"opacity":0.5})),
        rect(6, 5, 0, [0, 0, 255, 255]),
    ]));
    rgb(&h.rt.picture(1, 1.0).unwrap(), 20, 20, [191, 127, 191]);
    props(&mut h, 3, json!({"opacity":0}));
    rgb(&h.rt.picture(1, 1.0).unwrap(), 20, 20, [255, 255, 255]);
    props(&mut h, 3, json!({"opacity":null}));
    rgb(&h.rt.picture(1, 1.0).unwrap(), 20, 20, [127, 0, 128]);
}

#[test]
fn clipped_and_masked_contents_fade_with_their_slot() {
    let mut h = Harness::new();
    h.feed(&app(160, 120, &[
        create(3, "Stack", 2, json!({"left":20,"top":10,"width":80,"height":60,"opacity":0.5})),
        create(4, "Background", 3, json!({"fill":{"rgba":[255,0,0,255]}})),
        create(5, "Mask", 3, json!({"left":0,"top":0,"width":80,"height":60})),
        create(6, "Rect", 5, json!({"left":10,"top":10,"width":40,"height":30,"fill":{"rgba":[0,0,0,255]},"strokewidth":0})),
    ]));
    for scale in [1.0, 2.0] {
        let picture = h.rt.picture(1, scale).unwrap();
        rgb(&picture, (45.0 * scale) as u32, (30.0 * scale) as u32, [255, 127, 127]);
        rgb(&picture, (85.0 * scale) as u32, (30.0 * scale) as u32, [255, 255, 255]);
        rgb(&picture, (45.0 * scale) as u32, (90.0 * scale) as u32, [255, 255, 255]);
    }
    props(&mut h, 5, json!({"opacity":0.5}));
    rgb(&h.rt.picture(1, 1.0).unwrap(), 45, 30, [255, 191, 191]);
}

#[test]
fn a_scrollbars_ink_fades_with_its_contents() {
    let mut h = Harness::new();
    h.feed(&app(160, 130, &[
        create(3, "Stack", 2, json!({"left":10,"top":10,"width":100,"height":80,"scroll":true})),
        create(4, "Background", 3, json!({"fill":{"rgba":[255,0,0,255]}})),
        create(5, "Stack", 3, json!({"height":300})),
    ]));
    let opaque = h.rt.picture(1, 1.0).unwrap();
    props(&mut h, 3, json!({"opacity":0.5}));
    let faded = h.rt.picture(1, 1.0).unwrap();
    for (i, (full, half)) in opaque.pixels().iter().zip(faded.pixels()).enumerate() {
        let a = full.demultiply();
        let b = half.demultiply();
        for (a, b) in [a.red(), a.green(), a.blue()].into_iter().zip([b.red(), b.green(), b.blue()]) {
            assert!((u16::from(b) * 2).abs_diff(u16::from(a) + 255) <= 2, "pixel {i} fades once, including the scrollbar");
        }
    }
    props(&mut h, 3, json!({"opacity":0}));
    assert!(h.rt.picture(1, 1.0).unwrap().data().iter().all(|c| *c == 255), "zero opacity also removes the scrollbar's ink");
}

#[test]
fn a_transparent_control_keeps_its_focus_text_and_accessibility() {
    let mut h = Harness::new();
    h.feed(&app(200, 140, &[
        create(3, "Stack", 2, json!({"width":180,"height":100,"opacity":0})),
        create(4, "EditLine", 3, json!({"text":"Book","width":140})),
        create(5, "Button", 3, json!({"text":"Save"})),
    ]));
    h.value(json!({"op":"a11y_action","id":4,"action":"focus"}));
    h.value(json!({"op":"a11y_action","id":4,"action":"set_value","value":"New title"}));
    assert_eq!(h.value(json!({"op":"focused"})), json!(4));
    let tree = h.value(json!({"op":"a11y"}));
    assert_eq!(tree["children"][0]["value"], json!("New title"));
    assert!(h.rt.picture(1, 1.0).unwrap().data().iter().all(|c| *c == 255));
    props(&mut h, 3, json!({"opacity":1}));
    assert_eq!(h.value(json!({"op":"focused"})), json!(4));
    assert_eq!(h.value(json!({"op":"a11y"}))["children"][0]["value"], json!("New title"));
}

#[test]
fn deeply_nested_opacity_bounds_layer_allocations_and_still_honors_zero() {
    let mut h = Harness::new();
    let mut body = Vec::new();
    for id in 3..53 {
        body.push(create(id, "Stack", id - 1, json!({"width":100,"height":60,"opacity":0.5})));
    }
    body.push(rect(53, 52, 0, [255, 0, 0, 255]));
    h.feed(&app(120, 80, &body));
    let white = (255.0 * (1.0 - 0.5_f32.powi(scarpe_native::limits::MAX_MASK_DEPTH as i32))).round() as u8;
    rgb(&h.rt.picture(1, 1.0).unwrap(), 20, 20, [255, white, white]);
    props(&mut h, 52, json!({"opacity":0}));
    rgb(&h.rt.picture(1, 1.0).unwrap(), 20, 20, [255, 255, 255]);
    common::still_answers(&mut h);
}
