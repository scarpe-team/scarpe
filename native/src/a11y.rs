//! Screen readers (DESIGN 12, ledger N1). Scarpe draws its own controls ("our buttons are OUR
//! buttons", Nick, 27 Sep 2026), so no control of the operating system tells VoiceOver there is
//! a button on the screen. This module does. It builds an AccessKit tree of one app from its
//! document and layout, carries out what a screen reader asks for through the paths a click or
//! a key takes, and reads a tree back the way a platform adapter does, for the `a11y` op.
//!
//! The tree follows the document. The window holds the laid-out slots, plain containers a
//! screen reader looks straight through; a text block is static text, or a paragraph of its runs
//! of text and its links when it has links, and big text is a heading; controls carry their
//! state. A check or a radio is named by the text block just after it and a field or a list box
//! by the one just before it, the way `flow { check; para "Remember me" }` and
//! `para "Name"; edit_line` read on screen. Art, backgrounds, borders, masks and timers are not
//! content and stay out.

use crate::dialogs::{self, Modal, ModalKind, SWATCHES};
use crate::doc::{Doc, Kind, Node as DocNode};
use crate::elements::{disabled, list_box, readonly, text_field};
use crate::input::ViewState;
use crate::layout::{Layout, Rect};
use crate::props::{Id, TextItem};
use crate::runtime::Runtime;
use crate::text::TextEngine;
use accesskit::{Action, ActionData, ActionRequest, Affine, HasPopup, Node, NodeId, Role, Toggled, Tree, TreeId, TreeUpdate};
use serde_json::{json, Map, Value};
use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// Nodes that are no drawable of Lacci's (a para's runs of text, a list box's items, the parts
/// of an ask dialog) take ids a drawable never has: the top bit set, then the owner's id, then
/// the part's number. Lacci counts its ids up from 1, far below the 43 bits the owner gets.
const PART: u64 = 1 << 63;
const PART_BITS: u32 = 20;
const PART_MASK: u64 = (1 << PART_BITS) - 1;

/// The parts of an ask or ask_color dialog, numbered under the app's own id.
const DIALOG: usize = 0;
const MESSAGE: usize = 1;
const FIELD: usize = 2;
const CANCEL: usize = 3;
const OK: usize = 4;
const FIRST_SWATCH: usize = 5;
/// A dialog's own window (dialogs::open_standalone) has a negative id, so its node is a part of
/// it rather than something that could pass for a drawable.
const WINDOW: usize = FIRST_SWATCH + SWATCHES.len();

/// What a screen reader calls the ask_color swatches (dialogs::SWATCHES, in order).
pub const SWATCH_NAMES: [&str; 12] = ["Red", "Orange", "Yellow", "Green", "Mint", "Blue", "Indigo", "Purple", "Pink", "Brown", "Grey", "Black"];

/// The actions the `a11y` op lists, in this order.
const LISTED: [(Action, &str); 5] =
    [(Action::Click, "click"), (Action::Focus, "focus"), (Action::SetValue, "set_value"), (Action::Expand, "expand"), (Action::Collapse, "collapse")];

pub fn part(owner: Id, index: usize) -> NodeId {
    NodeId(PART | (((owner as u64) << PART_BITS) & !PART) | (index as u64 & PART_MASK))
}

/// The owner and number of a part; None for a drawable's own node. The owner's bits are read
/// as signed, so a dialog's own window (a negative id) gets its parts back.
pub fn part_of(id: NodeId) -> Option<(Id, usize)> {
    let owner = ((id.0 << 1) as Id) >> (PART_BITS + 1);
    (id.0 & PART != 0).then_some((owner, (id.0 & PART_MASK) as usize))
}

/// A drawable's node. Lacci never makes a negative id, and one that arrives anyway stays out
/// of the tree, where it could pass for a part.
fn node_id(id: Id) -> Option<NodeId> {
    (id >= 0).then_some(NodeId(id as u64))
}

fn bounds(r: Rect) -> accesskit::Rect {
    accesskit::Rect::new(r.x as f64, r.y as f64, (r.x + r.w) as f64, (r.y + r.h) as f64)
}

/// A drawable's `tooltip`, which a screen reader reads after its name.
fn tooltip(node: &DocNode) -> Option<String> {
    node.props.text("tooltip").filter(|t| !t.trim().is_empty())
}

