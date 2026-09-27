//! Painting a laid-out app into a tiny-skia Pixmap at any scale. Everything is
//! drawn in logical coordinates under a scale transform; text is rasterised at
//! the physical size so it stays crisp on HiDPI screens.

pub mod decor;
pub mod shapes;
pub mod text;

use crate::doc::{Doc, Kind};
use crate::props::Id;
use crate::elements::{self, image::ImageCache};
use crate::input::ViewState;
use crate::layout::{Layout, Rect};
use crate::style::{Color, Paint};
use crate::text::raster::PxClip;
use crate::text::TextEngine;
use std::collections::HashMap;
use tiny_skia::{
    FillRule, FilterQuality, GradientStop, LinearGradient, Mask, MaskType, Path, PathBuilder, Pattern, Pixmap, PixmapPaint,
    Point, Shader, SpreadMode, Stroke, Transform,
};

pub const BACKGROUND: Color = Color::WHITE;

pub struct Canvas<'a> {
    pub pm: &'a mut Pixmap,
    pub scale: f32,
    masks: HashMap<[u32; 4], Mask>,
}

impl<'a> Canvas<'a> {
    pub fn new(pm: &'a mut Pixmap, scale: f32) -> Self {
        Canvas { pm, scale, masks: HashMap::new() }
    }

    pub fn base(&self) -> Transform {
        Transform::from_scale(self.scale, self.scale)
    }

    fn mask_key(&mut self, clip: Option<Rect>) -> Option<[u32; 4]> {
        let clip = clip?;
        let key = [clip.x.to_bits(), clip.y.to_bits(), clip.w.to_bits(), clip.h.to_bits()];
        if !self.masks.contains_key(&key) {
            let mut mask = Mask::new(self.pm.width(), self.pm.height())?;
            if let Some(r) = tiny_skia::Rect::from_xywh(clip.x, clip.y, clip.w.max(0.001), clip.h.max(0.001)) {
                mask.fill_path(&PathBuilder::from_rect(r), FillRule::Winding, false, self.base());
            }
            self.masks.insert(key, mask);
        }
        Some(key)
    }

    pub fn fill_path(&mut self, path: &Path, shader: Shader, rule: FillRule, local: Transform, clip: Option<Rect>) {
        let key = self.mask_key(clip);
        let paint = tiny_skia::Paint { shader, anti_alias: true, ..tiny_skia::Paint::default() };
        let transform = self.base().pre_concat(local);
        let mask = key.and_then(|k| self.masks.get(&k));
        self.pm.fill_path(path, &paint, rule, transform, mask);
    }

    pub fn stroke_path(&mut self, path: &Path, shader: Shader, stroke: &Stroke, local: Transform, clip: Option<Rect>) {
        let key = self.mask_key(clip);
        let paint = tiny_skia::Paint { shader, anti_alias: true, ..tiny_skia::Paint::default() };
        let transform = self.base().pre_concat(local);
        let mask = key.and_then(|k| self.masks.get(&k));
        self.pm.stroke_path(path, &paint, stroke, transform, mask);
    }

    pub fn fill(&mut self, path: &Path, color: Color, clip: Option<Rect>) {
        if !color.is_invisible() {
            self.fill_path(path, Shader::SolidColor(color.to_skia()), FillRule::Winding, Transform::identity(), clip);
        }
    }

    pub fn stroke(&mut self, path: &Path, color: Color, width: f32, clip: Option<Rect>) {
        if !color.is_invisible() && width > 0.0 {
            let stroke = Stroke { width, ..Stroke::default() };
            self.stroke_path(path, Shader::SolidColor(color.to_skia()), &stroke, Transform::identity(), clip);
        }
    }

    pub fn fill_rect(&mut self, rect: Rect, color: Color, clip: Option<Rect>) {
        if let Some(path) = shapes::rounded_rect(rect, 0.0) {
            self.fill(&path, color, clip);
        }
    }

    pub fn fill_rounded(&mut self, rect: Rect, radius: f32, color: Color, clip: Option<Rect>) {
        if let Some(path) = shapes::rounded_rect(rect, radius) {
            self.fill(&path, color, clip);
        }
    }

    /// A 1px-style outline drawn inside `rect`, so it stays crisp.
    pub fn stroke_rounded(&mut self, rect: Rect, radius: f32, color: Color, width: f32, clip: Option<Rect>) {
        let half = width / 2.0;
        let inner = Rect::new(rect.x + half, rect.y + half, rect.w - width, rect.h - width);
        if let Some(path) = shapes::rounded_rect(inner, (radius - half).max(0.0)) {
            self.stroke(&path, color, width, clip);
        }
    }

