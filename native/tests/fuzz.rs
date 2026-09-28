//! Untrusted input never panics. Whatever arrives on stdin (malformed JSON, unknown kinds and
//! ops, NaN, infinite, negative or huge numbers, missing files, loops, deep nesting), Rust logs
//! what it cannot use and carries on drawing. These tests feed generated bad input through the
//! real entry point (`Runtime::handle_line`), then lay out, paint and poke the app the way a
//! test or a person would. A screen reader listens throughout, as AccessKit's platform adapters
//! do, so no hostile document makes a tree or an update that would panic one.
//! SCARPE_NATIVE_FUZZ_RUNS=N runs more sessions, and SCARPE_NATIVE_FUZZ_SEED=N replays one
//! (SCARPE_NATIVE_FUZZ_TRACE=1 prints its lines).

mod common;

use accesskit_consumer::{Node as SeenNode, Tree, TreeChangeHandler};
use common::{app, create, snapshot_path, still_answers, Harness};
use scarpe_native::a11y::{self, Mirror};
use serde_json::{json, Value};
use std::panic::{catch_unwind, AssertUnwindSafe};

struct Quiet;

impl TreeChangeHandler for Quiet {
    fn node_added(&mut self, _: &SeenNode) {}
    fn node_updated(&mut self, _: &SeenNode, _: &SeenNode) {}
    fn focus_moved(&mut self, _: Option<&SeenNode>, _: Option<&SeenNode>) {}
    fn node_removed(&mut self, _: &SeenNode) {}
}

/// What a platform adapter does with app 1's window: the whole tree once, then each update,
/// through AccessKit's own consumer, which panics on any update that does not fit.
#[derive(Default)]
struct ScreenReader {
    mirror: Mirror,
    tree: Option<Tree>,
}

impl ScreenReader {
    fn listen(&mut self, h: &mut Harness) {
        let update = self.mirror.update(h.rt.a11y_tree(1, 2.0));
        match &mut self.tree {
            Some(tree) => tree.update_and_process_changes(update, &mut Quiet),
            None => self.tree = Some(Tree::new(update, true)),
        }
    }

    /// After all those updates it holds what a fresh tree would.
    fn in_step(&self, h: &mut Harness) {
        let fresh = a11y::read_back(h.rt.a11y_tree(1, 2.0));
        assert_eq!(self.tree.as_ref().map(a11y::read), Some(fresh), "the screen reader fell out of step");
    }
}

/// xorshift64*: small, deterministic, so a failing seed reproduces.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n.max(1) as u64) as usize
    }

    fn pick<T: Clone>(&mut self, items: &[T]) -> T {
        items[self.below(items.len())].clone()
    }

    fn one_in(&mut self, n: usize) -> bool {
        self.below(n) == 0
    }
}

/// Numbers and near-numbers that break naive geometry. JSON has no NaN or infinity, but
/// 1e300 turns into one the moment it becomes an f32, and strings can spell them.
fn hostile_numbers() -> Vec<Value> {
    vec![
        json!(0),
        json!(-1),
        json!(-0.0),
        json!(0.5),
        json!(1.0000001),
        json!(-0.9999),
        json!(1e9),
        json!(-1e9),
        json!(1e38),
        json!(-3.4e38),
        json!(1e300),
        json!(-1e300),
        json!(2147483648_i64),
        json!(-2147483649_i64),
        json!(i64::MAX),
        json!(i64::MIN),
        json!(u64::MAX),
        json!("NaN"),
        json!("inf"),
        json!("-inf"),
        json!("1e999"),
        json!("1e30%"),
        json!("-1e30px"),
        json!("50%"),
        json!(""),
        json!("wide"),
        json!(true),
        json!(null),
        json!([]),
        json!([1e300, -1e300, "x", null]),
        json!({"left": 1e300, "top": "NaN"}),
    ]
}

fn hostile_value(rng: &mut Rng) -> Value {
    match rng.below(10) {
        0 => json!("\u{0}\u{200b}\u{202e}ﷺ𒐫\n\n\t"),
        1 => json!("x".repeat(rng.below(3000))),
        2 => json!({"rgba": [rng.pick(&hostile_numbers()), 1e300, -5, "red"]}),
        3 => json!({"gradient": [[255, 0, 0, 255], {"rgba": [0, 0, 1e300, 0]}], "angle": 1e300}),
        4 => json!({"image": "/no/such/image.png"}),
        _ => rng.pick(&hostile_numbers()),
    }
}

const KINDS: &[&str] = &[
    "Stack", "Flow", "Para", "Title", "Banner", "TextDrawable", "Strong", "Em", "Link", "Span", "Sub", "Sup", "Code",
    "Button", "Check", "Radio", "EditLine", "EditBox", "ListBox", "Progress", "Slider", "Image", "Video", "Background",
    "Border", "Rect", "Oval", "Line", "Arrow", "Star", "Arc", "Shape", "Mask", "Widget", "SubscriptionItem",
    "App", "DocumentRoot", "Blorp", "", "\u{1f600}",
];