/// What a control does for a screen reader: these actions, or none and "dimmed" when disabled.
fn works(n: &mut Node, node: &DocNode, actions: &[Action]) {
    if disabled(node) {
        n.set_disabled();
    } else {
        actions.iter().for_each(|a| n.add_action(*a));
    }
}

/// An image a click reaches: one given a block, or a `click` handler Lacci told us about.
fn clickable_image(node: &DocNode) -> bool {
    node.props.truthy("has_block") || node.props.truthy("has_click")
}

/// A stretch of a text block's text, inside a link or not.
struct Run {
    link: Option<Id>,
    text: String,
}

/// A text block's text as a screen reader reads it: runs of plain text and links, in order,
/// through the spans the painter draws (rich::collect), hidden ones left out.
fn text_runs(doc: &Doc, block: Id) -> Vec<Run> {
    fn walk(doc: &Doc, id: Id, link: Option<Id>, path: &mut Vec<Id>, runs: &mut Vec<Run>) {
        let Some(node) = doc.get(id) else { return };
        if path.len() > 32 {
            return;
        }
        for item in node.props.text_items() {
            match item {
                TextItem::Str(text) if text.is_empty() => {}
                TextItem::Str(text) => match runs.last_mut() {
                    Some(run) if run.link == link => run.text.push_str(&text),
                    _ => runs.push(Run { link, text }),
                },
                TextItem::Ref(span_id) => {
                    let Some(span) = doc.get(span_id) else { continue };
                    let inline = span.kind.is_span() || span.kind == Kind::TextDrawable;
                    if path.contains(&span_id) || !inline || span.props.truthy("hidden") {
                        continue;
                    }
                    let link = if span.kind == Kind::Link { Some(span_id) } else { link };
                    path.push(span_id);
                    walk(doc, span_id, link, path, runs);
                    path.pop();
                }
            }
        }
    }
    let mut runs = Vec::new();
    walk(doc, block, None, &mut Vec::new(), &mut runs);
    runs
}

/// Builds one app's tree. Every node goes in once: an id already in it (a span two paras
/// share, which Lacci never sends but a hostile line can) is left out, because AccessKit
/// panics on a node with two parents.
struct Builder<'a> {
    doc: &'a Doc,
    layout: &'a Layout,
    view: &'a ViewState,
    nodes: Vec<(NodeId, Node)>,
    seen: HashSet<NodeId>,
}

