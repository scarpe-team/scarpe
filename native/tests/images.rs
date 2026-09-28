//! Image files are read once and kept, but never kept past what is on disk or on screen.

mod common;

use common::{app, create, Harness};
use serde_json::{json, Value};
use tiny_skia::{Color, Pixmap};

/// A scratch directory of this test's own.
fn scratch(name: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("scarpe-native-images-{}-{name}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// Writes a solid PNG `side` px square.
fn png(path: &std::path::Path, side: u32, rgb: [u8; 3]) {
    let mut pm = Pixmap::new(side, side).unwrap();
    pm.fill(Color::from_rgba8(rgb[0], rgb[1], rgb[2], 255));
    pm.save_png(path).unwrap();
}

fn pixel(h: &mut Harness, x: f32, y: f32) -> Value {
    h.value(json!({"op": "pixel", "x": x, "y": y}))
}

fn set_url(h: &mut Harness, id: i64, url: &str) {
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": id, "props": {"url": url}})));
}

/// An app that writes chart.png, shows it, then writes it again and shows it again saw the
/// first picture forever: the cache kept every path's pixels whatever became of the file.
#[test]
fn a_rewritten_file_shows_its_new_pixels() {
    let path = scratch("rewritten").join("chart.png");
    png(&path, 20, [255, 0, 0]);
    let url = path.display().to_string();
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Image", 2, json!({"url": url}))]));
    assert_eq!(pixel(&mut h, 5.0, 5.0), json!([255, 0, 0, 255]));
    png(&path, 30, [0, 0, 255]);
    set_url(&mut h, 3, &url);
    assert_eq!(pixel(&mut h, 5.0, 5.0), json!([0, 0, 255, 255]), "the new picture");
    assert_eq!(h.node(|n| n["id"] == 3)["w"], json!(30.0), "at its new size");
}

/// An image made before its file exists (download, then show) stayed a placeholder: the
/// failed read was kept as the answer for good.
#[test]
fn a_file_that_arrives_late_shows_once_it_is_there() {
    let path = scratch("late").join("later.png");
    let _ = std::fs::remove_file(&path);
    let url = path.display().to_string();
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Image", 2, json!({"url": url, "width": 20, "height": 20}))]));
    assert_ne!(pixel(&mut h, 10.0, 10.0), json!([0, 128, 0, 255]), "nothing to show yet");
    png(&path, 20, [0, 128, 0]);
    set_url(&mut h, 3, &url);
    assert_eq!(pixel(&mut h, 10.0, 10.0), json!([0, 128, 0, 255]));
}

/// A slideshow kept every picture it had ever shown decoded in memory.
#[test]
fn pictures_nothing_shows_any_more_are_let_go() {
    let dir = scratch("slides");
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[]));
    for i in 0..5 {
        let path = dir.join(format!("slide{i}.png"));
        png(&path, 10, [i * 40, 0, 0]);
        let slide = 10 + i as i64;
        h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", create(slide, "Image", 2, json!({"url": path.display().to_string()}))));
        pixel(&mut h, 1.0, 1.0);
        h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "destroy", "id": slide})));
    }
    assert!(h.rt.images.len() <= 1, "{} pictures kept for no image", h.rt.images.len());
}

/// A picture shown bigger or smaller than its pixels is resampled once for the size it is shown
/// at, and that copy is kept, not resampled on every paint: a 211 px glow stretched to 422
/// points at 2x cost 21 ms a paint, where the same glow drawn from an 844 px file cost 4
/// (_repros/night_light_3.rb). At its own size a picture needs no copy at all.
#[test]
fn a_stretched_picture_is_resampled_once_not_every_paint() {
    let path = scratch("stretched").join("glow.png");
    png(&path, 20, [255, 0, 0]);
    let url = path.display().to_string();
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[
        create(3, "Image", 2, json!({"url": url, "left": 0, "top": 0, "width": 80, "height": 80})),
        create(4, "Oval", 2, json!({"left": 150, "top": 10, "width": 10})),
    ]));
    let resampled = |h: &Harness| h.rt.stats.counter("images_resampled");
    for x in [150, 160, 170] {
        h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 4, "props": {"left": x}})));
        assert_eq!(pixel(&mut h, 40.0, 40.0), json!([255, 0, 0, 255]));
    }
    assert_eq!(resampled(&h), 1, "three paints, one copy at 80 px");

    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 3, "props": {"width": 20, "height": 20}})));
    assert_eq!(pixel(&mut h, 10.0, 10.0), json!([255, 0, 0, 255]));
    assert_eq!(resampled(&h), 1, "at its own size it is drawn as it is");

    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", json!({"t": "props", "id": 3, "props": {"width": 60, "height": 30}})));
    pixel(&mut h, 30.0, 15.0);
    pixel(&mut h, 30.0, 15.0);
    assert_eq!(resampled(&h), 2, "a new size makes one more copy");
}
