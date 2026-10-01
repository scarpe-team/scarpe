//! Partial repaints (paint::damage) must leave exactly the pixels a full paint would. Every
//! test keeps a window's frame the way window.rs does, changes something, repaints what
//! changed, and compares the frame with a fresh full paint, pixel for pixel. The plans are
//! checked too, so a change that should be cheap stays cheap.

mod common;

use common::{app, create, Harness};
use scarpe_native::paint::damage::{FrameMemory, Repaint};
use serde_json::{json, Value};
use tiny_skia::Pixmap;

const APP: i64 = 1;

/// A window's last frame and what it remembers about it.
struct Window {
    frame: Pixmap,
    memory: FrameMemory,
    scale: f32,
    /// The previous frame painted in full, to catch pixels a partial repaint left stale.
    full_before: Pixmap,
}

impl Window {
    fn open(h: &mut Harness, scale: f32) -> Window {
        let (w, hgt) = h.rt.views[&APP].size;
        let frame = Pixmap::new((w * scale).ceil() as u32, (hgt * scale).ceil() as u32).unwrap();
        let full_before = frame.clone();
        let mut window = Window { frame, memory: FrameMemory::default(), scale, full_before };
        assert_eq!(window.repaint(h), Repaint::Everything, "the first frame is painted whole");
        window
    }

    /// Repaints what changed, then checks it against full paints (paint::damage::verify).
    fn repaint(&mut self, h: &mut Harness) -> Repaint {
        let plan = h.rt.repaint(APP, &mut self.frame, self.scale, &mut self.memory);
        let full = h.rt.picture(APP, self.scale).unwrap();
        if full.width() != self.full_before.width() || full.height() != self.full_before.height() {
            self.full_before = full.clone();
        }
        if let Err(problem) = h.rt.verify_repaint(APP, &plan, &self.frame, self.scale, &full, &self.full_before) {
            let dir = std::env::temp_dir();
            let (partial, whole) = (dir.join("damage-partial.png"), dir.join("damage-full.png"));
            self.frame.save_png(&partial).unwrap();
            full.save_png(&whole).unwrap();
            panic!("{problem}; see {} and {}", partial.display(), whole.display());
        }
        self.full_before = full;
        plan
    }

    fn pixels(&self) -> u64 {
        self.frame.width() as u64 * self.frame.height() as u64
    }
}

fn props(h: &mut Harness, id: i64, changes: Value) {
    h.feed(&format!("{}\n{}\n", json!({"t": "props", "id": id, "props": changes}), json!({"t": "flush"})));
}

fn feed(h: &mut Harness, lines: &[Value]) {
    let mut text: String = lines.iter().map(|l| format!("{l}\n")).collect();
    text.push_str("{\"t\":\"flush\"}\n");
    h.feed(&text);
}

fn mouse(h: &mut Harness, action: &str, x: f32, y: f32) {
    h.value(json!({"op": "mouse", "action": action, "x": x, "y": y}));
}

fn partial(plan: &Repaint, window: &Window, most: f64) -> bool {
    matches!(plan, Repaint::Rects(_)) && (plan.pixels((window.frame.width(), window.frame.height())) as f64) < most * window.pixels() as f64
}

/// Gradient backdrop, a card of text, translucent ovals, a button and a field.
fn busy_scene(h: &mut Harness) {
    let body = vec![
        create(3, "Background", 2, json!({"fill": {"gradient": [{"rgba": [250, 240, 200, 255]}, {"rgba": [180, 210, 250, 255]}], "angle": 0}})),
        create(4, "Stack", 2, json!({"margin": 16, "width": 300})),
        create(5, "Background", 4, json!({"fill": {"rgba": [255, 255, 255, 210]}, "curve": 10})),
        create(6, "Border", 4, json!({"stroke": {"rgba": [40, 40, 90, 255]}, "strokewidth": 2, "curve": 10})),
        create(7, "Title", 4, json!({"text_items": ["Damage"]})),
        create(8, "Para", 4, json!({"text_items": ["A para that wraps onto a second line inside the card, to be sure."]})),
        create(9, "Button", 4, json!({"text": "Press"})),
        create(10, "EditLine", 4, json!({"text": "field", "width": 200})),
        create(11, "Oval", 2, json!({"left": 330, "top": 60, "width": 80, "height": 80, "fill": {"rgba": [220, 40, 40, 150]}, "stroke": {"rgba": [0, 0, 0, 255]}, "strokewidth": 3})),
        create(12, "Oval", 2, json!({"left": 360, "top": 90, "width": 60, "height": 60, "fill": {"rgba": [40, 40, 220, 150]}})),
        create(13, "Rect", 2, json!({"left": 340, "top": 200, "width": 90, "height": 40, "curve": 8, "fill": {"rgba": [40, 160, 60, 200]}})),
        create(14, "Oval", 2, json!({"left": 380, "top": 110, "width": 30, "height": 30, "fill": {"rgba": [250, 200, 0, 180]}})),
    ];
    h.feed(&app(480, 320, &body));
}