impl Builder<'_> {
    fn add(&mut self, id: NodeId, node: Node) -> Option<NodeId> {
        self.seen.insert(id).then(|| {
            self.nodes.push((id, node));
            id
        })
    }

    /// Laid out, and something a person reads or works.
    fn takes_part(&self, id: Id) -> bool {
        self.layout.boxes.contains_key(&id)
            && self.doc.get(id).is_some_and(|n| {
                !(n.kind.is_art() || n.kind.is_decor() || matches!(n.kind, Kind::Mask | Kind::SubscriptionItem | Kind::App | Kind::Unknown(_)))
            })
    }

    fn children(&mut self, parent: Id) -> Vec<NodeId> {
        let kids: Vec<Id> = self.doc.children(parent).iter().copied().filter(|&c| self.takes_part(c)).collect();
        let mut out = Vec::with_capacity(kids.len());
        for (i, &kid) in kids.iter().enumerate() {
            let before = i.checked_sub(1).map(|j| kids[j]);
            out.extend(self.element(kid, before, kids.get(i + 1).copied()));
        }
        out
    }

    /// A text block beside a control that names it: plain text, with no links, that says something.
    fn label_beside(&self, neighbour: Option<Id>) -> Option<NodeId> {
        let id = neighbour.filter(|&n| self.doc.get(n).is_some_and(|n| matches!(n.kind, Kind::Para | Kind::TextDrawable)))?;
        let runs = text_runs(self.doc, id);
        let plain = runs.iter().all(|r| r.link.is_none()) && runs.iter().any(|r| !r.text.trim().is_empty());
        plain.then(|| node_id(id)).flatten()
    }

    fn element(&mut self, id: Id, before: Option<Id>, after: Option<Id>) -> Option<NodeId> {
        let nid = node_id(id)?;
        let doc = self.doc;
        let node = doc.get(id)?;
        if !self.seen.insert(nid) {
            return None;
        }
        let built = match node.kind {
            Kind::DocumentRoot | Kind::Stack | Kind::Flow | Kind::Widget => {
                let mut n = Node::new(Role::GenericContainer);
                n.set_children(self.children(id));
                Some(n)
            }
            Kind::Para | Kind::TextDrawable => self.text_block(id),
            Kind::Button => {
                let mut n = Node::new(Role::Button);
                n.set_label(node.props.text("text").unwrap_or_default());
                works(&mut n, node, &[Action::Click, Action::Focus]);
                Some(n)
            }
            Kind::Check | Kind::Radio => {
                let mut n = Node::new(if node.kind == Kind::Check { Role::CheckBox } else { Role::RadioButton });
                n.set_toggled(if node.props.truthy("checked") { Toggled::True } else { Toggled::False });
                n.set_labelled_by(self.label_beside(after).into_iter().collect::<Vec<_>>());
                works(&mut n, node, &[Action::Click, Action::Focus]);
                Some(n)
            }
            Kind::EditLine | Kind::EditBox => Some(self.field(node, before)),
            Kind::ListBox => Some(self.list_box(node, before)),
            Kind::Progress | Kind::Slider => {
                let mut n = Node::new(if node.kind == Kind::Progress { Role::ProgressIndicator } else { Role::Slider });
                n.set_min_numeric_value(0.0);
                n.set_max_numeric_value(1.0);
                // No fraction is a bar with no end in sight (indeterminate). Read as f64, so 0.4
                // stays 0.4 on its way to VoiceOver.
                let fraction = node.props.get("fraction").and_then(Value::as_f64).or_else(|| node.props.f32("fraction").map(f64::from));
                if let Some(f) = fraction.filter(|f| f.is_finite()) {
                    n.set_numeric_value(f.clamp(0.0, 1.0));
                }
                Some(n)
            }
            Kind::Image => {
                let mut n = Node::new(Role::Image);
                if let Some(alt) = node.props.text("alt").filter(|a| !a.trim().is_empty()) {
                    n.set_label(alt);
                }
                if clickable_image(node) {
                    works(&mut n, node, &[Action::Click]);
                }
                // What an image canvas holds (`image(w, h) { para "..." }`) reads inside it.
                n.set_children(self.children(id));
                Some(n)
            }
            Kind::Video => Some(Node::new(Role::Video)),
            _ => None,
        };
        let Some(mut n) = built else {
            self.seen.remove(&nid);
            return None;
        };
        if let Some(r) = self.layout.rect(id) {
            n.set_bounds(bounds(r));
        }
        if let Some(tip) = tooltip(node) {
            n.set_description(tip);
        }
        self.nodes.push((nid, n));
        Some(nid)
    }

    /// Big text is a heading, the way Scarpe's webview theme tags it (Tiranti): banner-sized
    /// text and bigger is level 1, title-sized 2, subtitle-sized 3.
    fn heading_level(&self, id: Id) -> Option<usize> {
        match self.layout.texts.get(&id)?.shaped.buffer.metrics().font_size {
            size if size >= 48.0 => Some(1),
            size if size >= 34.0 => Some(2),
            size if size >= 26.0 => Some(3),
            _ => None,
        }
    }

    /// Static text or a heading, or a paragraph (or heading) of its runs of text and its links,
    /// each link a node a screen reader can follow.
    fn text_block(&mut self, id: Id) -> Option<Node> {
        let runs = text_runs(self.doc, id);
        let level = self.heading_level(id);
        if runs.iter().all(|r| r.link.is_none()) {
            let text: String = runs.into_iter().map(|r| r.text).collect();
            if text.trim().is_empty() {
                return None;
            }
            let mut n = Node::new(if level.is_some() { Role::Heading } else { Role::Label });
            match level {
                Some(level) => {
                    n.set_label(text);
                    n.set_level(level);
                }
                // Static text carries its words as its value, AccessKit's convention.
                None => n.set_value(text),
            }
            return Some(n);
        }
        let mut kids = Vec::new();
        for (k, run) in runs.into_iter().enumerate() {
            if run.text.trim().is_empty() {
                continue;
            }
            let link = run.link.and_then(node_id).filter(|l| !self.seen.contains(l));
            let added = match link {
                Some(link) => {
                    let n = self.link(link.0 as Id, run.text);
                    self.add(link, n)
                }
                None => {
                    let mut n = Node::new(Role::Label);
                    n.set_value(run.text);
                    self.add(part(id, k), n)
                }
            };
            kids.extend(added);
        }
        let mut n = Node::new(if level.is_some() { Role::Heading } else { Role::Paragraph });
        if let Some(level) = level {
            n.set_level(level);
        }
        n.set_children(kids);
        Some(n)
    }

    fn link(&self, id: Id, text: String) -> Node {
        let mut n = Node::new(Role::Link);
        n.set_label(text);
        n.add_action(Action::Click);
        if let Some(url) = self.doc.get(id).and_then(|l| l.props.str("click")).filter(|u| u.starts_with("http://") || u.starts_with("https://")) {
            n.set_url(url);
        }
        if let Some(r) = crate::automation::fragment_rect(self.layout, id) {
            n.set_bounds(bounds(r));
        }
        n
    }

    /// A text field's value is what it shows: its live text, or bullets for a secret one.
    fn field(&self, node: &DocNode, before: Option<Id>) -> Node {
        let secret = node.props.truthy("secret");
        let role = match node.kind {
            Kind::EditBox => Role::MultilineTextInput,
            _ if secret => Role::PasswordInput,
            _ => Role::TextInput,
        };
        let mut n = Node::new(role);
        let text = self.view.fields.get(&node.id).map(|f| f.text()).or_else(|| node.props.text("text")).unwrap_or_default();
        n.set_value(if secret { text.chars().map(|_| text_field::BULLET).collect() } else { text });
        n.set_labelled_by(self.label_beside(before).into_iter().collect::<Vec<_>>());
        if readonly(node) {
            n.set_read_only();
            works(&mut n, node, &[Action::Click, Action::Focus]);
        } else {
            works(&mut n, node, &[Action::Click, Action::Focus, Action::SetValue]);
        }
        n
    }

    /// A popup button whose value is the chosen item, holding its items as options; while its
    /// popup is open the options sit where the popup draws them.
    fn list_box(&mut self, node: &DocNode, before: Option<Id>) -> Node {
        let mut n = Node::new(Role::ComboBox);
        let chosen = list_box::chosen(node);
        if let Some(chosen) = &chosen {
            n.set_value(chosen.clone());
        }
        n.set_has_popup(HasPopup::Listbox);
        let popup = self.view.popup.as_ref().filter(|p| p.list_box == node.id);
        n.set_expanded(popup.is_some());
        n.set_labelled_by(self.label_beside(before).into_iter().collect::<Vec<_>>());
        let mut options = Vec::new();
        for (i, item) in list_box::items(node).into_iter().enumerate() {
            let mut o = Node::new(Role::ListBoxOption);
            o.set_selected(chosen.as_ref() == Some(&item));
            o.set_label(item);
            if let Some(popup) = popup.filter(|p| i < p.items.len()) {
                o.set_bounds(bounds(popup.item_rect(i)));
            }
            works(&mut o, node, &[Action::Click]);
            options.extend(self.add(part(node.id, i), o));
        }
        n.set_children(options);
        let toggle = if popup.is_some() { Action::Collapse } else { Action::Expand };
        works(&mut n, node, &[Action::Click, Action::Focus, Action::SetValue, toggle]);
        n
    }

    /// The ask and ask_color dialog drawn over the window: modal, so a screen reader stays in it.
    fn dialog(&mut self, app: Id, modal: &Modal, size: (f32, f32), text: &mut TextEngine) -> Option<NodeId> {
        let (g, message) = dialogs::geometry(modal, size, text);
        let mut kids = Vec::new();
        let mut m = Node::new(Role::Label);
        m.set_value(modal.message.clone());
        m.set_bounds(bounds(Rect::new(g.message.0, g.message.1, g.message.2, message.height)));
        kids.extend(self.add(part(app, MESSAGE), m));
        match &modal.kind {
            ModalKind::Ask(field) => {
                let mut f = Node::new(if field.secret { Role::PasswordInput } else { Role::TextInput });
                f.set_value(if field.secret { field.bullets() } else { field.text() });
                f.set_bounds(bounds(g.field));
                f.add_action(Action::Focus);
                f.add_action(Action::SetValue);
                kids.extend(self.add(part(app, FIELD), f));
            }
            ModalKind::Color { selected } => {
                for (i, (name, rect)) in SWATCH_NAMES.iter().zip(&g.swatch).enumerate() {
                    let mut s = Node::new(Role::RadioButton);
                    s.set_label(*name);
                    s.set_toggled(if i == *selected { Toggled::True } else { Toggled::False });
                    s.set_bounds(bounds(*rect));
                    s.add_action(Action::Click);
                    kids.extend(self.add(part(app, FIRST_SWATCH + i), s));
                }
            }
        }
        for (index, role, label, rect) in [(CANCEL, Role::Button, "Cancel", g.cancel), (OK, Role::DefaultButton, "OK", g.ok)] {
            let mut b = Node::new(role);
            b.set_label(label);
            b.set_bounds(bounds(rect));
            b.add_action(Action::Click);
            kids.extend(self.add(part(app, index), b));
        }
        let mut d = Node::new(Role::Dialog);
        d.set_modal();
        d.set_label(modal.title.clone().filter(|t| !t.is_empty()).unwrap_or_else(|| modal.message.clone()));
        d.set_bounds(bounds(g.panel));
        d.set_children(kids);
        self.add(part(app, DIALOG), d)
    }

    /// Where keyboard focus is: in an open dialog, on the item an open popup points at, else on
    /// the focused control, else on the window.
    fn focus(&self, app: Id, root: NodeId) -> NodeId {
        let in_dialog = self.view.modal.as_ref().map(|m| match m.kind {
            ModalKind::Ask(_) => part(app, FIELD),
            ModalKind::Color { selected } => part(app, FIRST_SWATCH + selected),
        });
        let in_popup = self.view.popup.as_ref().and_then(|p| Some(part(p.list_box, p.hovered.or(p.chosen)?)));
        let control = self.view.focus.and_then(node_id);
        [in_dialog, in_popup, control].into_iter().flatten().find(|id| self.seen.contains(id)).unwrap_or(root)
    }
}

