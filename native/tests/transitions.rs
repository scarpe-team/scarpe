mod common;

use common::*;
use serde_json::{json, Value};

fn scene() -> Harness {
    let mut h = Harness::new();
    h.feed(&app(240, 160, &[
        create(3, "Stack", 2, json!({"left":10,"top":10,"width":100,"height":60})),
        create(4, "Background", 3, json!({"fill":"red"})),
        create(5, "Progress", 2, json!({"top":90,"width":100,"height":20})),
    ]));
    clock(&mut h, 0.0);
    h
}

fn clock(h: &mut Harness, at: f64) {
    h.feed(&format!("{}\n{{\"t\":\"flush\"}}", json!({"t":"motion_clock","at":at})));
}

fn start(h: &mut Harness, id: i64, token: u64, duration: f64, props: Value) {
    h.value(json!({"op":"transition","id":id,"token":token,"duration":duration,"props":props}));
}

fn frame(h: &mut Harness) -> Vec<Value> {
    h.req(json!({"op":"frames"})).0.into_iter().filter(|m| m["t"] == "transition_end").collect()
}

fn prop(h: &Harness, id: i64, key: &str) -> f64 {
    h.rt.doc.get(id).unwrap().props.0[key].as_f64().unwrap()
}

#[test]
fn defaults_easing_pixels_and_exact_final_values() {
    let mut h = scene();
    start(&mut h, 3, 1, 1.0, json!({"opacity":0.0,"displace_left":80.0}));
    start(&mut h, 5, 2, 1.0, json!({"fraction":0.8}));
    clock(&mut h, 0.5);
    assert!(frame(&mut h).is_empty());
    assert_eq!(prop(&h, 3, "opacity"), 0.125);
    assert_eq!(prop(&h, 3, "displace_left"), 70.0);
    assert!((prop(&h, 5, "fraction") - 0.7).abs() < 1e-6);
    assert_eq!(h.node(|n| n["id"] == 3)["x"], 80.0);
    let px = h.value(json!({"op":"pixel","x":90,"y":20}));
    assert_eq!(px, json!([255,223,223,255]));
    clock(&mut h, 1.0);
    let ended = frame(&mut h);
    assert_eq!(ended.len(), 2);
    assert!(ended.iter().all(|m| m["completed"] == true));
    assert_eq!(ended[0]["props"], json!({"opacity":0.0,"displace_left":80.0}));
    assert_eq!(ended[1]["props"], json!({"fraction":0.8}));
    assert!(frame(&mut h).is_empty());
}

#[test]
fn completion_waits_for_presentation_and_is_still_cancellable() {
    let mut h = scene();
    start(&mut h, 3, 1, 0.0, json!({"opacity":0.0}));
    h.rt.advance_transitions(1);
    assert!(h.rt.out.take_captured().iter().all(|m| m["t"] != "transition_end"));
    let (events, reply) = h.req(json!({"op":"cancel_transition","id":3,"token":1}));
    assert_eq!(reply["value"]["opacity"], 0.0);
    assert!(events.iter().any(|m| m["t"] == "transition_end" && m["completed"] == false));
    assert!(frame(&mut h).is_empty());
}

#[test]
fn replacement_cancels_the_whole_overlapping_group_and_reverses_from_the_sample() {
    let mut h = scene();
    start(&mut h, 3, 1, 1.0, json!({"opacity":0.0,"displace_left":80.0}));
    start(&mut h, 3, 2, 1.0, json!({"displace_top":40.0}));
    clock(&mut h, 0.5);
    frame(&mut h);
    let (events, reply) = h.req(json!({"op":"transition","id":3,"token":3,"duration":1.0,"props":{"opacity":1.0}}));
    assert!(reply["error"].is_null());
    let cancelled = events.iter().find(|m| m["t"] == "transition_end").unwrap();
    assert_eq!(cancelled["token"], 1);
    assert_eq!(cancelled["completed"], false);
    assert_eq!(cancelled["props"], json!({"opacity":0.125,"displace_left":70.0}));
    clock(&mut h, 1.0);
    let ended = frame(&mut h);
    assert_eq!(ended.len(), 1);
    assert_eq!(ended[0]["token"], 2);
    assert_eq!(prop(&h, 3, "opacity"), 0.890625);
    assert_eq!(prop(&h, 3, "displace_left"), 70.0);
    assert_eq!(prop(&h, 3, "displace_top"), 40.0);
}

