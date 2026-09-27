//! The retained document: every drawable Lacci created, as a tree per app.

use crate::props::{Id, Props, TextItem};
use serde_json::{Map, Value};
use std::collections::{HashMap, VecDeque};

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum Kind {
    App,
    DocumentRoot,
    Stack,
    Flow,
    Widget,
    Mask,
    Para,
    TextDrawable,
    Code,
    Del,
    Em,
    Strong,
    Span,
    Sub,
    Sup,
    Ins,
    Link,
    Button,
    Check,
    Radio,
    EditLine,
    EditBox,
    ListBox,
    Progress,
    Slider,
    Image,
    Video,
    Background,
    Border,
    Rect,
    Oval,
    Line,
    Arrow,
    Star,
    Arc,
    Shape,
    SubscriptionItem,
    Unknown(String),
}

impl Kind {
    pub fn from_wire(name: &str, widget: bool) -> Kind {
        if widget {
            return Kind::Widget;
        }
        match name {
            "App" => Kind::App,
            "DocumentRoot" => Kind::DocumentRoot,
            "Stack" => Kind::Stack,
            "Flow" => Kind::Flow,
            "Widget" => Kind::Widget,
            "Mask" => Kind::Mask,
            "Para" | "Banner" | "Title" | "Subtitle" | "Tagline" | "Caption" | "Inscription" => Kind::Para,
            "TextDrawable" => Kind::TextDrawable,
            "Code" => Kind::Code,
            "Del" => Kind::Del,
            "Em" => Kind::Em,
            "Strong" => Kind::Strong,
            "Span" => Kind::Span,
            "Sub" => Kind::Sub,
            "Sup" => Kind::Sup,
            "Ins" => Kind::Ins,
            "Link" | "LinkHover" => Kind::Link,
            "Button" => Kind::Button,
            "Check" => Kind::Check,
            "Radio" => Kind::Radio,
            "EditLine" => Kind::EditLine,
            "EditBox" => Kind::EditBox,
            "ListBox" => Kind::ListBox,
            "Progress" => Kind::Progress,
            "Slider" => Kind::Slider,
            "Image" => Kind::Image,
            "Video" => Kind::Video,
            "Background" => Kind::Background,
            "Border" => Kind::Border,
            "Rect" => Kind::Rect,
            "Oval" => Kind::Oval,
            "Line" => Kind::Line,
            "Arrow" => Kind::Arrow,
            "Star" => Kind::Star,
            "Arc" => Kind::Arc,
            "Shape" => Kind::Shape,
            "SubscriptionItem" => Kind::SubscriptionItem,
            other => Kind::Unknown(other.to_string()),
        }
    }

    pub fn name(&self) -> &str {
        match self {
            Kind::App => "App",
            Kind::DocumentRoot => "DocumentRoot",
            Kind::Stack => "Stack",
            Kind::Flow => "Flow",
            Kind::Widget => "Widget",
            Kind::Mask => "Mask",
            Kind::Para => "Para",
            Kind::TextDrawable => "TextDrawable",
            Kind::Code => "Code",
            Kind::Del => "Del",
            Kind::Em => "Em",
            Kind::Strong => "Strong",
            Kind::Span => "Span",
            Kind::Sub => "Sub",
            Kind::Sup => "Sup",
            Kind::Ins => "Ins",
            Kind::Link => "Link",
            Kind::Button => "Button",
            Kind::Check => "Check",
            Kind::Radio => "Radio",
            Kind::EditLine => "EditLine",
            Kind::EditBox => "EditBox",
            Kind::ListBox => "ListBox",
            Kind::Progress => "Progress",
            Kind::Slider => "Slider",
            Kind::Image => "Image",
            Kind::Video => "Video",
            Kind::Background => "Background",
            Kind::Border => "Border",
            Kind::Rect => "Rect",
            Kind::Oval => "Oval",
            Kind::Line => "Line",
            Kind::Arrow => "Arrow",
            Kind::Star => "Star",
            Kind::Arc => "Arc",
            Kind::Shape => "Shape",
            Kind::SubscriptionItem => "SubscriptionItem",
            Kind::Unknown(name) => name,
        }
    }

    pub fn is_slot(&self) -> bool {
        matches!(self, Kind::DocumentRoot | Kind::Stack | Kind::Flow | Kind::Widget | Kind::Mask)
    }