    pub fn fill_gradient(&mut self, rect: Rect, radius: f32, top: Color, bottom: Color, clip: Option<Rect>) {
        let Some(path) = shapes::rounded_rect(rect, radius) else { return };
        let stops = vec![GradientStop::new(0.0, top.to_skia()), GradientStop::new(1.0, bottom.to_skia())];
        if let Some(shader) = LinearGradient::new(
            Point::from_xy(rect.x, rect.y),
            Point::from_xy(rect.x, rect.bottom()),
            stops,
            SpreadMode::Pad,
            Transform::identity(),
        ) {
            self.fill_path(&path, shader, FillRule::Winding, Transform::identity(), clip);
        }
    }

    /// A logical clip rectangle as whole physical pixels, for the glyph blitter.
    pub fn px_clip(&self, clip: Option<Rect>) -> Option<PxClip> {
        clip.map(|c| PxClip {
            x0: (c.x * self.scale).floor() as i32,
            y0: (c.y * self.scale).floor() as i32,
            x1: (c.right() * self.scale).ceil() as i32,
            y1: (c.bottom() * self.scale).ceil() as i32,
        })
    }
}

/// Runs `f` with a shader for a Shoes paint over `bounds` (gradients stretch,
/// images tile from the top-left corner).
pub fn with_shader<R>(paint: &Paint, bounds: Rect, images: &mut ImageCache, f: impl FnOnce(Shader) -> R) -> Option<R> {
    match paint {
        Paint::Solid(c) => Some(f(Shader::SolidColor(c.to_skia()))),
        Paint::Linear { from, to, angle } => {
            // Shoes 3 (pattern.c): direction (sin a, cos a) across the unit box.
            let rads = angle.to_radians();
            let (dx, dy) = (rads.sin(), rads.cos());
            let edge = (dx.abs() + dy.abs()) * 0.5;
            let at = |u: f32, v: f32| Point::from_xy(bounds.x + bounds.w * u, bounds.y + bounds.h * v);
            let stops = vec![GradientStop::new(0.0, from.to_skia()), GradientStop::new(1.0, to.to_skia())];
            let shader = LinearGradient::new(
                at(0.5 - dx * edge, 0.5 - dy * edge),
                at(0.5 + dx * edge, 0.5 + dy * edge),
                stops,
                SpreadMode::Pad,
                Transform::identity(),
            )
            .unwrap_or(Shader::SolidColor(from.to_skia()));
            Some(f(shader))
        }
        Paint::Image(path) => {
            let image = images.get(path)?;
            let shader = Pattern::new(
                image.as_ref().as_ref(),
                SpreadMode::Repeat,
                FilterQuality::Bicubic,
                1.0,
                Transform::from_translate(bounds.x, bounds.y),
            );
            Some(f(shader))
        }
    }
}

/// Skips what cannot show: outside the window or scrolled out of its slot.
/// Shadows, focus rings and strokes spill a little; rotated art a lot.
fn on_screen(art: bool, lbox: &crate::layout::LBox, window: Rect) -> bool {
    let area = match lbox.clip {
        Some(clip) => match clip.intersect(&window) {
            Some(a) => a,
            None => return false,
        },
        None => window,
    };
    let r = lbox.rect;
    let slack = if art { r.w.max(r.h) / 2.0 + 8.0 } else { 8.0 };
    Rect::new(r.x - slack, r.y - slack, r.w + 2.0 * slack, r.h + 2.0 * slack).intersect(&area).is_some()
}

/// A picture of a see-through window: every pixel keeps `opacity` (0.0 to 1.0) of itself.
pub fn fade(pm: &mut Pixmap, opacity: f32) {
    let keep = opacity.clamp(0.0, 1.0);
    if keep < 1.0 {
        // Premultiplied, so every channel scales alike.
        pm.data_mut().iter_mut().for_each(|c| *c = (*c as f32 * keep).round() as u8);
    }
}

/// Everything painting needs besides the pixmap.
pub struct Scene<'a> {
    pub doc: &'a Doc,
    pub layout: &'a Layout,
    pub view: &'a mut ViewState,
    pub text: &'a mut TextEngine,
    pub images: &'a mut ImageCache,
}

