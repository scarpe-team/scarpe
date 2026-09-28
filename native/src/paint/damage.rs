//! Repainting only what changed (native/PERF.md).
//!
//! A window keeps its last frame. Each repaint sums every laid-out node up as the rect it can
//! paint into and a fingerprint of what decides its pixels: its box and clip, its shaped text,
//! whether it is hovered, pressed or focused, its text field's state, and whether its props
//! changed since the last repaint (Revisions). The old and new rects of every node whose
//! summary changed, appeared or vanished are painted again, each into a pixmap of that rect's
//! size under a translated transform, which clips everything outside it for free.
//!
//! The whole frame is painted whenever that cannot be trusted: the first frame, a new size or
//! scale, anything that scrolls, a popup, modal or tooltip, nodes changing places in paint
//! order, and a turned image. SCARPE_NATIVE_DAMAGE=off turns partial repaints off;
//! SCARPE_NATIVE_DAMAGE=check paints every frame in full as well and reports any pixel the
//! partial repaint got wrong.

use super::{paint_nodes, Canvas, Scene};
use crate::doc::{Doc, Kind, Node};
use crate::elements::text_field::TextField;
use crate::input::ViewState;
use crate::layout::{LBox, Layout, Rect, TextBox};
use crate::props::Id;
use cosmic_text::{Affinity, Buffer, Cursor, Edit, Selection};
use std::collections::hash_map::DefaultHasher;
use std::collections::{HashMap, HashSet};
use std::hash::{Hash, Hasher};
use std::rc::Rc;
use tiny_skia::Pixmap;

/// More damage than this share of the frame is cheaper to paint in one go.
const MOSTLY: f32 = 0.5;
/// Scattered damage beyond this many rects is joined into this many, the nearest first.
const MAX_RECTS: usize = 8;
/// Two rects merge when their union is at most this many pixels bigger than the pair.
const NEAR: i64 = 64 * 64;
/// Extra pixels painted around a damaged rect and thrown away, so the rect's own edges are
/// not where the pixmap cuts shapes off (tiny-skia antialiases a cut edge a shade differently).
const MARGIN: i32 = 4;

/// How a repaint went, for stats and tests.
#[derive(Clone, Debug, PartialEq)]
pub enum Repaint {
    /// Nothing on screen changed.
    Nothing,
    /// Only these rects of the frame, in physical pixels.
    Rects(Vec<PxRect>),
    Everything,
}

