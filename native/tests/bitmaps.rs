//! Caller-owned images use the normal layout/paint paths without a temporary file.

mod common;

use base64::{engine::general_purpose::STANDARD, Engine};
use common::{app, create, Harness};
use scarpe_native::elements::image::ImageCache;
use scarpe_native::limits;
use scarpe_native::paint::damage::{FrameMemory, Repaint};
use serde_json::{json, Value};
use std::path::Path;
use std::rc::Rc;
use tiny_skia::Pixmap;

fn upload(h: &mut Harness, key: &str, width: u32, height: u32, pixels: &[u8]) {
    assert_eq!(h.value(json!({
        "op": "cache_bitmap", "key": key, "width": width, "height": height, "rgba": STANDARD.encode(pixels),
    })), json!(key));
}

fn pixel(h: &mut Harness, x: f32, y: f32) -> Value {
    h.value(json!({"op": "pixel", "x": x, "y": y}))
}

#[test]
fn rgba_is_premultiplied_and_available_before_an_app_exists() {
    let mut h = Harness::new();
    upload(&mut h, "memory:rgba", 2, 2, &[200, 100, 50, 128, 255, 20, 30, 0, 7, 8, 9, 255, 255, 0, 0, 1]);
    assert!(h.rt.views.is_empty());
    assert_eq!(h.value(json!({"op": "bitmap_size", "key": "memory:rgba"})), json!([2, 2]));
    let image = h.rt.images.get(Path::new("memory:rgba")).unwrap();
    assert_eq!(image.data(), &[100, 50, 25, 128, 0, 0, 0, 0, 7, 8, 9, 255, 1, 0, 0, 1]);
    h.feed(&app(80, 60, &[create(3, "Image", 2, json!({"url": "memory:rgba"}))]));
    let node = h.node(|n| n["id"] == 3);
    assert_eq!((node["w"].clone(), node["h"].clone()), (json!(2.0), json!(2.0)));
    assert_eq!(pixel(&mut h, 0.0, 1.0), json!([7, 8, 9, 255]), "rows retain their order");
}

#[test]
fn shared_images_replace_resize_survive_removal_and_release_explicitly() {
    let mut h = Harness::new();
    upload(&mut h, "memory:page", 2, 3, &[255, 0, 0, 255].repeat(6));
    h.feed(&app(160, 100, &[
        create(3, "Image", 2, json!({"url": "memory:page", "width": 40, "height": 60})),
        create(4, "Image", 2, json!({"url": "memory:page", "left": 80, "top": 0})),
    ]));
    assert_eq!(pixel(&mut h, 20.0, 20.0), json!([255, 0, 0, 255]));
    assert_eq!(pixel(&mut h, 81.0, 1.0), json!([255, 0, 0, 255]));
    assert_eq!(h.rt.images.len(), 1, "two drawables share one original");
    upload(&mut h, "memory:page", 4, 2, &[0, 128, 0, 255].repeat(8));
    assert_eq!(pixel(&mut h, 20.0, 20.0), json!([0, 128, 0, 255]), "resized copies are refreshed");
    let node = h.node(|n| n["id"] == 4);
    assert_eq!((node["w"].clone(), node["h"].clone()), (json!(4.0), json!(2.0)), "intrinsic sizes refresh");
    assert_eq!(pixel(&mut h, 81.0, 1.0), json!([0, 128, 0, 255]));
    h.feed("{\"t\":\"destroy\",\"id\":3}\n{\"t\":\"destroy\",\"id\":4}\n{\"t\":\"flush\"}\n");
    assert_eq!(h.rt.images.len(), 1, "originals survive virtualization");
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", create(5, "Image", 2, json!({"url": "memory:page", "width": 40, "height": 40}))));
    assert_eq!(pixel(&mut h, 20.0, 20.0), json!([0, 128, 0, 255]));
    assert_eq!(h.value(json!({"op": "release_bitmap", "key": "memory:page"})), json!(true));
    assert_eq!(h.value(json!({"op": "release_bitmap", "key": "memory:page"})), json!(false));
    assert_eq!(h.value(json!({"op": "bitmap_size", "key": "memory:page"})), Value::Null);
    assert_ne!(pixel(&mut h, 20.0, 20.0), json!([0, 128, 0, 255]), "released images show placeholders");
    assert!(h.rt.images.is_empty(), "missing memory keys do not make filesystem cache entries");
    upload(&mut h, "memory:page", 1, 1, &[0, 0, 255, 255]);
    assert_eq!(pixel(&mut h, 20.0, 20.0), json!([0, 0, 255, 255]), "late uploads refresh existing drawables");
}

