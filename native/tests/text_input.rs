//! Text input quality: undo and redo in edit_line and edit_box, input method commits, and
//! secret fields that never give their text away.

mod common;

use common::{app, create, events, named, Harness};
use serde_json::{json, Value};

/// The `change` values a request caused, in order.
fn changes(h: &mut Harness, op: Value) -> Vec<String> {
    let (evs, reply) = h.req(op);
    assert_eq!(reply["error"], Value::Null, "{reply}");
    named(&events(&evs), "change").iter().map(|e| e.2[0].as_str().unwrap_or_default().to_string()).collect()
}

fn key(h: &mut Harness, name: &str) -> Vec<String> {
    changes(h, json!({"op": "key", "key": name}))
}

fn typed(h: &mut Harness, text: &str) -> Vec<String> {
    changes(h, json!({"op": "type", "text": text}))
}

fn field(kind: &str, props: Value) -> Harness {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, kind, 2, props), create(4, "EditLine", 2, json!({"text": ""}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    h
}

// ---- Undo and redo ----

/// Cmd-Z undoes a run of typing at once, Cmd-Shift-Z (`:alt_Z` by Shoes' name, Q5) redoes
/// it, and a caret move between two runs makes them two steps.
#[test]
fn command_z_undoes_typing_a_run_at_a_time_and_command_shift_z_redoes() {
    let mut h = field("EditLine", json!({"text": ""}));
    typed(&mut h, "hello");
    key(&mut h, "left");
    key(&mut h, "end");
    typed(&mut h, " world");
    assert_eq!(key(&mut h, ":command_z"), ["hello"], "the second run goes at once");
    assert_eq!(key(&mut h, ":command_z"), [""], "then the first");
    assert_eq!(key(&mut h, ":command_z"), Vec::<String>::new(), "nothing is left to undo");
    assert_eq!(key(&mut h, ":command_shift_z"), ["hello"]);
    assert_eq!(key(&mut h, ":command_shift_z"), ["hello world"]);
    assert_eq!(key(&mut h, ":command_shift_z"), Vec::<String>::new(), "nothing is left to redo");
}

/// Off a Mac the same keys are Control-Z, Control-Shift-Z and Control-Y.
#[test]
fn control_z_undoes_and_control_y_redoes() {
    let mut h = field("EditLine", json!({"text": ""}));
    typed(&mut h, "abc");
    assert_eq!(key(&mut h, ":control_z"), [""]);
    assert_eq!(key(&mut h, ":control_y"), ["abc"]);
    assert_eq!(key(&mut h, ":control_z"), [""]);
    assert_eq!(key(&mut h, ":control_shift_z"), ["abc"]);
}

/// A run of deleting is a step of its own, and a paste is one step whatever it holds.
#[test]
fn deleting_and_pasting_are_steps_of_their_own() {
    let mut h = field("EditBox", json!({"text": ""}));
    typed(&mut h, "one\ntwo");
    key(&mut h, "backspace");
    key(&mut h, "backspace");
    assert_eq!(key(&mut h, ":control_z"), ["one\ntwo"], "both backspaces come back together");
    key(&mut h, ":control_a");
    key(&mut h, ":control_c");
    key(&mut h, "end");
    assert_eq!(key(&mut h, ":control_v"), ["one\ntwoone\ntwo"]);
    assert_eq!(key(&mut h, ":control_z"), ["one\ntwo"], "the paste goes in one step");
}

/// The caret and selection come back with the text.
#[test]
fn undo_puts_the_caret_back_where_the_edit_was() {
    let mut h = field("EditLine", json!({"text": ""}));
    typed(&mut h, "abcd");
    key(&mut h, "left");
    key(&mut h, "left");
    key(&mut h, "backspace");
    assert_eq!(key(&mut h, ":control_z"), ["abcd"]);
    assert_eq!(typed(&mut h, "X"), ["abXcd"], "typing goes on from where the deleted letter was");
}

/// Lacci echoes every edit back as `text`; the echo keeps the history. Text the app sets
/// itself starts a new one, as a browser's field does.
#[test]
fn an_echo_keeps_the_history_and_text_the_app_sets_clears_it() {
    let mut h = field("EditLine", json!({"text": ""}));
    typed(&mut h, "abc");
    h.feed(&format!("{}\n", json!({"t": "props", "id": 3, "props": {"text": "abc"}})));
    assert_eq!(key(&mut h, ":control_z"), [""], "the echo changed nothing");
    typed(&mut h, "abc");
    h.feed(&format!("{}\n", json!({"t": "props", "id": 3, "props": {"text": "reset"}})));
    assert_eq!(key(&mut h, ":control_z"), Vec::<String>::new());
    assert_eq!(h.node(|n| n["id"] == 3)["text"], json!("reset"));
}

/// Echoes trail the keys: a `type` request types a whole word before Ruby sees its first
/// `change`, so "h", "he", "hel"... arrive after "hello". Each late echo is still our own
/// edit: it keeps the caret where it is and the history whole.
#[test]
fn late_echoes_keep_the_caret_and_the_history() {
    let mut h = field("EditLine", json!({"text": ""}));
    typed(&mut h, "hello");
    key(&mut h, "left");
    for echo in ["h", "he", "hel", "hell", "hello"] {
        h.feed(&format!("{}\n", json!({"t": "props", "id": 3, "props": {"text": echo}})));
    }
    assert_eq!(typed(&mut h, "X"), ["hellXo"], "the caret stayed before the o");
    assert_eq!(key(&mut h, ":control_z"), ["hello"]);
    assert_eq!(key(&mut h, ":control_z"), [""], "the history survived the echoes");
}

/// A readonly field keeps its text through Cmd-Z, even with edits from before it was locked.
#[test]
fn a_readonly_field_refuses_undo() {
    let mut h = field("EditLine", json!({"text": ""}));
    typed(&mut h, "abc");
    h.feed(&format!("{}\n", json!({"t": "props", "id": 3, "props": {"state": "readonly"}})));
    assert_eq!(key(&mut h, ":control_z"), Vec::<String>::new());
    assert_eq!(h.node(|n| n["id"] == 3)["text"], json!("abc"));
}

// ---- Secret fields ----

/// Copy and cut in a secret field give the clipboard nothing, and cut keeps the text.
#[test]
fn a_secret_field_never_copies_or_cuts() {
    let mut h = field("EditLine", json!({"text": "", "secret": true}));
    typed(&mut h, "hunter2");
    h.value(json!({"op": "click", "target": {"id": 4}}));
    typed(&mut h, "before");
    key(&mut h, ":control_a");
    key(&mut h, ":control_c");

    h.value(json!({"op": "click", "target": {"id": 3}}));
    key(&mut h, ":control_a");
    key(&mut h, ":command_c");
    assert_eq!(key(&mut h, ":command_x"), Vec::<String>::new(), "cut leaves the secret where it is");

    h.value(json!({"op": "click", "target": {"id": 4}}));
    key(&mut h, "end");
    assert_eq!(key(&mut h, ":control_v"), ["beforebefore"], "the clipboard still holds what was copied before");
}

/// Automation reads a secret field as a person does: bullets. Its text finds nothing.
#[test]
fn a_secret_field_shows_automation_bullets() {
    let mut h = field("EditLine", json!({"text": "", "secret": true}));
    typed(&mut h, "hunter2");
    assert_eq!(h.node(|n| n["id"] == 3)["text"], json!("\u{2022}".repeat(7)));
    let (_, reply) = h.req(json!({"op": "click", "target": {"text": "hunter2"}}));
    assert!(reply["error"].as_str().is_some_and(|e| e.contains("no visible drawable")), "{reply}");
}

/// A secret edit_line given text with a newline and multi-byte letters: selecting in it
/// counted bytes across the whole text and sliced inside a letter.
#[test]
fn a_secret_field_with_a_newline_selects_without_panicking() {
    let mut h = field("EditLine", json!({"text": "ab\n\u{e9}\u{e9}", "secret": true}));
    key(&mut h, ":control_end");
    key(&mut h, "shift_left");
    key(&mut h, "shift_home");
    let path = std::env::temp_dir().join(format!("scarpe-secret-{}.png", std::process::id()));
    h.value(json!({"op": "snapshot", "path": path.display().to_string()}));
    let _ = std::fs::remove_file(path);
    assert_eq!(key(&mut h, "backspace").len(), 1, "and the selection deletes");
}

// ---- Input methods ----

/// An input method's commit ("é" from a dead key, a word of Japanese) goes into the focused
/// field as one edit and one `change`, and undoes with the typing around it.
#[test]
fn an_input_method_commit_is_one_edit() {
    let mut h = field("EditLine", json!({"text": ""}));
    typed(&mut h, "caf");
    h.rt.ime_commit(1, "é");
    h.rt.ime_commit(1, "日本語");
    let msgs = h.rt.out.take_captured();
    let values: Vec<Value> = named(&events(&msgs), "change").iter().map(|e| e.2.clone()).collect();
    assert_eq!(values, vec![json!(["café"]), json!(["café日本語"])]);
    assert_eq!(key(&mut h, ":control_z"), [""], "one run of typing");
}

/// With no field focused a commit arrives as keypresses; a readonly field refuses it.
#[test]
fn an_input_method_commit_without_a_field_is_keypresses() {
    let mut h = Harness::new();
    h.feed(&app(300, 100, &[
        create(3, "EditLine", 2, json!({"text": "fixed", "state": "readonly"})),
        create(5, "SubscriptionItem", 2, json!({"shoes_api_name": "keypress"})),
    ]));
    h.rt.ime_commit(1, "日本");
    let keys: Vec<Value> = named(&events(&h.rt.out.take_captured()), "keypress").iter().map(|e| e.2.clone()).collect();
    assert_eq!(keys, vec![json!(["日"]), json!(["本"])]);

    h.value(json!({"op": "click", "target": {"id": 3}}));
    h.rt.ime_commit(1, "x");
    assert!(named(&events(&h.rt.out.take_captured()), "change").is_empty());
    assert_eq!(h.node(|n| n["id"] == 3)["text"], json!("fixed"));
}

/// The input method is on beside the caret of a focused field that takes text, and off for
/// secret, readonly or unfocused fields.
#[test]
fn the_input_method_follows_the_focused_fields_caret() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "EditLine", 2, json!({"text": "", "left": 20, "top": 30})),
        create(4, "EditLine", 2, json!({"text": "", "secret": true, "left": 20, "top": 80})),
        create(5, "EditLine", 2, json!({"text": "x", "state": "readonly", "left": 20, "top": 130})),
    ]));
    assert_eq!(h.rt.text_input_area(1), None, "nothing has focus");
    h.value(json!({"op": "click", "target": {"id": 3}}));
    let caret = h.rt.text_input_area(1).expect("a caret to put the candidates by");
    assert!(caret.x >= 20.0 && caret.x < 40.0 && caret.y >= 30.0 && caret.y < 58.0, "{caret:?}");
    typed(&mut h, "abc");
    assert!(h.rt.text_input_area(1).unwrap().x > caret.x, "it moves with the caret");
    h.value(json!({"op": "click", "target": {"id": 4}}));
    assert_eq!(h.rt.text_input_area(1), None, "a secret field takes keys only");
    h.value(json!({"op": "click", "target": {"id": 5}}));
    assert_eq!(h.rt.text_input_area(1), None, "a readonly field takes nothing");
}

