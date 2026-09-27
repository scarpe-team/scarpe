//! What input from Ruby can make Rust allocate: canvases, scales, frames, image and font
//! files, geometry tiny-skia would choke on, and bytes that are not UTF-8 (src/limits.rs).

mod common;

use common::{app, create, snapshot_path, still_answers, Harness};
use serde_json::{json, Value};

/// `width: 1e9` must not become a 1e9-pixel canvas (4 GB a row), and no request can ask for one.
#[test]
fn huge_and_hostile_sizes_never_make_a_giant_canvas() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Para", 2, json!({"text_items": ["hi"]}))]));
    h.feed(&format!("{}\n", json!({"t": "props", "id": 1, "props": {"width": 1e9, "height": 1e30}})));
    let shot = h.value(json!({"op": "snapshot", "path": snapshot_path(), "scale": 0.5}));
    assert_eq!((shot["w"].as_u64(), shot["h"].as_u64()), (Some(5000), Some(5000)), "the app is capped at 10,000 px a side");

    let (_, reply) = h.req(json!({"op": "snapshot", "path": snapshot_path(), "scale": 2}));
    assert!(reply["error"].as_str().is_some_and(|e| e.contains("too large")), "400 megapixels is refused: {reply}");
    let (_, reply) = h.req(json!({"op": "snapshot", "path": snapshot_path(), "scale": 1e6}));
    assert!(reply["error"].as_str().is_some_and(|e| e.contains("scale")), "{reply}");
    let (_, reply) = h.req(json!({"op": "snapshot", "path": snapshot_path(), "scale": -2}));
    assert!(reply["error"].as_str().is_some_and(|e| e.contains("scale")), "{reply}");

    for (w, h_) in [(json!(-5), json!(100)), (json!(0), json!(0)), (json!(1e300), json!(-1e300))] {
        let (_, reply) = h.req(json!({"op": "resize", "w": w, "h": h_}));
        assert!(reply["error"].is_string(), "{w}x{h_} is not a size: {reply}");
    }
    let (_, reply) = h.req(json!({"op": "resize", "w": 300, "h": 200}));
    assert_eq!(reply["error"], Value::Null);
    let shot = h.value(json!({"op": "snapshot", "path": snapshot_path(), "scale": 1}));
    assert_eq!((shot["w"].as_u64(), shot["h"].as_u64()), (Some(300), Some(200)), "a sane resize still works");
    let frames = h.value(json!({"op": "frames", "n": u64::MAX}));
    assert!(frames.as_u64().is_some_and(|n| n <= 2_000), "a frames request is capped: {frames}");
}