/// A node can only be labelled by a node in the tree: AccessKit's reader unwraps the lookup.
fn keep_labels_inside(nodes: &mut [(NodeId, Node)]) {
    let present: HashSet<NodeId> = nodes.iter().map(|(id, _)| *id).collect();
    for (_, n) in nodes.iter_mut() {
        if n.labelled_by().iter().any(|l| !present.contains(l)) {
            let kept: Vec<NodeId> = n.labelled_by().iter().copied().filter(|l| present.contains(l)).collect();
            n.set_labelled_by(kept);
        }
    }
}

impl Runtime {
    /// Every node of `app`'s tree, for a screen reader that has just asked or for the Mirror to
    /// diff. Bounds are in logical px; `scale` says how many device pixels make one (AccessKit
    /// counts device pixels; automation passes 1, so bounds read like `layout`'s). An app with
    /// nothing to show (closing, say) is a window alone; a dialog's own window holds its dialog.
    pub fn a11y_tree(&mut self, app: Id, scale: f32) -> TreeUpdate {
        self.ensure_layout(app);
        let root = node_id(app).unwrap_or_else(|| part(app, WINDOW));
        let mut window = Node::new(Role::Window);
        window.set_label(self.window_title(app));
        if scale != 1.0 {
            window.set_transform(Affine::scale(scale as f64));
        }
        let Runtime { doc, views, text, .. } = self;
        let mut nodes = Vec::new();
        let mut focus = root;
        if let Some((view, layout)) = views.get(&app).and_then(|v| Some((v, v.layout.as_ref()?))).filter(|(v, _)| app >= 0 || v.standalone) {
            let mut b = Builder { doc, layout, view: &view.ui, nodes: Vec::new(), seen: HashSet::from([root]) };
            let mut children: Vec<NodeId> = b.element(view.doc_root, None, None).into_iter().collect();
            if let Some(modal) = view.ui.modal.as_ref() {
                children.extend(b.dialog(app, modal, view.size, text));
            }
            window.set_bounds(bounds(Rect::new(0.0, 0.0, view.size.0, view.size.1)));
            window.set_children(children);
            focus = b.focus(app, root);
            nodes = b.nodes;
        }
        nodes.push((root, window));
        keep_labels_inside(&mut nodes);
        let tree = Tree { root, toolkit_name: Some("Scarpe".into()), toolkit_version: Some(env!("CARGO_PKG_VERSION").into()) };
        TreeUpdate { nodes, tree: Some(tree), tree_id: TreeId::ROOT, focus }
    }

