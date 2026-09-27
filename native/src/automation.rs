//! `req` ops: synthetic input through the real input path, layout dumps,
//! snapshots and pixel reads, for tests and `scarpe peek`.

use crate::doc::Kind;
use crate::input::{self, KeyInput};
use crate::layout::{Layout, Rect};
use crate::limits;
use crate::props::Id;
use crate::protocol::{MouseAction, Op, Outgoing, Target};
use crate::runtime::{Effect, Runtime};
use serde_json::{json, Value};

fn round(v: f32) -> Value {
    json!(((v as f64) * 100.0).round() / 100.0)
}

impl Runtime {
    pub fn handle_req(&mut self, req: u64, op: Op) {
        let reply = match self.run_op(req, op) {
            Ok(Some(value)) => Outgoing::reply(req, value),
            Ok(None) => return,
            Err((error, value)) => Outgoing::error(req, error, value),
        };
        self.out.send(reply);
    }

    /// Ok(None) means the reply comes later (frames in a window, dialogs).
    fn run_op(&mut self, req: u64, op: Op) -> Result<Option<Value>, (String, Value)> {
        let no_app = || ("no app to act on".to_string(), Value::Null);
        match op {
            Op::Ping => Ok(Some(json!("pong"))),
            Op::Invalid(e) => Err((e, Value::Null)),
            Op::Dialog { kind, message, default } => {
                if self.opts.headless {
                    let (value, cancelled) = crate::dialogs::headless_answer(&kind);
                    self.out.send(crate::dialogs::reply(req, value, cancelled));
                    return Ok(None);
                }
                match kind.as_str() {
                    "ask" | "ask_color" => match self.app_for(None) {
                        Some(app) => self.open_modal(app, req, &kind, &message, &default),
                        None => self.out.send(crate::dialogs::reply(req, Value::Null, true)),
                    },
                    _ => self.effects.push(Effect::Dialog { req, kind, message, default }),
                }
                Ok(None)
            }
            Op::Layout { app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                Ok(Some(self.layout_dump(app)))
            }
            Op::Snapshot { path, app, scale } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                let scale = scale.unwrap_or(self.views[&app].scale);
                if !limits::SCALES.contains(&scale) {
                    return Err((format!("scale {scale} is outside {:?}", limits::SCALES), Value::Null));
                }
                let pm = self.shown(app, scale).ok_or(("the canvas would be too large to make".to_string(), Value::Null))?;
                if let Some(dir) = std::path::Path::new(&path).parent().filter(|d| !d.as_os_str().is_empty()) {
                    let _ = std::fs::create_dir_all(dir);
                }
                pm.save_png(&path).map_err(|e| (format!("could not write {path}: {e}"), Value::Null))?;
                Ok(Some(json!({"path": path, "w": pm.width(), "h": pm.height()})))
            }
            Op::Click { target, button, app } => {
                let owner = match &target {
                    Target::Id(id) => self.owner_app(*id),
                    _ => None,
                };
                let app = owner.or_else(|| self.app_for(app)).ok_or_else(no_app)?;
                self.active_app = Some(app);
                self.click(app, target, button).map(Some)
            }
            Op::Mouse { action, x, y, button, app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                self.active_app = Some(app);
                self.pointer_move(app, x, y);
                match action {
                    MouseAction::Move => {}
                    MouseAction::Down => self.pointer_down(app, button),
                    MouseAction::Up => self.pointer_up(app, button),
                }
                Ok(Some(Value::Null))
            }
            Op::Type { text, app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                self.type_text(app, &text);
                Ok(Some(Value::Null))
            }
            Op::Key { key, app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                let input = KeyInput::parse(&key).ok_or_else(|| (format!("unknown key name `{key}`"), Value::Null))?;
                self.key_input(app, input);
                Ok(Some(Value::Null))
            }
            Op::Wheel { dy, x, y, app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                let at = match (x, y) {
                    (Some(x), Some(y)) => {
                        self.pointer_move(app, x, y);
                        Some((x, y))
                    }
                    _ => None,
                };
                self.wheel(app, dy, at);
                Ok(Some(Value::Null))
            }
            Op::Resize { app, w, h } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                let (Some(w), Some(h)) = (limits::side(w), limits::side(h)) else {
                    return Err((format!("{w}x{h} is not a window size"), Value::Null));
                };
                if !self.opts.headless {
                    self.effects.push(Effect::ResizeWindow(app, w, h));
                }
                self.resize_view(app, w, h, true);
                Ok(Some(Value::Null))
            }
            Op::Pixel { x, y, app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                let scale = self.views[&app].scale;
                let pm = self.shown(app, scale).ok_or(("could not make a canvas".to_string(), Value::Null))?;
                let (px, py) = ((x * scale).floor() as i64, (y * scale).floor() as i64);
                if px < 0 || py < 0 || px >= pm.width() as i64 || py >= pm.height() as i64 {
                    return Err(("point is outside the window".into(), Value::Null));
                }
                let c = pm.pixel(px as u32, py as u32).map(|p| p.demultiply()).expect("pixel in bounds");
                Ok(Some(json!([c.red(), c.green(), c.blue(), c.alpha()])))
            }
            Op::Frames { n, app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                let n = n.min(limits::MAX_FRAMES);
                if self.opts.headless {
                    let scale = self.views[&app].scale;
                    for _ in 0..n.max(1) {
                        self.picture(app, scale);
                    }
                    Ok(Some(json!(self.views[&app].frames)))
                } else {
                    self.wait_frames(req, app, n);
                    Ok(None)
                }
            }
            Op::Focused { app } => {
                let app = self.app_for(app).ok_or_else(no_app)?;
                Ok(Some(self.views[&app].ui.focus.map(Value::from).unwrap_or(Value::Null)))
            }
        }
    }

    /// The app as a person would see it: a see-through window (App `opacity`) keeps only
    /// that share of each pixel.
    fn shown(&mut self, app: Id, scale: f32) -> Option<tiny_skia::Pixmap> {
        let mut pm = self.picture(app, scale)?;
        if let Some(opacity) = self.doc.get(app).and_then(|n| n.props.f32("opacity")) {
            crate::paint::fade(&mut pm, opacity);
        }
        Some(pm)
    }

    /// `{id, kind, x, y, w, h, visible, text?}` for every laid-out node, in
    /// paint order; text fragments (links, spans) follow their para with the
    /// box of their first line of glyphs.
    pub fn layout_dump(&mut self, app: Id) -> Value {
        self.ensure_layout(app);
        let Some(layout) = self.views.get(&app).and_then(|v| v.layout.as_ref()) else { return json!([]) };
        let mut items = Vec::new();
        for &id in &layout.order {
            let (Some(node), Some(b)) = (self.doc.get(id), layout.boxes.get(&id)) else { continue };
            let mut entry = json!({
                "id": id,
                "kind": node.class,
                "x": round(b.rect.x),
                "y": round(b.rect.y),
                "w": round(b.rect.w),
                "h": round(b.rect.h),
                "visible": layout.visible_rect(id).is_some(),
            });
            if let Some(text) = self.text_of(app, id) {
                entry["text"] = Value::String(text);
            }
            items.push(entry);
            for fragment in fragments_in(layout, id) {
                if let (Some(r), Some(n)) = (fragment_rect(layout, fragment), self.doc.get(fragment)) {
                    items.push(json!({
                        "id": fragment, "kind": n.class, "x": round(r.x), "y": round(r.y), "w": round(r.w), "h": round(r.h),
                        "visible": layout.visible_rect(id).is_some(), "text": fragment_text(&self.doc, fragment),
                    }));
                }
            }
        }
        Value::Array(items)
    }

    /// The text a person would read on a node.
    fn text_of(&self, app: Id, id: Id) -> Option<String> {
        let node = self.doc.get(id)?;
        let layout = self.views.get(&app)?.layout.as_ref()?;
        match node.kind {
            Kind::Para | Kind::TextDrawable => layout.texts.get(&id).map(|tb| tb.shaped.text()),
            Kind::Button => node.props.text("text"),
            Kind::EditLine | Kind::EditBox => {
                self.views.get(&app).and_then(|v| v.ui.fields.get(&id)).map(|f| f.text()).or_else(|| node.props.text("text"))
            }
            Kind::ListBox => crate::elements::list_box::chosen(node),
            ref k if k.is_span() => Some(fragment_text(&self.doc, id)),
            _ => None,
        }
    }

    fn find_by_text(&self, app: Id, wanted: &str) -> Option<Id> {
        let layout = self.views.get(&app)?.layout.as_ref()?;
        let mut candidates: Vec<(Id, String)> = Vec::new();
        for &id in &layout.order {
            for link in fragments_in(layout, id).into_iter().filter(|f| self.doc.get(*f).is_some_and(|n| n.kind == Kind::Link)) {
                candidates.push((link, fragment_text(&self.doc, link)));
            }
            if let Some(text) = self.text_of(app, id) {
                candidates.push((id, text));
            }
        }
        let visible = |id: &Id| layout.visible_rect(*id).is_some() || para_of(layout, *id).is_some_and(|p| layout.visible_rect(p).is_some());
        candidates
            .iter()
            .find(|(id, t)| t == wanted && visible(id))
            .or_else(|| candidates.iter().find(|(id, t)| t.contains(wanted) && visible(id)))
            .map(|(id, _)| *id)
    }

    fn click(&mut self, app: Id, target: Target, button: u8) -> Result<Value, (String, Value)> {
        self.ensure_layout(app);
        if let Target::Text(t) = &target {
            if let Some(result) = self.click_popup_item(app, t) {
                return Ok(result);
            }
        }
        let (x, y, expected) = match target {
            Target::Point(x, y) => (x, y, None),
            Target::Id(id) => {
                let (x, y) = self.centre_of(app, id).ok_or_else(|| (format!("{id} is not visible"), json!({"hit": null})))?;
                (x, y, Some(id))
            }
            Target::Text(t) => {
                let id = self.find_by_text(app, &t).ok_or_else(|| (format!("no visible drawable shows `{t}`"), json!({"hit": null})))?;
                let (x, y) = self.centre_of(app, id).ok_or_else(|| (format!("`{t}` is not visible"), json!({"hit": null})))?;
                (x, y, Some(id))
            }
        };
        let hit = {
            let layout = self.views[&app].layout.as_ref().expect("layout");
            input::hit_test(&self.doc, layout, x, y)
        };
        let hit_id = hit.as_ref().map(|h| h.link.unwrap_or(h.node));
        if let Some(expected) = expected {
            let chain = hit.as_ref().map(|h| input::chain(&self.doc, h)).unwrap_or_default();
            if !chain.contains(&expected) {
                let on_top = hit_id.and_then(|id| self.doc.get(id)).map(|n| format!("{} {}", n.class, n.id)).unwrap_or("nothing".into());
                return Err((format!("{expected} is covered by {on_top}"), json!({"hit": hit_id, "x": x, "y": y})));
            }
        }
        self.pointer_move(app, x, y);
        self.pointer_down(app, button);
        self.pointer_up(app, button);
        Ok(json!({"hit": hit_id, "x": round(x), "y": round(y)}))
    }

    /// The open app a drawable is drawn in: up its parents, or for a text fragment
    /// (which has none), the app whose layout shows it.
    fn owner_app(&mut self, id: Id) -> Option<Id> {
        if let Some(app) = self.doc.app_of(id).filter(|a| self.views.contains_key(a)) {
            return Some(app);
        }
        let apps: Vec<Id> = self.views.keys().copied().collect();
        apps.into_iter().find(|&app| self.layout_of(app).is_some_and(|l| para_of(l, id).is_some()))
    }

    /// Clicking an item of an open list_box popup by its text.
    fn click_popup_item(&mut self, app: Id, text: &str) -> Option<Value> {
        let popup = self.views.get(&app)?.ui.popup.as_ref()?;
        let i = popup.items.iter().position(|item| item == text)?;
        let (x, y) = popup.item_rect(i).center();
        let list_box = popup.list_box;
        self.pointer_move(app, x, y);
        self.pointer_down(app, 1);
        self.pointer_up(app, 1);
        Some(json!({"hit": list_box, "x": round(x), "y": round(y)}))
    }

    fn centre_of(&self, app: Id, id: Id) -> Option<(f32, f32)> {
        let layout = self.views.get(&app)?.layout.as_ref()?;
        if self.doc.get(id).is_some_and(|n| n.kind.is_span()) {
            let r = fragment_rect(layout, id)?;
            layout.visible_rect(para_of(layout, id)?)?;
            return Some(r.center());
        }
        let visible = layout.visible_rect(id)?;
        Some(layout.texts.get(&id).map_or(visible.center(), |tb| tb.centre_within(visible)))
    }
}