    /// Inline text fragments: they live inside a Para's text_items, never in a slot.
    pub fn is_span(&self) -> bool {
        matches!(
            self,
            Kind::Code | Kind::Del | Kind::Em | Kind::Strong | Kind::Span | Kind::Sub | Kind::Sup | Kind::Ins | Kind::Link
        )
    }

    pub fn is_art(&self) -> bool {
        matches!(self, Kind::Rect | Kind::Oval | Kind::Line | Kind::Arrow | Kind::Star | Kind::Arc | Kind::Shape)
    }

    pub fn is_decor(&self) -> bool {
        matches!(self, Kind::Background | Kind::Border)
    }

    pub fn is_text_input(&self) -> bool {
        matches!(self, Kind::EditLine | Kind::EditBox)
    }

    /// Widgets that take keyboard focus and appear in the tab order.
    pub fn is_focusable(&self) -> bool {
        matches!(
            self,
            Kind::EditLine | Kind::EditBox | Kind::ListBox | Kind::Button | Kind::Check | Kind::Radio
        )
    }

    /// Controls that consume a press, so slot-level click subscriptions do not fire.
    pub fn consumes_press(&self) -> bool {
        matches!(
            self,
            Kind::Button | Kind::Check | Kind::Radio | Kind::EditLine | Kind::EditBox | Kind::ListBox | Kind::Slider
        )
    }
}

#[derive(Clone, Debug)]
pub struct Node {
    pub id: Id,
    pub kind: Kind,
    /// The class name Lacci sent (Banner, Title... all arrive as kinds of Para).
    pub class: String,
    pub parent: Option<Id>,
    pub children: Vec<Id>,
    pub props: Props,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AppEntry {
    pub id: Id,
    pub doc_root: Id,
    pub owner: Option<Id>,
}

#[derive(Default, Debug)]
pub struct Doc {
    nodes: HashMap<Id, Node>,
    apps: Vec<AppEntry>,
    spans: SpanNames,
}

/// Text spans (strong, em, link...) have no parent: paras, and spans, name them in their
/// text_items. Lacci makes a new span for every `strong("12:00:01")` and destroys none, and it
/// may name an old one again (`@p.replace(@bold)` long after `@bold` was last shown), so a span
/// is kept while any text names it, and after that until more than a bound of such loose
/// spans pile up (Doc::let_go_of_loose_spans), oldest first.
#[derive(Default, Debug)]
struct SpanNames {
    /// How many text_items lists name each id.
    named: HashMap<Id, u32>,
    /// Spans no list names, and when each became so (a running count).
    loose_since: HashMap<Id, u64>,
    /// The same, oldest first; an entry whose count is no longer in loose_since is stale.
    loose: VecDeque<(u64, Id)>,
    count: u64,
}

impl SpanNames {
    fn name(&mut self, items: &[TextItem]) {
        for item in items {
            if let TextItem::Ref(id) = item {
                *self.named.entry(*id).or_default() += 1;
                self.loose_since.remove(id);
            }
        }
    }

    fn unname(&mut self, items: &[TextItem]) {
        for item in items {
            if let TextItem::Ref(id) = item {
                let Some(n) = self.named.get_mut(id) else { continue };
                *n -= 1;
                if *n == 0 {
                    self.named.remove(id);
                    self.let_loose(*id);
                }
            }
        }
    }

    fn let_loose(&mut self, id: Id) {
        self.count += 1;
        self.loose_since.insert(id, self.count);
        self.loose.push_back((self.count, id));
    }

    /// Drops the queue's stale entries once they outnumber the live ones: an app that shows
    /// `@on` and `@off` by turns lets them loose and names them again every tick.
    fn forget_stale(&mut self) {
        if self.loose.len() > 2 * self.loose_since.len() + 1024 {
            let since = &self.loose_since;
            self.loose.retain(|(when, id)| since.get(id) == Some(when));
        }
    }
}

pub struct NewNode {
    pub id: Id,
    pub class: String,
    pub parent: Option<Id>,
    pub index: Option<usize>,
    pub widget: bool,
    pub props: Map<String, Value>,
    pub doc_root: Option<Id>,
    pub owner: Option<Id>,
}

impl Doc {
    pub fn get(&self, id: Id) -> Option<&Node> {
        self.nodes.get(&id)
    }

    pub fn get_mut(&mut self, id: Id) -> Option<&mut Node> {
        self.nodes.get_mut(&id)
    }

    pub fn contains(&self, id: Id) -> bool {
        self.nodes.contains_key(&id)
    }

