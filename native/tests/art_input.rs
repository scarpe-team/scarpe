//! Art and input (the M2 art-input lane): transforms, shape groups, image canvases,
//! masks, keys, coordinates, windows, tooltips and cursors, through the protocol.

mod common;

use common::{app, create, events, named, Harness};
use serde_json::{json, Value};

const WHITE: [i64; 3] = [255, 255, 255];
const RED: [i64; 3] = [255, 0, 0];
const BLACK: [i64; 3] = [0, 0, 0];

fn pixel(h: &mut Harness, x: f64, y: f64) -> [i64; 4] {
    let v = h.value(json!({"op": "pixel", "x": x, "y": y}));
    let c: Vec<i64> = v.as_array().unwrap().iter().map(|c| c.as_i64().unwrap()).collect();
    [c[0], c[1], c[2], c[3]]
}

fn rgb(h: &mut Harness, x: f64, y: f64) -> [i64; 3] {
    let [r, g, b, _] = pixel(h, x, y);
    [r, g, b]
}

fn near(a: [i64; 3], b: [i64; 3]) -> bool {
    a.iter().zip(b).all(|(x, y)| (x - y).abs() <= 20)
}

fn art(id: i64, kind: &str, parent: i64, props: Value) -> Value {
    create(id, kind, parent, props)
}

// ---- Transforms and caps (ledger E10, contract b) ----

/// `fill red; nostroke; rotate 90; rect 100, 100, 60, 20` (spec art.transform).
#[test]
fn rotate_turns_a_shape_about_its_corner() {
    let mut h = Harness::new();
    let dc = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "rotate": 90});
    h.feed(&app(300, 300, &[art(3, "Rect", 2, json!({"left": 100, "top": 100, "width": 60, "height": 20, "draw_context": dc}))]));
    assert_eq!(rgb(&mut h, 130.0, 110.0), WHITE, "the bar left where it was drawn");
    assert_eq!(rgb(&mut h, 130.0, 85.0), WHITE, "it did not turn about its centre");
    assert_eq!(rgb(&mut h, 110.0, 70.0), RED, "it turned counter-clockwise about (100, 100)");
}

#[test]
fn transform_center_turns_a_shape_about_its_middle() {
    let mut h = Harness::new();
    let dc = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "rotate": 90, "transform": "center"});
    h.feed(&app(300, 300, &[art(3, "Rect", 2, json!({"left": 100, "top": 100, "width": 60, "height": 20, "draw_context": dc}))]));
    assert_eq!(rgb(&mut h, 130.0, 85.0), RED);
    assert_eq!(rgb(&mut h, 130.0, 135.0), RED);
    assert_eq!(rgb(&mut h, 105.0, 110.0), WHITE);
    let rect = h.node(|n| n["id"] == 3);
    assert_eq!((rect["x"].as_f64(), rect["y"].as_f64(), rect["w"].as_f64(), rect["h"].as_f64()), (Some(120.0), Some(80.0), Some(20.0), Some(60.0)), "the layout box follows the turn");
}

/// manual 1862-1868 (spec art.translate): a shape drawn at (50, 60) after translate(10, 20).
#[test]
fn translate_moves_shapes_and_their_boxes() {
    let mut h = Harness::new();
    let dc = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}, "translate": [10, 20]});
    h.feed(&app(200, 200, &[art(3, "Rect", 2, json!({"left": 50, "top": 60, "width": 20, "height": 20, "draw_context": dc}))]));
    assert_eq!(rgb(&mut h, 75.0, 95.0), RED);
    assert_eq!(rgb(&mut h, 55.0, 65.0), WHITE);
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 75, "y": 95}}));
    assert!(named(&events(&evs), "click").is_empty());
    assert_eq!(h.node(|n| n["id"] == 3)["x"], json!(60.0), "hit-testing sees it where it is drawn");
}

fn capped_line(cap: &str) -> Harness {
    let mut h = Harness::new();
    let dc = json!({"stroke": {"rgba": [0, 0, 0, 255]}, "strokewidth": 20, "cap": cap});
    h.feed(&app(300, 200, &[art(3, "Line", 2, json!({"left": 50, "top": 100, "x2": 150, "y2": 100, "draw_context": dc}))]));
    h
}