#[test]
fn replacements_and_releases_repaint_images_icons_and_patterns_in_every_window() {
    let mut h = Harness::new();
    upload(&mut h, "memory:shared", 1, 1, &[255, 0, 0, 255]);
    h.feed(&app(300, 80, &[
        create(3, "Image", 2, json!({"url": "memory:shared", "width": 30, "height": 30})),
        create(4, "Button", 2, json!({"icon": "memory:shared", "text": "", "left": 60, "top": 0, "width": 60, "height": 40})),
        create(5, "Rect", 2, json!({"left": 140, "top": 0, "width": 40, "height": 40, "draw_context": {"fill": {"image": "memory:shared"}}})),
        create(6, "Rect", 2, json!({"left": 200, "top": 5, "width": 40, "height": 40, "fill": [0, 0, 0, 0], "stroke": {"image": "memory:shared"}, "strokewidth": 8})),
    ]));
    h.feed(&format!("{}\n{}\n{}\n{}\n", json!({"t":"create","id":100,"kind":"App","doc_root":101,"props":{"width":80,"height":60}}),
        create(101, "DocumentRoot", 100, json!({})),
        create(102, "Image", 101, json!({"url":"memory:shared","width":30,"height":30})), json!({"t":"run","app":100})));
    let mut frames = [(1, Pixmap::new(300, 80).unwrap(), FrameMemory::default()), (100, Pixmap::new(80, 60).unwrap(), FrameMemory::default())];
    for (id, frame, memory) in &mut frames {
        h.rt.repaint(*id, frame, 1.0, memory);
    }
    for (x, y) in [(10, 10), (90, 19), (160, 20), (220, 5)] {
        assert_eq!(frames[0].1.pixel(x, y).unwrap().red(), 255);
        assert_eq!(frames[0].1.pixel(x, y).unwrap().green(), 0, "the fixture paints the shared key at {x},{y}");
    }
    for pixels in [Some([0, 128, 0, 255]), None, Some([0, 0, 255, 255])] {
        if let Some(bytes) = pixels {
            upload(&mut h, "memory:shared", 1, 1, &bytes);
        } else {
            h.value(json!({"op":"release_bitmap","key":"memory:shared"}));
        }
        for (id, frame, memory) in &mut frames {
            assert!(h.rt.views[id].dirty, "every affected window is scheduled to repaint");
            let before = frame.clone();
            let plan = h.rt.repaint(*id, frame, 1.0, memory);
            assert_ne!(plan, Repaint::Nothing);
            let full = h.rt.picture(*id, 1.0).unwrap();
            h.rt.verify_repaint(*id, &plan, frame, 1.0, &full, &before).unwrap();
            assert_eq!(frame.data(), full.data(), "partial paints refresh all uses of the key");
        }
    }
}