    pub fn len(&self) -> usize {
        self.nodes.len()
    }

    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }

    pub fn apps(&self) -> &[AppEntry] {
        &self.apps
    }

    pub fn app(&self, id: Id) -> Option<&AppEntry> {
        self.apps.iter().find(|a| a.id == id)
    }

    pub fn children(&self, id: Id) -> &[Id] {
        self.nodes.get(&id).map(|n| n.children.as_slice()).unwrap_or(&[])
    }

    pub fn create(&mut self, new: NewNode) {
        let kind = Kind::from_wire(&new.class, new.widget);
        if let Some(old) = self.nodes.get(&new.id) {
            let old_items = old.props.text_items();
            self.spans.unname(&old_items);
            self.detach(new.id);
        }
        let children = self.nodes.get(&new.id).map(|n| n.children.clone()).unwrap_or_default();
        if kind == Kind::App {
            let doc_root = new.doc_root.unwrap_or(new.id + 1);
            self.apps.retain(|a| a.id != new.id);
            self.apps.push(AppEntry { id: new.id, doc_root, owner: new.owner });
        }
        let node = Node { id: new.id, kind, class: new.class, parent: new.parent, children, props: Props::new(new.props) };
        self.spans.name(&node.props.text_items());
        if node.kind.is_span() && node.parent.is_none() && !self.spans.named.contains_key(&node.id) {
            // Lacci makes a span before the text that names it.
            self.spans.let_loose(node.id);
        }
        self.nodes.insert(new.id, node);
        if let Some(parent) = new.parent {
            self.attach(new.id, parent, new.index);
        }
    }

    /// Applies prop changes. Unknown ids are ignored: Lacci sends a Para's
    /// text_items before its create.
    pub fn set_props(&mut self, id: Id, changes: Map<String, Value>) -> bool {
        let Some(node) = self.nodes.get_mut(&id) else { return false };
        if changes.contains_key("text_items") {
            let (old, new) = (node.props.text_items(), Props::new(changes.clone()).text_items());
            self.spans.name(&new);
            self.spans.unname(&old);
        }
        node.props.merge(changes);
        true
    }

    /// Removes the node and its whole subtree. Returns every removed id.
    pub fn destroy(&mut self, id: Id) -> Vec<Id> {
        if !self.nodes.contains_key(&id) {
            return Vec::new();
        }
        self.detach(id);
        let mut removed = Vec::new();
        let mut stack = vec![id];
        while let Some(next) = stack.pop() {
            if let Some(node) = self.nodes.remove(&next) {
                self.spans.unname(&node.props.text_items());
                self.spans.loose_since.remove(&next);
                stack.extend(node.children.iter().copied());
                removed.push(next);
            }
        }
        self.apps.retain(|a| !removed.contains(&a.id));
        removed
    }

    /// Destroys the spans no text has named for longest, while more than `keep` are loose.
    /// Returns every removed id.
    pub fn let_go_of_loose_spans(&mut self, keep: usize) -> Vec<Id> {
        let mut removed = Vec::new();
        while self.spans.loose_since.len() > keep {
            let Some((when, id)) = self.spans.loose.pop_front() else { break };
            if self.spans.loose_since.get(&id) != Some(&when) || self.spans.named.contains_key(&id) {
                continue;
            }
            self.spans.loose_since.remove(&id);
            if self.nodes.get(&id).is_some_and(|n| n.kind.is_span() && n.parent.is_none()) {
                removed.extend(self.destroy(id));
            }
        }
        self.spans.forget_stale();
        removed
    }

    /// How many spans no text names at the moment.
    pub fn loose_spans(&self) -> usize {
        self.spans.loose_since.len()
    }

    pub fn remove_app(&mut self, app: Id) -> Vec<Id> {
        let doc_root = self.app(app).map(|a| a.doc_root);
        let mut removed = self.destroy(app);
        if let Some(root) = doc_root {
            removed.extend(self.destroy(root));
        }
        self.apps.retain(|a| a.id != app);
        removed
    }

    pub fn reparent(&mut self, id: Id, parent: Option<Id>, index: Option<usize>) {
        if !self.nodes.contains_key(&id) || parent.is_some_and(|p| self.is_descendant_of(p, id)) {
            return;
        }
        self.detach(id);
        if let Some(node) = self.nodes.get_mut(&id) {
            node.parent = parent;
        }
        if let Some(parent) = parent {
            self.attach(id, parent, index);
        }
    }