/// manual 1676-1680: `:curve` is round, `:project` square and longer, `:rect` flat.
#[test]
fn caps_round_project_or_stop_flat() {
    let mut h = capped_line("curve");
    assert!(near(rgb(&mut h, 156.0, 100.0), BLACK), "a round end reaches past the end point");
    assert_eq!(rgb(&mut h, 157.0, 108.0), WHITE, "but not into the corner");

    let mut h = capped_line("project");
    assert!(near(rgb(&mut h, 157.0, 107.0), BLACK), "a projecting end is square");
    assert!(near(rgb(&mut h, 43.0, 100.0), BLACK), "at both ends");
    assert_eq!(rgb(&mut h, 163.0, 100.0), WHITE, "half the stroke width and no more");

    let mut h = capped_line("rect");
    assert!(near(rgb(&mut h, 148.0, 108.0), BLACK));
    assert_eq!(rgb(&mut h, 153.0, 100.0), WHITE, "a flat end stops at the end point");
}

// ---- Shape blocks (ledger E7, M21) ----

/// A Shape (id 3) holding `members`, each created inside it the way Lacci does.
fn shape_with(shape_props: Value, members: &[(i64, &str, Value)]) -> Harness {
    let mut body = vec![art(3, "Shape", 2, shape_props)];
    body.extend(members.iter().map(|(id, kind, props)| art(*id, kind, 3, props.clone())));
    let mut h = Harness::new();
    h.feed(&app(300, 200, &body));
    h
}

