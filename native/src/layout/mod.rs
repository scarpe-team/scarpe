//! The Shoes layout engine (DESIGN section 6): stacks, flows, text blocks,
//! widgets, out-of-flow placement, scrolling. Logical pixels throughout.
//!
//! Sizing rule for margins: a relative width or height (fraction, percent,
//! negative, or a slot filling its line) sizes the margin box, so two
//! `width: 0.5, margin: 10` flows sit side by side; a px size is the box
//! itself, and margins add outside it.

use crate::doc::{Doc, Kind, Node};
use crate::elements::{self, image::ImageCache};
use crate::paint::shapes;
use crate::props::{Edges, Id};
use crate::style::Dim;
use crate::text::{rich, ShapedText, TextEngine};
use std::collections::HashMap;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Rect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

impl Rect {
    pub const fn new(x: f32, y: f32, w: f32, h: f32) -> Self {
        Rect { x, y, w, h }
    }

    pub fn right(&self) -> f32 {
        self.x + self.w
    }

    pub fn bottom(&self) -> f32 {
        self.y + self.h
    }

    pub fn center(&self) -> (f32, f32) {
        (self.x + self.w / 2.0, self.y + self.h / 2.0)
    }

    pub fn contains(&self, x: f32, y: f32) -> bool {
        x >= self.x && x < self.right() && y >= self.y && y < self.bottom()
    }

    pub fn intersect(&self, other: &Rect) -> Option<Rect> {
        let x0 = self.x.max(other.x);
        let y0 = self.y.max(other.y);
        let x1 = self.right().min(other.right());
        let y1 = self.bottom().min(other.bottom());
        (x1 > x0 && y1 > y0).then(|| Rect::new(x0, y0, x1 - x0, y1 - y0))
    }

    pub fn translate(&self, dx: f32, dy: f32) -> Rect {
        Rect::new(self.x + dx, self.y + dy, self.w, self.h)
    }

    pub fn inset(&self, e: &Edges) -> Rect {
        Rect::new(self.x + e.left, self.y + e.top, (self.w - e.horizontal()).max(0.0), (self.h - e.vertical()).max(0.0))
    }
}

/// Where a laid-out node ended up.
#[derive(Clone, Debug, PartialEq)]
pub struct LBox {
    /// Border box in window coordinates.
    pub rect: Rect,
    /// The visible region imposed by scrolling ancestors, if any.
    pub clip: Option<Rect>,
    /// For art: the slot content origin its left/top are measured from.
    pub origin: (f32, f32),
    /// The slot content size relative values resolve against.
    pub parent_size: (f32, f32),
}

#[derive(Clone)]
pub struct TextBox {
    pub shaped: ShapedText,
    pub x: f32,
    pub y: f32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Scroller {
    pub viewport: Rect,
    pub content_height: f32,
    pub top: f32,
}

impl Scroller {
    pub fn max_top(&self) -> f32 {
        (self.content_height - self.viewport.h).max(0.0)
    }
}

#[derive(Clone, Default)]
pub struct Layout {
    pub size: (f32, f32),
    pub root: Id,
    pub boxes: HashMap<Id, LBox>,
    /// Paint order: tree order, laid-out nodes only.
    pub order: Vec<Id>,
    pub texts: HashMap<Id, TextBox>,
    pub scrollers: HashMap<Id, Scroller>,
    /// Live SubscriptionItems (their parent slot is laid out), in tree order.
    pub subscriptions: Vec<Id>,
}

impl Layout {
    pub fn rect(&self, id: Id) -> Option<Rect> {
        self.boxes.get(&id).map(|b| b.rect)
    }

    /// The part of a node's box a user can actually see.
    pub fn visible_rect(&self, id: Id) -> Option<Rect> {
        let b = self.boxes.get(&id)?;
        let window = Rect::new(0.0, 0.0, self.size.0, self.size.1);
        let r = b.rect.intersect(&window).or_else(|| (b.rect.w == 0.0 || b.rect.h == 0.0).then_some(b.rect))?;
        match b.clip {
            Some(clip) => r.intersect(&clip),
            None => Some(r),
        }
    }
}

pub struct Inputs<'a> {
    pub doc: &'a Doc,
    pub text: &'a mut TextEngine,
    pub images: &'a mut ImageCache,
    pub scroll: &'a HashMap<Id, f32>,
}

pub fn layout(inputs: Inputs, root: Id, size: (f32, f32)) -> Layout {
    let mut engine = Engine {
        doc: inputs.doc,
        text: inputs.text,
        images: inputs.images,
        scroll: inputs.scroll,
        out: Layout { size, root, ..Layout::default() },
        attached: Vec::new(),
        clips: HashMap::new(),
    };
    engine.root(root, size);
    let out = engine.finish(root);
    inputs.text.end_layout();
    out
}

