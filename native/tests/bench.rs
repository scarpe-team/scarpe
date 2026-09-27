//! Rust-side timings with no Ruby and no window in the way (native/PERF.md).
//!   cargo test --release --test bench -- --ignored --nocapture --test-threads 1
//!
//! Each bench feeds NDJSON through the real protocol path, keeps a window's frame at 2x the way
//! window.rs does (paint::damage), and prints where a frame's time goes.

mod common;

use common::{app, create, Harness};
use scarpe_native::paint::damage::{FrameMemory, Repaint};
use serde_json::json;
use std::time::{Duration, Instant};
use tiny_skia::Pixmap;

const APP: i64 = 1;
const SCALE: f32 = 2.0;

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
    let nodes = h.rt.doc.len();
    let mut pm = Pixmap::new(960, 840).unwrap();
    let t = Instant::now();
    h.rt.render(APP, &mut pm, SCALE);
    let cold_paint = t.elapsed();
    let n = 50;
    let (mut layout_total, mut paint_total) = (Duration::ZERO, Duration::ZERO);
    let mut worst = Duration::ZERO;
    for _ in 0..n {
        h.rt.invalidate();
        let t0 = Instant::now();
        h.rt.ensure_layout(APP);
        let t1 = Instant::now();
        h.rt.render(APP, &mut pm, SCALE);
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
    assert!(layout + paint < Duration::from_millis(5), "layout + paint should stay under 5 ms");
}

/// Where one frame's time went, averaged.
#[derive(Default)]
struct FrameTimes {
    frames: u32,
    feed: Duration,
    layout: Duration,
    paint: Duration,
    repainted: u64,
}

impl FrameTimes {
    fn report(&self, what: &str, frame_pixels: u64) {
        let n = self.frames.max(1);
        println!(
            "{what}: per frame parse+apply {:?}, layout {:?}, paint@2x {:?} = {:?}; repainted {:.1}% of the frame",
            self.feed / n,
            self.layout / n,
            self.paint / n,
            (self.feed + self.layout + self.paint) / n,
            100.0 * self.repainted as f64 / (frame_pixels * n as u64) as f64
        );
    }

    fn per_frame(&self) -> Duration {
        (self.feed + self.layout + self.paint) / self.frames.max(1)
    }
}

/// A window's frame, kept between repaints.
struct Frame {
    pm: Pixmap,
    memory: FrameMemory,
}

impl Frame {
    fn open(h: &mut Harness) -> Frame {
        let (w, hgt) = h.rt.views[&APP].size;
        let mut frame = Frame { pm: Pixmap::new((w * SCALE) as u32, (hgt * SCALE) as u32).unwrap(), memory: FrameMemory::default() };
        frame.repaint(h);
        frame
    }

    fn repaint(&mut self, h: &mut Harness) -> Repaint {
        h.rt.repaint(APP, &mut self.pm, SCALE, &mut self.memory)
    }

    fn pixels(&self) -> u64 {
        self.pm.width() as u64 * self.pm.height() as u64
    }
}

/// One frame: its NDJSON fed and applied, then the flush that lays it out, then a repaint.
fn frame(h: &mut Harness, window: &mut Frame, lines: &str, times: &mut FrameTimes) {
    let t0 = Instant::now();
    h.feed(lines);
    let t1 = Instant::now();
    h.feed("{\"t\":\"flush\"}\n");
    let t2 = Instant::now();
    let plan = window.repaint(h);
    let t3 = Instant::now();
    times.frames += 1;
    times.feed += t1 - t0;
    times.layout += t2 - t1;
    times.paint += t3 - t2;
    times.repainted += plan.pixels((window.pm.width(), window.pm.height()));
}

/// examples/native/bench/ovals.rb as the wire carries it: 500 translucent ovals, then every
/// frame 1000 prop changes (Lacci's move sends left and top apart) and a flush.
#[test]
#[ignore]
fn five_hundred_moving_ovals() {
    let mut h = Harness::new();
    let mut body = vec![create(3, "Background", 2, json!({"fill": {"rgba": [251, 251, 253, 255]}}))];
    let mut seed = 500u64;
    let mut rand = |n: u64| {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (seed >> 33) % n
    };
    let dots: Vec<(i64, f64, f64, f64, f64)> = (0..500)
        .map(|i| (10 + i, rand(600) as f64, rand(500) as f64, rand(600) as f64 / 100.0 - 3.0, rand(600) as f64 / 100.0 - 3.0))
        .collect();
    for &(id, x, y, _, _) in &dots {
        let size = 8 + rand(17) as i64;
        body.push(create(id, "Oval", 2, json!({"left": x, "top": y, "width": size, "height": size,
            "fill": {"rgba": [40 + rand(180), 40 + rand(180), 40 + rand(180), 178]}, "stroke": {"rgba": [0, 0, 0, 0]}})));
    }
    h.feed(&app(600, 500, &body));
    let mut window = Frame::open(&mut h);
    let bounce = |v: f64, max: f64| {
        let v = v.rem_euclid(2.0 * max);
        if v > max { 2.0 * max - v } else { v }
    };
    let mut times = FrameTimes::default();
    for n in 1..=120 {
        let mut lines = String::new();
        for &(id, x, y, vx, vy) in &dots {
            let (nx, ny) = (bounce(x + vx * n as f64, 580.0).round(), bounce(y + vy * n as f64, 480.0).round());
            lines.push_str(&format!("{}\n", json!({"t": "props", "id": id, "props": {"left": nx}})));
            lines.push_str(&format!("{}\n", json!({"t": "props", "id": id, "props": {"top": ny}})));
        }
        frame(&mut h, &mut window, &lines, &mut times);
    }
    times.report("500 moving ovals", window.pixels());
    assert!(times.per_frame() < Duration::from_millis(16), "a frame should fit in 60 fps");
}

