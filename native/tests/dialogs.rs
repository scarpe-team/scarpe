//! The in-window `ask` and `ask_color` modals, driven without a window (no OS
//! dialog can appear: native dialogs are only ever run by the window layer).

mod common;

use scarpe_native::dialogs::ModalKind;
use scarpe_native::input::Clipboard;
use scarpe_native::protocol::{DialogRequest, Outbox};
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

/// The modal after typing `text` into an `ask` with these extra fields, and the answer Return gives.
fn asked(extra: Value, text: &str) -> (Vec<u8>, Value) {
    let mut rt = windowed_runtime();
    let mut dialog = json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"Password?","default":null});
    dialog.as_object_mut().unwrap().extend(extra.as_object().unwrap().clone());
    send(&mut rt, dialog);
    send(&mut rt, json!({"t":"req","req":2,"op":"type","text":text}));
    let picture = rt.picture(1, 1.0).unwrap().data().to_vec();
    let msgs = send(&mut rt, json!({"t":"req","req":3,"op":"key","key":"\n"}));
    (picture, reply(&msgs, 1).expect("answered")["value"].clone())
}

// Ledger K1: `ask(msg, secret: true)` masks what is typed (manual 1385-1391), as a secret
// edit_line does, and the app still gets the text.
#[test]
fn a_secret_ask_shows_bullets_and_answers_the_text() {
    let (hunter, answer) = asked(json!({"secret": true}), "hunter2");
    let (other, _) = asked(json!({"secret": true}), "iiiiiii");
    assert_eq!(answer, json!("hunter2"));
    assert!(hunter == other, "any seven letters look alike: seven bullets");
    assert!(asked(json!({}), "hunter2").0 != asked(json!({}), "iiiiiii").0, "a plain ask shows them");
}

// Shoes 3's ask put its title on the dialog window; the in-window modal has no title bar, so
// the title heads the panel.
#[test]
fn an_ask_title_heads_the_modal() {
    assert!(asked(json!({"title": "Log in"}), "x").0 != asked(json!({}), "x").0, "the title is drawn");
}

fn position(msgs: &[Value], wanted: impl Fn(&Value) -> bool) -> Option<usize> {
    msgs.iter().position(wanted)
}

/// Ruby blocks on an `ask` until it is answered. A user who closes the window instead of
/// pressing OK or Cancel must still answer it, or Ruby never handles the `closed` behind it.
#[test]
fn closing_the_window_cancels_its_ask_before_saying_closed() {
    let mut rt = windowed_runtime();
    send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"Name?","default":null}));
    rt.window_closed(1);
    let msgs = rt.out.take_captured();
    let answered = position(&msgs, |m| m["t"] == "reply" && m["req"] == json!(1)).expect("the ask was answered");
    let closed = position(&msgs, |m| m["t"] == "closed").expect("Ruby heard the window close");
    assert!(answered < closed, "the answer comes first, so Ruby is free to handle `closed`: {msgs:?}");
    assert_eq!(msgs[answered]["cancelled"], json!(true));
    assert!(rt.views[&1].ui.modal.is_none());
}

/// A `frames` request waits for presents the closed window will never make.
#[test]
fn closing_the_window_fails_its_frames_request() {
    let mut rt = windowed_runtime();
    let msgs = send(&mut rt, json!({"t":"req","req":1,"op":"frames","n":3}));
    assert!(reply(&msgs, 1).is_none(), "frames waits for the window to present");
    rt.window_closed(1);
    let answer = reply(&rt.out.take_captured(), 1).expect("answered when the window closed");
    assert_eq!(answer["error"], json!("window closed"));
}

/// A windowed runtime whose app has been created but not run: Ruby is still inside its body.
fn app_being_built() -> Runtime {
    let opts = Options { headless: false, scale: Some(1.0), fonts: FontMode::Bundled, trace: false };
    let mut rt = Runtime::new(opts, Outbox::capture());
    rt.clipboard = Clipboard::local();
    for line in common::app(400, 300, &[]).lines().filter(|l| !l.contains(r#""t":"run""#)) {
        rt.handle_line(line);
    }
    rt.out.take_captured();
    rt
}

/// What the Runtime asked the window layer to show for `req`.
fn dialog_effect(rt: &Runtime, req: u64) -> Option<DialogRequest> {
    rt.effects.iter().find_map(|e| match e {
        Effect::Dialog { req: r, dialog } if *r == req => Some(dialog.clone()),
        _ => None,
    })
}

/// `Shoes.app { name = ask("Name?") }` asks while the app is being built, before `run`: no
/// window is up to draw a modal in. It used to open the modal on the app with no window,
/// which nobody could see or answer, so the app hung for good.
#[test]
fn ask_before_run_gets_a_window_of_its_own() {
    let mut rt = app_being_built();
    let msgs = send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"Name?","default":null}));
    assert!(reply(&msgs, 1).is_none(), "the answer waits for the user");
    assert!(rt.views[&1].ui.modal.is_none(), "no modal on the app that has no window");
    let dialog = dialog_effect(&rt, 1).expect("the window layer is asked to show it");
    rt.effects.clear();

    // What the window layer does with it: a view of its own, then a window for that view.
    let own = rt.open_standalone(1, &dialog);
    assert!(rt.is_standalone(own));
    let (w, h) = rt.views[&own].size;
    assert!(w == 360.0 && (100.0..=200.0).contains(&h), "sized to the panel: {w}x{h}");
    assert_eq!(rt.app_for(None), Some(1), "automation still means the app, not the dialog");
    rt.type_text(own, "Ann");
    rt.key_input(own, scarpe_native::input::KeyInput::named(scarpe_native::input::Named::Enter));
    let answer = reply(&rt.out.take_captured(), 1).expect("answered");
    assert_eq!((answer["value"].clone(), answer["cancelled"].clone()), (json!("Ann"), json!(false)));
    assert!(!rt.views.contains_key(&own), "the dialog's view goes with its answer");
    assert!(rt.effects.contains(&Effect::CloseWindow(own)), "and so does its window");
}