#[test]
fn nothing_changed_repaints_nothing() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 2.0);
    assert_eq!(window.repaint(&mut h), Repaint::Nothing);
    feed(&mut h, &[]);
    assert_eq!(window.repaint(&mut h), Repaint::Nothing, "a flush that changed nothing");
}

#[test]
fn moving_a_shape_repaints_where_it_was_and_where_it_is() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 2.0);
    for (x, y) in [(334, 62), (345, 70), (300, 150), (20, 250), (330, 60)] {
        props(&mut h, 12, json!({"left": x, "top": y}));
        let plan = window.repaint(&mut h);
        assert!(partial(&plan, &window, 0.2), "{plan:?}");
    }
}

#[test]
fn a_shape_under_and_over_others_keeps_their_blending() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 1.0);
    // The yellow oval sits over the blue one, which sits over the red one.
    props(&mut h, 12, json!({"left": 350, "top": 80}));
    assert!(partial(&window.repaint(&mut h), &window, 0.3));
    props(&mut h, 11, json!({"fill": {"rgba": [0, 200, 200, 90]}}));
    assert!(partial(&window.repaint(&mut h), &window, 0.3), "a new colour alone repaints the box");
}

#[test]
fn text_changes_repaint_the_text() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 2.0);
    props(&mut h, 7, json!({"text_items": ["Damaged"]}));
    assert!(partial(&window.repaint(&mut h), &window, 0.3));
    // Longer text wraps to more lines and pushes the button and field down.
    props(&mut h, 8, json!({"text_items": ["Now a much longer para, long enough to need a third line and push everything under it further down the card."]}));
    window.repaint(&mut h);
    props(&mut h, 8, json!({"text_items": ["Short."]}));
    window.repaint(&mut h);
}

#[test]
fn text_spilling_out_of_its_box_is_repainted_where_it_reaches() {
    let mut h = Harness::new();
    let body = vec![
        create(3, "Para", 2, json!({"text_items": ["Three lines of text in a para only ten pixels high, so most of it spills below."], "width": 150, "height": 10})),
        create(4, "Para", 2, json!({"text_items": ["A neighbour"]})),
    ];
    h.feed(&app(320, 200, &body));
    let mut window = Window::open(&mut h, 2.0);
    props(&mut h, 3, json!({"stroke": {"rgba": [200, 0, 0, 255]}}));
    window.repaint(&mut h);
    props(&mut h, 3, json!({"text_items": ["Different words now, still spilling well below the ten pixel box it sits in."]}));
    window.repaint(&mut h);
}

#[test]
fn created_destroyed_and_hidden_nodes_leave_no_trace() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 2.0);
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", create(20, "Star", 2, json!({"left": 60, "top": 260, "points": 5, "outer": 30, "inner": 12, "fill": {"rgba": [255, 120, 0, 255]}}))));
    assert!(partial(&window.repaint(&mut h), &window, 0.2));
    feed(&mut h, &[json!({"t": "destroy", "id": 13})]);
    assert!(partial(&window.repaint(&mut h), &window, 0.2));
    props(&mut h, 14, json!({"hidden": true}));
    assert!(partial(&window.repaint(&mut h), &window, 0.2));
    props(&mut h, 14, json!({"hidden": false}));
    window.repaint(&mut h);
    feed(&mut h, &[json!({"t": "destroy", "id": 4})]);
    window.repaint(&mut h);
}