// ---- Fonts ----

/// The dark pixels of a field's text, at 1x, as (x, y) points.
fn ink(h: &mut Harness, id: i64) -> Vec<(i64, i64)> {
    let n = h.node(|n| n["id"] == id);
    let (x, y, w, hh) = (n["x"].as_f64().unwrap(), n["y"].as_f64().unwrap(), n["w"].as_f64().unwrap(), n["h"].as_f64().unwrap());
    let mut dark = Vec::new();
    for py in (y as i64 + 3)..((y + hh) as i64 - 3) {
        for px in (x as i64 + 3)..((x + w) as i64 - 3) {
            let c = h.value(json!({"op": "pixel", "x": px, "y": py}));
            if c.as_array().unwrap()[..3].iter().map(|v| v.as_i64().unwrap()).sum::<i64>() < 300 {
                dark.push((px, py));
            }
        }
    }
    dark
}

/// How far right the upper half of some ink sits over its lower half, in pixels: about
/// nothing for upright letters, and a pixel or more for slanted ones.
fn lean(ink: &[(i64, i64)]) -> f64 {
    let mid = ink.iter().map(|p| p.1).sum::<i64>() as f64 / ink.len() as f64;
    let mean_x = |upper: bool| {
        let xs: Vec<f64> = ink.iter().filter(|p| ((p.1 as f64) < mid) == upper).map(|p| p.0 as f64).collect();
        xs.iter().sum::<f64>() / xs.len() as f64
    };
    mean_x(true) - mean_x(false)
}