/// A top-level `ask` before any Shoes.app has no app at all. It used to be answered as a
/// Cancel on the spot, without asking anyone.
#[test]
fn ask_before_any_app_is_shown_too() {
    let opts = Options { headless: false, scale: Some(1.0), fonts: FontMode::Bundled, trace: false };
    let mut rt = Runtime::new(opts, Outbox::capture());
    let msgs = send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask_color","message":"Pick","default":null}));
    assert!(reply(&msgs, 1).is_none(), "nobody has answered yet");
    assert_eq!(dialog_effect(&rt, 1).map(|d| d.kind), Some("ask_color".into()));
}

/// Closing the dialog's own window is a Cancel. Ruby never knew that window, so it hears
/// the answer and no `closed`.
#[test]
fn closing_a_dialogs_own_window_cancels_it_quietly() {
    let mut rt = app_being_built();
    send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"Name?","default":null}));
    let own = rt.open_standalone(1, &dialog_effect(&rt, 1).unwrap());
    rt.window_closed(own);
    let msgs = rt.out.take_captured();
    assert_eq!(reply(&msgs, 1).map(|r| r["cancelled"].clone()), Some(json!(true)));
    assert!(msgs.iter().all(|m| m["t"] != "closed"), "{msgs:?}");
    assert!(!rt.views.contains_key(&own));
}

/// `ask(msg, secret: true, title: "Bank")` (Lacci 5da2de2): the field shows bullets, the answer
/// is still the text, and the title heads the dialog and names its own window.
#[test]
fn a_secret_ask_is_typed_as_bullets_under_its_title() {
    let mut rt = windowed_runtime();
    send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"PIN?","default":null,"secret":true,"title":"Bank"}));
    let modal = rt.views[&1].ui.modal.as_ref().expect("an in-window modal");
    assert_eq!(modal.title.as_deref(), Some("Bank"));
    assert!(matches!(&modal.kind, ModalKind::Ask(field) if field.secret), "the field is secret");
    send(&mut rt, json!({"t":"req","req":2,"op":"type","text":"1234"}));
    let msgs = send(&mut rt, json!({"t":"req","req":3,"op":"key","key":"\n"}));
    assert_eq!(reply(&msgs, 1).expect("answered")["value"], json!("1234"));

    let mut rt = app_being_built();
    send(&mut rt, json!({"t":"req","req":4,"op":"dialog","kind":"ask","message":"PIN?","default":null,"title":"Bank"}));
    let own = rt.open_standalone(4, &dialog_effect(&rt, 4).unwrap());
    assert_eq!(rt.window_title(own), "Bank");
    assert_eq!(rt.window_title(1), "test", "an app's window keeps the app's title");
}

/// The pointer over a dialog's own window is none of the app's business: Ruby's `mouse` keeps
/// reporting its app window, and the dialog leaves nothing behind when it goes.
#[test]
fn a_dialogs_own_window_keeps_to_itself() {
    let mut rt = app_being_built();
    send(&mut rt, json!({"t":"req","req":1,"op":"dialog","kind":"ask","message":"Name?","default":null}));
    let own = rt.open_standalone(1, &dialog_effect(&rt, 1).unwrap());
    rt.pointer_move(own, 30.0, 20.0);
    rt.pointer_down(own, 1);
    let msgs = rt.out.take_captured();
    assert!(msgs.iter().all(|m| m["t"] != "mouse"), "{msgs:?}");
    let views = rt.views.len();
    rt.key_input(own, scarpe_native::input::KeyInput::named(scarpe_native::input::Named::Escape));
    assert_eq!(rt.views.len(), views - 1);
}