#[test]
fn explicit_properties_cancel_motion_without_later_overwrite() {
    let mut h = scene();
    start(&mut h, 3, 1, 1.0, json!({"opacity":0.0}));
    let events = h.feed(r#"{"t":"props","id":3,"props":{"opacity":0.7}}
{"t":"flush"}"#);
    assert!(events.iter().any(|m| m["t"] == "transition_end" && m["completed"] == false));
    clock(&mut h, 20.0);
    assert!(frame(&mut h).is_empty());
    assert_eq!(prop(&h, 3, "opacity"), 0.7);
}

#[test]
fn invalid_starts_reply_with_errors_without_cancelling_valid_jobs() {
    let mut h = scene();
    start(&mut h, 3, 1, 1.0, json!({"opacity":0.0}));
    for (id, duration, props) in [
        (3, -1.0, json!({"opacity":0.5})), (3, 1.0, json!({})),
        (3, 1.0, json!({"opacity":2})), (3, 1.0, json!({"opacity":"0.5"})),
        (3, 1.0, json!({"width":10})), (3, 1.0, json!({"fraction":0.5})),
        (3, 1.0, json!({"displace_left":1e100})), (99, 1.0, json!({"opacity":0})),
        (1, 1.0, json!({"opacity":0})),
    ] {
        let (events, reply) = h.req(json!({"op":"transition","id":id,"token":2,"duration":duration,"props":props}));
        assert!(reply["error"].is_string(), "{reply}");
        assert!(events.iter().all(|m| m["t"] != "transition_end"));
    }
    let (_, duplicate) = h.req(json!({"op":"transition","id":3,"token":1,"duration":1,"props":{"opacity":1}}));
    assert!(duplicate["error"].is_string());
    let (_, malformed) = h.req(json!({"op":"transition","id":3}));
    assert!(malformed["error"].is_string());
    clock(&mut h, 1.0);
    assert_eq!(frame(&mut h)[0]["token"], 1);
}

#[test]
fn cancellation_uses_last_sample_even_if_the_clock_has_advanced() {
    let mut h = scene();
    start(&mut h, 3, 1, 1.0, json!({"opacity":0.0}));
    clock(&mut h, 0.5);
    frame(&mut h);
    clock(&mut h, 0.9);
    let values = h.value(json!({"op":"cancel_transition","id":3,"token":1}));
    assert_eq!(values["opacity"], 0.125);
    clock(&mut h, 2.0);
    assert!(frame(&mut h).is_empty());
    assert_eq!(prop(&h, 3, "opacity"), 0.125);
}

#[test]
fn completed_values_remain_available_when_cancelling_before_ruby_dispatches() {
    let mut h = scene();
    start(&mut h, 3, 1, 0.0, json!({"opacity":0.0}));
    assert_eq!(frame(&mut h).len(), 1);
    assert_eq!(h.value(json!({"op":"cancel_transition","id":3,"token":1}))["opacity"], 0.0);
}

#[test]
fn destroying_a_subtree_or_closing_its_window_drops_all_jobs() {
    for close in [false, true] {
        let mut h = scene();
        start(&mut h, 3, 1, 1.0, json!({"opacity":0.0}));
        start(&mut h, 4, 2, 0.0, json!({"opacity":0.0}));
        h.rt.advance_transitions(1); // Includes a completion awaiting presentation.
        if close { h.rt.window_closed(1); } else { h.feed(r#"{"t":"destroy","id":3}"#); }
        clock(&mut h, 10.0);
        h.rt.set_motion_clock(None);
        assert!(!h.rt.transitions_running(None));
        assert!(frame(&mut h).is_empty());
    }
}

#[test]
fn one_windows_frame_does_not_finish_another_windows_job() {
    let mut h = scene();
    h.feed(r#"{"t":"create","id":11,"kind":"DocumentRoot","props":{}}
{"t":"create","id":10,"kind":"App","doc_root":11,"props":{"width":100,"height":80}}
{"t":"create","id":12,"kind":"Stack","parent":11,"props":{}}
{"t":"run","app":10}
{"t":"flush"}"#);
    start(&mut h, 3, 1, 0.0, json!({"opacity":0.0}));
    start(&mut h, 12, 2, 0.0, json!({"opacity":0.0}));
    let (events, _) = h.req(json!({"op":"frames","app":1}));
    assert_eq!(events.iter().filter(|m| m["t"] == "transition_end").map(|m| m["token"].clone()).collect::<Vec<_>>(), vec![json!(1)]);
    let (events, _) = h.req(json!({"op":"frames","app":10}));
    assert_eq!(events.iter().filter(|m| m["t"] == "transition_end").map(|m| m["token"].clone()).collect::<Vec<_>>(), vec![json!(2)]);
}

#[test]
fn detaching_a_running_target_cancels_its_job() {
    let mut h = scene();
    start(&mut h, 3, 1, 1.0, json!({"opacity":0.0}));
    let events = h.feed(r#"{"t":"reparent","id":3,"parent":null}
{"t":"flush"}"#);
    assert!(events.iter().any(|m| m["t"] == "transition_end" && m["completed"] == false));
    h.rt.set_motion_clock(None);
    assert!(!h.rt.transitions_running(None));
}

#[test]
fn frozen_clocks_and_open_batches_do_not_schedule_or_sample_motion() {
    let mut h = scene();
    start(&mut h, 3, 1, 1.0, json!({"opacity":0.0}));
    assert!(!h.rt.transitions_running(None));
    clock(&mut h, 0.5);
    h.feed(r#"{"t":"props","id":3,"props":{"cursor":"hand"}}"#);
    h.rt.advance_transitions(1);
    assert!(!h.rt.doc.get(3).unwrap().props.0.contains_key("opacity"));
    h.feed(r#"{"t":"flush"}"#);
    frame(&mut h);
    assert_eq!(prop(&h, 3, "opacity"), 0.125);
    h.rt.set_motion_clock(None);
    assert!(h.rt.transitions_running(Some(1)));
    h.rt.set_motion_clock(Some(100.0));
    frame(&mut h);
    assert!((prop(&h, 3, "opacity") - 0.125).abs() < 0.01);
    clock(&mut h, 101.0);
    assert_eq!(frame(&mut h).len(), 1);
}
