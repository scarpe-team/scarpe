use super::*;
use crate::doc::NewNode;
use crate::elements::image::ImageCache;
use crate::text::{FontMode, TextEngine};
use serde_json::{json, Value};

struct Scene {
    doc: Doc,
    text: TextEngine,
    images: ImageCache,
    scroll: HashMap<Id, f32>,
    next: Id,
}

const ROOT: Id = 2;

impl Scene {
    fn new() -> Self {
        let mut s = Scene { doc: Doc::default(), text: TextEngine::new(FontMode::Bundled), images: ImageCache::default(), scroll: HashMap::new(), next: 3 };
        s.create(ROOT, "DocumentRoot", None, json!({"width": "100%", "height": "100%"}));
        s.create(1, "App", None, json!({"width": 480, "height": 420}));
        s
    }

    fn create(&mut self, id: Id, class: &str, parent: Option<Id>, props: Value) {
        self.doc.create(NewNode {
            id,
            class: class.into(),
            parent,
            index: None,
            widget: false,
            props: props.as_object().unwrap().clone(),
            doc_root: (class == "App").then_some(ROOT),
            owner: None,
        });
    }

    fn add(&mut self, class: &str, parent: Id, props: Value) -> Id {
        let id = self.next;
        self.next += 1;
        self.create(id, class, Some(parent), props);
        id
    }

    fn layout(&mut self, w: f32, h: f32) -> Layout {
        layout(Inputs { doc: &self.doc, text: &mut self.text, images: &mut self.images, scroll: &self.scroll }, ROOT, (w, h))
    }
}

fn r(l: &Layout, id: Id) -> Rect {
    l.rect(id).unwrap_or_else(|| panic!("{id} was not laid out"))
}

#[test]
fn stack_children_go_top_to_bottom_with_margins() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"margin": 10}));
    let a = s.add("Button", stack, json!({"text": "A", "width": 100, "height": 30}));
    let b = s.add("Button", stack, json!({"text": "B", "width": 100, "height": 30, "margin_top": 5}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, stack), Rect::new(10.0, 10.0, 460.0, 65.0));
    assert_eq!(r(&l, a), Rect::new(10.0, 10.0, 100.0, 30.0));
    assert_eq!(r(&l, b), Rect::new(10.0, 45.0, 100.0, 30.0));
}

#[test]
fn flow_packs_left_to_right_and_wraps() {
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 200}));
    let ids: Vec<Id> = (0..3).map(|_| s.add("Button", flow, json!({"text": "x", "width": 80, "height": 20}))).collect();
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, ids[0]), Rect::new(0.0, 0.0, 80.0, 20.0));
    assert_eq!(r(&l, ids[1]), Rect::new(80.0, 0.0, 80.0, 20.0));
    assert_eq!(r(&l, ids[2]), Rect::new(0.0, 20.0, 80.0, 20.0));
    assert_eq!(r(&l, flow).h, 40.0);
}

#[test]
fn width_forms() {
    let mut s = Scene::new();
    let half = s.add("Stack", ROOT, json!({"width": 0.5, "height": 10}));
    let pct = s.add("Stack", ROOT, json!({"width": "25%", "height": 10}));
    let neg = s.add("Stack", ROOT, json!({"width": -400, "height": 10}));
    let px = s.add("Stack", ROOT, json!({"width": "30px", "height": 10}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, half).w, 240.0);
    assert_eq!(r(&l, pct).w, 120.0);
    assert_eq!(r(&l, neg).w, 80.0);
    assert_eq!(r(&l, px).w, 30.0);
    // 240 + 120 + 80 + 30 = 470 fits one row of 480.
    assert_eq!(r(&l, neg).x, 360.0);
    assert_eq!(r(&l, px), Rect::new(440.0, 0.0, 30.0, 10.0));
}

#[test]
fn relative_widths_size_the_margin_box() {
    let mut s = Scene::new();
    let a = s.add("Flow", ROOT, json!({"width": 0.5, "margin": 10, "height": 20}));
    let b = s.add("Flow", ROOT, json!({"width": 0.5, "margin": 10, "height": 20}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, a), Rect::new(10.0, 10.0, 220.0, 20.0));
    assert_eq!(r(&l, b), Rect::new(250.0, 10.0, 220.0, 20.0));
}