/// `font: "bold 16px"` draws a field's text bold, and `"italic 16px"` slanted, as they do a
/// para's (ledger G11). The fields took only the family and size from the string.
#[test]
fn a_fields_font_keeps_its_weight_and_slant() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "EditLine", 2, json!({"text": "Weight", "font": "16px", "width": 120})),
        create(4, "EditLine", 2, json!({"text": "Weight", "font": "bold 16px", "width": 120})),
        create(5, "EditLine", 2, json!({"text": "Weight", "font": "italic 16px", "width": 120})),
    ]));
    let (plain, bold, italic) = (ink(&mut h, 3), ink(&mut h, 4), ink(&mut h, 5));
    assert!(bold.len() * 10 > plain.len() * 13, "bold puts down at least 30% more ink: {} against {}", plain.len(), bold.len());
    assert!(lean(&italic) > lean(&plain) + 0.5, "italic leans right: {:.2} against {:.2}", lean(&plain), lean(&italic));
}

// ---- Placeholders ----

/// Red hint pixels, excluding the default frame, caret and text colours.
fn hint_ink(h: &mut Harness) -> Vec<(usize, usize)> {
    let picture = h.rt.picture(1, 1.0).unwrap();
    let width = picture.width() as usize;
    picture.pixels().iter().enumerate().filter_map(|(i, p)| {
        (p.red() > p.green().saturating_add(40) && p.red() > p.blue().saturating_add(40)).then_some((i % width, i / width))
    }).collect()
}