/// The Rules chapter (manual 392-408): ovals combined in a shape are one shape, so a
/// translucent fill does not build up where they overlap (nested_ovals.rb went black).
#[test]
fn art_in_a_shape_block_is_filled_once() {
    let grey = json!({"fill": {"rgba": [0, 0, 0, 128]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = shape_with(json!({"shape_commands": [], "draw_context": grey}), &[
        (4, "Rect", json!({"left": 0, "top": 0, "width": 100, "height": 100, "draw_context": red})),
        (5, "Rect", json!({"left": 50, "top": 0, "width": 100, "height": 100, "draw_context": red})),
    ]);
    let single = rgb(&mut h, 25.0, 50.0);
    let overlap = rgb(&mut h, 75.0, 50.0);
    assert!(single[0] > 100 && single[0] < 160 && single[0] == single[1], "the shape's own grey, not its members' red: {single:?}");
    assert_eq!(overlap, single, "the overlap is filled once");
}

#[test]
fn a_shape_block_strokes_every_outline_it_holds() {
    let outline = json!({"fill": {"rgba": [0, 0, 0, 0]}, "stroke": {"rgba": [0, 0, 0, 255]}, "strokewidth": 2});
    let mut h = shape_with(json!({"shape_commands": [], "draw_context": outline.clone()}), &[
        (4, "Oval", json!({"left": 20, "top": 20, "width": 100, "height": 100, "draw_context": outline.clone()})),
        (5, "Oval", json!({"left": 160, "top": 20, "width": 100, "height": 100, "draw_context": outline})),
    ]);
    assert!(near(rgb(&mut h, 20.5, 70.0), BLACK), "the first outline");
    assert!(near(rgb(&mut h, 259.5, 70.0), BLACK), "the second outline");
    assert_eq!(rgb(&mut h, 70.0, 70.0), WHITE, "no fill");
    assert_eq!(rgb(&mut h, 140.0, 70.0), WHITE, "and no line joining them");
}

/// `shape(left, top) { oval 0, 0, 20 }`: the art is measured from the shape's corner,
/// and the shape's box holds it all, so clicks and culling find it.
#[test]
fn a_shape_block_box_holds_its_art_from_its_left_top() {
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = shape_with(json!({"left": 100, "top": 100, "shape_commands": [], "draw_context": red.clone()}), &[
        (4, "Oval", json!({"left": 0, "top": 0, "width": 20, "height": 20, "draw_context": red.clone()})),
        (5, "Rect", json!({"left": 50, "top": 0, "width": 10, "height": 10, "draw_context": red})),
    ]);
    assert_eq!(rgb(&mut h, 110.0, 110.0), RED);
    assert_eq!(rgb(&mut h, 155.0, 105.0), RED);
    let shape = h.node(|n| n["id"] == 3);
    assert_eq!((shape["x"].clone(), shape["y"].clone(), shape["w"].clone(), shape["h"].clone()), (json!(100.0), json!(100.0), json!(60.0), json!(20.0)));
}

// ---- image(w, h) { ... } is a canvas (ledger E9, contract c) ----

/// An image block's art arrives as children of the Image node, in image-local
/// coordinates, and is clipped to the image's box.
#[test]
fn an_image_block_draws_its_art_inside_the_image() {
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[
        create(3, "Image", 2, json!({"url": "", "left": 100, "top": 100, "width": 100, "height": 100})),
        art(4, "Oval", 3, json!({"left": 0, "top": 0, "width": 50, "height": 50, "draw_context": red.clone()})),
        art(5, "Rect", 3, json!({"left": 80, "top": 80, "width": 50, "height": 50, "draw_context": red})),
    ]));
    assert_eq!(rgb(&mut h, 125.0, 125.0), RED, "the oval sits at the image's corner");
    assert_eq!(rgb(&mut h, 25.0, 25.0), WHITE, "not at the window's");
    assert_eq!(rgb(&mut h, 190.0, 190.0), RED, "the rect shows inside the image");
    assert_eq!(rgb(&mut h, 220.0, 220.0), WHITE, "and is cut off at its edge");
}

/// shoes-contrib simple-sphere.rb nests images with only a position inside a sized one:
/// they fill it. Text in a block lays out in the image like a flow.
#[test]
fn a_blank_image_inside_an_image_block_fills_it() {
    let red = json!({"fill": {"rgba": [255, 0, 0, 255]}, "stroke": {"rgba": [0, 0, 0, 0]}});
    let mut h = Harness::new();
    h.feed(&app(300, 300, &[
        create(3, "Image", 2, json!({"url": "", "left": 50, "top": 30, "width": 200, "height": 150})),
        create(4, "Image", 3, json!({"url": "", "left": 0, "top": 100})),
        art(5, "Rect", 4, json!({"left": 0, "top": 0, "width": 300, "height": 300, "draw_context": red})),
        create(6, "Para", 3, json!({"text_items": ["inside"]})),
    ]));
    let inner = h.node(|n| n["id"] == 4);
    assert_eq!((inner["x"].clone(), inner["y"].clone(), inner["w"].clone()), (json!(50.0), json!(130.0), json!(200.0)));
    assert_eq!(rgb(&mut h, 60.0, 170.0), RED, "the nested image's art shows");
    assert_eq!(rgb(&mut h, 60.0, 190.0), WHITE, "clipped by the outer image's bottom edge");
    let para = h.node(|n| n["id"] == 6);
    // Text blocks keep Shoes 3's 4 px margins (ledger C9).
    assert_eq!((para["x"].clone(), para["y"].clone()), (json!(54.0), json!(34.0)), "text starts at the image's corner");
}

// ---- Keys (ledger H1, Q5) ----

fn key(h: &mut Harness, name: &str) -> Vec<(String, Value, Value)> {
    let (evs, reply) = h.req(json!({"op": "key", "key": name}));
    assert_eq!(reply["error"], Value::Null, "{reply}");
    events(&evs)
}

/// manual 3221-3224 (spec list_box.focus): the arrows pick the other choices.
#[test]
fn arrows_on_a_focused_list_box_choose_without_the_popup() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "ListBox", 2, json!({"items": ["Grapes", "Pears", "Apricots"], "chosen": "Grapes"}))]));
    h.feed("{\"t\":\"focus\",\"id\":3}\n");
    let evs = key(&mut h, "down");
    assert_eq!(named(&evs, "change").iter().map(|e| e.2.clone()).collect::<Vec<_>>(), vec![json!(["Pears"])]);
    assert!(h.rt.views[&1].ui.popup.is_none(), "no popup");
    h.feed("{\"t\":\"props\",\"id\":3,\"props\":{\"chosen\":\"Pears\"}}\n");
    assert_eq!(named(&key(&mut h, "up"), "change")[0].2, json!(["Grapes"]));
    h.feed("{\"t\":\"props\",\"id\":3,\"props\":{\"chosen\":\"Grapes\"}}\n");
    assert!(named(&key(&mut h, "up"), "change").is_empty(), "nothing before the first");
    key(&mut h, "\n");
    assert!(h.rt.views[&1].ui.popup.is_some(), "Return still opens the popup");
}