impl Repaint {
    pub fn pixels(&self, frame: (u32, u32)) -> u64 {
        match self {
            Repaint::Nothing => 0,
            Repaint::Rects(rects) => rects.iter().map(|r| r.area() as u64).sum(),
            Repaint::Everything => frame.0 as u64 * frame.1 as u64,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PxRect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

impl PxRect {
    fn area(&self) -> i64 {
        self.w as i64 * self.h as i64
    }

    fn contains(&self, x: i32, y: i32) -> bool {
        x >= self.x && x < self.x + self.w && y >= self.y && y < self.y + self.h
    }

    fn union(&self, other: &PxRect) -> PxRect {
        let (x0, y0) = (self.x.min(other.x), self.y.min(other.y));
        let (x1, y1) = ((self.x + self.w).max(other.x + other.w), (self.y + self.h).max(other.y + other.h));
        PxRect { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
    }
}

/// When each node's props last changed, so a window can ask what changed since it painted.
#[derive(Default)]
pub struct Revisions {
    now: u64,
    /// The last change that reaches every node (a font arrived).
    everything: u64,
    nodes: HashMap<Id, u64>,
}

impl Revisions {
    pub fn touch(&mut self, id: Id) {
        self.now += 1;
        self.nodes.insert(id, self.now);
    }

    pub fn touch_everything(&mut self) {
        self.now += 1;
        self.everything = self.now;
    }

    pub fn forget(&mut self, removed: &[Id]) {
        for id in removed {
            self.nodes.remove(id);
        }
    }

    pub fn now(&self) -> u64 {
        self.now
    }

    /// How many nodes have a revision.
    pub fn tracked(&self) -> usize {
        self.nodes.len()
    }

    fn changed_after(&self, seen: u64) -> impl Iterator<Item = Id> + '_ {
        self.nodes.iter().filter(move |(_, at)| **at > seen).map(|(id, _)| *id)
    }
}

/// What a window's last frame showed.
#[derive(Default)]
pub struct FrameMemory {
    last: Option<Frame>,
}

impl FrameMemory {
    /// The next repaint paints everything.
    pub fn forget(&mut self) {
        self.last = None;
    }
}

struct Frame {
    revision: u64,
    size: (u32, u32),
    scale: f32,
    /// A popup, modal or tooltip was up: they draw over everything.
    overlaid: bool,
    /// Scroll offsets and scrollbars.
    scrolling: u64,
    order: Vec<Id>,
    nodes: HashMap<Id, Look>,
}

/// One node as it was painted.
struct Look {
    /// Where it can paint (logical px); None for a turned image, which may be anywhere.
    bounds: Option<Rect>,
    fingerprint: u64,
    /// Its shaped text, compared by pointer and held so the allocation cannot be reused.
    text: Option<Rc<Buffer>>,
}

/// Brings `frame` up to date with `scene`, painting as little as it can.
pub fn repaint(scene: &mut Scene, frame: &mut Pixmap, scale: f32, memory: &mut FrameMemory, revisions: &Revisions) -> Repaint {
    let hovered: HashSet<Id> = scene.view.hover_chain.iter().copied().collect();
    let mut now = look_at(scene.doc, scene.layout, scene.view, &hovered, (frame.width(), frame.height()), scale, revisions.now());
    let plan = match &memory.last {
        Some(before) => plan(before, &now, &changed_since(before, &now, scene.doc, revisions)),
        None => Repaint::Everything,
    };
    match &plan {
        Repaint::Everything => super::paint(scene, frame, scale),
        Repaint::Rects(rects) => {
            for r in rects {
                paint_rect(scene, frame, scale, *r);
            }
        }
        Repaint::Nothing => {}
    }
    // Drawing a text field sets it up (it is made the first time it is drawn, then fitted to
    // its box), so fields are summed up again as drawn.
    for id in scene.view.fields.keys() {
        if let (Some(look), Some(node), Some(lbox)) = (now.nodes.get_mut(id), scene.doc.get(*id), scene.layout.boxes.get(id)) {
            look.fingerprint = fingerprint(node, lbox, scene.layout.texts.get(id), scene.view, &hovered);
        }
    }
    memory.last = Some(now);
    plan
}

/// Paints one damaged rect and copies it into the frame.
fn paint_rect(scene: &mut Scene, frame: &mut Pixmap, scale: f32, r: PxRect) {
    let (part, (x0, y0)) = paint_padded(scene, (frame.width(), frame.height()), scale, r, true);
    let (frame_w, part_w, row) = (frame.width() as usize * 4, part.width() as usize * 4, r.w as usize * 4);
    let (dst, src) = (frame.data_mut(), part.data());
    for y in 0..r.h as usize {
        let to = (r.y as usize + y) * frame_w + r.x as usize * 4;
        let from = (r.y - y0) as usize * part_w + y * part_w + (r.x - x0) as usize * 4;
        dst[to..to + row].copy_from_slice(&src[from..from + row]);
    }
}

/// A rect and a margin around it painted into a pixmap of their own, and where that pixmap
/// sits in the frame. `cull`: skip nodes that cannot reach it (verify paints without).
fn paint_padded(scene: &mut Scene, frame: (u32, u32), scale: f32, r: PxRect, cull: bool) -> (Pixmap, (i32, i32)) {
    let x0 = (r.x - MARGIN).max(0);
    let y0 = (r.y - MARGIN).max(0);
    let x1 = (r.x + r.w + MARGIN).min(frame.0 as i32);
    let y1 = (r.y + r.h + MARGIN).min(frame.1 as i32);
    let mut part = Pixmap::new((x1 - x0).max(1) as u32, (y1 - y0).max(1) as u32).expect("a damaged rect inside the frame");
    let region = Rect::new(x0 as f32 / scale, y0 as f32 / scale, (x1 - x0) as f32 / scale, (y1 - y0) as f32 / scale);
    paint_nodes(scene, Canvas::at(&mut part, scale, (x0, y0)), cull.then_some(region));
    (part, (x0, y0))
}

/// What a repaint got wrong, if anything (SCARPE_NATIVE_DAMAGE=check, and the tests).
///
/// Outside the repainted rects, a full paint now must equal the full paint before, bit for
/// bit, or a pixel went stale. Inside them the frame must equal the same rects painted with no
/// node skipped, or culling left out a node that reaches in. (A rect is not compared with a
/// full paint: tiny-skia approximates a curve that a pixmap edge cuts through a shade
/// differently, and both shades are right.) A repaint of everything must equal a full paint.
pub fn verify(scene: &mut Scene, plan: &Repaint, frame: &Pixmap, scale: f32, full: &Pixmap, full_before: &Pixmap) -> Result<(), String> {
    let width = full.width() as usize;
    let differ = |a: &Pixmap, b: &Pixmap, i: usize| a.data()[i * 4..i * 4 + 4] != b.data()[i * 4..i * 4 + 4];
    let rects: &[PxRect] = match plan {
        Repaint::Everything if frame.data() != full.data() => return Err("a repaint of everything differs from a full paint".into()),
        Repaint::Everything => return Ok(()),
        Repaint::Nothing => &[],
        Repaint::Rects(rects) => rects,
    };
    let stale = (0..width * full.height() as usize)
        .filter(|i| !rects.iter().any(|r| r.contains((i % width) as i32, (i / width) as i32)))
        .filter(|i| differ(full, full_before, *i))
        .count();
    if stale > 0 {
        return Err(format!("{stale} stale pixels after {plan:?}"));
    }
    for r in rects {
        let (part, at) = paint_padded(scene, (frame.width(), frame.height()), scale, *r, false);
        let wrong = (0..r.h as usize)
            .flat_map(|y| (0..r.w as usize).map(move |x| (x, y)))
            .filter(|(x, y)| {
                let f = ((r.y as usize + y) * width + r.x as usize + x) * 4;
                let p = ((y + (r.y - at.1) as usize) * part.width() as usize + x + (r.x - at.0) as usize) * 4;
                frame.data()[f..f + 4] != part.data()[p..p + 4]
            })
            .count();
        if wrong > 0 {
            return Err(format!("{wrong} pixels in {r:?} differ from the rect painted with no node skipped"));
        }
    }
    Ok(())
}

/// The painted nodes whose props changed since `before`. A change to a node painted in neither
/// frame (a text span, art an image draws itself) can only show through a painted ancestor,
/// so the nearest one counts as changed instead.
fn changed_since(before: &Frame, now: &Frame, doc: &Doc, revisions: &Revisions) -> Changed {
    if revisions.everything > before.revision {
        return Changed::Everything;
    }
    let mut changed = HashSet::new();
    for id in revisions.changed_after(before.revision) {
        if now.nodes.contains_key(&id) || before.nodes.contains_key(&id) {
            changed.insert(id);
        } else if let Some(painted) = painted_ancestor(doc, now, id) {
            changed.insert(painted);
        }
    }
    Changed::Nodes(changed)
}

/// The nearest ancestor a change to `id` could show through: none when the node or anything
/// above it is hidden, or for a SubscriptionItem, which draws nothing.
fn painted_ancestor(doc: &Doc, now: &Frame, id: Id) -> Option<Id> {
    let hidden = |id: Id| doc.get(id).is_none_or(|n| n.props.truthy("hidden"));
    if hidden(id) || doc.get(id).is_some_and(|n| n.kind == Kind::SubscriptionItem) {
        return None;
    }
    for ancestor in doc.ancestors(id) {
        if now.nodes.contains_key(&ancestor) {
            return Some(ancestor);
        }
        if hidden(ancestor) {
            return None;
        }
    }
    None
}

enum Changed {
    Everything,
    Nodes(HashSet<Id>),
}

fn plan(before: &Frame, now: &Frame, changed: &Changed) -> Repaint {
    let Changed::Nodes(changed) = changed else { return Repaint::Everything };
    let whole = before.size != now.size
        || before.scale != now.scale
        || before.overlaid
        || now.overlaid
        || before.scrolling != now.scrolling
        || !same_order(before, now);
    if whole {
        return Repaint::Everything;
    }
    // Where changed nodes were and are; a change nobody can bound repaints everything.
    let mut damage = Vec::new();
    for (id, look) in &now.nodes {
        let old = before.nodes.get(id);
        let unchanged = old.is_some_and(|old| {
            old.fingerprint == look.fingerprint && old.bounds == look.bounds && same_text(&old.text, &look.text) && !changed.contains(id)
        });
        if unchanged {
            continue;
        }
        for bounds in old.map(|old| old.bounds).into_iter().chain([look.bounds]) {
            let Some(bounds) = bounds else { return Repaint::Everything };
            damage.push(bounds);
        }
    }
    for (id, old) in &before.nodes {
        if !now.nodes.contains_key(id) {
            let Some(bounds) = old.bounds else { return Repaint::Everything };
            damage.push(bounds);
        }
    }
    let rects: Vec<PxRect> = damage.into_iter().filter_map(|b| to_pixels(b, now.scale, now.size)).collect();
    if rects.is_empty() {
        return Repaint::Nothing;
    }
    let rects = merge(rects);
    let area: i64 = rects.iter().map(PxRect::area).sum();
    if area as f32 > MOSTLY * now.size.0 as f32 * now.size.1 as f32 {
        return Repaint::Everything;
    }
    Repaint::Rects(rects)
}

/// Nodes kept their places relative to each other; new and removed ones aside.
fn same_order(before: &Frame, now: &Frame) -> bool {
    let kept_before = before.order.iter().filter(|id| now.nodes.contains_key(id));
    let kept_now = now.order.iter().filter(|id| before.nodes.contains_key(id));
    kept_before.eq(kept_now)
}

fn same_text(a: &Option<Rc<Buffer>>, b: &Option<Rc<Buffer>>) -> bool {
    match (a, b) {
        (Some(a), Some(b)) => Rc::ptr_eq(a, b),
        (None, None) => true,
        _ => false,
    }
}

fn look_at(doc: &Doc, layout: &Layout, view: &ViewState, hovered: &HashSet<Id>, size: (u32, u32), scale: f32, revision: u64) -> Frame {
    let mut nodes = HashMap::with_capacity(layout.order.len());
    for &id in &layout.order {
        let (Some(node), Some(lbox)) = (doc.get(id), layout.boxes.get(&id)) else { continue };
        let text = layout.texts.get(&id);
        nodes.insert(
            id,
            Look {
                bounds: paint_bounds(node, lbox, text),
                fingerprint: fingerprint(node, lbox, text, view, hovered),
                text: text.map(|tb| tb.shaped.buffer.clone()),
            },
        );
    }
    Frame {
        revision,
        size,
        scale,
        // A tooltip counts from when the pointer rests on its owner, not only once it shows, so
        // the frame that brings it up is painted whole.
        overlaid: view.popup.is_some() || view.modal.is_some() || view.tooltip.as_ref().is_some_and(|t| !t.dismissed),
        scrolling: scrolling(layout),
        order: layout.order.clone(),
        nodes,
    }
}

/// Everything besides props that decides a node's pixels.
fn fingerprint(node: &Node, lbox: &LBox, text: Option<&TextBox>, view: &ViewState, hovered: &HashSet<Id>) -> u64 {
    let mut h = DefaultHasher::new();
    rect_bits(lbox.rect).hash(&mut h);
    lbox.clip.map(rect_bits).hash(&mut h);
    if let Some(tb) = text {
        // A block's fill is a highlight in its runs (manual 1208-1210), so a new fill shapes a
        // new buffer, which `Look::text` tells apart.
        (tb.x.to_bits(), tb.y.to_bits()).hash(&mut h);
        // A hovered link changes colour, which only the paras holding it show.
        view.hover_link.filter(|link| tb.shaped.metas.iter().any(|m| m.link == Some(*link))).hash(&mut h);
    }
    if shows_widget_state(&node.kind) {
        let focused = view.focus == Some(node.id);
        let pressed = view.pressed.as_ref().is_some_and(|p| p.target == node.id);
        (hovered.contains(&node.id), pressed, focused, focused && view.focus_visible).hash(&mut h);
        match view.fields.get(&node.id) {
            Some(field) => field_state(field, &mut h),
            None => 0u8.hash(&mut h),
        }
    }
    h.finish()
}

/// The controls whose look follows the pointer and the focus (elements::state_of).
fn shows_widget_state(kind: &Kind) -> bool {
    matches!(kind, Kind::Button | Kind::Check | Kind::Radio | Kind::EditLine | Kind::EditBox | Kind::ListBox | Kind::Slider)
}

fn field_state(field: &TextField, h: &mut DefaultHasher) {
    field.editor_buffer(|buffer| buffer.lines.iter().for_each(|line| line.text().hash(h)));
    cursor_bits(field.editor.cursor()).hash(h);
    match field.editor.selection() {
        Selection::None => 0u8.hash(h),
        Selection::Normal(c) => (1u8, cursor_bits(c)).hash(h),
        Selection::Line(c) => (2u8, cursor_bits(c)).hash(h),
        Selection::Word(c) => (3u8, cursor_bits(c)).hash(h),
    }
    (field.offset.0.to_bits(), field.offset.1.to_bits(), field.secret).hash(h);
}

fn cursor_bits(c: Cursor) -> (usize, usize, bool) {
    (c.line, c.index, c.affinity == Affinity::After)
}

fn scrolling(layout: &Layout) -> u64 {
    let mut scrollers: Vec<_> =
        layout.scrollers.iter().map(|(id, s)| (*id, rect_bits(s.viewport), s.content_height.to_bits(), s.top.to_bits())).collect();
    scrollers.sort_unstable();
    let mut h = DefaultHasher::new();
    scrollers.hash(&mut h);
    h.finish()
}

fn rect_bits(r: Rect) -> [u32; 4] {
    [r.x.to_bits(), r.y.to_bits(), r.w.to_bits(), r.h.to_bits()]
}

/// Where a node can put pixels, in logical px: its box, grown by what it draws outside it
/// (shadows and focus rings, strokes, glyphs past the line box), cut to its clip. None for a
/// turned image, which may be anywhere.
pub fn paint_bounds(node: &Node, lbox: &LBox, text: Option<&TextBox>) -> Option<Rect> {
    let p = &node.props;
    let (slack_x, slack_y) = match &node.kind {
        k if k.is_art() => {
            // Layout has turned art's box already (layout::turn_art). A stroke or a star's
            // points reach past it by `reach`, and turn, scale and skew with the art: along x
            // by |sx| + |kx| of that, along y by |ky| + |sy|.
            let reach = p.art_f32("strokewidth").unwrap_or(1.0).abs() + 2.0 + super::shapes::overhang(node);
            let t = super::shapes::art_transform(node, lbox.rect);
            (reach * (t.sx.abs() + t.kx.abs()), reach * (t.ky.abs() + t.sy.abs()))
        }
        Kind::Image if p.f32("rotate_angle").is_some_and(|deg| deg != 0.0) => return None,
        Kind::Background | Kind::Border => (2.0, 2.0),
        _ => (10.0, 10.0),
    };
    let mut bounds = grow(lbox.rect, slack_x, slack_y);
    if let Some(tb) = text {
        let reach = slack_x + tb.shaped.buffer.metrics().line_height * 0.5;
        let (left, right) = (tb.shaped.ink.0.min(0.0), tb.shaped.ink.1.max(tb.shaped.width));
        bounds = union(bounds, grow(Rect::new(tb.x + left, tb.y, right - left, tb.shaped.height), reach, reach));
    }
    Some(match lbox.clip {
        Some(clip) => bounds.intersect(&clip).unwrap_or(Rect::new(clip.x, clip.y, 0.0, 0.0)),
        None => bounds,
    })
}

/// Whether a node can put pixels inside `region` (the culling side of paint_bounds).
pub fn may_touch(node: &Node, lbox: &LBox, text: Option<&TextBox>, region: Rect) -> bool {
    paint_bounds(node, lbox, text).is_none_or(|b| b.x < region.right() && region.x < b.right() && b.y < region.bottom() && region.y < b.bottom())
}

fn grow(r: Rect, x: f32, y: f32) -> Rect {
    Rect::new(r.x - x, r.y - y, r.w + 2.0 * x, r.h + 2.0 * y)
}

fn union(a: Rect, b: Rect) -> Rect {
    let (x0, y0) = (a.x.min(b.x), a.y.min(b.y));
    Rect::new(x0, y0, a.right().max(b.right()) - x0, a.bottom().max(b.bottom()) - y0)
}

/// Logical rect to whole frame pixels, one more on each side for antialiasing.
fn to_pixels(r: Rect, scale: f32, frame: (u32, u32)) -> Option<PxRect> {
    let x0 = ((r.x * scale).floor() as i32 - 1).max(0);
    let y0 = ((r.y * scale).floor() as i32 - 1).max(0);
    let x1 = ((r.right() * scale).ceil() as i32 + 1).min(frame.0 as i32);
    let y1 = ((r.bottom() * scale).ceil() as i32 + 1).min(frame.1 as i32);
    (x1 > x0 && y1 > y0).then_some(PxRect { x: x0, y: y0, w: x1 - x0, h: y1 - y0 })
}

/// Joins rects that overlap (every pixel belongs to one rect, painted once) or nearly touch.
/// Past MAX_RECTS it joins the two whose union is the smallest box, by its width and height,
/// again and again, so a dozen fireflies far apart stay a few small clusters rather than one
/// box across the window. (Joining whatever adds the fewest pixels instead lines far dots up
/// into long strips, which later joins widen into boxes as big as the window.)
fn merge(mut rects: Vec<PxRect>) -> Vec<PxRect> {
    loop {
        while let Some((i, j)) = mergeable(&rects) {
            rects[i] = rects[i].union(&rects[j]);
            rects.swap_remove(j);
        }
        if rects.len() <= MAX_RECTS {
            return rects;
        }
        let (i, j) = cheapest_pair(&rects);
        rects[i] = rects[i].union(&rects[j]);
        rects.swap_remove(j);
    }
}

/// The two rects whose union is the smallest box, measured by its width plus its height.
fn cheapest_pair(rects: &[PxRect]) -> (usize, usize) {
    let mut best = (0, 1, i32::MAX);
    for i in 0..rects.len() {
        for j in i + 1..rects.len() {
            let both = rects[i].union(&rects[j]);
            if both.w + both.h < best.2 {
                best = (i, j, both.w + both.h);
            }
        }
    }
    (best.0, best.1)
}

fn mergeable(rects: &[PxRect]) -> Option<(usize, usize)> {
    if rects.len() > 64 {
        return Some((0, 1));
    }
    for i in 0..rects.len() {
        for j in i + 1..rects.len() {
            let (a, b) = (rects[i], rects[j]);
            let overlap = a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
            if overlap || a.union(&b).area() <= a.area() + b.area() + NEAR {
                return Some((i, j));
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn px(x: i32, y: i32, w: i32, h: i32) -> PxRect {
        PxRect { x, y, w, h }
    }

    #[test]
    fn neighbours_merge_and_strangers_stay_apart() {
        assert_eq!(merge(vec![px(0, 0, 10, 10), px(5, 5, 10, 10)]), vec![px(0, 0, 15, 15)]);
        assert_eq!(merge(vec![px(0, 0, 10, 10), px(500, 500, 10, 10)]).len(), 2);
    }

    #[test]
    fn overlapping_rects_always_merge_so_no_pixel_is_painted_twice() {
        // Their union is far bigger than the pair, but they share pixels.
        assert_eq!(merge(vec![px(0, 0, 200, 200), px(190, 190, 200, 200)]), vec![px(0, 0, 390, 390)]);
    }

    #[test]
    fn scattered_damage_joins_its_nearest_rects_down_to_max_rects() {
        // Twenty dots in four far corners: four clusters, not one box across everything.
        let corners = [(0, 0), (5000, 0), (0, 5000), (5000, 5000)];
        let many: Vec<PxRect> = (0..20).map(|i| {
            let (x, y) = corners[i % 4];
            px(x + (i as i32 / 4) * 200, y + (i as i32 / 4) * 150, 4, 4)
        }).collect();
        let merged = merge(many.clone());
        assert!(merged.len() <= MAX_RECTS, "{merged:?}");
        for r in &many {
            assert!(merged.iter().any(|m| m.contains(r.x, r.y) && m.contains(r.x + r.w - 1, r.y + r.h - 1)), "{r:?} is covered");
        }
        let area: i64 = merged.iter().map(PxRect::area).sum();
        assert!(area < 4 * 804 * 604, "{area} pixels for {merged:?}");
        let overlap = |a: &PxRect, b: &PxRect| a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
        for (i, a) in merged.iter().enumerate() {
            assert!(merged[i + 1..].iter().all(|b| !overlap(a, b)), "no pixel is painted twice: {merged:?}");
        }
    }

    #[test]
    fn logical_rects_snap_outwards_to_whole_pixels_inside_the_frame() {
        assert_eq!(to_pixels(Rect::new(10.25, 5.0, 2.0, 2.0), 2.0, (100, 100)), Some(px(19, 9, 7, 6)));
        assert_eq!(to_pixels(Rect::new(-5.0, -5.0, 10.0, 10.0), 1.0, (100, 100)), Some(px(0, 0, 6, 6)));
        assert_eq!(to_pixels(Rect::new(200.0, 0.0, 10.0, 10.0), 1.0, (100, 100)), None);
    }

    fn node(doc: &mut Doc, id: Id, class: &str, parent: Option<Id>, props: serde_json::Value) {
        let props = props.as_object().cloned().unwrap_or_default();
        doc.create(crate::doc::NewNode { id, class: class.into(), parent, index: None, widget: false, props, doc_root: None, owner: None });
    }

    fn frame_of(painted: &[Id]) -> Frame {
        let look = || Look { bounds: Some(Rect::new(0.0, 0.0, 10.0, 10.0)), fingerprint: 0, text: None };
        Frame { revision: 0, size: (10, 10), scale: 1.0, overlaid: false, scrolling: 0, order: painted.to_vec(), nodes: painted.iter().map(|id| (*id, look())).collect() }
    }

    #[test]
    fn a_change_shows_through_the_nearest_painted_ancestor() {
        let mut doc = Doc::default();
        node(&mut doc, 2, "DocumentRoot", None, serde_json::json!({}));
        node(&mut doc, 3, "Para", Some(2), serde_json::json!({}));
        node(&mut doc, 4, "Strong", Some(3), serde_json::json!({}));
        node(&mut doc, 5, "Stack", Some(2), serde_json::json!({"hidden": true}));
        node(&mut doc, 6, "Para", Some(5), serde_json::json!({}));
        node(&mut doc, 7, "SubscriptionItem", Some(2), serde_json::json!({}));
        let (before, now) = (frame_of(&[2, 3]), frame_of(&[2, 3]));
        let changed = |touched: &[Id]| {
            let mut revisions = Revisions::default();
            touched.iter().for_each(|id| revisions.touch(*id));
            match changed_since(&before, &now, &doc, &revisions) {
                Changed::Nodes(ids) => ids.into_iter().collect::<Vec<_>>(),
                Changed::Everything => panic!("not everything"),
            }
        };
        assert_eq!(changed(&[4]), vec![3], "a span shows through its para");
        assert_eq!(changed(&[6]), Vec::<Id>::new(), "nothing inside a hidden stack shows");
        assert_eq!(changed(&[7]), Vec::<Id>::new(), "a subscription item draws nothing");
        assert_eq!(changed(&[3]), vec![3]);
    }

    #[test]
    fn revisions_answer_what_changed_since_a_frame() {
        let mut revisions = Revisions::default();
        revisions.touch(4);
        let seen = revisions.now();
        assert_eq!(revisions.changed_after(seen).count(), 0);
        revisions.touch(4);
        assert_eq!(revisions.changed_after(seen).collect::<Vec<_>>(), vec![4]);
        revisions.forget(&[4]);
        assert_eq!(revisions.changed_after(seen).count(), 0);
    }
}