/// examples/native/bench/backdrop.rb without the image: a busy still window and one ball.
#[test]
#[ignore]
fn one_ball_over_a_still_window() {
    let mut h = Harness::new();
    let mut body = vec![
        create(3, "Background", 2, json!({"fill": {"gradient": [{"rgba": [250, 240, 200, 255]}, {"rgba": [180, 210, 250, 255]}], "angle": 0}})),
        create(4, "Stack", 2, json!({"margin": 20})),
    ];
    for i in 0..30 {
        body.push(create(10 + i, "Para", 4, json!({"text_items": [format!("Line {i} of a page of text that stays where it is while the ball moves.")]})));
    }
    body.push(create(99, "Oval", 2, json!({"left": 0, "top": 400, "width": 24, "height": 24, "fill": {"rgba": [220, 30, 30, 255]}})));
    h.feed(&app(600, 500, &body));
    let mut window = Frame::open(&mut h);
    let mut times = FrameTimes::default();
    for n in 1..=120 {
        let x = (n * 4) % 1100;
        let props = json!({"t": "props", "id": 99, "props": {"left": if x > 550 { 1100 - x } else { x }, "top": 400}});
        frame(&mut h, &mut window, &format!("{props}\n"), &mut times);
    }
    times.report("one ball over a still window", window.pixels());
    assert!(times.per_frame() < Duration::from_millis(4), "only the ball's rects are painted");
}

/// examples/native/bench/rebuild.rb's native side: 2000 paras in a stack, destroyed and created
/// again with new words (so every one is shaped again).
#[test]
#[ignore]
fn clearing_and_rebuilding_2000_paras() {
    let mut h = Harness::new();
    let paras = |round: usize, first: i64| -> String {
        (0..2000)
            .map(|i| {
                let text = format!("Round {round}, line {i}: the quick brown fox jumps over the lazy dog");
                format!("{}\n", create(first + i, "Para", 4, json!({"text_items": [text]})))
            })
            .collect()
    };
    h.feed(&app(600, 500, &[create(4, "Stack", 2, json!({}))]));
    let mut window = Frame::open(&mut h);
    let mut build = FrameTimes::default();
    frame(&mut h, &mut window, &paras(0, 1000), &mut build);
    let mut rebuild = FrameTimes::default();
    let rounds = std::env::var("REBUILD_ROUNDS").ok().and_then(|r| r.parse().ok()).unwrap_or(5);
    for round in 1..=rounds {
        let first = 1000 + round as i64 * 10_000;
        let old = first - 10_000;
        let destroys: String = (0..2000).map(|i| format!("{}\n", json!({"t": "destroy", "id": old + i}))).collect();
        frame(&mut h, &mut window, &format!("{destroys}{}", paras(round, first)), &mut rebuild);
    }
    build.report("building 2000 paras", window.pixels());
    rebuild.report("clearing and rebuilding 2000 paras", window.pixels());
}

/// A long document with one small thing moving: every frame lays out all 2000 paras again (their
/// shapes come from the cache) to move one ball.
#[test]
#[ignore]
fn one_ball_over_2000_paras() {
    let mut h = Harness::new();
    let mut body = vec![create(4, "Stack", 2, json!({}))];
    for i in 0..2000 {
        body.push(create(1000 + i, "Para", 4, json!({"text_items": [format!("Line {i}: the quick brown fox jumps over the lazy dog")]})));
    }
    body.push(create(99, "Oval", 2, json!({"left": 0, "top": 100, "width": 24, "height": 24, "fill": {"rgba": [220, 30, 30, 255]}})));
    h.feed(&app(600, 500, &body));
    let mut window = Frame::open(&mut h);
    let mut times = FrameTimes::default();
    for n in 1..=60 {
        let props = json!({"t": "props", "id": 99, "props": {"left": (n * 4) % 550, "top": 100}});
        frame(&mut h, &mut window, &format!("{props}\n"), &mut times);
    }
    times.report("one ball over 2000 paras", window.pixels());
}

