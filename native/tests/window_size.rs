//! App minimum sizes, without creating OS windows.

mod common;

use common::Harness;
use scarpe_native::runtime::{app_size, Effect};
use serde_json::{json, Value};

fn app(props: Value) -> Harness {
    let mut h = Harness::new();
    let lines = [
        json!({"t":"create","id":2,"kind":"DocumentRoot","props":{"width":"100%","height":"100%"}}),
        json!({"t":"create","id":1,"kind":"App","doc_root":2,"props":props}),
        json!({"t":"run","app":1}),
    ];
    h.feed(&lines.iter().map(Value::to_string).collect::<Vec<_>>().join("\n"));
    h
}

#[test]
fn minimums_apply_to_initial_size_and_each_resize_path() {
    let mut h = app(json!({"width":320,"height":240,"min_width":800,"min_height":600}));
    assert_eq!(h.rt.views[&1].size, (800.0, 600.0));
    let root = h.node(|n| n["kind"] == "DocumentRoot");
    assert_eq!((root["w"].clone(), root["h"].clone()), (json!(800.0), json!(600.0)));

    h.value(json!({"op":"resize","w":1000,"h":720}));
    let (messages, _) = h.req(json!({"op":"resize","w":420,"h":420}));
    assert_eq!(h.rt.views[&1].size, (800.0, 600.0));
    assert!(messages.iter().any(|m| m["t"] == "resize" && m["w"] == 800 && m["h"] == 600));
    h.rt.resize_view(1, 0.0, 0.0, true);
    assert_eq!(h.rt.views[&1].size, (800.0, 600.0), "minimizing keeps the last usable size");

    // The window-event path uses the same bounds.
    h.rt.resize_view(1, 900.0, 700.0, true);
    h.rt.resize_view(1, 420.0, 420.0, true);
    assert_eq!(h.rt.views[&1].size, (800.0, 600.0));
    h.rt.out.take_captured();
    let messages = h.feed(r#"{"t":"props","id":1,"props":{"width":320,"height":240}}"#);
    assert_eq!(h.rt.views[&1].size, (800.0, 600.0));
    assert!(messages.iter().any(|m| m["t"] == "resize" && m["w"] == 800 && m["h"] == 600), "Ruby hears the clamped size even when the view was already at its minimum");

    // Queuing an OS resize uses the constrained size too; no window layer runs here.
    h.rt.opts.headless = false;
    h.rt.effects.clear();
    h.value(json!({"op":"resize","w":320,"h":240}));
    assert!(h.rt.effects.contains(&Effect::ResizeWindow(1, 800.0, 600.0)));
}

#[test]
fn changing_or_clearing_minimums_preserves_the_current_size_until_it_must_grow() {
    let mut h = app(json!({"width":400,"height":300}));
    h.value(json!({"op":"resize","w":1000,"h":720}));
    h.rt.effects.clear();
    h.feed(r#"{"t":"props","id":1,"props":{"min_width":800,"min_height":600}}"#);
    assert_eq!(h.rt.views[&1].size, (1000.0, 720.0), "do not reset to the original dimensions");
    assert!(h.rt.effects.contains(&Effect::SetMinimumSize(1, 800.0, 600.0)));
    assert!(!h.rt.effects.iter().any(|effect| matches!(effect, Effect::ResizeWindow(..))));

    let messages = h.feed(r#"{"t":"props","id":1,"props":{"min_height":800}}"#);
    assert_eq!(h.rt.views[&1].size, (1000.0, 800.0));
    assert!(messages.iter().any(|m| m["t"] == "resize" && m["w"] == 1000 && m["h"] == 800));
    assert!(h.rt.effects.contains(&Effect::ResizeWindow(1, 1000.0, 800.0)));

    h.feed(r#"{"t":"props","id":1,"props":{"min_width":null}}"#);
    h.value(json!({"op":"resize","w":320,"h":240}));
    assert_eq!(h.rt.views[&1].size, (320.0, 800.0), "limits are independent");
    h.rt.effects.clear();
    h.feed(r#"{"t":"props","id":1,"props":{"min_height":null}}"#);
    assert_eq!(h.rt.views[&1].size, (320.0, 800.0), "removing the last limit does not resize");
    assert!(h.rt.effects.contains(&Effect::SetMinimumSize(1, 0.0, 0.0)));
    h.value(json!({"op":"resize","w":320,"h":240}));
    assert_eq!(h.rt.views[&1].size, (320.0, 240.0));
}

#[test]
fn minimums_are_optional_independent_and_bounded() {
    for (props, expected) in [
        (json!({}), (600.0, 500.0)),
        (json!({"width":320,"height":240,"min_width":800}), (800.0, 240.0)),
        (json!({"width":320,"height":240,"min_height":600}), (320.0, 600.0)),
        (json!({"min_width":null,"min_height":0}), (600.0, 500.0)),
        (json!({"min_width":-1,"min_height":"invalid"}), (600.0, 500.0)),
        (json!({"min_width":1e300,"min_height":false}), (600.0, 500.0)),
        (json!({"min_width":1e9,"min_height":1e9}), (10_000.0, 10_000.0)),
    ] {
        assert_eq!(app_size(props.as_object().unwrap()), expected, "{props}");
    }
}
