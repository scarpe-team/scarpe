//! Golden PNGs: each fixture scene rendered at 2x with bundled fonts must match
//! its picture in tests/golden within a small tolerance.
//!   UPDATE_GOLDEN=1 cargo test --release --test golden   # to accept new pictures

mod common;

use common::Harness;
use serde_json::json;

fn render(scene: &str) -> image::RgbaImage {
    let mut h = Harness::new();
    h.scene(scene);
    let path = std::env::temp_dir().join(format!("scarpe-native-golden-{scene}-{}.png", std::process::id()));
    let shot = h.value(json!({"op": "snapshot", "path": path.to_string_lossy(), "scale": 2}));
    assert!(shot["w"].as_u64().unwrap() > 0);
    let img = image::open(&path).expect("snapshot png").to_rgba8();
    let _ = std::fs::remove_file(&path);
    img
}

fn check(scene: &str) {
    let actual = render(scene);
    let golden_path = format!("tests/golden/{scene}.png");
    if std::env::var_os("UPDATE_GOLDEN").is_some() {
        actual.save(&golden_path).expect("write golden");
        return;
    }
    let golden = image::open(&golden_path).unwrap_or_else(|_| panic!("missing {golden_path}; run with UPDATE_GOLDEN=1")).to_rgba8();
    assert_eq!(actual.dimensions(), golden.dimensions(), "{scene}: size changed");
    let differing = actual
        .pixels()
        .zip(golden.pixels())
        .filter(|(a, b)| a.0.iter().zip(b.0.iter()).any(|(x, y)| x.abs_diff(*y) > 24))
        .count();
    let total = (actual.width() * actual.height()) as usize;
    assert!(
        differing * 1000 <= total * 2,
        "{scene}: {differing} of {total} pixels differ from {golden_path} (tolerance 0.2%)"
    );
}

#[test]
fn hello() {
    check("hello");
}

#[test]
fn layout() {
    check("layout");
}

#[test]
fn art() {
    check("art");
}

#[test]
fn widgets() {
    check("widgets");
}

#[test]
fn rich_text() {
    check("rich_text");
}

#[test]
fn scroll() {
    check("scroll");
}