#[test]
fn hovering_and_pressing_a_button_repaints_the_button() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 2.0);
    let button = h.node(|n| n["kind"] == "Button");
    let (x, y) = (button["x"].as_f64().unwrap() as f32 + 10.0, button["y"].as_f64().unwrap() as f32 + 10.0);
    mouse(&mut h, "move", x, y);
    assert!(partial(&window.repaint(&mut h), &window, 0.2), "hover");
    mouse(&mut h, "down", x, y);
    assert!(partial(&window.repaint(&mut h), &window, 0.2), "press");
    mouse(&mut h, "up", x, y);
    window.repaint(&mut h);
    mouse(&mut h, "move", 5.0, 300.0);
    assert!(partial(&window.repaint(&mut h), &window, 0.2), "leave");
}

#[test]
fn typing_into_a_field_repaints_the_field() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 2.0);
    h.value(json!({"op": "click", "target": {"id": 10}}));
    window.repaint(&mut h);
    for key in ["a", "b", "left", "shift_left", "backspace", "end"] {
        h.value(json!({"op": "key", "key": key}));
        assert!(partial(&window.repaint(&mut h), &window, 0.2), "after {key}");
    }
    h.value(json!({"op": "type", "text": " and more text than the field can show at once"}));
    window.repaint(&mut h);
    // Lacci echoes the text back; the field keeps its caret.
    props(&mut h, 10, json!({"text": "echoed"}));
    window.repaint(&mut h);
    h.value(json!({"op": "key", "key": "tab"}));
    window.repaint(&mut h);
}

#[test]
fn hovering_a_link_recolours_only_its_para() {
    let mut h = Harness::new();
    h.scene("rich_text");
    let mut window = Window::open(&mut h, 2.0);
    let link = h.node(|n| n["kind"] == "Link");
    let (x, y) = (link["x"].as_f64().unwrap() as f32 + 3.0, link["y"].as_f64().unwrap() as f32 + 5.0);
    mouse(&mut h, "move", x, y);
    assert!(partial(&window.repaint(&mut h), &window, 0.5));
    mouse(&mut h, "move", 1.0, 1.0);
    window.repaint(&mut h);
}

#[test]
fn widgets_and_their_popup() {
    let mut h = Harness::new();
    h.scene("widgets");
    let mut window = Window::open(&mut h, 2.0);
    let list = h.id_of_kind("ListBox");
    h.value(json!({"op": "click", "target": {"id": list}}));
    assert_eq!(window.repaint(&mut h), Repaint::Everything, "a popup draws over everything");
    mouse(&mut h, "move", 5.0, 5.0);
    assert_eq!(window.repaint(&mut h), Repaint::Everything);
    h.value(json!({"op": "key", "key": "escape"}));
    assert_eq!(window.repaint(&mut h), Repaint::Everything, "and once more as it goes");
    let check = h.id_of_kind("Check");
    props(&mut h, check, json!({"checked": true}));
    assert!(partial(&window.repaint(&mut h), &window, 0.2));
}

#[test]
fn scrolling_repaints_everything() {
    let mut h = Harness::new();
    h.scene("scroll");
    let mut window = Window::open(&mut h, 1.0);
    h.value(json!({"op": "wheel", "dy": 120, "x": 100, "y": 100}));
    assert_eq!(window.repaint(&mut h), Repaint::Everything);
    h.value(json!({"op": "wheel", "dy": -60, "x": 100, "y": 100}));
    assert_eq!(window.repaint(&mut h), Repaint::Everything);
}