    /// The `a11y` op: the tree as a screen reader meets it.
    pub fn a11y_dump(&mut self, app: Id) -> Value {
        let tree = self.a11y_tree(app, 1.0);
        read_back(tree)
    }

    /// The app an accessibility node is shown in: its drawable's, or its owner's for a part.
    pub fn a11y_owner(&mut self, id: NodeId) -> Option<Id> {
        let owner = part_of(id).map_or(id.0 as Id, |(owner, _)| owner);
        if self.views.contains_key(&owner) {
            return Some(owner);
        }
        self.owner_app(owner)
    }

    /// Carries out what a screen reader asked for, through the path a click or a key takes:
    /// a pressed button sends `click` as Return on a focused one does, a value typed into a
    /// field is one edit and one `change`. Err says why a node cannot do it.
    pub fn a11y_action(&mut self, app: Id, request: &ActionRequest) -> Result<(), String> {
        if !self.views.contains_key(&app) {
            return Err(format!("no app {app}"));
        }
        self.ensure_layout(app);
        let value = match &request.data {
            Some(ActionData::Value(v)) => Some(v.to_string()),
            _ => None,
        };
        let action = request.action;
        let done = match part_of(request.target_node) {
            Some((owner, index)) if owner == app => self.dialog_action(app, index, action, value),
            Some((owner, index)) => self.option_action(app, owner, index, action),
            None => self.drawable_action(app, request.target_node.0 as Id, action, value),
        };
        if done.is_ok() {
            self.request_redraw(app);
        }
        done
    }