/// Paints the whole app: nodes in tree order, then overlays (scrollbars,
/// list_box popup, in-window dialog).
pub fn paint(scene: &mut Scene, pm: &mut Pixmap, scale: f32) {
    pm.fill(BACKGROUND.to_skia());
    let mut canvas = Canvas::new(pm, scale);
    let layout = scene.layout;
    paint_nodes(scene, &mut canvas, &layout.order);
    decor::scrollbars(&mut canvas, layout);
    elements::list_box::paint_popup(&mut canvas, scene.view, scene.text);
    if scene.view.popup.is_none() {
        elements::tooltip::paint(&mut canvas, scene.view.tooltip.as_mut(), scene.text, layout.size);
    }
    crate::dialogs::paint_modal(&mut canvas, scene.view, scene.text, layout.size);
}

/// Paints a run of the paint order. A slot holding a mask paints the rest of its
/// contents through the mask's alpha, as Shoes 3 does (s3_canvas.c:531-613).
fn paint_nodes(scene: &mut Scene, canvas: &mut Canvas, ids: &[Id]) {
    let mut i = 0;
    while i < ids.len() {
        let masks = masks_in(scene, ids[i]);
        if masks.is_empty() {
            paint_node(scene, canvas, ids[i]);
            i += 1;
        } else {
            let end = subtree_end(scene.doc, ids, i);
            paint_masked(scene, canvas, &ids[i + 1..end], &masks);
            i = end;
        }
    }
}

/// The laid-out Mask children of a slot.
fn masks_in(scene: &Scene, slot: Id) -> Vec<Id> {
    let doc = scene.doc;
    doc.children(slot)
        .iter()
        .copied()
        .filter(|c| doc.get(*c).is_some_and(|n| n.kind == Kind::Mask) && scene.layout.boxes.contains_key(c))
        .collect()
}

/// Where the subtree starting at ids[start] ends in a pre-order run.
fn subtree_end(doc: &Doc, ids: &[Id], start: usize) -> usize {
    let root = ids[start];
    let mut end = start + 1;
    while end < ids.len() && doc.is_descendant_of(ids[end], root) {
        end += 1;
    }
    end
}

/// Draws a masked slot's contents into one layer and its masks into another, then
/// shows the contents only where the masks drew something.
fn paint_masked(scene: &mut Scene, canvas: &mut Canvas, contents: &[Id], masks: &[Id]) {
    let doc = scene.doc;
    let (mask_ids, content_ids): (Vec<Id>, Vec<Id>) = contents.iter().partition(|id| masks.iter().any(|m| doc.is_descendant_of(**id, *m)));
    let (w, h) = (canvas.pm.width(), canvas.pm.height());
    let (Some(mut content), Some(mut alpha)) = (Pixmap::new(w, h), Pixmap::new(w, h)) else { return };
    paint_nodes(scene, &mut Canvas::new(&mut content, canvas.scale), &content_ids);
    paint_nodes(scene, &mut Canvas::new(&mut alpha, canvas.scale), &mask_ids);
    let mask = Mask::from_pixmap(alpha.as_ref(), MaskType::Alpha);
    canvas.pm.draw_pixmap(0, 0, content.as_ref(), &PixmapPaint::default(), Transform::identity(), Some(&mask));
}

fn paint_node(scene: &mut Scene, canvas: &mut Canvas, id: Id) {
    let layout = scene.layout;
    let doc = scene.doc;
    let window = Rect::new(0.0, 0.0, layout.size.0, layout.size.1);
    let (Some(node), Some(lbox)) = (doc.get(id), layout.boxes.get(&id)) else { return };
    if !on_screen(node.kind.is_art(), lbox, window) {
        return;
    }
    match &node.kind {
        Kind::Background => decor::background(canvas, node, lbox, scene.images),
        Kind::Border => decor::border(canvas, node, lbox, scene.images),
        // Art inside a shape block is painted with its shape, as one path.
        k if k.is_art() && shapes::in_shape(doc, node) => {}
        k if k.is_art() => shapes::paint_art(canvas, doc, &layout.boxes, node, lbox, scene.images),
        Kind::Para | Kind::TextDrawable => {
            if let Some(tb) = layout.texts.get(&id) {
                // `wrap: "trim"` keeps the text on one line and cuts it off at the para's own edge.
                let clip = if node.props.str("wrap") == Some("trim") {
                    lbox.clip.map_or(Some(lbox.rect), |c| c.intersect(&lbox.rect)).or(Some(Rect::new(0.0, 0.0, 0.0, 0.0)))
                } else {
                    lbox.clip
                };
                let hover = scene.view.hover_link;
                text::draw_shaped(canvas, scene.text, &tb.shaped, tb.x, tb.y, clip, hover);
                text::draw_para_cursor(canvas, node, tb, clip);
            }
        }
        _ => elements::paint(canvas, node, lbox, layout.texts.get(&id), scene.view, scene.text, scene.images),
    }
}