/// The same long document with a shape that only changes colour: nothing needs laying out again
/// (runtime.rs, changes_only_looks), so only the shape repaints.
#[test]
#[ignore]
fn one_shape_changing_colour_over_2000_paras() {
    let mut h = Harness::new();
    let mut body = vec![create(4, "Stack", 2, json!({}))];
    for i in 0..2000 {
        body.push(create(1000 + i, "Para", 4, json!({"text_items": [format!("Line {i}: the quick brown fox jumps over the lazy dog")]})));
    }
    body.push(create(99, "Oval", 2, json!({"left": 400, "top": 100, "width": 60, "height": 60, "fill": {"rgba": [220, 30, 30, 255]}})));
    h.feed(&app(600, 500, &body));
    let mut window = Frame::open(&mut h);
    let mut times = FrameTimes::default();
    for n in 1..=60 {
        let props = json!({"t": "props", "id": 99, "props": {"fill": {"rgba": [(n * 4) % 256, 30, 200, 255]}}});
        frame(&mut h, &mut window, &format!("{props}\n"), &mut times);
    }
    times.report("one shape changing colour over 2000 paras", window.pixels());
}

/// The showcase starfield's first nebula (showcase lane, wave 4): 72 large translucent circles
/// under 420 stars, six stars twinkling a frame. Each damaged rect paints the nebula again
/// clipped small, which the lane measured as dearer than one whole repaint; on the merged tree
/// it is not (native/PERF.md, wave 5). Run it with SCARPE_NATIVE_DAMAGE=off to compare.
#[test]
#[ignore]
fn stars_twinkling_over_a_nebula() {
    let mut h = Harness::new();
    let mut seed = 72u64;
    let mut rand = |n: u64| {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (seed >> 33) % n
    };
    let mut body = vec![create(3, "Background", 2, json!({"fill": {"rgba": [8, 10, 30, 255]}}))];
    for i in 0..72 {
        let r = 100 + rand(200) as i64;
        body.push(create(10 + i, "Oval", 2, json!({"left": rand(800) as i64 - r, "top": rand(500) as i64 - r, "width": 2 * r,
            "fill": {"rgba": [60 + rand(120), 40, 120 + rand(120), 18]}, "stroke": {"rgba": [0, 0, 0, 0]}})));
    }
    let stars: Vec<i64> = (0..420).map(|i| 1000 + i).collect();
    for &id in &stars {
        body.push(create(id, "Oval", 2, json!({"left": rand(800), "top": rand(500), "width": 2 + rand(3),
            "fill": {"rgba": [255, 255, 255, 200]}, "stroke": {"rgba": [0, 0, 0, 0]}})));
    }
    h.feed(&app(800, 500, &body));
    let mut window = Frame::open(&mut h);
    let mut times = FrameTimes::default();
    for n in 0..120u64 {
        let lines: String = (0..6)
            .map(|k| {
                let id = stars[((n * 37 + k * 71) % 420) as usize];
                format!("{}\n", json!({"t": "props", "id": id, "props": {"fill": {"rgba": [255, 255, 200 + n % 50, 120 + n * 7 % 130]}}}))
            })
            .collect();
        frame(&mut h, &mut window, &lines, &mut times);
    }
    times.report("stars twinkling over a nebula", window.pixels());
}

/// What listening costs a window (src/a11y.rs): after each frame it builds the app's tree and
/// sends the screen reader what changed. A window nobody reads aloud builds nothing.
#[test]
#[ignore]
fn a_screen_reader_listening_to_2000_paras() {
    use scarpe_native::a11y::Mirror;
    let mut h = Harness::new();
    let mut body: Vec<_> = (0..2000).map(|i| create(3 + i, "Para", 2, json!({"text_items": [format!("Paragraph {i} of a long document")]}))).collect();
    body.push(create(2003, "Check", 2, json!({})));
    h.feed(&app(600, 500, &body));
    h.rt.ensure_layout(APP);
    let mut mirror = Mirror::default();
    let t = Instant::now();
    let first = mirror.update(h.rt.a11y_tree(APP, SCALE));
    let whole = t.elapsed();
    let rounds = 20;
    let (mut spent, mut sent) = (Duration::ZERO, 0);
    for i in 0..rounds {
        h.feed(&format!("{}\n{}\n", json!({"t": "props", "id": 2003, "props": {"checked": i % 2 == 0}}), json!({"t": "flush"})));
        let t = Instant::now();
        sent += mirror.update(h.rt.a11y_tree(APP, SCALE)).nodes.len();
        spent += t.elapsed();
    }
    println!(
        "a screen reader over 2000 paras: the whole tree ({} nodes) {whole:?}; a check toggling, per frame {:?}, {} node(s) sent",
        first.nodes.len(),
        spent / rounds,
        sent / rounds as usize
    );
}