    fn drawable_action(&mut self, app: Id, id: Id, action: Action, value: Option<String>) -> Result<(), String> {
        let (kind, clickable, locked) = {
            let node = self.doc.get(id).ok_or_else(|| format!("no node {id}"))?;
            let layout = self.views[&app].layout.as_ref().ok_or("no layout")?;
            let shown = layout.boxes.contains_key(&id) || (node.kind == Kind::Link && crate::automation::fragment_rect(layout, id).is_some());
            if !shown {
                return Err(format!("{} {id} is not laid out", node.class));
            }
            if disabled(node) {
                return Err(format!("{} {id} is disabled", node.class));
            }
            (node.kind.clone(), clickable_image(node), readonly(node))
        };
        match (&kind, action) {
            (Kind::Button | Kind::Check | Kind::Radio, Action::Click) => self.out.event("click", Some(id), vec![]),
            (Kind::Image, Action::Click) if clickable => self.out.event("click", Some(id), vec![]),
            (Kind::Link, Action::Click) => {
                self.out.event("click", Some(id), vec![]);
                self.follow_link(id);
            }
            (Kind::EditLine | Kind::EditBox, Action::Click) => self.a11y_focus(app, id),
            (k, Action::Focus) if k.is_focusable() => self.a11y_focus(app, id),
            (Kind::EditLine | Kind::EditBox, Action::SetValue) if !locked => {
                let text = value.ok_or("set_value needs a value")?;
                self.a11y_type(app, id, &text);
            }
            (Kind::ListBox, Action::Click | Action::Expand | Action::Collapse) => {
                let open = self.views[&app].ui.popup.as_ref().is_some_and(|p| p.list_box == id);
                match (open, action) {
                    (true, Action::Click | Action::Collapse) => self.views.get_mut(&app).expect("view").ui.popup = None,
                    (false, Action::Click | Action::Expand) => self.open_popup(app, id),
                    _ => {}
                }
            }
            (Kind::ListBox, Action::SetValue) => {
                let item = value.ok_or("set_value needs a value")?;
                if !self.doc.get(id).is_some_and(|n| list_box::items(n).contains(&item)) {
                    return Err(format!("the list box has no item `{item}`"));
                }
                self.choose(id, &item);
            }
            (kind, action) => return Err(format!("a {} cannot {action:?}", kind.name())),
        }
        Ok(())
    }

    /// Picking a list box item as a screen reader would, open popup or not. The other parts of a
    /// drawable, a para's runs of text, take no action.
    fn option_action(&mut self, app: Id, list_box: Id, index: usize, action: Action) -> Result<(), String> {
        let node = self.doc.get(list_box).filter(|n| n.kind == Kind::ListBox).ok_or_else(|| format!("part {index} of {list_box} takes no action"))?;
        if disabled(node) {
            return Err(format!("ListBox {list_box} is disabled"));
        }
        let item = list_box::items(node).get(index).cloned().ok_or_else(|| format!("the list box has no item {index}"))?;
        if action != Action::Click {
            return Err(format!("a list box item cannot {action:?}"));
        }
        let view = self.views.get_mut(&app).expect("view");
        if view.ui.popup.as_ref().is_some_and(|p| p.list_box == list_box) {
            view.ui.popup = None;
        }
        self.choose(list_box, &item);
        Ok(())
    }