/// The text fragments (links and spans) inside a para, in reading order.
fn fragments_in(layout: &Layout, id: Id) -> Vec<Id> {
    let Some(tb) = layout.texts.get(&id) else { return Vec::new() };
    let mut out = Vec::new();
    for meta in tb.shaped.metas.iter() {
        for span in meta.spans.iter().rev() {
            if !out.contains(span) {
                out.push(*span);
            }
        }
    }
    out
}

fn para_of(layout: &Layout, fragment: Id) -> Option<Id> {
    layout.texts.iter().find(|(_, tb)| tb.shaped.metas.iter().any(|m| m.spans.contains(&fragment))).map(|(id, _)| *id)
}

/// The box of a fragment's first line of glyphs, in window coordinates.
pub fn fragment_rect(layout: &Layout, fragment: Id) -> Option<Rect> {
    let tb = layout.texts.get(&para_of(layout, fragment)?)?;
    for run in tb.shaped.buffer.layout_runs() {
        let glyphs: Vec<_> = run.glyphs.iter().filter(|g| tb.shaped.meta(g.metadata).is_some_and(|m| m.spans.contains(&fragment))).collect();
        if let (Some(first), Some(last)) = (glyphs.first(), glyphs.last()) {
            let x0 = first.x.min(last.x);
            let x1 = (first.x + first.w).max(last.x + last.w);
            let (top, h) = tb.shaped.line_box(run.line_top, run.line_height);
            return Some(Rect::new(tb.x + x0, tb.y + top, x1 - x0, h));
        }
    }
    None
}

fn fragment_text(doc: &crate::doc::Doc, fragment: Id) -> String {
    fn walk(doc: &crate::doc::Doc, id: Id, out: &mut String, depth: usize) {
        let Some(node) = doc.get(id) else { return };
        if depth > 16 {
            return;
        }
        for item in node.props.text_items() {
            match item {
                crate::props::TextItem::Str(s) => out.push_str(&s),
                crate::props::TextItem::Ref(child) => walk(doc, child, out, depth + 1),
            }
        }
    }
    let mut out = String::new();
    walk(doc, fragment, &mut out, 0);
    out
}
