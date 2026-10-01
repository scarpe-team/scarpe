//! The Shoes layout engine (DESIGN section 6): stacks, flows, text blocks,
//! widgets, out-of-flow placement, scrolling. Logical pixels throughout.
//!
//! Sizing rule for margins: a width or height the app gives, px or relative, sizes the
//! margin box, margins inside it, as in Shoes 3 (ledger C14, Q9): two `width: 0.5,
//! margin: 10` flows sit side by side, and `stack width: 100, margin: 10` is an 80 px box
//! with 10 px either side. A size the element finds for itself (a button's label, an
//! image's pixels) is the box, and margins add outside it.

use crate::doc::{Doc, Kind, Node};
use crate::elements::{self, image::ImageCache};
use crate::limits;
use crate::paint::shapes;
use crate::props::{Edges, Id};
use crate::style::Dim;
use crate::text::{rich, RichText, ShapedText, TextEngine};
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

    /// The smallest box holding both.
    pub fn union(&self, other: &Rect) -> Rect {
        let (x0, y0) = (self.x.min(other.x), self.y.min(other.y));
        Rect::new(x0, y0, self.right().max(other.right()) - x0, self.bottom().max(other.bottom()) - y0)
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

/// Shaped text and where its buffer's origin sits, in window coordinates.
#[derive(Clone)]
pub struct TextBox {
    pub shaped: ShapedText,
    pub x: f32,
    pub y: f32,
}

impl TextBox {
    /// The corner a first-line indent leaves at the top left of text that continues a line
    /// in a flow. It belongs to what came before on that line, down to the second line.
    pub fn indent_corner(&self) -> Option<Rect> {
        if self.shaped.indent <= 0.0 {
            return None;
        }
        let first = self.shaped.buffer.layout_runs().next()?;
        Some(Rect::new(self.x, self.y - self.shaped.top, self.shaped.indent, first.line_height))
    }

    /// Whether (x, y) is this text's own ground rather than its indent corner.
    pub fn owns(&self, x: f32, y: f32) -> bool {
        !self.indent_corner().is_some_and(|corner| corner.contains(x, y))
    }

    /// A point on this text inside `visible`: its centre, or one clear of the indent corner.
    pub fn centre_within(&self, visible: Rect) -> (f32, f32) {
        let centre = visible.center();
        let Some(corner) = self.indent_corner().filter(|c| c.contains(centre.0, centre.1)) else { return centre };
        let below = Rect::new(visible.x, corner.bottom(), visible.w, visible.bottom() - corner.bottom());
        if below.h > 1.0 {
            below.center()
        } else {
            Rect::new(corner.right(), visible.y, visible.right() - corner.right(), visible.h).center()
        }
    }
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
    /// How tall each slot's content is, padding included: its scroll height.
    pub content_heights: HashMap<Id, f32>,
    /// Live SubscriptionItems (their parent slot is laid out), in tree order.
    pub subscriptions: Vec<Id>,
    /// Slots with a fixed height: they chop off what does not fit, scrolling or not.
    clips: HashMap<Id, Rect>,
    /// Something is placed against the window or another drawable (`attach`): it does not
    /// scroll with its slot, so a scroll lays everything out again.
    attached: bool,
    /// Where things were laid out, kept from the first scroll after a layout (Layout::scroll).
    as_laid_out: Option<Box<AsLaidOut>>,
}

/// A layout's positions before anything scrolled it in place. Each scroll places what moves
/// from here by the scrollers' total change, so the offsets never add up rounding errors.
#[derive(Clone, Default)]
struct AsLaidOut {
    boxes: HashMap<Id, LBox>,
    texts: HashMap<Id, (f32, f32)>,
    scrollers: HashMap<Id, Scroller>,
    clips: HashMap<Id, Rect>,
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
        depth: 0,
        row_floor: None,
    };
    engine.text.begin_layout(root);
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
    /// How many slots (and shape blocks) deep the node being placed sits.
    depth: usize,
    /// The height a slot about to be placed in a flow reaches down to at least: the bottom of
    /// what came before it on its row (ledger C16). Taken by the next slot.
    row_floor: Option<f32>,
}