/// Turned, scaled or skewed art repaints the box its transform turns it into, grown by how
/// far its stroke and points can reach once stretched. Any transform used to repaint the whole
/// window, so one star turned once made every later twinkle a full repaint
/// (_repros/night_light_2.rb).
#[test]
fn turned_scaled_and_skewed_art_repaints_in_part() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    props(&mut h, 13, json!({"draw_context": {"rotate": 30}}));
    let mut window = Window::open(&mut h, 2.0);
    props(&mut h, 13, json!({"left": 300}));
    assert!(partial(&window.repaint(&mut h), &window, 0.3), "a turned rect moving");
    props(&mut h, 13, json!({"fill": {"rgba": [200, 60, 160, 220]}, "strokewidth": 6, "stroke": {"rgba": [0, 0, 0, 255]}}));
    assert!(partial(&window.repaint(&mut h), &window, 0.3), "a turned rect changing colour, with a wide stroke");
    props(&mut h, 13, json!({"draw_context": {"rotate": 75, "scale": [1.6, 0.7], "skew": [20, 5], "transform": "center"}}));
    assert!(partial(&window.repaint(&mut h), &window, 0.4), "turned, scaled and skewed about its centre");
    props(&mut h, 12, json!({"left": 300}));
    assert!(partial(&window.repaint(&mut h), &window, 0.3), "untransformed art stays cheap, and the transformed rect still shows through");
    props(&mut h, 13, json!({"draw_context": {"scale": [30, 30]}}));
    assert_eq!(window.repaint(&mut h), Repaint::Everything, "scaled past the window, it is cheaper to paint it all");

    feed(&mut h, &[create(30, "Star", 2, json!({"left": 120, "top": 270, "points": 5, "outer": 12, "inner": 5.4, "draw_context": {"rotate": 20, "transform": "center"}}))]);
    window.repaint(&mut h);
    for alpha in [120, 250, 60] {
        props(&mut h, 30, json!({"fill": {"rgba": [255, 244, 204, alpha]}}));
        let plan = window.repaint(&mut h);
        assert!(partial(&plan, &window, 0.02), "a turned star twinkling repaints only the star: {plan:?}");
    }
}

/// More scattered changes than MAX_RECTS: twelve 8 px dots drifting far apart (fireflies,
/// confetti, fish). They were joined into one bounding box across the window, which plan() then
/// painted whole (_repros/night_light_1.rb); now the nearest are joined until eight rects remain.
#[test]
fn many_small_things_moving_far_apart_repaint_in_part() {
    let mut h = Harness::new();
    let sky = create(3, "Background", 2, json!({"fill": {"gradient": [{"rgba": [20, 26, 68, 255]}, {"rgba": [70, 57, 127, 255]}], "angle": 0}}));
    let spot = |i: i64, frame: i64| (60 + (i * 211) % 840 + frame * 2, 60 + (i * 157) % 520);
    let dots: Vec<Value> = (0..12)
        .map(|i| create(10 + i, "Oval", 2, json!({"left": spot(i, 0).0, "top": spot(i, 0).1, "width": 8, "height": 8, "center": true, "fill": {"rgba": [255, 244, 204, 255]}})))
        .collect();
    h.feed(&app(960, 640, &[vec![sky], dots].concat()));
    let mut window = Window::open(&mut h, 2.0);
    for frame in 1..=5 {
        let moves: Vec<Value> = (0..12).map(|i| json!({"t": "props", "id": 10 + i, "props": {"left": spot(i, frame).0}})).collect();
        feed(&mut h, &moves);
        let plan = window.repaint(&mut h);
        assert!(partial(&plan, &window, 0.02), "frame {frame}: {plan:?}");
        assert!(matches!(&plan, Repaint::Rects(r) if r.len() <= 8), "{plan:?}");
    }
}

#[test]
fn a_change_of_paint_order_repaints_everything() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 1.0);
    feed(&mut h, &[json!({"t": "reparent", "id": 11, "parent": 2, "index": 99})]);
    assert_eq!(window.repaint(&mut h), Repaint::Everything, "the red oval now paints over the others");
}

#[test]
fn a_new_size_repaints_everything() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    let mut window = Window::open(&mut h, 1.0);
    h.value(json!({"op": "resize", "w": 400, "h": 300}));
    window.frame = Pixmap::new(400, 300).unwrap();
    assert_eq!(window.repaint(&mut h), Repaint::Everything);
}

/// A tiny deterministic generator, so a failing walk can be replayed.
struct Walk(u64);

impl Walk {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }

    fn below(&mut self, n: u64) -> i64 {
        (self.next() % n) as i64
    }
}