const KEYS: &[&str] = &[
    "width", "height", "left", "top", "right", "bottom", "margin", "margin_left", "margin_top", "padding", "size",
    "leading", "kerning", "rise", "strokewidth", "curve", "radius", "points", "outer", "inner", "angle1", "angle2",
    "x2", "y2", "displace_left", "displace_top", "fraction", "scroll", "hidden", "center", "wedge", "fill", "stroke",
    "text", "text_items", "items", "choose", "url", "icon", "font", "family", "weight", "align", "wrap", "cursor",
    "text_cursor", "text_marker", "attach", "tooltip", "state", "secret", "opacity", "rotate_angle", "shape_commands",
    "draw_context", "shoes_api_name", "has_click", "checked",
];

fn hostile_props(rng: &mut Rng, ids: &[i64]) -> Value {
    let mut props = serde_json::Map::new();
    for _ in 0..rng.below(8) {
        let key = rng.pick(KEYS);
        let value = match key {
            "text_items" => json!([rng.pick(ids), "text", rng.pick(ids), [1, [2]], null, 1e300]),
            "shape_commands" => json!([
                ["move_to", rng.pick(&hostile_numbers()), 1e300],
                ["line_to", 1e38, -1e38],
                ["curve_to", 1, 2, 3, 4, 1e300, 6],
                ["arc_to", 0, 0, 1e300, -1e300, 0, 1e300],
                ["teleport"],
                "not a command",
            ]),
            "draw_context" => json!({
                "rotate": rng.pick(&hostile_numbers()), "scale": [1e300, -1e300], "skew": [90, 1e300],
                "translate": [1e300, "x"], "strokewidth": 1e30, "fill": hostile_value(rng), "transform": "center",
            }),
            "items" => json!(["a", 1e300, null, [], {"x": 1}, "\u{0}"]),
            "shoes_api_name" => json!(rng.pick(&["click", "motion", "keypress", "wheel", "hover", "animate", "nope"])),
            _ => hostile_value(rng),
        };
        props.insert(key.to_string(), value);
    }
    Value::Object(props)
}

/// One generated session: a tree of hostile nodes, then every request an automation client
/// can send, with hostile arguments, interleaved with changes, reparents and destroys.
fn hostile_session(rng: &mut Rng, h: &mut Harness) {
    let mut ids: Vec<i64> = vec![1, 2, -7, 0, 999_999, i64::MAX];
    let mut body = Vec::new();
    for n in 0..(3 + rng.below(40)) {
        let id = 3 + n as i64;
        let parent = if rng.one_in(6) { rng.pick(&ids) } else { *ids.iter().rfind(|i| **i >= 2 && **i < id).unwrap_or(&2) };
        let mut line = create(id, rng.pick(KINDS), parent, hostile_props(rng, &ids));
        if rng.one_in(10) {
            line["index"] = rng.pick(&hostile_numbers());
        }
        if rng.one_in(12) {
            line["widget"] = json!(true);
        }
        body.push(line);
        ids.push(id);
    }
    let size = |rng: &mut Rng| rng.pick(&[json!(300), json!(1e9), json!(-40), json!(0), json!(1e300), json!("wide")]);
    let mut lines = app(300, 200, &body);
    lines.push_str(&format!("{}\n", json!({"t": "props", "id": 1, "props": {"width": size(rng), "height": size(rng)}})));
    if std::env::var_os("SCARPE_NATIVE_FUZZ_TRACE").is_some() {
        eprintln!("fuzz >> {lines}");
    }
    h.feed(&lines);
    let mut reader = ScreenReader::default();
    reader.listen(h);

    for _ in 0..(10 + rng.below(30)) {
        let id = rng.pick(&ids);
        let part = a11y::part(id, rng.below(3)).0;
        let line = match rng.below(19) {
            0 => json!({"t": "props", "id": id, "props": hostile_props(rng, &ids)}),
            1 => json!({"t": "reparent", "id": id, "parent": rng.pick(&ids), "index": rng.pick(&hostile_numbers())}),
            2 => json!({"t": "destroy", "id": id}),
            3 => json!({"t": "focus", "id": id}),
            4 => json!({"t": "scroll_to", "id": id, "top": rng.pick(&hostile_numbers())}),
            5 => json!({"t": "req", "req": 7, "op": "click", "target": rng.pick(&[json!({"id": id}), json!({"text": "a"}), json!({"x": 1e300, "y": -1e300}), json!({"x": 150, "y": 100})])}),
            6 => json!({"t": "req", "req": 7, "op": "mouse", "action": rng.pick(&["move", "down", "up"]), "x": rng.pick(&hostile_numbers()), "y": rng.pick(&[json!(40), json!(1e300), json!(-3)]), "button": rng.pick(&hostile_numbers())}),
            7 => json!({"t": "req", "req": 7, "op": "key", "key": rng.pick(&["a", "tab", ":control_z", ":command_shift_z", "\n", "backspace", "f99", ":shift_", "", "left", ":control_v", ":control_a"])}),
            8 => json!({"t": "req", "req": 7, "op": "type", "text": hostile_value(rng).to_string()}),
            9 => json!({"t": "req", "req": 7, "op": "wheel", "dy": rng.pick(&hostile_numbers()), "x": 100, "y": 100}),
            10 => json!({"t": "req", "req": 7, "op": "resize", "w": rng.pick(&hostile_numbers()), "h": rng.pick(&hostile_numbers())}),
            11 => json!({"t": "req", "req": 7, "op": "pixel", "x": rng.pick(&hostile_numbers()), "y": 10}),
            12 => json!({"t": "req", "req": 7, "op": "layout", "app": rng.pick(&ids)}),
            13 => json!({"t": "req", "req": 7, "op": "frames", "n": rng.pick(&[json!(3), json!(0), json!(-1), json!(1e300)])}),
            14 => json!({"t": "req", "req": 7, "op": "snapshot", "path": snapshot_path(), "scale": rng.pick(&hostile_numbers())}),
            15 => json!({"t": "create", "id": id, "kind": rng.pick(KINDS), "parent": rng.pick(&ids), "props": hostile_props(rng, &ids)}),
            16 => json!({"t": "req", "req": 7, "op": "a11y", "app": rng.pick(&[json!(null), json!(id)])}),
            17 => json!({
                "t": "req", "req": 7, "op": "a11y_action",
                "id": rng.pick(&[json!(id), json!(part), json!(u64::MAX), json!(-1)]),
                "action": rng.pick(&["click", "focus", "set_value", "expand", "collapse", "fly"]),
                "value": hostile_value(rng),
            }),
            _ => json!({"t": "flush"}),
        };
        if std::env::var_os("SCARPE_NATIVE_FUZZ_TRACE").is_some() {
            eprintln!("fuzz >> {line}");
        }
        h.feed(&format!("{line}\n"));
        reader.listen(h);
    }
    reader.in_step(h);
    // A pixel paints the whole picture, as a snapshot does, without the PNG encoding.
    h.feed(&format!("{}\n", json!({"t": "req", "req": 8, "op": "pixel", "x": 10, "y": 10})));
}