#[derive(Clone, Copy)]
enum Attach {
    Window,
    Node(Id),
}

/// Where the next in-flow child goes, relative to the slot's content box.
#[derive(Default)]
struct Cursor {
    x: f32,
    /// The top of the current row.
    y: f32,
    /// The row's height, bottom margins included.
    row_h: f32,
    /// How far down the row's own boxes reach, margins left out.
    content_bottom: f32,
}

impl Cursor {
    fn new_row(&mut self) {
        self.y += self.row_h;
        self.x = 0.0;
        self.row_h = 0.0;
        self.content_bottom = self.y;
    }
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

fn is_text(node: &Node) -> bool {
    matches!(node.kind, Kind::Para | Kind::TextDrawable)
}

/// Shoes 3's margins for text blocks (ledger C9): 4 px all round, and 12 px below when
/// neither `margin` nor `margin_bottom` says otherwise (s3t_textblock.c:108-110).
const TEXT_MARGIN: f32 = 4.0;
const TEXT_MARGIN_BOTTOM: f32 = 12.0;

/// An element's margins; text blocks keep Shoes 3's defaults for every side not given.
fn margins_of(node: &Node, basis: f32) -> Edges {
    if !is_text(node) {
        return node.props.margins(basis);
    }
    let p = &node.props;
    let bottom = if p.has("margin") || p.has("margin_bottom") { TEXT_MARGIN } else { TEXT_MARGIN_BOTTOM };
    p.margins_or(basis, Edges { left: TEXT_MARGIN, top: TEXT_MARGIN, right: TEXT_MARGIN, bottom })
}

fn role(node: &Node) -> Role {
    match &node.kind {
        Kind::SubscriptionItem => Role::Subscription,
        k if k.is_span() => Role::Skip,
        Kind::App | Kind::DocumentRoot | Kind::Unknown(_) => Role::Skip,
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
        self.out.content_heights.insert(root, content_h + padding.vertical());
        self.place_later(&later, slot_box, Rect::new(content.x, content.y, content.w, doc_h - padding.vertical()), size.1);
        // The window's own backgrounds cover the whole document, so they scroll with it.
        self.scroll_subtree(root, viewport, content_h + padding.vertical(), true, true);
    }

    fn finish(mut self, root: Id) -> Layout {
        let doc = self.doc;
        let window = Rect::new(0.0, 0.0, self.out.size.0, self.out.size.1);
        self.out.attached = !self.attached.is_empty();
        for (id, attach) in std::mem::take(&mut self.attached) {
            let frame = match attach {
                Attach::Window => window,
                Attach::Node(target) => self.out.rect(target).map(|r| Rect::new(r.x, r.y, window.w, window.h)).unwrap_or(window),
            };
            if let Some(node) = doc.get(id) {
                self.place_positioned(node, frame, window.h);
            }
        }
        self.out.assign_clips(doc, root, None);
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
        // Past limits::MAX_DEPTH a slot is laid out empty, so no input can overflow the stack.
        if self.depth >= limits::MAX_DEPTH {
            return (0.0, Vec::new());
        }
        self.depth += 1;
        let placed = self.children_within_depth(slot, flow, content, avail_h);
        self.depth -= 1;
        placed
    }

    fn children_within_depth(&mut self, slot: Id, flow: bool, content: Rect, avail_h: f32) -> (f32, Vec<Id>) {
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
        if flow {
            if let Some(rich) = self.flowing_text(node) {
                return self.place_paragraph(node, &rich, content, cursor, avail_h);
            }
        }
        let m = margins_of(node, content.w);
        let parent = (content.w, avail_h);
        let remaining = if flow { content.w - cursor.x } else { content.w };
        let mut width = self.width_for(node, flow, parent, remaining, &m);
        let overflows = cursor.x + m.horizontal() + width > content.w + 0.5;
        if flow && cursor.x > 0.0 && overflows {
            if let Some((rich, wanted)) = self.line_beside(node, &m, width, content, cursor) {
                return self.place_line(node, &rich, wanted, &m, content, cursor, parent);
            }
            cursor.new_row();
            width = self.width_for(node, flow, parent, content.w, &m);
        }
        let x = content.x + cursor.x + m.left;
        let y = content.y + cursor.y + m.top;
        // A slot with no height of its own beside what came before it on the row reaches down to
        // the bottom of that, as Shoes 3 grows it to its parent's end (s3_canvas.c:639-642).
        self.row_floor = (flow && cursor.x > 0.0 && node.kind.is_slot()).then(|| cursor.row_h - m.vertical());
        let h = self.place_box(node, x, y, width, parent, &m);
        self.row_floor = None;
        if flow {
            cursor.x += m.horizontal() + width;
            cursor.row_h = cursor.row_h.max(m.vertical() + h);
            cursor.content_bottom = cursor.content_bottom.max(cursor.y + m.top + h);
        } else {
            cursor.y += m.vertical() + h;
        }
    }

    /// A text block that reads as part of a paragraph when it sits in a flow: left aligned,
    /// wrapping, and sized by its text rather than by a width or height of its own.
    fn flowing_text(&self, node: &Node) -> Option<RichText> {
        if !is_text(node) || node.props.has("width") || node.props.has("height") {
            return None;
        }
        let rich = rich::resolve_block(self.doc, &self.text.fonts, node.id)?;
        (rich.align == rich::Align::Left && rich.wrap != rich::WrapMode::Trim).then_some(rich)
    }

    /// Text in a flow carries on from whatever came before it on the line, as one paragraph
    /// (manual 1610-1612, ledger C7): its first line starts where the line stands, its later
    /// lines wrap back to the flow's left edge, and what follows carries on from the end of
    /// its last line (Shoes 3, s3t_textblock.c:134-165, 217-228).
    fn place_paragraph(&mut self, node: &Node, rich: &RichText, content: Rect, cursor: &mut Cursor, avail_h: f32) {
        let m = margins_of(node, content.w);
        let parent = (content.w, avail_h);
        let full = (content.w - m.horizontal()).max(0.0);
        let wanted = self.text.max_content(rich);
        // A newline in the text ends a line, so it cannot sit on this one as a single box. A
        // closing newline leaves an empty line under the text, as Pango lays it out (cosmic-text
        // drops it): what follows starts there, at the flow's left edge.
        let one_line = !rich.runs.iter().any(|run| run.text.contains('\n'));
        let closing_newline = rich.runs.last().is_some_and(|run| run.text.ends_with('\n'));
        loop {
            if one_line && wanted <= full - cursor.x + 0.5 {
                return self.place_line(node, rich, wanted, &m, content, cursor, parent);
            }
            let shaped = if cursor.x > 0.0 {
                if overhangs(cursor, rich, &m) {
                    cursor.new_row();
                    continue;
                }
                let shaped = self.text.shape_indented(rich, Some(full.max(1.0)), cursor.x);
                // Not even the first word fits on the rest of the line: Shoes 3 starts a row.
                if !shaped.indent_holds() {
                    cursor.new_row();
                    continue;
                }
                shaped
            } else {
                self.text.shape(rich, Some(full.max(1.0)))
            };
            let (mut last_top, last_w) = shaped.buffer.layout_runs().last().map(|run| (run.line_top, run.line_w)).unwrap_or_default();
            // The shaped height already counts the empty line under a closing newline.
            let height = shaped.height;
            if shaped.closing_newline {
                last_top += rich.line_height;
            }
            let rect = Rect::new(content.x + m.left, content.y + cursor.y + m.top, full, height);
            self.put_text(node, shaped, rect, parent);
            // The next child goes on the last line, as if the rows before it were done.
            let row_bottom = (cursor.y + cursor.row_h).max(rect.bottom() - content.y + m.bottom);
            cursor.y = rect.y - content.y + last_top - m.top;
            cursor.row_h = row_bottom - cursor.y;
            cursor.content_bottom = rect.bottom() - content.y;
            // "Newlines have an empty size" (s3t_textblock.c:217-228): after one, the next line
            // starts at the flow's edge, margin and all.
            cursor.x = if closing_newline { 0.0 } else { carry_on(m.left + last_w, &m) };
            return;
        }
    }

    /// One line of text beside what came before on the line, as wide as its text; what follows
    /// carries on after it.
    #[allow(clippy::too_many_arguments)]
    fn place_line(&mut self, node: &Node, rich: &RichText, wanted: f32, m: &Edges, content: Rect, cursor: &mut Cursor, parent: (f32, f32)) {
        let shaped = self.text.shape(rich, Some(wanted.max(1.0)));
        let rect = Rect::new(content.x + cursor.x + m.left, content.y + cursor.y + m.top, wanted, shaped.height);
        self.put_text(node, shaped, rect, parent);
        cursor.row_h = cursor.row_h.max(m.vertical() + rect.h);
        cursor.content_bottom = cursor.content_bottom.max(rect.bottom() - content.y);
        cursor.x = carry_on(rect.right() - content.x, m);
    }

    /// A text block with a width of its own, or trimmed, that is too wide as a box for the
    /// rest of the line but whose text fits there on one line, and inside its own width after
    /// what came before. Shoes 3 starts such a block at the flow's left edge with its first line
    /// indented past what came before (s3t_textblock.c:125-145), and one line shrinks to its
    /// text (:207-210), so it sits on the line instead of starting a row (ledger C7). Hackety
    /// Hack puts every program's and lesson's name beside its icon this way.
    fn line_beside(&mut self, node: &Node, m: &Edges, width: f32, content: Rect, cursor: &Cursor) -> Option<(RichText, f32)> {
        if !is_text(node) || node.props.has("height") {
            return None;
        }
        let rich = rich::resolve_block(self.doc, &self.text.fonts, node.id)?;
        if rich.align != rich::Align::Left || rich.runs.iter().any(|run| run.text.contains('\n')) {
            return None;
        }
        let wanted = self.text.max_content(&rich);
        let room = (content.w - m.horizontal()).min(width) - cursor.x;
        (wanted <= room + 0.5).then_some((rich, wanted))
    }

    /// Records a text block's box and its shaped text.
    fn put_text(&mut self, node: &Node, shaped: ShapedText, rect: Rect, parent: (f32, f32)) {
        let y = rect.y + shaped.top;
        self.out.texts.insert(node.id, TextBox { shaped, x: rect.x, y });
        self.record(node, rect, parent);
        self.displace(node);
    }

    /// The border-box width a node gets on a line with `remaining` px left.
    fn width_for(&mut self, node: &Node, parent_flow: bool, parent: (f32, f32), remaining: f32, m: &Edges) -> f32 {
        let parent_w = parent.0;
        if let Some(dim) = node.props.dim("width") {
            return sized(dim, parent_w, m.horizontal());
        }
        let fill = (remaining - m.horizontal()).max(0.0);
        match &node.kind {
            // A slot is as wide as its parent unless told otherwise, so after anything else on
            // a line it starts a row (ledger C8: Shoes 3 s3_canvas.c:468, Shoes 4 s4_slot.rb:48).
            // A mask lays out like a flow (Shoes 3 draws it as a canvas, s3_canvas.c:531-613).
            Kind::Flow | Kind::Stack | Kind::Widget | Kind::Mask => (parent_w - m.horizontal()).max(0.0),
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
            // A blank image canvas with no size of its own fills its line.
            Kind::Image if canvas_image(self.doc, node) && self.intrinsic(node).0 == 0.0 => fill,
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
                let blank_canvas = natural.1 == 0.0 && canvas_image(self.doc, node);
                explicit_h.unwrap_or_else(|| if blank_canvas { parent.1 } else { elements::image::height_for_width(natural, w) })
            }
            _ => {
                let (_, ih) = self.intrinsic(node);
                explicit_h.unwrap_or(ih)
            }
        };
        self.record(node, Rect::new(x, y, w, h), parent);
        if canvas_image(self.doc, node) {
            self.image_canvas(node, Rect::new(x, y, w, h));
        }
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
        let floor = self.row_floor.take().unwrap_or(0.0);
        let padding = node.props.padding(frame.w);
        let content = Rect::new(frame.x + padding.left, frame.y + padding.top, (frame.w - padding.horizontal()).max(0.0), 0.0);
        let avail_h = explicit_h.map(|h| (h - padding.vertical()).max(0.0)).unwrap_or(parent.1);
        let flow = matches!(node.kind, Kind::Flow | Kind::DocumentRoot | Kind::Widget | Kind::Mask);
        let (used, later) = self.children(node.id, flow, content, avail_h);
        let h = explicit_h.unwrap_or((used + padding.vertical()).max(floor));
        let slot_box = Rect::new(frame.x, frame.y, frame.w, h);
        self.record(node, slot_box, parent);
        self.out.content_heights.insert(node.id, used + padding.vertical());
        let content = Rect::new(content.x, content.y, content.w, (h - padding.vertical()).max(0.0));
        self.place_later(&later, slot_box, content, avail_h);
        let scrolls = node.props.truthy("scroll") && explicit_h.is_some();
        if explicit_h.is_some() {
            // Manual 345-352: a fixed height makes the slot a nested window, cut off at its edges.
            self.out.clips.insert(node.id, slot_box);
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

    /// Art turns about its own corner (or centre) by its draw context's rotate, scale and skew,
    /// and its box is where it then shows. A shape block turns as one, about the group's
    /// corner, and its members' own transforms play no part (DESIGN 12, ledger E7), just as
    /// paint::shapes draws it; so the member boxes turn with the group.
    fn place_art(&mut self, node: &Node, content: Rect) {
        let Some(frame) = self.art_frame(node, content) else { return };
        let transform = shapes::art_transform(node, frame);
        if !transform.is_identity() {
            self.turn_art(node.id, transform);
        }
    }

    /// Lays out an art element, and a shape block's members inside it, at their untransformed
    /// frames. Returns the element's frame: for a shape block, the union of its own and its
    /// members'.
    fn art_frame(&mut self, node: &Node, content: Rect) -> Option<Rect> {
        let doc = self.doc;
        let parent = (content.w, content.h);
        let mut frame = shapes::art(node, (content.x, content.y), parent).map(|art| art.frame);
        if node.kind == Kind::Shape && self.depth < limits::MAX_DEPTH {
            // Art drawn inside a shape block joins its path, measured from the shape's left/top (E7).
            let (x, y) = shapes::group_origin(node, (content.x, content.y), parent);
            let inner = Rect::new(x, y, content.w, content.h);
            self.depth += 1;
            for &child in doc.children(node.id) {
                if let Some(member) = doc.get(child).filter(|c| c.kind.is_art() && !hidden(c)) {
                    if self.art_frame(member, inner).is_some() {
                        let r = self.out.rect(child).unwrap_or_default();
                        frame = Some(frame.map_or(r, |f| f.union(&r)));
                    }
                }
            }
            self.depth -= 1;
        }
        self.out.boxes.insert(node.id, LBox { rect: frame?, clip: None, origin: (content.x, content.y), parent_size: parent });
        self.displace(node);
        self.out.rect(node.id)
    }

    /// Turns the laid-out boxes of an art element and every member inside it by `transform`.
    fn turn_art(&mut self, id: Id, transform: tiny_skia::Transform) {
        let doc = self.doc;
        let mut stack = vec![id];
        while let Some(next) = stack.pop() {
            if let Some(b) = self.out.boxes.get_mut(&next) {
                b.rect = shapes::transformed_box(b.rect, transform);
                stack.extend(doc.children(next).iter().copied());
            }
        }
    }

    /// `image(w, h) { ... }` is a canvas (manual 410-426, ledger E9): what the block draws
    /// lays out inside the image's box, like a flow, and is clipped to it.
    fn image_canvas(&mut self, node: &Node, frame: Rect) {
        let (_, later) = self.children(node.id, true, frame, frame.h);
        self.place_later(&later, frame, frame, frame.h);
    }

    /// An element with left/top/right/bottom, out of flow in `frame`.
    fn place_positioned(&mut self, node: &Node, frame: Rect, avail_h: f32) {
        let p = &node.props;
        let m = margins_of(node, frame.w);
        // Every position is a plain number, as Shoes 3 reads one (dim::position): a negative
        // left or top lies past the slot's left or top edge, a negative right or bottom past
        // its far edge (ledger Q10, C10).
        let left = p.position("left", frame.w);
        // Positioned text shrinks to fit what is left of the slot, like CSS absolute.
        let remaining = frame.w - left.unwrap_or(0.0);
        let w = self.width_for(node, true, (frame.w, avail_h), remaining, &m);
        let x = match (left, p.position("right", frame.w)) {
            (Some(left), _) => frame.x + left + m.left,
            (None, Some(right)) => frame.right() - right - w - m.right,
            (None, None) => frame.x + m.left,
        };
        let top = p.position("top", frame.h);
        let y = frame.y + top.unwrap_or(0.0) + m.top;
        let h = self.place_box(node, x, y, w, (frame.w, avail_h), &m);
        if top.is_none() {
            if let Some(bottom) = p.position("bottom", frame.h) {
                // A slot with no height of its own is placed by its margins alone, its top
                // `bottom` and its margins above the slot's foot, as Shoes 3 places a canvas
                // whose height it does not know yet (shoes_place_decide: dh is the margins, and
                // th = place->h, s3_ruby.c:434-436, 511-525; ledger C10).
                let measured = if node.kind.is_slot() && !p.has("height") { 0.0 } else { h };
                let dy = frame.bottom() - bottom - measured - m.bottom - y;
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
        self.out.translate_subtree(self.doc, id, dx, dy);
    }
}

impl Layout {
    /// Scrolls `slot` to `top` without laying anything out again: what it holds moves by the
    /// difference, and clips are worked out anew, just as a fresh layout would place them.
    /// Returns the top it settled on, clamped; None when `slot` does not scroll or the layout
    /// has something `attach`ed, which only a fresh layout places.
    pub fn scroll(&mut self, doc: &Doc, slot: Id, top: f32) -> Option<f32> {
        if self.attached {
            return None;
        }
        let scroller = self.scrollers.get(&slot)?;
        let top = top.clamp(0.0, scroller.max_top());
        if top == scroller.top {
            return Some(top);
        }
        if self.as_laid_out.is_none() {
            let texts = self.texts.iter().map(|(id, t)| (*id, (t.x, t.y))).collect();
            let kept = AsLaidOut { boxes: self.boxes.clone(), texts, scrollers: self.scrollers.clone(), clips: self.clips.clone() };
            self.as_laid_out = Some(Box::new(kept));
        }
        if let Some(scroller) = self.scrollers.get_mut(&slot) {
            scroller.top = top;
        }
        self.place_scrolled(doc);
        self.assign_clips(doc, self.root, None);
        Some(top)
    }

    /// Puts everything where the scrollers' tops now put it: where it was laid out, moved by how
    /// far each scroller above it has scrolled since. A slot's own backgrounds stay put; the
    /// window's scroll with the document, as a fresh layout does (Engine::scroll_subtree).
    fn place_scrolled(&mut self, doc: &Doc) {
        let Some(laid_out) = self.as_laid_out.take() else { return };
        let mut stack = vec![(self.root, 0.0f32)];
        while let Some((id, dy)) = stack.pop() {
            if let Some(b) = laid_out.boxes.get(&id) {
                let placed = LBox { rect: b.rect.translate(0.0, dy), clip: None, origin: (b.origin.0, b.origin.1 + dy), parent_size: b.parent_size };
                self.boxes.insert(id, placed);
            }
            if let (Some((x, y)), Some(t)) = (laid_out.texts.get(&id), self.texts.get_mut(&id)) {
                (t.x, t.y) = (*x, *y + dy);
            }
            if let Some(c) = laid_out.clips.get(&id) {
                self.clips.insert(id, c.translate(0.0, dy));
            }
            let mut scrolled = 0.0;
            if let (Some(was), Some(now)) = (laid_out.scrollers.get(&id), self.scrollers.get_mut(&id)) {
                now.viewport = was.viewport.translate(0.0, dy);
                scrolled = was.top - now.top;
            }
            for &child in doc.children(id).iter().filter(|c| laid_out.boxes.contains_key(c)) {
                let moves = id == self.root || !doc.get(child).is_some_and(|c| c.kind.is_decor());
                stack.push((child, if moves { dy + scrolled } else { dy }));
            }
        }
        self.as_laid_out = Some(laid_out);
    }

    fn translate_subtree(&mut self, doc: &Doc, id: Id, dx: f32, dy: f32) {
        let mut stack = vec![id];
        while let Some(next) = stack.pop() {
            if let Some(b) = self.boxes.get_mut(&next) {
                b.rect = b.rect.translate(dx, dy);
                b.origin = (b.origin.0 + dx, b.origin.1 + dy);
            }
            if let Some(t) = self.texts.get_mut(&next) {
                t.x += dx;
                t.y += dy;
            }
            if let Some(s) = self.scrollers.get_mut(&next) {
                s.viewport = s.viewport.translate(dx, dy);
            }
            if let Some(c) = self.clips.get_mut(&next) {
                *c = c.translate(dx, dy);
            }
            stack.extend(doc.children(next).iter().copied());
        }
    }

    /// Scrolling and fixed-height slots clip their descendants (not their own decor).
    fn assign_clips(&mut self, doc: &Doc, id: Id, clip: Option<Rect>) {
        if let Some(b) = self.boxes.get_mut(&id) {
            b.clip = clip;
        }
        let own = match self.scrollers.get(&id) {
            Some(s) if id != self.root => Some(s.viewport),
            _ => self.clips.get(&id).copied(),
        };
        let inner = match (own, clip) {
            (Some(own), Some(c)) => Some(c.intersect(&own).unwrap_or(Rect::new(own.x, own.y, 0.0, 0.0))),
            (Some(own), None) => Some(own),
            (None, c) => c,
        };
        let inner = match doc.get(id).filter(|n| canvas_image(doc, n)).and_then(|_| self.rect(id)) {
            Some(canvas) => Some(inner.map_or(canvas, |c| c.intersect(&canvas).unwrap_or(Rect::new(canvas.x, canvas.y, 0.0, 0.0)))),
            None => inner,
        };
        // Only laid-out nodes need a clip, and only they have laid-out children.
        for &child in doc.children(id) {
            if !self.boxes.contains_key(&child) {
                continue;
            }
            let child_clip = if doc.get(child).is_some_and(|c| c.kind.is_decor()) { clip } else { inner };
            self.assign_clips(doc, child, child_clip);
        }
    }
}

/// Where a line goes on after text ending at `text_end`: its right margin counts only for
/// what it adds to its left one, so two paras sit one margin apart, as in Shoes 3
/// (s3t_textblock.c:217-228), and nothing that follows can start inside the text.
fn carry_on(text_end: f32, m: &Edges) -> f32 {
    text_end + (m.right - m.left).max(0.0)
}

/// Whether something earlier on the line reaches well below this text's first line (an
/// image, a title, a tall control), so wrapped lines would run into it at the left edge.
/// Shoes 3 wraps them anyway; here the text starts a new row instead.
fn overhangs(cursor: &Cursor, rich: &RichText, m: &Edges) -> bool {
    let first_line = rich.size * rich::LINE_HEIGHT;
    cursor.content_bottom > cursor.y + m.top + first_line * 1.5
}

/// A background or border fills its slot, less any edges it names: `top: 50` runs from
/// 50 down to the bottom, `right: 0, width: 55` hugs the right side, `margin` insets it.
fn decor_box(node: &Node, slot: Rect) -> Rect {
    let p = &node.props;
    let m = p.margins(slot.w);
    let area = Rect::new(slot.x + m.left, slot.y + m.top, (slot.w - m.horizontal()).max(0.0), (slot.h - m.vertical()).max(0.0));
    let edge = |key: &str, basis: f32| p.dim(key).map(|d| d.resolve(basis));
    // Positions are plain numbers, a negative one past the edge it counts from (ledger Q10).
    let (left, right) = (p.position("left", area.w), p.position("right", area.w));
    let (top, bottom) = (p.position("top", area.h), p.position("bottom", area.h));
    let (given_w, given_h) = (edge("width", area.w), edge("height", area.h));
    let w = given_w.unwrap_or(area.w - left.unwrap_or(0.0) - right.unwrap_or(0.0)).max(0.0);
    let h = given_h.unwrap_or(area.h - top.unwrap_or(0.0) - bottom.unwrap_or(0.0)).max(0.0);
    // Placed from the far edge with a size of its own, a colour or a gradient keeps its near side
    // `right` (or `bottom`) px and one more in from that edge: Shoes 3 measures a tile's offset
    // against the pattern's own size, which is 1 for anything but a picture (PATTERN_DIM,
    // shoes/types/pattern.h; shoes_place_decide keeps tw and th for REL_TILE, s3_ruby.c:514-520).
    // So `background ..., height: 150, bottom: 150` runs along the foot, and the manual's
    // `width: 50, right: 50` is "a fifty pixel column on the right-side" (ledger M19). A picture
    // keeps its size as the one it is measured by.
    let key = if node.kind == Kind::Border { "stroke" } else { "fill" };
    let own = match p.paint(key) {
        Some(crate::style::color::Paint::Image(_)) => None,
        _ => Some(1.0),
    };
    let x = match (left, right) {
        (Some(left), _) => left,
        (None, Some(right)) => area.w - right - given_w.and(own).unwrap_or(w),
        (None, None) => 0.0,
    };
    let y = match (top, bottom) {
        (Some(top), _) => top,
        (None, Some(bottom)) => area.h - bottom - given_h.and(own).unwrap_or(h),
        (None, None) => 0.0,
    };
    Rect::new(area.x + x, area.y + y, w, h)
}

/// An image with a drawing block: its children draw inside it.
fn canvas_image(doc: &Doc, node: &Node) -> bool {
    node.kind == Kind::Image && !doc.children(node.id).is_empty()
}

fn is_window(s: &str) -> bool {
    let lower = s.to_ascii_lowercase();
    lower == "window" || lower == "shoes::app" || lower == "shoes::window" || lower == "app"
}

/// A requested size, which is the margin box, as the box inside the margins (see the module
/// comment on margins).
fn sized(dim: Dim, parent: f32, margins: f32) -> f32 {
    (dim.resolve(parent) - margins).max(0.0)
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