    fn dialog_action(&mut self, app: Id, index: usize, action: Action, value: Option<String>) -> Result<(), String> {
        let Runtime { views, text, .. } = self;
        let modal = views.get_mut(&app).and_then(|v| v.ui.modal.as_mut()).ok_or("no dialog is open")?;
        let answered = match (index, action, &mut modal.kind) {
            (OK, Action::Click, _) => Some(true),
            (CANCEL, Action::Click, _) => Some(false),
            (FIELD, Action::Focus, ModalKind::Ask(_)) => None,
            (FIELD, Action::SetValue, ModalKind::Ask(field)) => {
                field.select_all();
                field.type_in(&mut text.fonts.system, &value.ok_or("set_value needs a value")?);
                None
            }
            (i, Action::Click, ModalKind::Color { selected }) if (FIRST_SWATCH..FIRST_SWATCH + SWATCHES.len()).contains(&i) => {
                *selected = i - FIRST_SWATCH;
                None
            }
            _ => return Err(format!("that part of the dialog cannot {action:?}")),
        };
        if let Some(ok) = answered {
            self.close_modal(app, ok);
        }
        Ok(())
    }

    /// Focus as the keyboard gives it, with the ring showing.
    fn a11y_focus(&mut self, app: Id, id: Id) {
        self.set_focus(app, Some(id));
        if let Some(view) = self.views.get_mut(&app) {
            view.ui.focus_visible = true;
        }
    }

    /// A screen reader's new value for a field: all of it replaced, one edit, one `change`.
    fn a11y_type(&mut self, app: Id, id: Id, text: &str) {
        let (Some(node), Some(view)) = (self.doc.get(id), self.views.get_mut(&app)) else { return };
        let field = text_field::ensure(&mut view.ui.fields, node, &mut self.text.fonts);
        field.select_all();
        if field.type_in(&mut self.text.fonts.system, text) {
            let reported = field.reported();
            self.out.event("change", Some(id), vec![Value::String(reported)]);
        }
    }
}

/// An act through AppKit on the element with this title, as VoiceOver works a window.
#[derive(Clone, Debug, PartialEq)]
pub struct PlatformAct {
    pub title: String,
    pub action: String,
    pub value: Option<String>,
}

/// A screen reader's request by name, as the `a11y_action` op spells it.
pub fn request(id: u64, action: &str, value: Option<String>) -> Result<ActionRequest, String> {
    let (action, data) = match action {
        "click" => (Action::Click, None),
        "focus" => (Action::Focus, None),
        "expand" => (Action::Expand, None),
        "collapse" => (Action::Collapse, None),
        "set_value" => (Action::SetValue, Some(ActionData::Value(value.ok_or("set_value needs a value")?.into()))),
        other => return Err(format!("unknown accessibility action `{other}`")),
    };
    Ok(ActionRequest { action, target_tree: TreeId::ROOT, target_node: NodeId(id), data })
}

/// What a platform adapter was last sent, so each update after the first carries only the nodes
/// that changed. AccessKit's adapters take the whole tree once, then changes, and take it whole
/// again when a screen reader starts again (Linux adapters stop and start with the screen reader).
#[derive(Default)]
pub struct Mirror {
    sent: Option<HashMap<NodeId, Node>>,
    /// Set by the adapter's own handlers as a screen reader starts or stops. They run while the
    /// adapter changes its state, under its lock, and so does `update` (inside update_if_active),
    /// so the next update is whole exactly when the adapter needs it to be.
    restarted: Arc<AtomicBool>,
}

impl Mirror {
    /// The flag a window's screen reader handlers raise as a screen reader starts or stops.
    pub fn restarts(&self) -> Arc<AtomicBool> {
        Arc::clone(&self.restarted)
    }

    /// The update that takes the adapter from what it was last sent to `full`.
    pub fn update(&mut self, full: TreeUpdate) -> TreeUpdate {
        if self.restarted.swap(false, Ordering::SeqCst) {
            self.sent = None;
        }
        let TreeUpdate { nodes, tree, tree_id, focus } = full;
        let Some(sent) = self.sent.take() else {
            self.sent = Some(nodes.iter().cloned().collect());
            return TreeUpdate { nodes, tree, tree_id, focus };
        };
        let changed = nodes.iter().filter(|(id, n)| sent.get(id) != Some(n)).cloned().collect();
        self.sent = Some(nodes.into_iter().collect());
        TreeUpdate { nodes: changed, tree: None, tree_id, focus }
    }
}