/// Command edits like Control in a text field, while keypress names it alt_ (Q5).
#[test]
fn command_a_selects_all_in_a_field() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "EditLine", 2, json!({"text": "hello"}))]));
    h.value(json!({"op": "click", "target": {"id": 3}}));
    key(&mut h, ":command_a");
    let (evs, _) = h.req(json!({"op": "type", "text": "x"}));
    assert_eq!(named(&events(&evs), "change")[0].2, json!(["x"]), "the whole text was selected and replaced");
}

// ---- Coordinates of slot events (ledger H3, Q4) ----

/// Q4 (27 Sep 2026): a stack nested at (100, 100) hears a click at window (150, 120) as
/// (150, 120), like Shoes 3, and so do its release and motion blocks.
#[test]
fn slot_click_release_and_motion_use_window_coordinates() {
    let mut h = Harness::new();
    h.feed(&app(400, 300, &[
        create(3, "Stack", 2, json!({"left": 100, "top": 100, "width": 200, "height": 100})),
        create(4, "SubscriptionItem", 3, json!({"shoes_api_name": "click"})),
        create(5, "SubscriptionItem", 3, json!({"shoes_api_name": "release"})),
        create(6, "SubscriptionItem", 3, json!({"shoes_api_name": "motion"})),
    ]));
    let (evs, _) = h.req(json!({"op": "click", "target": {"x": 150, "y": 120}}));
    let evs = events(&evs);
    assert_eq!(named(&evs, "click")[0].2, json!([1, 150, 120]));
    assert_eq!(named(&evs, "release")[0].2, json!([1, 150, 120]));
    assert_eq!(named(&evs, "motion")[0].2, json!([150, 120, false, false]));
}

// ---- Several windows ----

/// A second app (9, root 10) beside the harness's app 1, with a button and a link.
fn second_window(h: &mut Harness) {
    let lines = [
        json!({"t":"create","id":10,"kind":"DocumentRoot","parent":null,"props":{}}),
        json!({"t":"create","id":9,"kind":"App","parent":null,"props":{"width":200,"height":100},"doc_root":10}),
        create(11, "Button", 10, json!({"text": "Close me"})),
        json!({"t":"create","id":12,"kind":"Link","parent":null,"props":{"text_items":["more"]}}),
        create(13, "Para", 10, json!({"text_items": [12]})),
        json!({"t":"run","app":9}),
        json!({"t":"flush"}),
    ];
    h.feed(&lines.iter().map(|l| format!("{l}\n")).collect::<String>());
}

/// spec app.close: a click by id goes to the window the drawable is in, whichever
/// app the request names.
#[test]
fn a_click_by_id_goes_to_the_drawables_own_window() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Button", 2, json!({"text": "Another"}))]));
    second_window(&mut h);
    for target in [11, 12] {
        let (evs, reply) = h.req(json!({"op": "click", "target": {"id": target}, "app": 1}));
        assert_eq!(reply["error"], Value::Null, "{reply}");
        assert_eq!(named(&events(&evs), "click")[0].1, json!(target));
    }
    assert_eq!(h.rt.active_app, Some(9), "that window is now the active one");
}

// ---- Masks ----

/// shoes-contrib art/mask.rb: a slot's other contents show only where its mask draws,
/// and the window's white shows everywhere else (Shoes 3, s3_canvas.c:531-613).
#[test]
fn a_mask_shows_its_slots_contents_only_where_it_draws() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Background", 2, json!({"fill": {"rgba": [255, 0, 0, 255]}})),
        create(4, "Mask", 2, json!({})),
        art(5, "Rect", 4, json!({"left": 50, "top": 50, "width": 100, "height": 100, "draw_context": {"fill": {"rgba": [0, 0, 0, 255]}}})),
    ]));
    assert_eq!(rgb(&mut h, 100.0, 100.0), RED, "the background shows through the mask's rect");
    assert_eq!(rgb(&mut h, 20.0, 20.0), WHITE, "and nowhere else");
    assert_eq!(rgb(&mut h, 180.0, 180.0), WHITE);
}

