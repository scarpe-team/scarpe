//! Painting a laid-out app into a tiny-skia Pixmap at any scale. Everything is
//! drawn in logical coordinates under a scale transform; text is rasterised at
//! the physical size so it stays crisp on HiDPI screens.

pub mod damage;
pub mod decor;
pub mod shapes;
pub mod text;

use crate::doc::{Doc, Kind};
use crate::props::Id;
use crate::elements::{self, image::ImageCache};
use crate::input::ViewState;
use crate::layout::{Layout, Rect};
use crate::style::{Color, Paint};
use crate::text::raster::{self, PxClip};
use crate::text::TextEngine;
use cosmic_text::SwashImage;
use std::collections::HashMap;
use tiny_skia::{
    FillRule, FilterQuality, GradientStop, LinearGradient, Mask, MaskType, Path, PathBuilder, Pattern, Pixmap, PixmapPaint,
    Point, Shader, SpreadMode, Stroke, Transform,
};

pub const BACKGROUND: Color = Color::WHITE;

/// How far from the canvas, in device pixels, a path may reach and still be drawn. tiny-skia
/// rasterises in fixed point and panics past its range (a stroke 2^31 px wide did); nothing
/// that reaches a million pixels out is a drawing anyone can see in a 10,000 px window.
const MAX_DEVICE_REACH: f32 = 1_048_576.0;

/// Whether a path with these bounds, drawn under `transform` with a stroke `stroke_width`
/// wide (0 for a fill), stays inside MAX_DEVICE_REACH. False for NaN or infinite geometry.
pub(crate) fn within_reach(bounds: tiny_skia::Rect, transform: Transform, stroke_width: f32) -> bool {
    let mut corners = [
        Point::from_xy(bounds.left(), bounds.top()),
        Point::from_xy(bounds.right(), bounds.top()),
        Point::from_xy(bounds.left(), bounds.bottom()),
        Point::from_xy(bounds.right(), bounds.bottom()),
    ];
    transform.map_points(&mut corners);
    let stretch = (transform.sx.abs() + transform.kx.abs()).max(transform.ky.abs() + transform.sy.abs());
    let pad = stroke_width.max(0.0) * stretch;
    pad.is_finite() && corners.iter().all(|c| c.x.abs() + pad <= MAX_DEVICE_REACH && c.y.abs() + pad <= MAX_DEVICE_REACH)
}

pub struct Canvas<'a> {
    pub pm: &'a mut Pixmap,
    pub scale: f32,
    /// Where the pixmap's top-left sits in the window, in physical pixels: a repaint of one
    /// damaged rect paints into a pixmap of that rect's size (paint::damage).
    origin: (i32, i32),
    masks: HashMap<[u32; 4], Mask>,
}

impl<'a> Canvas<'a> {
    pub fn new(pm: &'a mut Pixmap, scale: f32) -> Self {
        Canvas::at(pm, scale, (0, 0))
    }

    pub fn at(pm: &'a mut Pixmap, scale: f32, origin: (i32, i32)) -> Self {
        Canvas { pm, scale, origin, masks: HashMap::new() }
    }

    /// Logical window coordinates to the pixmap's pixels.
    pub fn base(&self) -> Transform {
        Transform::from_row(self.scale, 0.0, 0.0, self.scale, -self.origin.0 as f32, -self.origin.1 as f32)
    }

    /// The part of the window this pixmap covers, in logical px.
    pub fn visible(&self) -> Rect {
        let s = self.scale;
        Rect::new(self.origin.0 as f32 / s, self.origin.1 as f32 / s, self.pm.width() as f32 / s, self.pm.height() as f32 / s)
    }

    /// Draws a glyph image whose origin is at (gx, gy) in window pixels.
    pub fn blit(&mut self, img: &SwashImage, gx: i32, gy: i32, color: Color, clip: Option<PxClip>) {
        let (ox, oy) = self.origin;
        let clip = clip.map(|c| PxClip { x0: c.x0 - ox, y0: c.y0 - oy, x1: c.x1 - ox, y1: c.y1 - oy });
        raster::blit(self.pm, img, gx - ox, gy - oy, color, clip);
    }

    /// Fills a rectangle given in window pixels, unantialiased.
    pub fn fill_px(&mut self, rect: tiny_skia::Rect, paint: &tiny_skia::Paint) {
        let to_pixmap = Transform::from_translate(-self.origin.0 as f32, -self.origin.1 as f32);
        if within_reach(rect, to_pixmap, 0.0) {
            self.pm.fill_rect(rect, paint, to_pixmap, None);
        }
    }