/// A tree as a screen reader meets it, read back through AccessKit's own consumer, the reader
/// every platform adapter uses: a control's name comes from the text that labels it, and the
/// containers nobody reads are looked through.
pub fn read_back(update: TreeUpdate) -> Value {
    read(&accesskit_consumer::Tree::new(update, true))
}

/// What a platform adapter holding `tree` would tell a screen reader, from the window down.
pub fn read(tree: &accesskit_consumer::Tree) -> Value {
    describe(&tree.state().root())
}

fn describe(node: &accesskit_consumer::Node) -> Value {
    let data = node.data();
    let mut out = Map::new();
    out.insert("id".into(), json!(node.locate().0 .0));
    out.insert("role".into(), json!(role_name(node.role())));
    if let Some(name) = node.label().filter(|n| !n.is_empty()) {
        out.insert("name".into(), json!(name));
    }
    if let Some(value) = node.value() {
        out.insert("value".into(), json!(value));
    }
    if let Some(description) = node.description() {
        out.insert("description".into(), json!(description));
    }
    if let Some(toggled) = node.toggled() {
        out.insert("toggled".into(), if toggled == Toggled::Mixed { json!("mixed") } else { json!(toggled == Toggled::True) });
    }
    if let Some(v) = node.numeric_value() {
        out.insert("numeric".into(), json!({"value": v, "min": node.min_numeric_value(), "max": node.max_numeric_value()}));
    }
    if let Some(expanded) = data.is_expanded() {
        out.insert("expanded".into(), json!(expanded));
    }
    if let Some(selected) = node.is_selected() {
        out.insert("selected".into(), json!(selected));
    }
    if let Some(url) = node.url() {
        out.insert("url".into(), json!(url));
    }
    if let Some(level) = node.level() {
        out.insert("level".into(), json!(level));
    }
    for (flag, on) in [("focused", node.is_focused()), ("disabled", node.is_disabled()), ("read_only", data.is_read_only()), ("modal", data.is_modal())] {
        if on {
            out.insert(flag.into(), json!(true));
        }
    }
    let actions: Vec<&str> = LISTED.iter().filter(|(a, _)| data.supports_action(*a)).map(|(_, name)| *name).collect();
    if !actions.is_empty() {
        out.insert("actions".into(), json!(actions));
    }
    if let Some(b) = node.bounding_box() {
        let r = |v: f64| (v * 100.0).round() / 100.0;
        out.insert("bounds".into(), json!([r(b.x0), r(b.y0), r(b.width()), r(b.height())]));
    }
    let children: Vec<Value> = node.filtered_children(accesskit_consumer::common_filter).map(|c| describe(&c)).collect();
    if !children.is_empty() {
        out.insert("children".into(), Value::Array(children));
    }
    Value::Object(out)
}

/// AccessKit's role as the op spells it: `CheckBox` is "check_box".
fn role_name(role: Role) -> String {
    let mut out = String::new();
    for (i, c) in format!("{role:?}").chars().enumerate() {
        if c.is_uppercase() && i > 0 {
            out.push('_');
        }
        out.extend(c.to_lowercase());
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// AccessKit's reader unwraps every labelled-by lookup, so a label that is not in the tree
    /// would panic inside a screen reader's request. The build drops such labels.
    #[test]
    fn a_label_that_is_not_in_the_tree_is_dropped() {
        let (root, check) = (NodeId(1), NodeId(3));
        let mut window = Node::new(Role::Window);
        window.set_children(vec![check]);
        let mut n = Node::new(Role::CheckBox);
        n.set_labelled_by(vec![NodeId(99)]);
        let mut nodes = vec![(root, window), (check, n)];
        keep_labels_inside(&mut nodes);
        let update = TreeUpdate { nodes, tree: Some(Tree::new(root)), tree_id: TreeId::ROOT, focus: root };
        let read = read_back(update);
        assert_eq!(read["children"][0]["role"], json!("check_box"));
        assert!(read["children"][0].get("name").is_none());
    }

    #[test]
    fn roles_are_spelt_the_way_accesskit_names_them() {
        assert_eq!(role_name(Role::CheckBox), "check_box");
        assert_eq!(role_name(Role::ListBoxOption), "list_box_option");
        assert_eq!(role_name(Role::Window), "window");
    }
}
