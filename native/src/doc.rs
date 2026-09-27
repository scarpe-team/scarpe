//! The retained document: every drawable Lacci created, as a tree per app.

use crate::props::{Id, Props};
use serde_json::{Map, Value};
use std::collections::HashMap;

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
        if self.nodes.contains_key(&new.id) {
            self.detach(new.id);
        }
        let children = self.nodes.get(&new.id).map(|n| n.children.clone()).unwrap_or_default();
        if kind == Kind::App {
            let doc_root = new.doc_root.unwrap_or(new.id + 1);
            self.apps.retain(|a| a.id != new.id);
            self.apps.push(AppEntry { id: new.id, doc_root, owner: new.owner });
        }
        self.nodes.insert(
            new.id,
            Node { id: new.id, kind, class: new.class, parent: new.parent, children, props: Props::new(new.props) },
        );
        if let Some(parent) = new.parent {
            self.attach(new.id, parent, new.index);
        }
    }

    /// Applies prop changes. Unknown ids are ignored: Lacci sends a Para's
    /// text_items before its create.
    pub fn set_props(&mut self, id: Id, changes: Map<String, Value>) -> bool {
        match self.nodes.get_mut(&id) {
            Some(node) => {
                node.props.merge(changes);
                true
            }
            None => false,
        }
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
                stack.extend(node.children.iter().copied());
                removed.push(next);
            }
        }
        self.apps.retain(|a| !removed.contains(&a.id));
        removed
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
        if !self.nodes.contains_key(&id) || parent == Some(id) {
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

    fn attach(&mut self, id: Id, parent: Id, index: Option<usize>) {
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

    /// Ancestors from the node's parent up to the root.
    pub fn ancestors(&self, id: Id) -> Vec<Id> {
        let mut out = Vec::new();
        let mut current = self.nodes.get(&id).and_then(|n| n.parent);
        while let Some(p) = current {
            if out.contains(&p) {
                break;
            }
            out.push(p);
            current = self.nodes.get(&p).and_then(|n| n.parent);
        }
        out
    }

    pub fn is_descendant_of(&self, id: Id, ancestor: Id) -> bool {
        id == ancestor || self.ancestors(id).contains(&ancestor)
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