struct Engine<'a> {
    doc: &'a Doc,
    text: &'a mut TextEngine,
    images: &'a mut ImageCache,
    scroll: &'a HashMap<Id, f32>,
    out: Layout,
    attached: Vec<(Id, Attach)>,
    /// Slots with a fixed height: they chop off what does not fit, scrolling or not.
    clips: HashMap<Id, Rect>,
}

#[derive(Clone, Copy)]
enum Attach {
    Window,
    Node(Id),
}

#[derive(Default)]
struct Cursor {
    x: f32,
    y: f32,
    row_h: f32,
}

/// How a slot child takes part in layout.
enum Role {
    Skip,
    Subscription,
    InFlow,
    OutOfFlow,
}

fn hidden(node: &Node) -> bool {
    node.props.truthy("hidden")
}

fn role(node: &Node) -> Role {
    match &node.kind {
        Kind::SubscriptionItem => Role::Subscription,
        k if k.is_span() => Role::Skip,
        Kind::App | Kind::DocumentRoot | Kind::Mask | Kind::Unknown(_) => Role::Skip,
        k if k.is_art() || k.is_decor() => Role::OutOfFlow,
        _ => {
            let p = &node.props;
            if p.has("left") || p.has("top") || p.has("right") || p.has("bottom") || p.has("attach") {
                Role::OutOfFlow
            } else {
                Role::InFlow
            }
        }
    }
}

