//! Golden PNGs: each fixture scene rendered at 2x with bundled fonts must match its picture
//! in tests/golden. What may differ is a share of the picture's ink (the pixels unlike its
//! background), not of its canvas, so a frame that loses its words or a span's colour fails
//! while antialiasing that shades an edge a little differently does not.
//!   UPDATE_GOLDEN=1 cargo test --release --test golden   # to accept new pictures

mod common;

use common::Harness;
use image::{Rgba, RgbaImage};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};

/// Renders a fixture scene, then `changes` on top of it.
fn render_with(scene: &str, changes: &[Value]) -> RgbaImage {
    let mut h = Harness::new();
    h.scene(scene);
    h.feed(&changes.iter().map(|c| format!("{c}\n")).collect::<String>());
    // Tests render the same scene at once: each picture gets a file of its own.
    static RENDERS: AtomicUsize = AtomicUsize::new(0);
    let n = RENDERS.fetch_add(1, Ordering::Relaxed);
    let path = std::env::temp_dir().join(format!("scarpe-native-golden-{scene}-{}-{n}.png", std::process::id()));
    let shot = h.value(json!({"op": "snapshot", "path": path.to_string_lossy(), "scale": 2}));
    assert!(shot["w"].as_u64().unwrap() > 0);
    let img = image::open(&path).expect("snapshot png").to_rgba8();
    let _ = std::fs::remove_file(&path);
    img
}

fn golden(scene: &str) -> RgbaImage {
    let path = format!("tests/golden/{scene}.png");
    image::open(&path).unwrap_or_else(|_| panic!("missing {path}; run with UPDATE_GOLDEN=1")).to_rgba8()
}

/// Two pixels a person would tell apart: a channel more than 24 levels off.
fn apart(a: &Rgba<u8>, b: &Rgba<u8>) -> bool {
    a.0.iter().zip(b.0.iter()).any(|(x, y)| x.abs_diff(*y) > 24)
}

/// Where `actual` parts from `golden` beyond antialiasing, if it does. At most 2% of the
/// golden's ink may differ, and never more than 64 pixels (a three-letter word at 2x is
/// about 270) nor fewer than 8; the ink itself may grow or shrink by at most 3%.
fn mismatch(actual: &RgbaImage, golden: &RgbaImage) -> Option<String> {
    if actual.dimensions() != golden.dimensions() {
        return Some(format!("size {:?} is not {:?}", actual.dimensions(), golden.dimensions()));
    }
    let mut counts: HashMap<[u8; 4], usize> = HashMap::new();
    golden.pixels().for_each(|p| *counts.entry(p.0).or_default() += 1);
    let background = Rgba(counts.into_iter().max_by_key(|(_, n)| *n).map(|(p, _)| p).unwrap_or([255; 4]));
    let ink = |img: &RgbaImage| img.pixels().filter(|p| apart(p, &background)).count();
    let (inked, inked_now) = (ink(golden), ink(actual));
    let off = actual.pixels().zip(golden.pixels()).filter(|(a, b)| apart(a, b)).count();
    let budget = (inked / 50).clamp(8, 64);
    if off > budget {
        return Some(format!("{off} pixels differ, over the {budget} allowed ({inked} inked)"));
    }
    if inked_now.abs_diff(inked) > (inked / 33).max(8) {
        return Some(format!("{inked_now} pixels inked instead of {inked}"));
    }
    None
}

fn check(scene: &str) {
    let actual = render_with(scene, &[]);
    if std::env::var_os("UPDATE_GOLDEN").is_some() {
        actual.save(format!("tests/golden/{scene}.png")).expect("write golden");
        return;
    }
    if let Some(problem) = mismatch(&actual, &golden(scene)) {
        // Keep what this machine drew, so a failure elsewhere (CI uploads the folder) can be seen.
        let kept = std::path::Path::new(env!("CARGO_TARGET_TMPDIR")).join("golden-actual").join(format!("{scene}.png"));
        let saved = std::fs::create_dir_all(kept.parent().unwrap()).is_ok() && actual.save(&kept).is_ok();
        let drawn = if saved { format!("; this run drew {}", kept.display()) } else { String::new() };
        panic!("{scene}: {problem} (tests/golden/{scene}.png{drawn})");
    }
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

// The check itself, against renders broken on purpose. The old budget (0.2% of the canvas,
// 1,612 pixels at 2x) passed both of the first two.

#[test]
fn a_hello_frame_without_its_words_fails() {
    let blank = render_with("hello", &[json!({"t": "props", "id": 3, "props": {"text_items": [""]}}), json!({"t": "flush"})]);
    assert!(mismatch(&blank, &golden("hello")).is_some());
}

#[test]
fn a_red_span_drawn_black_fails() {
    let black = render_with("rich_text", &[json!({"t": "props", "id": 14, "props": {"stroke": {"rgba": [0, 0, 0, 255]}}}), json!({"t": "flush"})]);
    assert!(mismatch(&black, &golden("rich_text")).is_some());
}

/// Antialiasing on another machine shades edges a few levels differently: that still matches.
#[test]
fn shading_a_few_levels_off_still_matches() {
    for scene in ["hello", "rich_text", "art"] {
        let mut shaded = golden(scene);
        for (i, p) in shaded.pixels_mut().enumerate() {
            let nudge = [0i16, 6, -6, 3][i % 4];
            p.0 = p.0.map(|c| (c as i16 + nudge).clamp(0, 255) as u8);
        }
        assert_eq!(mismatch(&shaded, &golden(scene)), None, "{scene}");
    }
}