#[test]
fn stack_in_flow_fills_the_rest_of_the_line() {
    let mut s = Scene::new();
    let first = s.add("Stack", ROOT, json!({"width": 100, "height": 10}));
    let rest = s.add("Stack", ROOT, json!({"height": 10}));
    let flow = s.add("Flow", ROOT, json!({"height": 10}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, first).w, 100.0);
    assert_eq!(r(&l, rest), Rect::new(100.0, 0.0, 380.0, 10.0));
    assert_eq!(r(&l, flow), Rect::new(0.0, 10.0, 480.0, 10.0), "a full row pushes the flow down");
}

#[test]
fn stack_in_stack_takes_the_full_width() {
    let mut s = Scene::new();
    let outer = s.add("Stack", ROOT, json!({"width": 300}));
    let inner = s.add("Stack", outer, json!({"margin_left": 20}));
    let _ = s.add("Button", inner, json!({"text": "x", "width": 10, "height": 10}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, inner), Rect::new(20.0, 0.0, 280.0, 10.0));
}

#[test]
fn out_of_flow_placement() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 200, "height": 100, "margin": 10}));
    let first = s.add("Button", stack, json!({"text": "a", "width": 50, "height": 20}));
    let placed = s.add("Button", stack, json!({"text": "b", "width": 50, "height": 20, "left": 30, "top": 40}));
    let corner = s.add("Button", stack, json!({"text": "c", "width": 50, "height": 20, "right": 0, "bottom": 0}));
    let after = s.add("Button", stack, json!({"text": "d", "width": 50, "height": 20}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, first).y, 10.0);
    assert_eq!(r(&l, placed), Rect::new(40.0, 50.0, 50.0, 20.0));
    assert_eq!(r(&l, corner), Rect::new(160.0, 90.0, 50.0, 20.0));
    assert_eq!(r(&l, after).y, 30.0, "positioned siblings take no room");
}

#[test]
fn art_is_out_of_flow_and_does_not_grow_its_slot() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 200}));
    let rect = s.add("Rect", stack, json!({"left": 10, "top": 10, "width": 30, "height": 30}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, rect), Rect::new(10.0, 10.0, 30.0, 30.0));
    assert_eq!(r(&l, stack).h, 0.0);
}

#[test]
fn hidden_nodes_take_no_part() {
    let mut s = Scene::new();
    let a = s.add("Button", ROOT, json!({"text": "a", "width": 50, "height": 20, "hidden": true}));
    let b = s.add("Button", ROOT, json!({"text": "b", "width": 50, "height": 20}));
    let l = s.layout(480.0, 420.0);
    assert!(l.rect(a).is_none());
    assert_eq!(r(&l, b).x, 0.0);
    assert!(!l.order.contains(&a));
}

#[test]
fn text_in_a_stack_fills_and_in_a_flow_shrinks() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 300}));
    let in_stack = s.add("Para", stack, json!({"text_items": ["Hi"]}));
    let flow = s.add("Flow", ROOT, json!({"width": 300}));
    let one = s.add("Para", flow, json!({"text_items": ["Hi"]}));
    let two = s.add("Para", flow, json!({"text_items": ["there"]}));
    let long = s.add("Para", flow, json!({"text_items": ["A long para that will certainly not fit on the rest of this short row at all."]}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, in_stack).w, 300.0);
    let (a, b, c) = (r(&l, one), r(&l, two), r(&l, long));
    assert!(a.w > 5.0 && a.w < 30.0, "{a:?}");
    assert_eq!(b.x, a.w, "the second para sits beside the first");
    assert_eq!(c.x, 0.0, "the long para starts a row of its own");
    assert_eq!(c.w, 300.0);
    assert!(c.h > 20.0, "and wraps there: {c:?}");
    assert!((a.h - 14.4).abs() < 0.01, "line height is 1.2 x 12px: {a:?}");
}