    /// Puts `id` among `parent`'s children, unless `parent` is `id` itself or inside it: a
    /// node cannot hold itself, so a loop leaves it detached instead. Only a node that already
    /// has children can hold `parent`, so a fresh create costs no walk up the tree.
    fn attach(&mut self, id: Id, parent: Id, index: Option<usize>) {
        let holds_children = self.nodes.get(&id).is_some_and(|n| !n.children.is_empty());
        if parent == id || holds_children && self.is_descendant_of(parent, id) {
            if let Some(node) = self.nodes.get_mut(&id) {
                node.parent = None;
            }
            return;
        }
        if let Some(p) = self.nodes.get_mut(&parent) {
            let at = index.unwrap_or(p.children.len()).min(p.children.len());
            p.children.insert(at, id);
        }
    }

    fn detach(&mut self, id: Id) {
        let parent = self.nodes.get(&id).and_then(|n| n.parent);
        if let Some(parent) = parent.and_then(|p| self.nodes.get_mut(&p)) {
            parent.children.retain(|c| *c != id);
        }
    }

    /// The app a node belongs to, found by walking up to its DocumentRoot.
    pub fn app_of(&self, id: Id) -> Option<Id> {
        let mut current = id;
        for _ in 0..10_000 {
            let node = self.nodes.get(&current)?;
            match node.parent {
                Some(parent) => current = parent,
                None => {
                    return match node.kind {
                        Kind::App => Some(node.id),
                        Kind::DocumentRoot => self.apps.iter().find(|a| a.doc_root == node.id).map(|a| a.id),
                        _ => None,
                    }
                }
            }
        }
        None
    }

    /// Ancestors from the node's parent up to the root. `attach` never makes a loop; the walk
    /// still stops after as many steps as there are nodes, so it always ends.
    pub fn ancestors(&self, id: Id) -> Vec<Id> {
        let mut out = Vec::new();
        let mut current = self.nodes.get(&id).and_then(|n| n.parent);
        while let Some(p) = current.filter(|_| out.len() < self.nodes.len()) {
            out.push(p);
            current = self.nodes.get(&p).and_then(|n| n.parent);
        }
        out
    }

    /// Whether `id` is `ancestor` or sits somewhere inside it.
    pub fn is_descendant_of(&self, id: Id, ancestor: Id) -> bool {
        let mut current = Some(id);
        for _ in 0..=self.nodes.len() {
            match current {
                Some(c) if c == ancestor => return true,
                Some(c) => current = self.nodes.get(&c).and_then(|n| n.parent),
                None => return false,
            }
        }
        false
    }

    pub fn iter(&self) -> impl Iterator<Item = &Node> {
        self.nodes.values()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn new(id: Id, class: &str, parent: Option<Id>, index: Option<usize>) -> NewNode {
        NewNode {
            id,
            class: class.into(),
            parent,
            index,
            widget: false,
            props: json!({}).as_object().unwrap().clone(),
            doc_root: None,
            owner: None,
        }
    }

    #[test]
    fn document_root_before_app() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        doc.create(new(1, "App", None, None));
        doc.create(new(3, "Para", Some(2), None));
        assert_eq!(doc.app_of(3), Some(1));
        assert_eq!(doc.apps()[0].doc_root, 2);
    }