#[test]
fn a_placeholder_shows_only_while_the_field_is_empty() {
    for secret in [false, true] {
        let mut h = field("EditLine", json!({"placeholder": "Search books", "placeholder_color": "#d02020", "secret": secret}));
        let hint = hint_ink(&mut h);
        assert!(!hint.is_empty(), "the empty field shows its hint");
        assert_eq!(h.node(|n| n["id"] == 3)["text"], json!(""));
        assert_eq!(typed(&mut h, "book"), ["b", "bo", "boo", "book"]);
        assert!(hint_ink(&mut h).is_empty(), "typing hides the hint before Ruby echoes the text");
        assert_eq!(key(&mut h, ":control_z"), [""]);
        assert_eq!(hint_ink(&mut h), hint, "undo restores the empty field's hint");
        assert_eq!(key(&mut h, ":control_y"), ["book"]);
        assert!(hint_ink(&mut h).is_empty());
        key(&mut h, ":control_a");
        assert_eq!(key(&mut h, "backspace"), [""]);
        assert_eq!(hint_ink(&mut h), hint);
    }
}

#[test]
fn a_placeholder_never_becomes_a_value_clipboard_text_or_undo_step() {
    let mut h = field("EditLine", json!({"placeholder": "Search books", "placeholder_color": "#d02020"}));
    assert!(!hint_ink(&mut h).is_empty());
    assert_eq!(h.value(json!({"op": "a11y"}))["children"][0]["value"], json!(""));
    h.value(json!({"op": "click", "target": {"id": 4}}));
    typed(&mut h, "kept");
    key(&mut h, ":control_a");
    key(&mut h, ":control_c");
    h.value(json!({"op": "click", "target": {"id": 3}}));
    key(&mut h, ":control_a");
    key(&mut h, ":control_c");
    assert!(key(&mut h, ":control_z").is_empty());
    assert_eq!(h.node(|n| n["id"] == 3)["text"], json!(""));
    h.value(json!({"op": "click", "target": {"id": 4}}));
    key(&mut h, ":control_end");
    assert_eq!(key(&mut h, ":control_v"), ["keptkept"], "copying an empty field leaves the clipboard alone");
}