#[test]
fn widgets_have_intrinsic_sizes() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({}));
    let el = s.add("EditLine", stack, json!({"text": ""}));
    let eb = s.add("EditBox", stack, json!({}));
    let lb = s.add("ListBox", stack, json!({"items": ["a"]}));
    let pr = s.add("Progress", stack, json!({}));
    let ch = s.add("Check", stack, json!({}));
    let bt = s.add("Button", stack, json!({"text": "OK"}));
    let wide = s.add("EditLine", stack, json!({"width": 300}));
    let l = s.layout(480.0, 420.0);
    assert_eq!((r(&l, el).w, r(&l, el).h), (200.0, 28.0));
    assert_eq!((r(&l, eb).w, r(&l, eb).h), (200.0, 108.0));
    // Ledger C4: the manual gives list_box and progress 200 px.
    assert_eq!((r(&l, lb).w, r(&l, lb).h), (200.0, 28.0));
    assert_eq!((r(&l, pr).w, r(&l, pr).h), (200.0, 14.0));
    assert_eq!((r(&l, ch).w, r(&l, ch).h), (18.0, 18.0));
    assert!(r(&l, bt).h >= 22.0 && r(&l, bt).w > 28.0);
    assert_eq!(r(&l, wide).w, 300.0);
}

#[test]
fn backgrounds_fill_their_slot() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 200, "margin": 5}));
    let bg = s.add("Background", stack, json!({"fill": "#fff"}));
    let stripe = s.add("Background", stack, json!({"fill": "#000", "width": 50}));
    let _ = s.add("Button", stack, json!({"text": "x", "width": 10, "height": 40}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, bg), Rect::new(5.0, 5.0, 200.0, 40.0));
    assert_eq!(r(&l, stripe), Rect::new(5.0, 5.0, 50.0, 40.0));
    assert_eq!(l.order.iter().position(|i| *i == bg), Some(2), "paint order is tree order");
}

#[test]
fn window_backgrounds_cover_the_document() {
    let mut s = Scene::new();
    let bg = s.add("Background", ROOT, json!({"fill": "#fff"}));
    let l = s.layout(300.0, 200.0);
    assert_eq!(r(&l, bg), Rect::new(0.0, 0.0, 300.0, 200.0));
}

#[test]
fn scrolling_slot_clips_and_clamps() {
    let mut s = Scene::new();
    let box_ = s.add("Stack", ROOT, json!({"width": 100, "height": 50, "scroll": true}));
    let kids: Vec<Id> = (0..5).map(|_| s.add("Button", box_, json!({"text": "x", "width": 100, "height": 30}))).collect();
    s.scroll.insert(box_, 1000.0);
    let l = s.layout(480.0, 420.0);
    let sc = &l.scrollers[&box_];
    assert_eq!(sc.content_height, 150.0);
    assert_eq!(sc.top, 100.0, "clamped to content - viewport");
    assert_eq!(r(&l, kids[0]).y, -100.0);
    assert_eq!(l.boxes[&kids[4]].clip, Some(Rect::new(0.0, 0.0, 100.0, 50.0)));
    assert_eq!(l.visible_rect(kids[0]), None);
    assert_eq!(l.visible_rect(kids[4]), Some(Rect::new(0.0, 20.0, 100.0, 30.0)));
}

#[test]
fn the_window_scrolls_when_content_is_taller() {
    let mut s = Scene::new();
    let tall = s.add("Stack", ROOT, json!({"height": 1000}));
    s.scroll.insert(ROOT, 300.0);
    let l = s.layout(480.0, 400.0);
    assert_eq!(l.scrollers[&ROOT].max_top(), 600.0);
    assert_eq!(r(&l, tall).y, -300.0);
}

#[test]
fn displace_moves_without_disturbing_siblings() {
    let mut s = Scene::new();
    let a = s.add("Button", ROOT, json!({"text": "a", "width": 50, "height": 20, "displace_left": 5, "displace_top": 7}));
    let b = s.add("Button", ROOT, json!({"text": "b", "width": 50, "height": 20}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, a), Rect::new(5.0, 7.0, 50.0, 20.0));
    assert_eq!(r(&l, b).x, 50.0);
}

#[test]
fn attach_window_uses_window_coordinates() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"margin": 40}));
    let pinned = s.add("Stack", stack, json!({"attach": "window", "left": 10, "top": 10, "width": 20, "height": 20}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, pinned), Rect::new(10.0, 10.0, 20.0, 20.0));
}