    #[test]
    fn index_inserts_in_position() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        doc.create(new(3, "Para", Some(2), None));
        doc.create(new(4, "Para", Some(2), None));
        doc.create(new(5, "Para", Some(2), Some(0)));
        doc.create(new(6, "Para", Some(2), Some(1)));
        assert_eq!(doc.children(2), &[5, 6, 3, 4]);
    }

    #[test]
    fn destroy_removes_subtree_and_is_idempotent() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        doc.create(new(3, "Stack", Some(2), None));
        doc.create(new(4, "Para", Some(3), None));
        let mut removed = doc.destroy(3);
        removed.sort();
        assert_eq!(removed, vec![3, 4]);
        assert!(doc.children(2).is_empty());
        assert!(doc.destroy(3).is_empty());
        assert!(!doc.set_props(4, json!({"text_items": []}).as_object().unwrap().clone()));
    }

    #[test]
    fn a_node_never_ends_up_inside_itself() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        doc.create(new(3, "Stack", Some(2), None));
        doc.create(new(4, "Stack", Some(3), None));
        doc.reparent(3, Some(4), None);
        assert_eq!((doc.children(2), doc.children(4)), (&[3][..], &[][..]), "a move under its own child is refused");
        doc.create(new(3, "Stack", Some(4), None));
        assert_eq!(doc.get(3).and_then(|n| n.parent), None, "so is a create under a node it already holds");
        assert!(doc.children(4).is_empty());
        doc.create(new(5, "Stack", Some(5), None));
        assert!(doc.children(5).is_empty(), "or under itself");
        assert_eq!(doc.ancestors(4), vec![3]);
    }

    fn span(doc: &mut Doc, id: Id, text: &str) {
        let mut s = new(id, "Strong", None, None);
        s.props = json!({"text_items": [text]}).as_object().unwrap().clone();
        doc.create(s);
    }

    fn show(doc: &mut Doc, para: Id, items: serde_json::Value) {
        doc.set_props(para, json!({ "text_items": items }).as_object().unwrap().clone());
    }

    /// A clock that shows `strong(Time.now)` every tick makes a span a tick and destroys none.
    #[test]
    fn spans_no_text_names_are_let_go_oldest_first_past_the_bound() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        doc.create(new(3, "Para", Some(2), None));
        for tick in 0..10 {
            span(&mut doc, 100 + tick, "12:00");
            show(&mut doc, 3, json!([100 + tick]));
            doc.let_go_of_loose_spans(3);
        }
        assert_eq!(doc.len(), 2 + 1 + 3, "the root, the para, its span and three loose ones");
        assert!(doc.contains(109), "the span on show stays");
        assert!(doc.contains(106) && !doc.contains(105), "the three let go most recently stay, older ones go");
    }

    /// Lacci names a span again after the text that named it went (`@s.clear { para @bold }`,
    /// or `@p.replace(@on)` after `@p.replace(@off)`): while loose spans are few it is there.
    #[test]
    fn a_span_named_again_is_still_there() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        span(&mut doc, 4, "kept");
        doc.create(new(6, "Para", Some(2), None));
        show(&mut doc, 6, json!(["Hi ", 4]));
        doc.destroy(6);
        assert_eq!(doc.loose_spans(), 1);
        doc.let_go_of_loose_spans(10);
        doc.create(new(9, "Para", Some(2), None));
        show(&mut doc, 9, json!(["Again ", 4]));
        assert!(doc.contains(4));
        assert_eq!(doc.loose_spans(), 0, "named again, it is no longer loose");
        show(&mut doc, 9, json!(["plain"]));
        doc.let_go_of_loose_spans(0);
        assert!(!doc.contains(4), "past the bound it goes");
    }

    /// `@p.replace(@on)` and `@p.replace(@off)` by turns, for hours: two spans, and the queue of
    /// loose ones stays about that size.
    #[test]
    fn spans_named_by_turns_leave_no_trail() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        doc.create(new(3, "Para", Some(2), None));
        span(&mut doc, 4, "ON");
        span(&mut doc, 5, "off");
        for tick in 0..10_000 {
            show(&mut doc, 3, json!([if tick % 2 == 0 { 4 } else { 5 }]));
            doc.let_go_of_loose_spans(crate::limits::LOOSE_SPANS);
        }
        assert!(doc.contains(4) && doc.contains(5));
        assert!(doc.spans.loose.len() < 2_000, "{} queued for 1 loose span", doc.spans.loose.len());
    }

    /// A span inside a span is named by the outer one's text.
    #[test]
    fn letting_a_span_go_loosens_the_spans_it_names() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        span(&mut doc, 4, "inner");
        let mut outer = new(5, "Em", None, None);
        outer.props = json!({"text_items": ["a ", 4]}).as_object().unwrap().clone();
        doc.create(outer);
        doc.create(new(6, "Para", Some(2), None));
        show(&mut doc, 6, json!([5]));
        assert_eq!(doc.loose_spans(), 0);
        show(&mut doc, 6, json!(["plain"]));
        let mut gone = doc.let_go_of_loose_spans(0);
        gone.sort();
        assert_eq!(gone, vec![4, 5]);
    }

    #[test]
    fn reparent_moves() {
        let mut doc = Doc::default();
        doc.create(new(2, "DocumentRoot", None, None));
        doc.create(new(3, "Stack", Some(2), None));
        doc.create(new(4, "Para", Some(2), None));
        doc.reparent(4, Some(3), None);
        assert_eq!(doc.children(2), &[3]);
        assert_eq!(doc.children(3), &[4]);
    }
}
