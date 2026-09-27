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