impl Engine<'_> {
    fn root(&mut self, root: Id, size: (f32, f32)) {
        let doc = self.doc;
        let Some(node) = doc.get(root) else { return };
        let viewport = Rect::new(0.0, 0.0, size.0, size.1);
        let padding = node.props.padding(size.0);
        let content = viewport.inset(&padding);
        let (content_h, later) = self.children(root, true, content, size.1);
        let doc_h = (content_h + padding.vertical()).max(size.1);
        let slot_box = Rect::new(0.0, 0.0, size.0, doc_h);
        self.out.boxes.insert(root, LBox { rect: viewport, clip: None, origin: (0.0, 0.0), parent_size: size });
        self.place_later(&later, slot_box, Rect::new(content.x, content.y, content.w, doc_h - padding.vertical()), size.1);
        // The window's own backgrounds cover the whole document, so they scroll with it.
        self.scroll_subtree(root, viewport, content_h + padding.vertical(), true, true);
    }

    fn finish(mut self, root: Id) -> Layout {
        let doc = self.doc;
        let window = Rect::new(0.0, 0.0, self.out.size.0, self.out.size.1);
        for (id, attach) in std::mem::take(&mut self.attached) {
            let frame = match attach {
                Attach::Window => window,
                Attach::Node(target) => self.out.rect(target).map(|r| Rect::new(r.x, r.y, window.w, window.h)).unwrap_or(window),
            };
            if let Some(node) = doc.get(id) {
                self.place_positioned(node, frame, window.h);
            }
        }
        self.assign_clips(root, None);
        let mut order = Vec::with_capacity(self.out.boxes.len());
        let mut subs = Vec::new();
        collect_order(doc, root, &self.out.boxes, &mut order, &mut subs);
        self.out.order = order;
        self.out.subscriptions = subs;
        self.out
    }

    /// Lays out a slot's in-flow children in `content`. Returns the height they
    /// need and the children placed after the slot's size is known.
    fn children(&mut self, slot: Id, flow: bool, content: Rect, avail_h: f32) -> (f32, Vec<Id>) {
        let doc = self.doc;
        let mut cursor = Cursor::default();
        let mut later = Vec::new();
        for &child in doc.children(slot) {
            let Some(node) = doc.get(child) else { continue };
            if hidden(node) {
                continue;
            }
            match role(node) {
                Role::Skip | Role::Subscription => {}
                Role::OutOfFlow => later.push(child),
                Role::InFlow => self.place_in_flow(node, flow, content, &mut cursor, avail_h),
            }
        }
        let used = if flow { cursor.y + cursor.row_h } else { cursor.y };
        (used, later)
    }

    fn place_in_flow(&mut self, node: &Node, flow: bool, content: Rect, cursor: &mut Cursor, avail_h: f32) {
        let m = node.props.margins(content.w);
        let parent = (content.w, avail_h);
        let remaining = if flow { content.w - cursor.x } else { content.w };
        let mut width = self.width_for(node, flow, parent, remaining, &m);
        let overflows = cursor.x + m.horizontal() + width > content.w + 0.5;
        // A slot filling its line would get no width at all after a full row.
        let squeezed = width < 1.0 && node.kind.is_slot();
        if flow && cursor.x > 0.0 && (overflows || squeezed) {
            cursor.y += cursor.row_h;
            cursor.x = 0.0;
            cursor.row_h = 0.0;
            width = self.width_for(node, flow, parent, content.w, &m);
        }
        let x = content.x + cursor.x + m.left;
        let y = content.y + cursor.y + m.top;
        let h = self.place_box(node, x, y, width, parent, &m);
        if flow {
            cursor.x += m.horizontal() + width;
            cursor.row_h = cursor.row_h.max(m.vertical() + h);
        } else {
            cursor.y += m.vertical() + h;
        }
    }

    /// The border-box width a node gets on a line with `remaining` px left.
    fn width_for(&mut self, node: &Node, parent_flow: bool, parent: (f32, f32), remaining: f32, m: &Edges) -> f32 {
        let parent_w = parent.0;
        if let Some(dim) = node.props.dim("width") {
            return sized(dim, parent_w, m.horizontal());
        }
        let fill = (remaining - m.horizontal()).max(0.0);
        match &node.kind {
            Kind::Flow => (parent_w - m.horizontal()).max(0.0),
            Kind::Stack | Kind::Widget => fill,
            Kind::Para | Kind::TextDrawable => {
                let full = (parent_w - m.horizontal()).max(0.0);
                if !parent_flow {
                    return full;
                }
                let doc = self.doc;
                let Some(rich) = rich::resolve_block(doc, &self.text.fonts, node.id) else { return 0.0 };
                if rich.align != rich::Align::Left {
                    return if fill > 0.0 { fill } else { full };
                }
                let wanted = self.text.max_content(&rich);
                if wanted <= fill {
                    wanted
                } else {
                    wanted.min(full)
                }
            }
            Kind::Image => {
                let natural = self.intrinsic(node);
                match node.props.dim("height") {
                    Some(dim) => elements::image::width_for_height(natural, sized(dim, parent.1, m.vertical())),
                    None => natural.0,
                }
            }
            _ => self.intrinsic(node).0,
        }
    }

    fn intrinsic(&mut self, node: &Node) -> (f32, f32) {
        elements::intrinsic_size(node, self.text, self.images)
    }

    /// Lays out one node's box at (x, y) with a known width. Returns its height.
    fn place_box(&mut self, node: &Node, x: f32, y: f32, w: f32, parent: (f32, f32), m: &Edges) -> f32 {
        let explicit_h = node.props.dim("height").map(|d| sized(d, parent.1, m.vertical()));
        let h = match &node.kind {
            k if k.is_slot() => return self.slot(node, Rect::new(x, y, w, 0.0), explicit_h, parent),
            Kind::Para | Kind::TextDrawable => {
                let doc = self.doc;
                let shaped = rich::resolve_block(doc, &self.text.fonts, node.id).map(|rich| self.text.shape(&rich, Some(w.max(1.0))));
                let text_h = shaped.as_ref().map(|s| s.height).unwrap_or(0.0);
                if let Some(shaped) = shaped {
                    let y = y + shaped.top;
                    self.out.texts.insert(node.id, TextBox { shaped, x, y });
                }
                explicit_h.unwrap_or(text_h)
            }
            Kind::Image => {
                let natural = self.intrinsic(node);
                explicit_h.unwrap_or_else(|| elements::image::height_for_width(natural, w))
            }
            _ => {
                let (_, ih) = self.intrinsic(node);
                explicit_h.unwrap_or(ih)
            }
        };
        self.record(node, Rect::new(x, y, w, h), parent);
        if let Some(label) = elements::label(node, w, h, self.text) {
            self.out.texts.insert(node.id, TextBox { shaped: label.shaped, x: x + label.dx, y: y + label.dy });
        }
        self.displace(node);
        h
    }

    fn record(&mut self, node: &Node, rect: Rect, parent: (f32, f32)) {
        self.out.boxes.insert(node.id, LBox { rect, clip: None, origin: (rect.x, rect.y), parent_size: parent });
    }

    /// A slot: its children, then its decor and positioned children, then scrolling.
    fn slot(&mut self, node: &Node, frame: Rect, explicit_h: Option<f32>, parent: (f32, f32)) -> f32 {
        let padding = node.props.padding(frame.w);
        let content = Rect::new(frame.x + padding.left, frame.y + padding.top, (frame.w - padding.horizontal()).max(0.0), 0.0);
        let avail_h = explicit_h.map(|h| (h - padding.vertical()).max(0.0)).unwrap_or(parent.1);
        let flow = matches!(node.kind, Kind::Flow | Kind::DocumentRoot | Kind::Widget);
        let (used, later) = self.children(node.id, flow, content, avail_h);
        let h = explicit_h.unwrap_or(used + padding.vertical());
        let slot_box = Rect::new(frame.x, frame.y, frame.w, h);
        self.record(node, slot_box, parent);
        let content = Rect::new(content.x, content.y, content.w, (h - padding.vertical()).max(0.0));
        self.place_later(&later, slot_box, content, avail_h);
        let scrolls = node.props.truthy("scroll") && explicit_h.is_some();
        if explicit_h.is_some() {
            // Manual 345-352: a fixed height makes the slot a nested window, cut off at its edges.
            self.clips.insert(node.id, slot_box);
        }
        self.scroll_subtree(node.id, slot_box, used + padding.vertical(), scrolls, false);
        self.displace(node);
        h
    }

    fn place_later(&mut self, later: &[Id], slot_box: Rect, content: Rect, avail_h: f32) {
        let doc = self.doc;
        for &id in later {
            let Some(node) = doc.get(id) else { continue };
            match &node.kind {
                Kind::Background | Kind::Border => {
                    self.record(node, decor_box(node, slot_box), (slot_box.w, slot_box.h));
                }
                k if k.is_art() => self.place_art(node, content),
                _ => match node.props.get("attach") {
                    Some(serde_json::Value::String(s)) if is_window(s) => self.attached.push((id, Attach::Window)),
                    Some(v) if v.as_i64().is_some() => self.attached.push((id, Attach::Node(v.as_i64().unwrap_or(0)))),
                    _ => self.place_positioned(node, content, avail_h),
                },
            }
        }
    }

    fn place_art(&mut self, node: &Node, content: Rect) {
        let doc = self.doc;
        let parent = (content.w, content.h);
        let bounds = match shapes::art(node, (content.x, content.y), parent) {
            Some(art) => art.bounds,
            // A shape block holding only other art has no path of its own.
            None if node.kind == Kind::Shape => Rect::new(content.x, content.y, 0.0, 0.0),
            None => return,
        };
        self.out.boxes.insert(node.id, LBox { rect: bounds, clip: None, origin: (content.x, content.y), parent_size: parent });
        if node.kind == Kind::Shape {
            // Art drawn inside a shape block is positioned like its siblings.
            for &child in doc.children(node.id) {
                if let Some(c) = doc.get(child).filter(|c| c.kind.is_art() && !hidden(c)) {
                    self.place_art(c, content);
                }
            }
        }
        self.displace(node);
    }

    /// An element with left/top/right/bottom, out of flow in `frame`.
    fn place_positioned(&mut self, node: &Node, frame: Rect, avail_h: f32) {
        let p = &node.props;
        let m = p.margins(frame.w);
        let dim = |key: &str, basis: f32| p.dim(key).map(|d| d.resolve(basis));
        // Positioned text shrinks to fit what is left of the slot, like CSS absolute.
        let remaining = frame.w - dim("left", frame.w).unwrap_or(0.0);
        let w = self.width_for(node, true, (frame.w, avail_h), remaining, &m);
        let x = match (dim("left", frame.w), dim("right", frame.w)) {
            (Some(left), _) => frame.x + left + m.left,
            (None, Some(right)) => frame.right() - right - w - m.right,
            (None, None) => frame.x + m.left,
        };
        let top = dim("top", frame.h);
        let y = frame.y + top.unwrap_or(0.0) + m.top;
        let h = self.place_box(node, x, y, w, (frame.w, avail_h), &m);
        if top.is_none() {
            if let Some(bottom) = dim("bottom", frame.h) {
                let dy = frame.bottom() - bottom - h - m.bottom - y;
                self.translate_subtree(node.id, 0.0, dy);
            }
        }
    }

    fn displace(&mut self, node: &Node) {
        let dx = node.props.f32("displace_left").unwrap_or(0.0);
        let dy = node.props.f32("displace_top").unwrap_or(0.0);
        if dx != 0.0 || dy != 0.0 {
            self.translate_subtree(node.id, dx, dy);
        }
    }

    /// Clamps and applies a slot's scroll offset to everything inside it.
    fn scroll_subtree(&mut self, slot: Id, viewport: Rect, content_height: f32, scrolls: bool, decor_scrolls: bool) {
        if !scrolls {
            return;
        }
        let doc = self.doc;
        let mut scroller = Scroller { viewport, content_height, top: 0.0 };
        scroller.top = self.scroll.get(&slot).copied().unwrap_or(0.0).clamp(0.0, scroller.max_top());
        if scroller.top != 0.0 {
            for &child in doc.children(slot) {
                if decor_scrolls || !doc.get(child).is_some_and(|c| c.kind.is_decor()) {
                    self.translate_subtree(child, 0.0, -scroller.top);
                }
            }
        }
        self.out.scrollers.insert(slot, scroller);
    }

    fn translate_subtree(&mut self, id: Id, dx: f32, dy: f32) {
        let doc = self.doc;
        let mut stack = vec![id];
        while let Some(next) = stack.pop() {
            if let Some(b) = self.out.boxes.get_mut(&next) {
                b.rect = b.rect.translate(dx, dy);
                b.origin = (b.origin.0 + dx, b.origin.1 + dy);
            }
            if let Some(t) = self.out.texts.get_mut(&next) {
                t.x += dx;
                t.y += dy;
            }
            if let Some(s) = self.out.scrollers.get_mut(&next) {
                s.viewport = s.viewport.translate(dx, dy);
            }
            if let Some(c) = self.clips.get_mut(&next) {
                *c = c.translate(dx, dy);
            }
            stack.extend(doc.children(next).iter().copied());
        }
    }

    /// Scrolling and fixed-height slots clip their descendants (not their own decor).
    fn assign_clips(&mut self, id: Id, clip: Option<Rect>) {
        let doc = self.doc;
        if let Some(b) = self.out.boxes.get_mut(&id) {
            b.clip = clip;
        }
        let own = match self.out.scrollers.get(&id) {
            Some(s) if id != self.out.root => Some(s.viewport),
            _ => self.clips.get(&id).copied(),
        };
        let inner = match (own, clip) {
            (Some(own), Some(c)) => Some(c.intersect(&own).unwrap_or(Rect::new(own.x, own.y, 0.0, 0.0))),
            (Some(own), None) => Some(own),
            (None, c) => c,
        };
        for &child in doc.children(id) {
            let child_clip = if doc.get(child).is_some_and(|c| c.kind.is_decor()) { clip } else { inner };
            self.assign_clips(child, child_clip);
        }
    }
}

