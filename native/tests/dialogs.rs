//! The in-window `ask` and `ask_color` modals, driven without a window (no OS
//! dialog can appear: native dialogs are only ever run by the window layer).

mod common;

use scarpe_native::input::Clipboard;
use scarpe_native::protocol::Outbox;
use scarpe_native::runtime::{Effect, Options, Runtime};
use scarpe_native::text::FontMode;
use serde_json::{json, Value};

fn windowed_runtime() -> Runtime {
    let opts = Options { headless: false, scale: Some(1.0), fonts: FontMode::Bundled, trace: false };
    let mut rt = Runtime::new(opts, Outbox::capture());
    rt.clipboard = Clipboard::local();
    for line in common::app(400, 300, &[]).lines() {
        rt.handle_line(line);
    }
    rt.out.take_captured();
    rt
}

fn send(rt: &mut Runtime, v: Value) -> Vec<Value> {
    rt.handle_line(&v.to_string());
    rt.out.take_captured()
}

fn reply(msgs: &[Value], req: u64) -> Option<Value> {
    msgs.iter().find(|m| m["t"] == "reply" && m["req"] == json!(req)).cloned()
}

#[test]
fn ask_opens_a_modal_and_answers_on_return() {
    let mut rt = windowed_runtime();
    let msgs = send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"Your name?","default":"Bob"}));
    assert!(reply(&msgs, 1).is_none(), "the answer waits for the user");
    assert!(rt.effects.iter().all(|e| !matches!(e, Effect::Dialog { .. })), "no native dialog for ask");
    let picture = rt.picture(1, 1.0).unwrap();
    assert!(picture.pixel(200, 10).unwrap().red() < 250, "the modal dims the window");
    send(&mut rt, json!({"t":"req","req":2,"op":"type","text":"Ann"}));
    let msgs = send(&mut rt, json!({"t":"req","req":3,"op":"key","key":"\n"}));
    let answer = reply(&msgs, 1).expect("answered");
    assert_eq!(answer["value"], json!("Ann"), "typing replaced the selected default");
    assert_eq!(answer["cancelled"], json!(false));
}

#[test]
fn escape_cancels_ask() {
    let mut rt = windowed_runtime();
    send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"?","default":null}));
    let msgs = send(&mut rt, json!({"t":"req","req":2,"op":"key","key":"escape"}));
    let answer = reply(&msgs, 1).expect("answered");
    assert_eq!(answer["value"], Value::Null);
    assert_eq!(answer["cancelled"], json!(true));
}

#[test]
fn ask_color_answers_a_swatch() {
    let mut rt = windowed_runtime();
    send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask_color","message":"Pick","default":null}));
    send(&mut rt, json!({"t":"req","req":2,"op":"key","key":"right"}));
    let msgs = send(&mut rt, json!({"t":"req","req":3,"op":"key","key":"\n"}));
    let answer = reply(&msgs, 1).expect("answered");
    assert_eq!(answer["value"], json!([0x58, 0x56, 0xd6, 255]));
}

#[test]
fn clicking_ok_answers_too() {
    let mut rt = windowed_runtime();
    send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"?","default":"yes"}));
    // OK sits at the panel's bottom right; find it by scanning for the accent colour.
    let pm = rt.picture(1, 1.0).unwrap();
    let mut ok = None;
    for y in (0..300).rev() {
        for x in (0..400).rev() {
            let p = pm.pixel(x, y).unwrap().demultiply();
            if p.blue() > 240 && p.red() < 30 && p.green() > 110 && p.green() < 150 {
                ok = Some((x as f32 - 20.0, y as f32 - 8.0));
                break;
            }
        }
        if ok.is_some() {
            break;
        }
    }
    let (x, y) = ok.expect("an OK button");
    let msgs = send(&mut rt, json!({"t":"req","req":2,"op":"click","target":{"x":x,"y":y}}));
    assert_eq!(reply(&msgs, 1).expect("answered")["value"], json!("yes"));
}

#[test]
fn native_dialogs_are_left_to_the_window_layer() {
    let mut rt = windowed_runtime();
    let msgs = send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"alert","message":"Hi","default":null}));
    assert!(reply(&msgs, 1).is_none());
    assert!(rt.effects.iter().any(|e| matches!(e, Effect::Dialog { req: 1, .. })));
    rt.dialog_answered(1, Value::Null, false);
    assert_eq!(reply(&rt.out.take_captured(), 1).unwrap()["cancelled"], json!(false));
}