/// Image and font files that are missing, empty, junk, directories, or FIFOs (which would
/// block whoever opens them) are skipped, and the app draws on.
#[test]
fn missing_and_broken_images_and_fonts_are_skipped() {
    let dir = std::env::temp_dir().join(format!("scarpe-robustness-files-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let junk = dir.join("junk.png");
    std::fs::write(&junk, b"this is not a png").unwrap();
    let empty = dir.join("empty.ttf");
    std::fs::write(&empty, b"").unwrap();
    // A PNG header claiming 100,000 x 100,000 pixels: 40 GB decoded.
    let mut giant = b"\x89PNG\r\n\x1a\n\0\0\0\x0dIHDR".to_vec();
    giant.extend_from_slice(&[0, 1, 0x86, 0xa0, 0, 1, 0x86, 0xa0, 8, 6, 0, 0, 0, 0, 0, 0, 0]);
    let giant_path = dir.join("giant.png");
    std::fs::write(&giant_path, giant).unwrap();
    let fifo = dir.join("pipe.png");
    let _ = std::process::Command::new("mkfifo").arg(&fifo).status();

    let paths = [dir.join("missing.png"), dir.clone(), junk.clone(), empty.clone(), giant_path, fifo.clone()];
    let mut body = Vec::new();
    for (i, path) in paths.iter().enumerate() {
        let url = path.display().to_string();
        body.push(create(3 + i as i64, "Image", 2, json!({"url": url, "width": 40, "height": 40})));
        body.push(create(20 + i as i64, "Background", 2, json!({"fill": {"image": url}})));
    }
    body.push(create(40, "Para", 2, json!({"text_items": ["still here"]})));
    let lines = app(300, 200, &body);

    let (done, finished) = std::sync::mpsc::channel();
    let worker = std::thread::spawn(move || {
        let mut h = Harness::new();
        h.feed(&lines);
        for path in [dir.join("missing.ttf"), dir.clone(), junk, empty, fifo] {
            h.feed(&format!("{}\n", json!({"t": "font", "path": path.display().to_string()})));
        }
        h.value(json!({"op": "snapshot", "path": snapshot_path(), "scale": 1}));
        still_answers(&mut h);
        let text = h.node(|n| n["id"] == 40)["text"].clone();
        let _ = done.send(text);
    });
    let text = finished.recv_timeout(std::time::Duration::from_secs(20)).expect("the display finished instead of blocking on a FIFO");
    assert_eq!(text, json!("still here"));
    worker.join().unwrap();
}

/// A line that is not UTF-8 is one bad line, not the end of the input.
#[test]
fn a_line_that_is_not_utf8_does_not_end_the_input() {
    let mut input = app(200, 100, &[create(3, "Para", 2, json!({"text_items": ["hi"]}))]).into_bytes();
    input.extend_from_slice(b"{\"t\":\"props\",\"id\":3,\"props\":{\"text_items\":[\"\xff\xfe\"]}}\n");
    input.extend_from_slice(b"\xc3\x28 not json either\n");
    input.extend_from_slice(b"{\"t\":\"req\",\"req\":77,\"op\":\"ping\"}\n");
    let mut rt = scarpe_native::Runtime::headless_for_tests();
    let code = scarpe_native::headless::serve(&mut rt, std::io::Cursor::new(input), None);
    assert_eq!(code, 0);
    let replies: Vec<Value> = rt.out.take_captured().into_iter().filter(|m| m["t"] == "reply").collect();
    assert_eq!(replies.last().map(|r| r["value"].clone()), Some(json!("pong")), "the ping after the bad bytes is answered");
}

/// tiny-skia rasterises in fixed point and panicked inside its own code (AlphaRuns::break_run)
/// on a shape block stroked 2^31 px wide round a star, painted at 2x: fuzz seed 1084, cut
/// down. Art too big to draw is skipped; what is left of the app draws on.
#[test]
fn art_too_big_to_rasterise_is_skipped() {
    let dc = |extra: Value| {
        let mut dc = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 255, 255]}});
        dc.as_object_mut().unwrap().extend(extra.as_object().unwrap().clone());
        dc
    };
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[
        create(3, "Shape", 2, json!({"strokewidth": 2147483648_i64})),
        create(4, "Star", 3, json!({})),
        create(5, "Rect", 2, json!({"left": 1e30, "top": -1e30, "width": 1e30, "height": 5, "draw_context": dc(json!({}))})),
        create(6, "Oval", 2, json!({"left": 20, "top": 20, "width": 40, "height": 40, "draw_context": dc(json!({"scale": [1e20, 1e20]}))})),
        create(7, "Line", 2, json!({"left": 0, "top": 0, "x2": 3e38, "y2": 50, "draw_context": dc(json!({"strokewidth": 3}))})),
        create(8, "Background", 2, json!({"fill": {"rgba": [0, 255, 0, 255]}, "width": 1e30, "curve": 1e30})),
        create(9, "Rect", 2, json!({"left": 150, "top": 60, "width": 20, "height": 20, "draw_context": dc(json!({}))})),
    ]));
    h.value(json!({"op": "snapshot", "path": snapshot_path(), "scale": 2}));
    assert_eq!(h.value(json!({"op": "pixel", "x": 160, "y": 70})), json!([255, 0, 0, 255]), "the sane rect still draws on top");
    still_answers(&mut h);
}

/// A slot or control millions of pixels tall reaches past what tiny-skia can rasterise. Wave 4
/// stopped the panic by skipping such paths, which also dropped the part on screen: a red
/// background 3,000,000 px tall, or a button a billion px tall scrolled into view, showed
/// nothing. Rects are cut down to what the window shows instead.
#[test]
fn the_visible_part_of_a_huge_box_still_draws() {
    let look = |kind: &str, height: f64, dy: f64, background: bool| {
        let mut h = Harness::new();
        let mut body = vec![create(14, kind, 2, json!({"height": height, "width": 200}))];
        if background {
            body.push(create(15, "Background", 14, json!({"fill": {"rgba": [255, 0, 0, 255]}})));
        }
        h.feed(&app(300, 200, &body));
        if dy > 0.0 {
            h.value(json!({"op": "wheel", "dy": dy, "x": 20, "y": 20}));
        }
        h.value(json!({"op": "pixel", "x": 10, "y": 100}))
    };
    for dy in [0.0, 1.5e6] {
        assert_eq!(look("Stack", 3e6, dy, true), json!([255, 0, 0, 255]), "a 3e6 px red stack scrolled {dy}");
    }
    for kind in ["Button", "ListBox"] {
        assert_ne!(look(kind, 1e9, 5e8, false), json!([255, 255, 255, 255]), "a 1e9 px {kind} shows its face");
    }
}