#[test]
fn a_random_walk_of_changes_never_leaves_a_stale_pixel() {
    for (seed, scale) in [(0x5ca7e, 2.0), (0xdecaf, 1.0), (0xfeed, 1.5)] {
        let mut h = Harness::new();
        busy_scene(&mut h);
        let mut window = Window::open(&mut h, scale);
        let mut walk = Walk(seed);
        let mut next_id = 100;
        let mut art: Vec<i64> = vec![11, 12, 13, 14];
        let mut paras: Vec<i64> = vec![7, 8];
        for step in 0..150 {
            match walk.below(10) {
                0 | 1 => {
                    let id = art[walk.below(art.len() as u64) as usize];
                    props(&mut h, id, json!({"left": walk.below(470), "top": walk.below(310)}));
                }
                2 => {
                    let id = art[walk.below(art.len() as u64) as usize];
                    let c = [walk.below(256), walk.below(256), walk.below(256), 60 + walk.below(196)];
                    props(&mut h, id, json!({"fill": {"rgba": c}, "strokewidth": walk.below(6)}));
                }
                3 => {
                    let id = paras[walk.below(paras.len() as u64) as usize];
                    let words = ["tick", "a longer line that may wrap in the card", "", "Z"];
                    props(&mut h, id, json!({"text_items": [words[walk.below(4) as usize]]}));
                }
                4 => {
                    next_id += 1;
                    let kind = ["Oval", "Rect", "Para"][walk.below(3) as usize];
                    let parent = if kind == "Para" { 4 } else { 2 };
                    let body = json!({"left": walk.below(440), "top": walk.below(290), "width": 10 + walk.below(60), "height": 10 + walk.below(60),
                        "fill": {"rgba": [walk.below(256), 90, 200, 140]}, "text_items": [format!("new {next_id}")]});
                    let body = if kind == "Para" { json!({"text_items": [format!("new para {next_id}")]}) } else { body };
                    h.feed(&format!("{}\n{{\"t\":\"flush\"}}\n", create(next_id, kind, parent, body)));
                    if kind == "Para" { paras.push(next_id) } else { art.push(next_id) }
                }
                5 if art.len() > 1 => {
                    let id = art.remove(walk.below(art.len() as u64) as usize);
                    feed(&mut h, &[json!({"t": "destroy", "id": id})]);
                }
                6 => mouse(&mut h, "move", walk.below(480) as f32, walk.below(320) as f32),
                7 => {
                    let id = art[walk.below(art.len() as u64) as usize];
                    props(&mut h, id, json!({"hidden": walk.below(2) == 0}));
                }
                8 => {
                    let id = art[walk.below(art.len() as u64) as usize];
                    let (sx, sy) = (0.5 + walk.below(20) as f64 / 10.0, 0.5 + walk.below(20) as f64 / 10.0);
                    let about = ["corner", "center"][walk.below(2) as usize];
                    let turn = json!({"rotate": walk.below(360), "scale": [sx, sy], "skew": [walk.below(40) - 20, 0], "transform": about});
                    props(&mut h, id, json!({"draw_context": if walk.below(4) == 0 { json!({}) } else { turn }}));
                }
                _ => props(&mut h, 4, json!({"displace_left": walk.below(20), "displace_top": walk.below(10)})),
            }
            let plan = window.repaint(&mut h);
            assert!(!matches!(plan, Repaint::Rects(ref r) if r.is_empty()), "step {step}: an empty plan");
        }
    }
}

// ---- What the art-input lane draws, under partial repaints ----

/// A tooltip draws below the pointer, outside every node's box, so the frame that shows it
/// and the frame that hides it are painted whole.
#[test]
fn a_tooltip_shows_and_hides_without_stale_pixels() {
    let mut h = Harness::new();
    busy_scene(&mut h);
    props(&mut h, 9, json!({"tooltip": "Presses the button"}));
    let mut window = Window::open(&mut h, 2.0);
    let button = h.node(|n| n["kind"] == "Button");
    let (x, y) = (button["x"].as_f64().unwrap() as f32 + 10.0, button["y"].as_f64().unwrap() as f32 + 10.0);
    mouse(&mut h, "move", x, y);
    assert_eq!(window.repaint(&mut h), Repaint::Everything, "the bubble shows");
    mouse(&mut h, "move", 5.0, 300.0);
    assert_eq!(window.repaint(&mut h), Repaint::Everything, "and goes");
    mouse(&mut h, "move", 5.0, 310.0);
    assert_eq!(window.repaint(&mut h), Repaint::Nothing, "then nothing is left to paint");
}

