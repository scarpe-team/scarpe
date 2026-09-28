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
    assert_eq!(r(&l, stack), Rect::new(10.0, 10.0, 460.0, 60.0));
    assert_eq!(r(&l, a), Rect::new(10.0, 10.0, 100.0, 30.0));
    assert_eq!(r(&l, b), Rect::new(10.0, 45.0, 100.0, 25.0), "its 30 px hold its 5 px margin (Q9)");
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
    let a = s.add("Flow", ROOT, json!({"width": 0.5, "margin": 10, "height": 40}));
    let b = s.add("Flow", ROOT, json!({"width": 0.5, "margin": 10, "height": 40}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, a), Rect::new(10.0, 10.0, 220.0, 20.0));
    assert_eq!(r(&l, b), Rect::new(250.0, 10.0, 220.0, 20.0));
}

/// Q9 (ruled 27 Sep 2026, ledger C14): an explicit width or height is the margin box, as in
/// Shoes 3 (s3_ruby.c:506, 537; s3t_textblock.c:125-126), px or relative alike. menu1.rb's four
/// panels (170, 140, 140 and 140 px, margin 4) fill one 600 px row only so: 590 px against 622.
#[test]
fn an_explicit_size_is_the_margin_box() {
    let mut s = Scene::new();
    let panels: Vec<Id> = [170, 140, 140, 140].iter().map(|w| s.add("Widget", ROOT, json!({"width": w, "height": 120, "margin": 4}))).collect();
    let para = s.add("Para", ROOT, json!({"text_items": ["words"], "width": 200}));
    let l = s.layout(600.0, 130.0);
    assert_eq!(r(&l, panels[0]), Rect::new(4.0, 4.0, 162.0, 112.0));
    assert_eq!((r(&l, panels[3]).y, r(&l, panels[3]).right() + 4.0), (4.0, 590.0), "all four on one row");
    assert_eq!(r(&l, para).w, 192.0, "a para 200 wide wraps inside its 4 px margins, at 192");
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
    // 200 x 100 with a 10 px margin: a 180 x 80 box inside it (Q9).
    let stack = s.add("Stack", ROOT, json!({"width": 200, "height": 100, "margin": 10}));
    let first = s.add("Button", stack, json!({"text": "a", "width": 50, "height": 20}));
    let placed = s.add("Button", stack, json!({"text": "b", "width": 50, "height": 20, "left": 30, "top": 40}));
    let corner = s.add("Button", stack, json!({"text": "c", "width": 50, "height": 20, "right": 0, "bottom": 0}));
    let after = s.add("Button", stack, json!({"text": "d", "width": 50, "height": 20}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, first).y, 10.0);
    assert_eq!(r(&l, placed), Rect::new(40.0, 50.0, 50.0, 20.0));
    assert_eq!(r(&l, corner), Rect::new(140.0, 70.0, 50.0, 20.0));
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
    assert_eq!(r(&l, bg), Rect::new(5.0, 5.0, 190.0, 40.0), "the slot is 200 with its margins (Q9)");
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

/// examples/radio/radio_same_slot.rb (the manual's radio example): `para "...?\n"; radio;
/// para "..."`. A text that ends in a newline ends its line, so what follows starts the next
/// one at the flow's left edge (Shoes 3 s3t_textblock.c:217-228: "newlines have an empty size").
#[test]
fn a_trailing_newline_ends_the_line() {
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 400}));
    let question = s.add("Para", flow, json!({"text_items": ["Among these films, which do you prefer?\n"]}));
    let radio = s.add("Radio", flow, json!({}));
    let answer = s.add("Para", flow, json!({"text_items": ["The Taste of Tea\n"]}));
    let second = s.add("Radio", flow, json!({}));
    let l = s.layout(480.0, 420.0);
    let (q, r1, a, r2) = (r(&l, question), r(&l, radio), r(&l, answer), r(&l, second));
    let first_line = l.texts[&question].shaped.buffer.layout_runs().next().unwrap();
    assert_eq!(r1.x, 0.0, "the radio starts the next line at the flow's edge: {r1:?}");
    assert!(r1.y >= q.y + first_line.line_top + first_line.line_height - 4.0 - 0.5, "below the question's line: {r1:?} {q:?}");
    assert!((a.y - q.y - (r1.y - q.y)).abs() < 12.0 && a.x < r1.right() + 8.0, "its answer sits beside it: {a:?} {r1:?}");
    assert_eq!(r2.x, 0.0, "and the next radio starts a line of its own: {r2:?}");
    assert!(r2.y > r1.y + 10.0, "{r2:?} {r1:?}");
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
fn a_sized_line_too_wide_as_a_box_still_sits_beside_what_came_before() {
    // Ledger C7, from Hackety Hack's britelink: an icon, then its name in a para 280 wide and
    // trimmed, in a flow 300 wide, then the date. Shoes 3 starts a sized text block at the left
    // edge with its first line indented past what came before (s3t_textblock.c:125-145), and
    // one line shrinks to its text (:207-210), so the name sits beside the icon and the date
    // carries on after it. As a box, 280 did not fit beside the icon and took a row of its own.
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 300, "margin": 4}));
    // the 16 px icon with its margins of 3, and 6 on the right
    let icon = s.add("Button", flow, json!({"text": "", "width": 25, "height": 22}));
    let name = s.add("Para", flow, json!({"text_items": ["Hello World"], "width": 280, "wrap": "trim", "margin": 0, "size": 13}));
    let date = s.add("Para", flow, json!({"text_items": ["Sep 28"], "size": 9, "margin": 4, "margin_bottom": 0}));
    let l = s.layout(480.0, 420.0);
    let (i, n, d) = (r(&l, icon), r(&l, name), r(&l, date));
    assert!((n.y - i.y).abs() < 0.01, "the name shares the icon's row: {i:?} {n:?}");
    assert!((n.x - i.right()).abs() < 0.01, "and starts after it: {i:?} {n:?}");
    assert!(n.w < 280.0 && (n.w - s.text.max_content(&rich::resolve_block(&s.doc, &s.text.fonts, name).unwrap())).abs() < 0.01, "one line is as wide as its text: {n:?}");
    let glyphs: usize = l.texts[&name].shaped.buffer.layout_runs().map(|run| run.glyphs.len()).sum();
    assert_eq!(glyphs, "Hello World".len(), "all of it, with no ellipsis");
    assert!((d.y - (n.y + 4.0)).abs() < 0.01 && (d.x - (n.right() + 4.0)).abs() < 0.01, "the date carries on after the name: {n:?} {d:?}");

    // A sized box that fits beside keeps its box, and a line too long for the rest of the row
    // (or for its own width after the indent) still starts a row.
    let flow2 = s.add("Flow", ROOT, json!({"width": 300}));
    s.add("Button", flow2, json!({"text": "", "width": 100, "height": 16}));
    let fits = s.add("Para", flow2, json!({"text_items": ["fits"], "width": 150}));
    let flow3 = s.add("Flow", ROOT, json!({"width": 300}));
    s.add("Button", flow3, json!({"text": "", "width": 100, "height": 16}));
    let long = s.add("Para", flow3, json!({"text_items": ["a line far too long for what is left of this row"], "width": 280, "wrap": "trim"}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(r(&l, fits).w, 150.0 - 8.0, "a box that fits beside is still its own width, less its margins");
    assert!(r(&l, long).x <= 4.0 + 0.01, "a line that does not fit takes a row: {:?}", r(&l, long));
}

#[test]
fn right_and_bottom_place_from_the_far_edges() {
    // Ledger C10: `right: 50` puts the right edge 50 px in from the slot's (manual 1356-1364). A
    // background with a width of its own is measured by its pattern's size instead, 1 px for a
    // colour, as Shoes 3 places a tile (M19): the manual's column sits on the right-side.
    let mut s = Scene::new();
    let column = s.add("Background", ROOT, json!({"fill": "#000", "width": 50, "right": 50}));
    let slot = s.add("Stack", ROOT, json!({"width": 100, "height": 40, "right": 0, "bottom": 0}));
    let text = s.add("Para", ROOT, json!({"text_items": ["right"], "right": 20, "top": 100}));
    let l = s.layout(400.0, 300.0);
    assert_eq!(r(&l, column), Rect::new(349.0, 0.0, 50.0, 300.0));
    assert_eq!(r(&l, slot), Rect::new(300.0, 260.0, 100.0, 40.0));
    let t = r(&l, text);
    assert!((t.right() + 4.0 - 380.0).abs() < 0.01 && (t.y - 104.0).abs() < 0.01, "a text's margin box ends 20 px in: {t:?}");
}

#[test]
fn negative_right_and_bottom_place_past_the_far_edges() {
    // Shoes 3 reads a position as a plain number, negative too (shoes_px2 passes nv 0 to
    // shoes_px, s3_ruby.c:327-337): bottom: -3 hangs an element 3 px below its slot's lower
    // edge. Hackety Hack's editor hangs its button bar so. Native read it as the slot less 3.
    let mut s = Scene::new();
    let bar = s.add("Stack", ROOT, json!({"width": 182, "height": 40, "right": 0, "bottom": -3}));
    let tab = s.add("Stack", ROOT, json!({"width": 50, "height": 20, "right": -10, "top": 0}));
    let share = s.add("Stack", ROOT, json!({"width": 40, "height": 20, "right": "-10%", "top": 30}));
    let band = s.add("Background", ROOT, json!({"fill": "#000", "bottom": -5}));
    let l = s.layout(400.0, 300.0);
    assert_eq!(r(&l, bar), Rect::new(218.0, 263.0, 182.0, 40.0));
    assert_eq!(r(&l, tab), Rect::new(360.0, 0.0, 50.0, 20.0), "right: -10 sits 10 px past the right edge");
    assert_eq!(r(&l, share), Rect::new(400.0, 30.0, 40.0, 20.0), "a negative share of the slot is past it too");
    assert_eq!(r(&l, band), Rect::new(0.0, 0.0, 400.0, 305.0), "a background with no height reaches 5 px past the foot");
}

#[test]
fn negative_left_and_top_place_past_the_near_edges() {
    // Shoes 3 reads every position as a plain number (shoes_px2 passes nv 0 to shoes_px,
    // s3_ruby.c:298-337), for slots, controls, images and tiles alike (shoes_place_decide,
    // s3_ruby.c:518-520; ledger C18, Q10). Hackety Hack's intro starts its hand at top: -400,
    // above the window, and Ready sweeps the intro off to the left with move(-40, 0) and on;
    // native read both as the slot less that much, so the hand rose from the bottom.
    let mut s = Scene::new();
    let hand = s.add("Stack", ROOT, json!({"width": 370, "height": 370, "left": 100, "top": -400}));
    let swept = s.add("Stack", ROOT, json!({"width": 1.0, "height": 1.0, "left": -40, "top": 0}));
    let undo = s.add("Button", ROOT, json!({"text": "Undo", "width": 144, "height": 28, "left": -150, "top": 0}));
    let share = s.add("Stack", ROOT, json!({"width": 40, "height": 20, "left": -0.25, "top": "-10%"}));
    let px = s.add("Stack", ROOT, json!({"width": 40, "height": 20, "left": "-12px", "top": 50}));
    let band = s.add("Background", ROOT, json!({"fill": "#000", "left": -5, "top": -5}));
    let l = s.layout(400.0, 300.0);
    assert_eq!(r(&l, hand), Rect::new(100.0, -400.0, 370.0, 370.0), "top: -400 is 400 px above the slot");
    assert_eq!(r(&l, swept), Rect::new(-40.0, 0.0, 400.0, 300.0), "left: -40 is 40 px past the left edge");
    assert_eq!(r(&l, undo).x, -150.0, "a control too");
    assert_eq!(r(&l, share), Rect::new(-100.0, -30.0, 40.0, 20.0), "a negative share of the slot is past it");
    assert_eq!(r(&l, px).x, -12.0);
    assert_eq!(r(&l, band), Rect::new(-5.0, -5.0, 405.0, 305.0), "a background runs from past the corner to the far edges");
}

#[test]
fn a_sized_colour_or_gradient_is_placed_from_the_far_edge_by_one_pixel() {
    // Shoes 3 places a background or border with shoes_place_decide(REL_TILE), which measures a
    // right or bottom offset against the pattern's own size, not the size given it: tw and th keep
    // PATTERN_DIM, 1 for anything but a picture (s3_ruby.c:473-520, shoes/types/pattern.h). So
    // Hackety Hack's `background "#e9efe0".."#c1c5d0", height: 150, bottom: 150` runs along the
    // window's foot, as the Ubuntu 1.0.1 screenshot shows it; native hung it mid-window, with a
    // hard edge at y 399. With no size, a far-edge offset still insets the box (kanban's cards).
    let mut s = Scene::new();
    let band = s.add("Background", ROOT, json!({"fill": {"gradient": [[233, 239, 224, 255], [193, 197, 208, 255]]}, "height": 150, "bottom": 150}));
    let edge = s.add("Border", ROOT, json!({"stroke": [0, 0, 0, 255], "width": 20, "right": 10}));
    let inset = s.add("Background", ROOT, json!({"fill": "#fff", "bottom": 2}));
    let tile = s.add("Background", ROOT, json!({"fill": {"image": "/nonexistent/tile.png"}, "width": 55, "right": 0}));
    let l = s.layout(790.0, 550.0);
    assert_eq!(r(&l, band), Rect::new(0.0, 399.0, 790.0, 150.0), "the band's top is 151 px up");
    assert_eq!(r(&l, edge), Rect::new(779.0, 0.0, 20.0, 550.0), "a border likewise, 11 px in");
    assert_eq!(r(&l, inset), Rect::new(0.0, 0.0, 790.0, 548.0));
    assert_eq!(r(&l, tile), Rect::new(735.0, 0.0, 55.0, 550.0), "a picture keeps its width as its measure");
}

#[test]
fn word_wrap_never_breaks_a_word() {
    // Manual 1552-1556: "word" breaks lines at word breaks; only "char" breaks words.
    // Shoes 3 leaves Pango's PANGO_WRAP_WORD, which lets a word too long for the line overflow.
    let mut s = Scene::new();
    let narrow = s.add("Stack", ROOT, json!({"width": 100}));
    let word = s.add("Para", narrow, json!({"text_items": ["Seven"], "size": 32}));
    let chars = s.add("Para", narrow, json!({"text_items": ["Seven"], "size": 32, "wrap": "char"}));
    let l = s.layout(480.0, 420.0);
    assert_eq!(l.texts[&word].shaped.buffer.layout_runs().count(), 1, "one line, running past the box");
    assert_eq!(l.texts[&chars].shaped.buffer.layout_runs().count(), 2, "wrap: char breaks the word");
}

#[test]
fn an_indented_paragraph_counts_characters_from_its_own_text() {
    // The indent's blank is layout, not text: the dump, Para#hit and the para cursor skip it.
    let mut s = Scene::new();
    let flow = s.add("Flow", ROOT, json!({"width": 300}));
    s.add("Para", flow, json!({"text_items": ["Short."]}));
    let long = s.add("Para", flow, json!({"text_items": [LONG]}));
    let l = s.layout(480.0, 420.0);
    let tb = &l.texts[&long];
    assert!(tb.shaped.indent > 0.0);
    assert_eq!(tb.shaped.text(), LONG);
    let start = tb.shaped.cursor_at(0);
    assert_eq!(tb.shaped.char_index(start), 0);
    let (caret_x, _, _) = crate::paint::text::caret_position(&tb.shaped.buffer, start).expect("a caret");
    assert!((caret_x - tb.shaped.indent).abs() < 0.5, "character 0 sits after the indent: {caret_x}");
    let run = tb.shaped.buffer.layout_runs().next().unwrap();
    let first = run.glyphs.iter().find(|g| g.metadata != crate::text::shape_cache::INDENT_META).unwrap();
    let hit = crate::input::char_at(tb, tb.x + first.x + 1.0, tb.y + run.line_y - 3.0);
    assert_eq!(hit, Some(0), "Para#hit on the first letter is character 0");
    let end = tb.shaped.cursor_at(LONG.chars().count());
    assert_eq!(tb.shaped.char_index(end), LONG.chars().count());
}

#[test]
fn a_slot_beside_a_taller_one_in_a_flow_reaches_down_to_its_bottom() {
    // Shoes 3 grows a slot with no height of its own to its parent's end as it draws it
    // (shoes_canvas_draw: fully = canvas->endy = max(canvas->endy, endy + bmargin), and
    // place.h = canvas->endy - place.y, s3_canvas.c:639-642), and the parent's end is already the
    // bottom of what came before on the row. So Hackety Hack's lesson pane, beside its 549 px
    // content flow, is dark to the window's foot with its buttons along it; native stopped it at
    // its own content and left a white strip under it.
    let mut s = Scene::new();
    let tall = s.add("Flow", ROOT, json!({"width": 200, "height": 300}));
    let pane = s.add("Stack", ROOT, json!({"width": 150}));
    let back = s.add("Background", pane, json!({"fill": "#111"}));
    let words = s.add("Stack", pane, json!({"height": 100}));
    let bar = s.add("Flow", pane, json!({"height": 32, "bottom": 0}));
    let under = s.add("Stack", ROOT, json!({"width": 400}));
    let short = s.add("Stack", under, json!({"width": 100}));
    s.add("Stack", short, json!({"height": 40}));
    let l = s.layout(400.0, 400.0);
    assert_eq!(r(&l, tall), Rect::new(0.0, 0.0, 200.0, 300.0));
    assert_eq!(r(&l, pane), Rect::new(200.0, 0.0, 150.0, 300.0), "as tall as the flow before it");
    assert_eq!(r(&l, back), Rect::new(200.0, 0.0, 150.0, 300.0), "and its background with it");
    assert_eq!(r(&l, words), Rect::new(200.0, 0.0, 150.0, 100.0));
    assert_eq!(r(&l, bar), Rect::new(200.0, 268.0, 150.0, 32.0), "bottom: 0 is at the stretched foot");
    assert_eq!(r(&l, short).h, 40.0, "the first on its row has nothing to reach down to");
    let _ = under;
}

#[test]
fn a_slot_with_no_height_placed_by_bottom_is_measured_by_its_margins() {
    // Shoes 3 places a canvas it has not drawn yet with dh = its margins (shoes_place_decide,
    // s3_ruby.c:434-436), so `stack bottom: 26, margin: 4` has its top 26 + 8 px above the foot
    // and its contents below that: Hackety Hack's Quit tab icon sits at y 524 of 550, as the Mac
    // 1.0 screenshot has it (523), where native stood the stack on the 26 px line, 24 px higher.
    let mut s = Scene::new();
    let tab = s.add("Stack", ROOT, json!({"bottom": 26, "left": 0, "width": 38, "margin": 4}));
    let icon = s.add("Image", tab, json!({"url": "", "width": 16, "height": 16, "margin": 4}));
    let sized = s.add("Stack", ROOT, json!({"bottom": 26, "left": 100, "width": 38, "height": 32}));
    let l = s.layout(790.0, 550.0);
    assert_eq!(r(&l, tab).y, 550.0 - 26.0 - 8.0 + 4.0, "the stack's box starts inside its margin");
    assert_eq!(r(&l, icon).y, 524.0, "and its icon four more px down");
    assert_eq!(r(&l, sized), Rect::new(100.0, 492.0, 38.0, 32.0), "a slot with a height of its own stands on the line");
}