#[test]
fn malformed_requests_reply_with_errors_without_replacing_valid_pixels() {
    let mut h = Harness::new();
    upload(&mut h, "memory:valid", 1, 1, &[10, 20, 30, 255]);
    let original = h.rt.images.get(Path::new("memory:valid")).unwrap();
    let valid = json!({"op":"cache_bitmap","key":"memory:valid","width":1,"height":1,"rgba":STANDARD.encode([10, 20, 30, 255])});
    for (field, value) in [
        ("key", json!("file.png")), ("key", json!("memory:")), ("key", json!("memory:a/b")), ("key", json!("memory:a\\b")),
        ("key", json!("memory:a\nb")), ("key", json!(format!("memory:{}", "a".repeat(200)))),
        ("width", json!(0)), ("width", json!(-1)), ("width", json!(1.5)), ("width", json!(u64::MAX)),
        ("height", json!(null)), ("height", json!(16_385)), ("rgba", json!("invalid!")),
        ("rgba", json!(STANDARD.encode([1, 2, 3, 4, 5]))), ("rgba", json!(null)),
    ] {
        let mut request = valid.clone();
        request[field] = value;
        let (_, reply) = h.req(request);
        assert!(reply["error"].is_string(), "{reply}");
        assert!(Rc::ptr_eq(&original, &h.rt.images.get(Path::new("memory:valid")).unwrap()));
        assert_eq!(h.rt.images.len(), 1);
    }
    let (_, reply) = h.req(json!({"op":"cache_bitmap","key":"memory:huge","width":16_384,"height":16_384,"rgba":""}));
    assert!(reply["error"].as_str().unwrap().contains("64 MiB"));
    for op in ["release_bitmap", "bitmap_size"] {
        assert!(h.req(json!({"op":op,"key":"file.png"})).1["error"].is_string());
    }
    assert_eq!(h.value(json!({"op":"ping"})), json!("pong"));
}

#[test]
fn original_and_entry_budgets_reject_atomically_and_release_recovers_capacity() {
    let mut images = ImageCache::default();
    let rgba = STANDARD.encode(vec![255; limits::MAX_BITMAP_BYTES]);
    images.insert_rgba("memory:one", 4096, 4096, &rgba).unwrap();
    images.insert_rgba("memory:two", 4096, 4096, &rgba).unwrap();
    let tiny = STANDARD.encode([0, 0, 0, 255]);
    assert!(images.insert_rgba("memory:extra", 1, 1, &tiny).unwrap_err().contains("128 MiB"));
    images.insert_rgba("memory:one", 4096, 4096, &rgba).unwrap(); // same-sized replacement at capacity
    images.release_bitmap("memory:two").unwrap();
    images.insert_rgba("memory:extra", 4096, 4096, &rgba).unwrap();
    images.release_bitmap("memory:one").unwrap();
    images.release_bitmap("memory:extra").unwrap();
    assert!(images.is_empty());
    for n in 0..limits::MAX_BITMAP_ENTRIES {
        images.insert_rgba(&format!("memory:{n}"), 1, 1, &tiny).unwrap();
    }
    assert!(images.insert_rgba("memory:extra", 1, 1, &tiny).unwrap_err().contains("1024 keys"));
    images.insert_rgba("memory:0", 1, 1, &tiny).unwrap();
    images.release_bitmap("memory:0").unwrap();
    images.insert_rgba("memory:extra", 1, 1, &tiny).unwrap();
}

#[test]
fn resized_copies_have_a_separate_budget_and_are_discarded_when_unshown() {
    let mut images = ImageCache::default();
    let rgba = STANDARD.encode([255, 0, 0, 255]);
    images.insert_rgba("memory:one", 1, 1, &rgba).unwrap();
    images.insert_rgba("memory:two", 1, 1, &rgba).unwrap();
    assert!(images.at_size(Path::new("memory:one"), 4096, 4096).is_some());
    assert!(images.at_size(Path::new("memory:two"), 20, 20).is_none(), "budget prevents another cached resize");
    assert!(images.get(Path::new("memory:two")).is_some(), "uncached resizes can still draw the original");
    images.retain(|path| path == Path::new("memory:two"));
    assert_eq!(images.len(), 2, "unshown originals remain caller-owned");
    assert!(images.at_size(Path::new("memory:two"), 20, 20).is_some());
    images.release_bitmap("memory:two").unwrap();
    for side in [20, 30, 40, 50, 60] {
        assert!(images.at_size(Path::new("memory:one"), side, side).is_some());
    }
    images.insert_rgba("memory:one", 1, 1, &rgba).unwrap();
    assert!(images.at_size(Path::new("memory:one"), 4096, 4096).is_some(), "replacement frees all previous sizes");
    images.release_bitmap("memory:one").unwrap();
    assert!(images.get(Path::new("memory:one")).is_none());
    assert!(images.is_empty());
}