/// A mask is a slot in the flow, like Shoes 3's canvas: its text lays out at its corner.
#[test]
fn a_mask_lays_out_like_a_flow() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Para", 2, json!({"text_items": ["before"], "width": 300})),
        create(4, "Mask", 2, json!({})),
        create(5, "Para", 4, json!({"text_items": ["Shoes"], "size": 48})),
    ]));
    let mask = h.node(|n| n["id"] == 4);
    let para = h.node(|n| n["id"] == 5);
    assert_eq!((mask["x"].clone(), mask["w"].clone()), (json!(0.0), json!(300.0)));
    // Its text sits in its corner, inside the text's 4 px margins (ledger C9).
    let inset = |key: &str| json!(mask[key].as_f64().unwrap() + 4.0);
    assert_eq!((para["x"].clone(), para["y"].clone()), (inset("x"), inset("y")));
    assert!(mask["y"].as_f64().unwrap() > 10.0, "after the para before it");
}

// ---- Tooltips ----

/// A snapshot of the app as an image, to look at a region without one request per pixel.
fn picture(h: &mut Harness) -> image::RgbaImage {
    let path = std::env::temp_dir().join(format!("scarpe-art-input-{}-{}.png", std::process::id(), h.rt.views[&1].frames));
    h.value(json!({"op": "snapshot", "path": path.to_string_lossy(), "scale": 1}));
    let img = image::open(&path).expect("snapshot").to_rgba8();
    let _ = std::fs::remove_file(&path);
    img
}

/// Dark pixels (text ink) inside a region.
fn ink(img: &image::RgbaImage, x0: u32, y0: u32, x1: u32, y1: u32) -> usize {
    (y0..y1).flat_map(|y| (x0..x1).map(move |x| (x, y))).filter(|&(x, y)| img.get_pixel(x, y).0[0] < 110).count()
}

/// Shoes 3.3's `tooltip:` (shoes3-tests/tooltips.rb): resting on a control shows its text
/// in a bubble below the pointer; a press hides it.
#[test]
fn a_tooltip_shows_under_the_pointer_and_a_press_hides_it() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Button", 2, json!({"text": "Quit", "tooltip": "kill Shoes"}))]));
    let quiet = picture(&mut h);
    assert_eq!(ink(&quiet, 20, 40, 120, 70), 0, "nothing below the button yet");

    h.value(json!({"op": "mouse", "action": "move", "x": 20, "y": 14}));
    let hovering = picture(&mut h);
    assert!(ink(&hovering, 20, 40, 120, 70) > 20, "the bubble's text shows below the pointer");
    let tip = h.rt.views[&1].ui.tooltip.clone().expect("a tooltip");
    assert_eq!((tip.owner, tip.text.as_str()), (3, "kill Shoes"));

    h.value(json!({"op": "mouse", "action": "down", "x": 20, "y": 14}));
    h.value(json!({"op": "mouse", "action": "up", "x": 20, "y": 14}));
    assert_eq!(ink(&picture(&mut h), 20, 40, 120, 70), 0, "gone after a press");

    h.value(json!({"op": "mouse", "action": "move", "x": 250, "y": 150}));
    assert!(h.rt.views[&1].ui.tooltip.is_none(), "and forgotten once the pointer leaves");
}

// ---- Cursors and App opacity ----

fn cursor_at(h: &mut Harness, x: f64, y: f64) -> scarpe_native::input::CursorShape {
    h.value(json!({"op": "mouse", "action": "move", "x": x, "y": y}));
    h.rt.views[&1].ui.cursor
}