#[test]
fn placeholder_text_and_colour_can_change_or_be_cleared() {
    let mut h = field("EditLine", json!({"text": ""}));
    let blank = h.rt.picture(1, 1.0).unwrap();
    h.feed(&json!({"t": "props", "id": 3, "props": {"placeholder": "Search books"}}).to_string());
    let muted = h.rt.picture(1, 1.0).unwrap();
    assert!(muted.data() != blank.data(), "there is a default hint colour");
    h.feed(&json!({"t": "props", "id": 3, "props": {"placeholder_color": "#d02020"}}).to_string());
    let first = hint_ink(&mut h);
    assert!(!first.is_empty(), "the explicit colour paints the hint");
    h.feed(&json!({"t": "props", "id": 3, "props": {"placeholder": "Author"}}).to_string());
    assert_ne!(hint_ink(&mut h), first, "changing the hint repaints it");
    h.feed(&json!({"t": "props", "id": 3, "props": {"placeholder": "Search books", "placeholder_color": null}}).to_string());
    assert!(h.rt.picture(1, 1.0).unwrap().data() == muted.data(), "clearing the colour restores the default");
    for props in [json!({"placeholder_color": "#00000000"}), json!({"placeholder": ""}), json!({"placeholder": null})] {
        h.feed(&json!({"t": "props", "id": 3, "props": {"placeholder": "Search books", "placeholder_color": "#d02020"}}).to_string());
        h.feed(&json!({"t": "props", "id": 3, "props": props}).to_string());
        assert!(h.rt.picture(1, 1.0).unwrap().data() == blank.data(), "an invisible or absent hint paints nothing");
    }
}

#[test]
fn placeholders_use_the_fields_font_and_baseline() {
    for font in ["13px", "Fira Mono bold 18px", "Fira Mono italic 18px"] {
        let mut actual = field("EditLine", json!({"text": "Hint", "font": font, "height": 44, "stroke": "#d02020"}));
        actual.value(json!({"op": "click", "target": {"id": 4}}));
        let letters = hint_ink(&mut actual);
        assert!(!letters.is_empty());
        let mut hint = field("EditLine", json!({"placeholder": "Hint", "font": font, "height": 44, "placeholder_color": "#d02020"}));
        assert_eq!(hint_ink(&mut hint), letters, "{font}: the hint uses the same face, size and baseline as typed text");
    }
}

#[test]
fn placeholders_follow_left_center_and_right_alignment() {
    for hint in ["Search", "ابحث"] {
        let mut h = field("EditLine", json!({"placeholder": hint, "placeholder_color": "#d02020", "width": 240}));
        for (align, left, right) in [(Value::Null, 8, 70), (json!("center"), 80, 160), (json!("right"), 160, 232)] {
            h.feed(&json!({"t": "props", "id": 3, "props": {"align": align}}).to_string());
            let ink = hint_ink(&mut h);
            assert!(!ink.is_empty());
            assert!(ink.iter().all(|&(x, _)| x >= left && x < right), "{hint}, {align}: the hint follows the field's alignment");
        }
    }
}

#[test]
fn long_placeholders_stay_inside_the_field_and_ancestor_clip() {
    for hint in ["Search books ".repeat(20), "ابحث عن كتاب ".repeat(20), "Search\nsecond line".to_string()] {
        let mut h = field("EditLine", json!({"placeholder": hint, "placeholder_color": "#d02020", "width": 80, "height": 56}));
        let ink = hint_ink(&mut h);
        assert!(!ink.is_empty());
        assert!(ink.iter().all(|&(x, y)| (8..72).contains(&x) && (20..36).contains(&y)), "the hint is clipped to the single text line");
    }
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Stack", 2, json!({"width": 100, "height": 16, "scroll": true})),
        create(4, "EditLine", 3, json!({"placeholder": "Search books everywhere", "placeholder_color": "#d02020", "width": 200})),
        create(5, "EditLine", 3, json!({"placeholder": "Hidden", "placeholder_color": "#d02020", "width": 200, "top": 40})),
    ]));
    let ink = hint_ink(&mut h);
    assert!(!ink.is_empty(), "the partly clipped field still paints");
    assert!(ink.iter().all(|&(x, y)| x < 100 && y < 16), "hints never paint outside the scroll area");
}
