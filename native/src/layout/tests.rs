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

/// Rects equal to a hundredth of a pixel (text heights carry f32 rounding).
fn assert_near(actual: Rect, expected: Rect) {
    let close = |a: f32, b: f32| (a - b).abs() < 0.01;
    assert!(
        close(actual.x, expected.x) && close(actual.y, expected.y) && close(actual.w, expected.w) && close(actual.h, expected.h),
        "{actual:?} is not {expected:?}"
    );
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
fn a_slot_without_a_width_takes_the_whole_line() {
    // Ledger C8: a slot's default width is its parent's (Shoes 3 s3_canvas.c:468 with
    // s3_ruby.c:505-532, Shoes 4 s4_slot.rb:48), so after anything on the line it starts a row.
    let mut s = Scene::new();
    let first = s.add("Stack", ROOT, json!({"width": 100, "height": 10}));
    let rest = s.add("Stack", ROOT, json!({"height": 10}));
    let widget = s.add("Widget", ROOT, json!({"height": 10}));
    let beside = s.add("Stack", ROOT, json!({"width": 100, "height": 10}));
    let flow = s.add("Flow", ROOT, json!({"height": 10}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, first).w, 100.0);
    assert_eq!(r(&l, rest), Rect::new(0.0, 10.0, 480.0, 10.0));
    assert_eq!(r(&l, widget), Rect::new(0.0, 20.0, 480.0, 10.0));
    assert_eq!(r(&l, beside), Rect::new(0.0, 30.0, 100.0, 10.0));
    assert_eq!(r(&l, flow), Rect::new(0.0, 40.0, 480.0, 10.0), "a full row pushes the flow down");
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
    assert_eq!(r(&l, in_stack).w, 292.0, "less the 4 px text margins");
    let (a, b, c) = (r(&l, one), r(&l, two), r(&l, long));
    assert!(a.w > 5.0 && a.w < 30.0, "{a:?}");
    assert_eq!(b.x, a.right() + 4.0, "the second para sits beside the first, one margin apart");
    assert_eq!((c.x, c.y), (a.x, a.y), "the long one carries on along the same line, from the left edge");
    assert_eq!(c.w, 292.0);
    assert!(c.h > 20.0, "and wraps: {c:?}");
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

#[test]
fn a_fixed_height_clips_without_scrolling() {
    // Manual 345-352: a fixed height makes the slot a "nested window" that chops its end off.
    let mut s = Scene::new();
    let fixed = s.add("Stack", ROOT, json!({"width": 200, "height": 100}));
    let tall = s.add("Stack", fixed, json!({"height": 300}));
    let free = s.add("Stack", ROOT, json!({"width": 200}));
    let inside = s.add("Stack", free, json!({"height": 300}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(l.boxes[&tall].clip, Some(Rect::new(0.0, 0.0, 200.0, 100.0)));
    assert_eq!(l.visible_rect(tall), Some(Rect::new(0.0, 0.0, 200.0, 100.0)));
    assert!(!l.scrollers.contains_key(&fixed), "clipping is not scrolling");
    assert_eq!(l.boxes[&inside].clip, None, "a slot that grows with its content clips nothing");
}

#[test]
fn text_blocks_keep_shoes_3_margins() {
    // Ledger C9 (Q3): 4 px all round, 12 px below unless margin or margin_bottom is given.
    let mut s = Scene::new();
    let stack = s.add("Stack", ROOT, json!({"width": 300}));
    let first = s.add("Para", stack, json!({"text_items": ["one"]}));
    let second = s.add("Para", stack, json!({"text_items": ["two"]}));
    let flush = s.add("Para", stack, json!({"text_items": ["flush"], "margin": 0}));
    let own_bottom = s.add("Para", stack, json!({"text_items": ["own"], "margin_bottom": 2}));
    let after = s.add("Button", stack, json!({"text": "b", "width": 10, "height": 10}));
    let l = s.layout(480.0, 420.0);
    assert_near(r(&l, first), Rect::new(4.0, 4.0, 292.0, 14.4));
    assert!((r(&l, second).y - (4.0 + 14.4 + 12.0 + 4.0)).abs() < 0.01, "{:?}", r(&l, second));
    let f = r(&l, flush);
    assert!((f.y - (r(&l, second).bottom() + 12.0)).abs() < 0.01 && f.x == 0.0 && f.w == 300.0, "margin: 0 is flush: {f:?}");
    let o = r(&l, own_bottom);
    assert!((o.y - (f.bottom() + 4.0)).abs() < 0.01, "{o:?}");
    assert!((r(&l, after).y - (o.bottom() + 2.0)).abs() < 0.01, "margin_bottom: 2 replaces the 12");
}

const LONG: &str = "This second paragraph is long enough that it has to wrap onto more lines inside three hundred pixels.";

/// The window x where each line of a text block starts, from its glyphs.
fn line_starts(l: &Layout, id: Id) -> Vec<f32> {
    let tb = &l.texts[&id];
    tb.shaped
        .buffer
        .layout_runs()
        .map(|run| tb.x + run.glyphs.iter().find(|g| g.metadata != crate::text::shape_cache::INDENT_META).map_or(0.0, |g| g.x))
        .collect()
}

#[test]
fn text_side_by_side_in_a_flow_reads_as_one_paragraph() {
    // Ledger C7 (Q2): the second para's first line carries on from the first, and its later
    // lines wrap back to the flow's left edge (manual 1610-1612, Shoes 3).
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 300}));
    let short = s.add("Para", flow, json!({"text_items": ["Short."]}));
    let long = s.add("Para", flow, json!({"text_items": [LONG]}));
    let l = s.layout(480.0, 420.0);
    let (a, b) = (r(&l, short), r(&l, long));
    assert_eq!((b.x, b.y), (a.x, a.y), "one row, one left edge: {a:?} {b:?}");
    assert_eq!(b.w, 292.0, "the paragraph spans the flow, less its margins");
    let starts = line_starts(&l, long);
    assert!(starts.len() >= 2, "it wraps: {starts:?}");
    assert!((starts[0] - (a.right() + 4.0)).abs() < 0.5, "its first line follows the first para's text: {starts:?} {a:?}");
    assert!(starts[1..].iter().all(|x| (x - b.x).abs() < 0.5), "its later lines start at the left edge: {starts:?}");
    let first_top = l.texts[&long].shaped.buffer.layout_runs().next().unwrap().line_top;
    assert_eq!(first_top, l.texts[&short].shaped.buffer.layout_runs().next().unwrap().line_top, "the first lines share a baseline");
}

#[test]
fn a_paragraph_indent_belongs_to_what_came_before() {
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 300}));
    let short = s.add("Para", flow, json!({"text_items": ["Short."]}));
    let long = s.add("Para", flow, json!({"text_items": [LONG]}));
    let l = s.layout(480.0, 420.0);
    let (a, b) = (r(&l, short), r(&l, long));
    let (x, y) = a.center();
    assert_eq!(crate::input::hit_test(&s.doc, &l, x, y).map(|h| h.node), Some(short), "the first para's text is still the first para");
    let below = (b.x + 5.0, b.bottom() - 5.0);
    assert_eq!(crate::input::hit_test(&s.doc, &l, below.0, below.1).map(|h| h.node), Some(long));
    let (cx, cy) = l.texts[&long].centre_within(b);
    assert!(l.texts[&long].owns(cx, cy), "a click aimed at the paragraph lands on it");
}