#[test]
fn malformed_lines_are_logged_and_the_next_line_still_works() {
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Para", 2, json!({"text_items": ["hi"]}))]));
    let bad = [
        "{", "}", "[]", "null", "42", "\"t\"", "{\"t\":5}", "{\"t\":null}", "{\"t\":\"create\"}",
        "{\"t\":\"create\",\"id\":\"3\",\"kind\":\"Para\"}", "{\"t\":\"create\",\"id\":4,\"kind\":7}",
        "{\"t\":\"create\",\"id\":4,\"kind\":\"Para\",\"props\":[1,2]}", "{\"t\":\"props\",\"id\":3,\"props\":\"x\"}",
        "{\"t\":\"req\"}", "{\"t\":\"req\",\"req\":-1,\"op\":\"ping\"}", "{\"t\":\"req\",\"req\":1,\"op\":{}}",
        "{\"t\":\"req\",\"req\":1,\"op\":\"click\",\"target\":7}", "{\"t\":\"req\",\"req\":1,\"op\":\"mouse\",\"action\":\"fly\",\"x\":1,\"y\":1}",
        "{\"t\":\"font\",\"path\":17}", "{\"t\":\"reparent\",\"id\":3,\"parent\":3}",
        "{\"t\":\"hello\",\"v\":\"one\"}", "{\"t\":\"create\",\"id\":1e400,\"kind\":\"Para\"}",
        &format!("{}{}", "[".repeat(5000), "]".repeat(5000)),
        &format!("{{\"t\":\"props\",\"id\":3,\"props\":{{\"text_items\":{}{}}}}}", "[".repeat(200), "]".repeat(200)),
    ];
    for line in bad {
        h.feed(&format!("{line}\n"));
    }
    still_answers(&mut h);
    let para = h.node(|n| n["id"] == 3);
    assert_eq!(para["text"], json!("hi"), "the good para survived the bad lines");
}

#[test]
fn hostile_sessions_never_panic() {
    let runs: u64 = std::env::var("SCARPE_NATIVE_FUZZ_RUNS").ok().and_then(|n| n.parse().ok()).unwrap_or(150);
    // SCARPE_NATIVE_FUZZ_SEED=N replays one session.
    let seeds = match std::env::var("SCARPE_NATIVE_FUZZ_SEED").ok().and_then(|n| n.parse().ok()) {
        Some(seed) => seed..=seed,
        None => 1..=runs,
    };
    let mut failures = Vec::new();
    for seed in seeds {
        let outcome = catch_unwind(AssertUnwindSafe(|| {
            let mut rng = Rng(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1);
            let mut h = Harness::new();
            hostile_session(&mut rng, &mut h);
            still_answers(&mut h);
        }));
        if let Err(panic) = outcome {
            let msg = panic.downcast_ref::<String>().cloned().or_else(|| panic.downcast_ref::<&str>().map(|s| s.to_string()));
            failures.push(format!("seed {seed}: {}", msg.unwrap_or_default()));
        }
    }
    let _ = std::fs::remove_file(snapshot_path());
    assert!(failures.is_empty(), "{} of {runs} sessions panicked:\n{}", failures.len(), failures.join("\n"));
}