/// Whether the frame looks like a full paint. `verify` checks a repainted rect against the
/// same rect painted with no node skipped, so a rect that paints wrong both ways (a layer
/// that forgets where the rect sits) needs this look at the whole picture as well. Edges a
/// rect cuts through antialias a shade differently, hence the tolerance.
fn looks_like_a_full_paint(h: &mut Harness, window: &Window) -> bool {
    let full = h.rt.picture(APP, window.scale).unwrap();
    let off = window.frame.data().chunks(4).zip(full.data().chunks(4)).filter(|(a, b)| a.iter().zip(b.iter()).any(|(x, y)| x.abs_diff(*y) > 24)).count();
    off as u64 * 1000 <= window.pixels() * 2
}

/// A slot with a mask shows its other contents only where the mask draws. Moving what the
/// mask draws repaints in part: the layers cover just the repainted rect.
#[test]
fn a_masked_slot_repaints_in_part() {
    let mut h = Harness::new();
    let black = json!({"fill": {"rgba": [0, 0, 0, 255]}});
    let body = vec![
        create(3, "Stack", 2, json!({"width": 400, "height": 300})),
        create(4, "Background", 3, json!({"fill": {"gradient": [{"rgba": [250, 60, 60, 255]}, {"rgba": [60, 60, 250, 255]}], "angle": 90}})),
        create(5, "Mask", 3, json!({})),
        create(6, "Oval", 5, json!({"left": 40, "top": 40, "width": 120, "height": 120, "draw_context": black.clone()})),
        create(7, "Rect", 5, json!({"left": 220, "top": 60, "width": 100, "height": 60, "draw_context": black})),
        create(8, "Para", 2, json!({"text_items": ["Outside the masked stack"]})),
    ];
    h.feed(&app(480, 400, &body));
    let mut window = Window::open(&mut h, 2.0);
    for (x, y) in [(60, 50), (100, 120), (10, 10)] {
        props(&mut h, 6, json!({"left": x, "top": y}));
        let plan = window.repaint(&mut h);
        assert!(partial(&plan, &window, 0.5), "{plan:?}");
        assert!(looks_like_a_full_paint(&mut h, &window), "the masked stack at {x},{y}");
    }
    props(&mut h, 4, json!({"fill": {"rgba": [20, 160, 60, 255]}}));
    window.repaint(&mut h);
    assert!(looks_like_a_full_paint(&mut h, &window), "a new backdrop behind the mask");
}

/// Art in a shape block paints as the shape's one path, so a member that moves repaints
/// through the shape and its box.
#[test]
fn a_shape_block_member_moving_repaints_the_shape() {
    let mut h = Harness::new();
    let grey = json!({"fill": {"rgba": [0, 0, 0, 128]}, "stroke": {"rgba": [0, 0, 0, 255]}, "strokewidth": 2});
    let body = vec![
        create(3, "Shape", 2, json!({"left": 40, "top": 40, "shape_commands": [], "draw_context": grey.clone()})),
        create(4, "Oval", 3, json!({"left": 0, "top": 0, "width": 100, "height": 100, "draw_context": grey.clone()})),
        create(5, "Rect", 3, json!({"left": 60, "top": 20, "width": 100, "height": 60, "draw_context": grey})),
        create(6, "Para", 2, json!({"text_items": ["Beside the shape"]})),
    ];
    h.feed(&app(480, 320, &body));
    let mut window = Window::open(&mut h, 2.0);
    for (x, y) in [(70, 30), (20, 60), (60, 20)] {
        props(&mut h, 5, json!({"left": x, "top": y}));
        window.repaint(&mut h);
        assert!(looks_like_a_full_paint(&mut h, &window), "the rect at {x},{y}");
    }
}