/// DESIGN look and feel: a pointing hand over links and buttons, an I-beam over text
/// fields; a drawable's `cursor` style wins, and the App's (`app.cursor = :watch_cursor`,
/// shoes3-tests/cursor/c1.rb) covers the rest, at once.
#[test]
fn the_pointer_follows_what_it_is_over() {
    use scarpe_native::input::CursorShape::{Arrow, Hand, Text, Wait};
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[
        create(3, "Button", 2, json!({"text": "Go", "left": 10, "top": 10})),
        create(4, "EditLine", 2, json!({"left": 10, "top": 60})),
        create(5, "Para", 2, json!({"text_items": ["point here"], "left": 10, "top": 120, "cursor": "hand_cursor"})),
    ]));
    assert_eq!(cursor_at(&mut h, 20.0, 20.0), Hand);
    assert_eq!(cursor_at(&mut h, 20.0, 70.0), Text);
    assert_eq!(cursor_at(&mut h, 20.0, 125.0), Hand);
    assert_eq!(cursor_at(&mut h, 250.0, 150.0), Arrow);
    h.feed("{\"t\":\"props\",\"id\":1,\"props\":{\"cursor\":\"watch_cursor\"}}\n");
    assert_eq!(h.rt.views[&1].ui.cursor, Wait, "without the pointer moving");
    assert_eq!(cursor_at(&mut h, 20.0, 20.0), Hand, "the button still says hand");
}

/// shoes3-tests/opacity_test.rb: `app.opacity = 0.5` makes the whole window see-through.
/// A picture of it keeps half of every pixel; a real window gets the Opacity effect.
#[test]
fn app_opacity_makes_the_window_see_through() {
    use scarpe_native::runtime::Effect;
    let mut h = Harness::new();
    h.feed(&app(200, 100, &[create(3, "Background", 2, json!({"fill": {"rgba": [255, 0, 0, 255]}}))]));
    assert_eq!(pixel(&mut h, 10.0, 10.0), [255, 0, 0, 255]);
    h.feed("{\"t\":\"props\",\"id\":1,\"props\":{\"opacity\":0.5}}\n");
    let [r, g, b, a] = pixel(&mut h, 10.0, 10.0);
    assert!(r >= 254 && g == 0 && b == 0 && (127..=129).contains(&a), "half see-through red: {:?}", [r, g, b, a]);
    assert!(h.rt.effects.contains(&Effect::Opacity(1, 0.5)));
    h.feed("{\"t\":\"props\",\"id\":1,\"props\":{\"opacity\":1.0}}\n");
    assert_eq!(pixel(&mut h, 10.0, 10.0), [255, 0, 0, 255]);
}

// ---- Button icons (Shoes 3.3 `icon:`, `icon_pos:`; ledger G7) ----

/// A solid 16x16 icon on disk.
fn red_icon() -> String {
    let path = std::env::temp_dir().join(format!("scarpe-art-input-icon-{}.png", std::process::id()));
    image::RgbaImage::from_pixel(16, 16, image::Rgba([255, 0, 0, 255])).save(&path).expect("icon");
    path.to_string_lossy().into_owned()
}

/// shoes3-tests/button/button.rb: the icon sits beside the label, on the side
/// `icon_pos` names, and the button grows to hold both.
#[test]
fn a_button_draws_its_icon_beside_its_label() {
    let icon = red_icon();
    let mut h = Harness::new();
    h.feed(&app(400, 200, &[
        create(3, "Button", 2, json!({"text": "Info", "left": 10, "top": 10})),
        create(4, "Button", 2, json!({"text": "Info", "left": 10, "top": 60, "icon": icon})),
        create(5, "Button", 2, json!({"text": "Info", "left": 10, "top": 110, "icon": icon, "icon_pos": "right"})),
    ]));
    let plain = h.node(|n| n["id"] == 3)["w"].as_f64().unwrap();
    let with_icon = h.node(|n| n["id"] == 4);
    let (x, y, w, bh) = (with_icon["x"].as_f64().unwrap(), with_icon["y"].as_f64().unwrap(), with_icon["w"].as_f64().unwrap(), with_icon["h"].as_f64().unwrap());
    assert_eq!(w, plain + 22.0, "room for a 16 px icon and a 6 px gap");
    assert_eq!(rgb(&mut h, x + 14.0 + 8.0, y + bh / 2.0), RED, "the icon comes first by default");
    assert_ne!(rgb(&mut h, x + w - 14.0 - 8.0, y + bh / 2.0), RED);
    let right = h.node(|n| n["id"] == 5);
    let (rx, ry, rw, rh) = (right["x"].as_f64().unwrap(), right["y"].as_f64().unwrap(), right["w"].as_f64().unwrap(), right["h"].as_f64().unwrap());
    assert_eq!(rgb(&mut h, rx + rw - 14.0 - 8.0, ry + rh / 2.0), RED, "icon_pos: right puts it after the label");
    let _ = std::fs::remove_file(icon);
}