/// A background or border fills its slot, less any edges it names: `top: 50` runs from
/// 50 down to the bottom, `right: 0, width: 55` hugs the right side, `margin` insets it.
fn decor_box(node: &Node, slot: Rect) -> Rect {
    let p = &node.props;
    let m = p.margins(slot.w);
    let area = Rect::new(slot.x + m.left, slot.y + m.top, (slot.w - m.horizontal()).max(0.0), (slot.h - m.vertical()).max(0.0));
    let edge = |key: &str, basis: f32| p.dim(key).map(|d| d.resolve(basis));
    let (left, right) = (edge("left", area.w), edge("right", area.w));
    let (top, bottom) = (edge("top", area.h), edge("bottom", area.h));
    let w = edge("width", area.w).unwrap_or(area.w - left.unwrap_or(0.0) - right.unwrap_or(0.0)).max(0.0);
    let h = edge("height", area.h).unwrap_or(area.h - top.unwrap_or(0.0) - bottom.unwrap_or(0.0)).max(0.0);
    let x = match (left, right) {
        (Some(left), _) => left,
        (None, Some(right)) => area.w - right - w,
        (None, None) => 0.0,
    };
    let y = match (top, bottom) {
        (Some(top), _) => top,
        (None, Some(bottom)) => area.h - bottom - h,
        (None, None) => 0.0,
    };
    Rect::new(area.x + x, area.y + y, w, h)
}

fn is_window(s: &str) -> bool {
    let lower = s.to_ascii_lowercase();
    lower == "window" || lower == "shoes::app" || lower == "shoes::window" || lower == "app"
}

/// A requested size as a border-box size (see the module comment on margins).
fn sized(dim: Dim, parent: f32, margins: f32) -> f32 {
    match dim {
        Dim::Px(px) => px.max(0.0),
        relative => (relative.resolve(parent) - margins).max(0.0),
    }
}

fn collect_order(doc: &Doc, id: Id, boxes: &HashMap<Id, LBox>, order: &mut Vec<Id>, subs: &mut Vec<Id>) {
    if boxes.contains_key(&id) {
        order.push(id);
    }
    for &child in doc.children(id) {
        let Some(node) = doc.get(child) else { continue };
        if node.kind == Kind::SubscriptionItem {
            if boxes.contains_key(&id) && !hidden(node) {
                subs.push(child);
            }
            continue;
        }
        if boxes.contains_key(&child) {
            collect_order(doc, child, boxes, order, subs);
        }
    }
}

#[cfg(test)]
mod tests;