#[test]
fn what_follows_a_paragraph_carries_on_from_its_last_line() {
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 300}));
    let long = s.add("Para", flow, json!({"text_items": [format!("{LONG}\nend")]}));
    let button = s.add("Button", flow, json!({"text": "b", "width": 40, "height": 10}));
    let l = s.layout(480.0, 420.0);
    let (p, b) = (r(&l, long), r(&l, button));
    let tb = &l.texts[&long];
    let last = tb.shaped.buffer.layout_runs().last().unwrap();
    assert!((b.x - (p.x + last.line_w)).abs() < 0.5, "the button follows the last line's text: {b:?} {}", last.line_w);
    assert!((b.y - (p.y + last.line_top - 4.0)).abs() < 0.5, "on the last line's row: {b:?} {p:?}");
    assert!(r(&l, flow).h >= p.bottom() + 12.0 - 0.01, "the flow still holds the whole paragraph and its margin");
}

#[test]
fn words_in_a_flow_sit_one_margin_apart() {
    // examples/para/rainbow.rb: one para per word must read as a sentence.
    let mut s = Scene::new();
    let words: Vec<Id> = ["Paint", "the", "Whole"].iter().map(|w| s.add("Para", ROOT, json!({"text_items": [w]}))).collect();
    let l = s.layout(480.0, 420.0);
    let (a, b, c) = (r(&l, words[0]), r(&l, words[1]), r(&l, words[2]));
    assert_eq!((a.x, a.y), (4.0, 4.0));
    assert!((b.x - (a.right() + 4.0)).abs() < 0.01 && (c.x - (b.right() + 4.0)).abs() < 0.01, "{a:?} {b:?} {c:?}");
    assert!(a.y == b.y && b.y == c.y);
}

#[test]
fn text_that_cannot_share_the_line_starts_a_row() {
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 300}));
    let tall = s.add("Button", flow, json!({"text": "tall", "width": 40, "height": 60}));
    let beside = s.add("Para", flow, json!({"text_items": ["fits beside"]}));
    let wraps = s.add("Para", flow, json!({"text_items": [LONG]}));
    let flow2 = s.add("Flow", ROOT, json!({"width": 300}));
    let short = s.add("Para", flow2, json!({"text_items": ["Short words here and then"]}));
    let word = s.add("Para", flow2, json!({"text_items": ["Pneumonoultramicroscopicsilicovolcanoconiosis goes on for a while after it"]}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, beside).y, 4.0, "a single line sits beside even a tall control");
    let w = r(&l, wraps);
    assert!(w.y >= r(&l, tall).bottom(), "a wrapping para does not run under it: {w:?}");
    assert!(line_starts(&l, wraps)[0] - w.x < 0.5, "and starts its row without an indent");
    let (a, b) = (r(&l, short), r(&l, word));
    assert!(b.y > a.y, "a first word too long for the rest of the line takes the para to a new row: {a:?} {b:?}");
    assert!(line_starts(&l, word)[0] - b.x < 0.5);
}

#[test]
fn right_and_bottom_place_from_the_far_edges() {
    // Ledger C10 and M19: `right: 50` puts the right edge 50 px in from the slot's (manual 1356-1364).
    let mut s = Scene::new();
    let column = s.add("Background", ROOT, json!({"fill": "#000", "width": 50, "right": 50}));
    let slot = s.add("Stack", ROOT, json!({"width": 100, "height": 40, "right": 0, "bottom": 0}));
    let text = s.add("Para", ROOT, json!({"text_items": ["right"], "right": 20, "top": 100}));
    let l = s.layout(400.0, 300.0);
    assert_eq!(r(&l, column), Rect::new(300.0, 0.0, 50.0, 300.0));
    assert_eq!(r(&l, slot), Rect::new(300.0, 260.0, 100.0, 40.0));
    let t = r(&l, text);
    assert!((t.right() + 4.0 - 380.0).abs() < 0.01 && (t.y - 104.0).abs() < 0.01, "a text's margin box ends 20 px in: {t:?}");
}