#[test]
fn heights_resolve_against_the_parent() {
    let mut s = Scene::new();
    let outer = s.add("Stack", ROOT, json!({"height": 200}));
    let inner = s.add("Stack", outer, json!({"height": 0.5}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, outer).h, 200.0);
    assert_eq!(r(&l, inner).h, 100.0);
}

#[test]
fn subscriptions_are_listed_with_their_slot() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({}));
    let item = s.add("SubscriptionItem", stack, json!({"shoes_api_name": "click", "args": []}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(l.subscriptions, vec![item]);
    assert!(l.rect(item).is_none());
}

#[test]
fn art_inside_a_pathless_shape_is_still_laid_out() {
    let mut s = Scene::new();
    let shape = s.add("Shape", ROOT, json!({"shape_commands": []}));
    let line = s.add("Line", shape, json!({"left": 0, "top": 0, "x2": 100, "y2": 100}));
    let l = s.layout(480.0, 420.0);
    assert!(l.rect(shape).is_some());
    assert_eq!(r(&l, line), Rect::new(-0.5, -0.5, 101.0, 101.0));
    assert!(l.order.contains(&line));
}

#[test]
fn risen_text_makes_room_in_its_line() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 300}));
    let plain = s.add("Para", stack, json!({"text_items": ["H2O"]}));
    s.create(50, "Sub", None, json!({"text_items": ["2"]}));
    let with_sub = s.add("Para", stack, json!({"text_items": ["H", 50, "O"]}));
    let l = s.layout(480.0, 420.0);
    let (plain_h, sub_h) = (r(&l, plain).h, r(&l, with_sub).h);
    // A sub drops 10 px below a 12 px line whose descent is about 3 px.
    assert!(sub_h >= plain_h + 2.0 * 7.0, "the line holding the sub grows: {plain_h} -> {sub_h}");
}

#[test]
fn trimmed_text_ends_in_an_ellipsis_inside_its_box() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 100}));
    let para = s.add("Para", stack, json!({"text_items": ["HHHHHHHHHHHHHHHHHHHHHHHHHHHHHH"], "wrap": "trim"}));
    let l = s.layout(480.0, 420.0);
    let (tb, b) = (&l.texts[&para], r(&l, para));
    let runs: Vec<_> = tb.shaped.buffer.layout_runs().collect();
    assert_eq!(runs.len(), 1, "trim keeps one line");
    assert!(runs[0].line_w <= b.w + 0.5, "the line fits its box: {} > {}", runs[0].line_w, b.w);
    let last = runs[0].glyphs.last().expect("glyphs");
    assert_eq!(last.start, last.end, "the last glyph is the ellipsis, which stands for no text of its own");
}

#[test]
fn leading_goes_between_lines_and_defaults_to_four() {
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 300}));
    let tight = s.add("Para", stack, json!({"text_items": ["one\ntwo"], "leading": 0}));
    let normal = s.add("Para", stack, json!({"text_items": ["one\ntwo"]}));
    let wide = s.add("Para", stack, json!({"text_items": ["one\ntwo"], "leading": 20}));
    let single = s.add("Para", stack, json!({"text_items": ["one"]}));
    let l = s.layout(480.0, 420.0);
    let h = |id| r(&l, id).h;
    // Manual 1286: "Defaults to 4 pixels", spacing between lines, as Pango's.
    assert!((h(normal) - h(tight) - 4.0).abs() < 0.01, "{} {}", h(normal), h(tight));
    assert!((h(wide) - h(tight) - 20.0).abs() < 0.01, "{} {}", h(wide), h(tight));
    assert!((h(single) - 14.4).abs() < 0.01, "one line has no leading: {}", h(single));
    let (tb, b) = (&l.texts[&normal], r(&l, normal));
    let first = tb.shaped.buffer.layout_runs().next().unwrap();
    let tight_first = l.texts[&tight].shaped.buffer.layout_runs().next().unwrap();
    let baseline = |tb: &TextBox, y: f32, box_y: f32| tb.y + y - box_y;
    assert!(
        (baseline(tb, first.line_y, b.y) - baseline(&l.texts[&tight], tight_first.line_y, r(&l, tight).y)).abs() < 0.01,
        "the first line sits where it would without leading"
    );
}