/// What an image(w, h) { } block draws lays out inside the image and is clipped to it.
#[test]
fn an_image_canvas_child_moving_repaints_in_part() {
    let mut h = Harness::new();
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 255]}});
    let body = vec![
        create(3, "Image", 2, json!({"url": "", "left": 40, "top": 30, "width": 200, "height": 150})),
        create(4, "Oval", 3, json!({"left": 20, "top": 20, "width": 60, "height": 60, "draw_context": red.clone()})),
        create(5, "Rect", 3, json!({"left": 150, "top": 100, "width": 100, "height": 100, "draw_context": red})),
        create(6, "Para", 3, json!({"text_items": ["inside"]})),
    ];
    h.feed(&app(480, 320, &body));
    let mut window = Window::open(&mut h, 2.0);
    for (x, y) in [(60, 40), (170, 120), (20, 20)] {
        props(&mut h, 4, json!({"left": x, "top": y}));
        let plan = window.repaint(&mut h);
        assert!(partial(&plan, &window, 0.5), "{plan:?}");
        assert!(looks_like_a_full_paint(&mut h, &window), "the oval at {x},{y}");
    }
}

/// A damaged rect that cuts through an error underline repaints the very waves a full paint
/// draws there: the waves are counted from the start of the span, not from the rect's edge.
#[test]
fn an_error_underline_repaints_in_part() {
    for scale in [1.0, 2.0] {
        let mut h = Harness::new();
        h.feed(&app(420, 120, &[
            create(3, "Para", 2, json!({"text_items": ["a long misspeled line of wurds to squiggle under"], "underline": "error", "size": 18})),
            create(4, "Oval", 2, json!({"left": 100, "top": 16, "width": 10, "draw_context": {"fill": {"rgba": [0, 0, 255, 255]}}})),
        ]));
        let mut window = Window::open(&mut h, scale);
        for x in [131, 163, 197, 229, 262] {
            props(&mut h, 4, json!({"left": x}));
            let plan = window.repaint(&mut h);
            assert!(partial(&plan, &window, 0.5), "moving the dot repaints in part: {plan:?}");
            // verify() compares a rect with itself painted unculled; this compares it with the
            // whole picture, where a squiggle out of step shows as a run of wrong pixels.
            let full = h.rt.picture(APP, scale).unwrap();
            let off = window.frame.pixels().iter().zip(full.pixels()).filter(|(a, b)| {
                let (a, b) = (a.demultiply(), b.demultiply());
                [a.red().abs_diff(b.red()), a.green().abs_diff(b.green()), a.blue().abs_diff(b.blue())].into_iter().max().unwrap_or(0) > 40
            });
            assert_eq!(off.count(), 0, "at {scale}x with the dot at {x}");
        }
    }
}

/// A star whose inner radius is longer than its outer one reaches past its layout box (which,
/// as in Shoes 3, is sized by `outer`). Recolouring and moving it must repaint all of it.
#[test]
fn a_star_with_long_inner_points_repaints_all_of_itself() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Star", 2, json!({"left": 150, "top": 100, "points": 5, "outer": 10, "inner": 80, "draw_context": {"fill": {"rgba": [255, 0, 0, 255]}}}))]));
    let mut window = Window::open(&mut h, 1.0);
    props(&mut h, 3, json!({"draw_context": {"fill": {"rgba": [0, 0, 255, 255]}}}));
    window.repaint(&mut h);
    props(&mut h, 3, json!({"left": 60}));
    window.repaint(&mut h);
}

/// Negative kerning pulls glyphs left of where the text box starts.
#[test]
fn text_kerned_tight_repaints_all_of_itself() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Para", 2, json!({"text_items": ["hello world"], "kerning": -15, "margin_left": 100, "size": 20}))]));
    let mut window = Window::open(&mut h, 1.0);
    props(&mut h, 3, json!({"text_items": ["HELLO WORLD"]}));
    window.repaint(&mut h);
    props(&mut h, 3, json!({"stroke": {"rgba": [0, 0, 255, 255]}}));
    window.repaint(&mut h);
}