// ---- Widget polish (DESIGN look and feel, ledger C4) ----

#[test]
fn control_shadows_stay_inside_their_boxes() {
    let mut h = Harness::new();
    h.feed(&app(400, 100, &[
        create(3, "Button", 2, json!({"text": "Push", "left": 10, "top": 10})),
        create(4, "ListBox", 2, json!({"items": ["Grapes"], "chosen": "Grapes", "left": 150, "top": 10})),
    ]));
    for id in [3, 4] {
        let n = h.node(|n| n["id"] == id);
        let (x, w, bottom) = (n["x"].as_f64().unwrap(), n["w"].as_f64().unwrap(), n["y"].as_f64().unwrap() + n["h"].as_f64().unwrap());
        assert_eq!(rgb(&mut h, x + w / 2.0, bottom + 0.5), WHITE, "nothing drawn below #{id}'s box");
        assert_ne!(rgb(&mut h, x + w / 2.0, bottom - 0.5), WHITE, "its shadow is inside");
    }
}

/// DESIGN: check boxes are accent blue when on, even at the middle of the box.
#[test]
fn a_checked_box_is_accent_blue_in_the_middle() {
    let mut h = Harness::new();
    h.feed(&app(100, 100, &[create(3, "Check", 2, json!({"checked": true, "left": 10, "top": 10}))]));
    let [r, g, b] = rgb(&mut h, 19.0, 19.0);
    assert!(r < 60 && g < 160 && b > 200, "accent at the centre: {:?}", [r, g, b]);
}

/// Manual 3183, 3245 (spec list_box.default_size, progress.default_width): 200 wide.
#[test]
fn list_boxes_and_progress_bars_are_200_wide() {
    let mut h = Harness::new();
    h.feed(&app(500, 100, &[create(3, "ListBox", 2, json!({"items": ["a"]})), create(4, "Progress", 2, json!({}))]));
    assert_eq!(h.node(|n| n["id"] == 3)["w"], json!(200.0));
    assert_eq!(h.node(|n| n["id"] == 4)["w"], json!(200.0));
}

#[test]
fn arrows_on_an_empty_list_box_do_nothing() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "ListBox", 2, json!({"items": []}))]));
    h.feed("{\"t\":\"focus\",\"id\":3}\n");
    assert!(named(&key(&mut h, "down"), "change").is_empty());
    assert!(named(&key(&mut h, "up"), "change").is_empty());
}

/// manual 3356-3359 and ledger G9: Enter on a focused radio (or check) clicks it, as Space
/// does; Lacci toggles it. Only a focused button took Enter before.
#[test]
fn enter_clicks_a_focused_check_or_radio() {
    let mut h = Harness::new();
    h.feed(&app(300, 200, &[create(3, "Check", 2, json!({})), create(4, "Radio", 2, json!({}))]));
    for id in [3, 4] {
        h.feed(&format!("{}\n", json!({"t": "focus", "id": id})));
        for name in ["\n", " "] {
            let evs = key(&mut h, name);
            assert_eq!(named(&evs, "click").iter().map(|e| e.1.clone()).collect::<Vec<_>>(), vec![json!(id)], "{name:?} on {id}");
            assert!(named(&evs, "keypress").is_empty(), "the control used the key");
        }
    }
    let mut modified = scarpe_native::input::KeyInput::named(scarpe_native::input::Named::Enter);
    modified.ctrl = true;
    h.rt.key_input(1, modified);
    assert!(named(&events(&h.rt.out.take_captured()), "click").is_empty(), "Control-Enter is a keypress, not a click");
}