    fn mask_key(&mut self, clip: Option<Rect>) -> Option<[u32; 4]> {
        // Only the part of the clip on this canvas matters, and a huge one would not rasterise.
        let clip = clip?.intersect(&self.visible()).unwrap_or_default();
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
        let transform = self.base().pre_concat(local);
        if !within_reach(path.bounds(), transform, 0.0) {
            return;
        }
        let key = self.mask_key(clip);
        let paint = tiny_skia::Paint { shader, anti_alias: true, ..tiny_skia::Paint::default() };
        let mask = key.and_then(|k| self.masks.get(&k));
        self.pm.fill_path(path, &paint, rule, transform, mask);
    }

    pub fn stroke_path(&mut self, path: &Path, shader: Shader, stroke: &Stroke, local: Transform, clip: Option<Rect>) {
        let transform = self.base().pre_concat(local);
        if !within_reach(path.bounds(), transform, stroke.width) {
            return;
        }
        let key = self.mask_key(clip);
        let paint = tiny_skia::Paint { shader, anti_alias: true, ..tiny_skia::Paint::default() };
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
/// list_box popup, tooltip, in-window dialog).
pub fn paint(scene: &mut Scene, pm: &mut Pixmap, scale: f32) {
    paint_nodes(scene, Canvas::new(pm, scale), None);
}

/// Paints what `canvas` covers, from the background up. `only`: a damaged rect (logical px);
/// nodes that cannot touch it are skipped, and the canvas clips the rest (paint::damage).
pub fn paint_nodes(scene: &mut Scene, mut canvas: Canvas, only: Option<Rect>) {
    canvas.pm.fill(BACKGROUND.to_skia());
    let layout = scene.layout;
    paint_run(scene, &mut canvas, &layout.order, only, 0);
    decor::scrollbars(&mut canvas, layout);
    elements::list_box::paint_popup(&mut canvas, scene.view, scene.text);
    if scene.view.popup.is_none() {
        elements::tooltip::paint(&mut canvas, scene.view.tooltip.as_mut(), scene.text, layout.size);
    }
    crate::dialogs::paint_modal(&mut canvas, scene.view, scene.text, layout.size);
}

/// Paints a run of the paint order. A slot holding a mask paints the rest of its
/// contents through the mask's alpha, as Shoes 3 does (s3_canvas.c:531-613). Masks nested
/// deeper than limits::MAX_MASK_DEPTH paint unmasked: each level holds two frame-sized layers.
fn paint_run(scene: &mut Scene, canvas: &mut Canvas, ids: &[Id], only: Option<Rect>, mask_depth: usize) {
    let mut i = 0;
    while i < ids.len() {
        let masks = if mask_depth < crate::limits::MAX_MASK_DEPTH { masks_in(scene, ids[i]) } else { Vec::new() };
        if masks.is_empty() {
            paint_node(scene, canvas, ids[i], only);
            i += 1;
        } else {
            let end = subtree_end(scene.doc, ids, i);
            paint_masked(scene, canvas, &ids[i + 1..end], &masks, only, mask_depth + 1);
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
/// shows the contents only where the masks drew something. The layers cover what the
/// canvas covers, so a partial repaint (paint::damage) masks just its own rect.
fn paint_masked(scene: &mut Scene, canvas: &mut Canvas, contents: &[Id], masks: &[Id], only: Option<Rect>, mask_depth: usize) {
    let doc = scene.doc;
    let (mask_ids, content_ids): (Vec<Id>, Vec<Id>) = contents.iter().partition(|id| masks.iter().any(|m| doc.is_descendant_of(**id, *m)));
    let (w, h) = (canvas.pm.width(), canvas.pm.height());
    let (Some(mut content), Some(mut alpha)) = (Pixmap::new(w, h), Pixmap::new(w, h)) else { return };
    paint_run(scene, &mut Canvas::at(&mut content, canvas.scale, canvas.origin), &content_ids, only, mask_depth);
    paint_run(scene, &mut Canvas::at(&mut alpha, canvas.scale, canvas.origin), &mask_ids, only, mask_depth);
    let mask = Mask::from_pixmap(alpha.as_ref(), MaskType::Alpha);
    canvas.pm.draw_pixmap(0, 0, content.as_ref(), &PixmapPaint::default(), Transform::identity(), Some(&mask));
}

fn paint_node(scene: &mut Scene, canvas: &mut Canvas, id: Id, only: Option<Rect>) {
    let layout = scene.layout;
    let doc = scene.doc;
    let window = Rect::new(0.0, 0.0, layout.size.0, layout.size.1);
    let (Some(node), Some(lbox)) = (doc.get(id), layout.boxes.get(&id)) else { return };
    if !on_screen(node.kind.is_art(), lbox, window) {
        return;
    }
    if only.is_some_and(|region| !damage::may_touch(node, lbox, layout.texts.get(&id), region)) {
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
