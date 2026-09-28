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
    clip_mask: Option<ClipMask>,
}

/// The one mask a canvas draws through for whatever a clip cuts across. It holds one clip at a
/// time, rasterised by tiny-skia as a fresh mask would be, and is zero everywhere else: moving
/// to another clip clears only the pixels the last one set. (A mask per clip was a whole frame
/// of memory each: 40 fixed-height rows made 40 masks of 3.2 MB every frame at 2x.)
struct ClipMask {
    mask: Mask,
    /// The clip it holds (logical px, as bits) and the device pixels that may be set for it.
    holds: Option<([u32; 4], PxBounds)>,
}

/// A rect of device pixels, [x0, x1) x [y0, y1).
#[derive(Clone, Copy, Debug, PartialEq)]
struct PxBounds {
    x0: i64,
    y0: i64,
    x1: i64,
    y1: i64,
}

impl PxBounds {
    fn within(&self, other: &PxBounds) -> bool {
        self.x0 >= other.x0 && self.y0 >= other.y0 && self.x1 <= other.x1 && self.y1 <= other.y1
    }

    fn meets(&self, other: &PxBounds) -> bool {
        self.x0 < other.x1 && other.x0 < self.x1 && self.y0 < other.y1 && other.y0 < self.y1
    }
}

/// Where a clip leaves a path: nothing cut, all of it cut, or cut across.
enum Clipping<'m> {
    Whole,
    Nothing,
    Through(&'m Mask),
}

impl<'a> Canvas<'a> {
    pub fn new(pm: &'a mut Pixmap, scale: f32) -> Self {
        Canvas::at(pm, scale, (0, 0))
    }

    pub fn at(pm: &'a mut Pixmap, scale: f32, origin: (i32, i32)) -> Self {
        Canvas { pm, scale, origin, clip_mask: None }
    }

    /// Logical window coordinates to the pixmap's pixels.
    pub fn base(&self) -> Transform {
        Transform::from_row(self.scale, 0.0, 0.0, self.scale, -self.origin.0 as f32, -self.origin.1 as f32)
    }

    /// `r` (logical px) cut down, if it has to be, to what tiny-skia can rasterise. A rect
    /// reaching past MAX_DEVICE_REACH (a list box a billion px tall scrolled into view) would be
    /// skipped whole, the part on screen with it; it is cut to this canvas grown by `margin`,
    /// which keeps the cut edges, their corners and any stroke out of sight. Any other rect
    /// comes back as it is, so ordinary drawing does not change by a bit.
    pub fn reachable(&self, r: Rect, margin: f32) -> Rect {
        let bounds = tiny_skia::Rect::from_xywh(r.x, r.y, r.w.max(0.001), r.h.max(0.001));
        if bounds.is_some_and(|b| within_reach(b, self.base(), margin.max(0.0) * self.scale)) {
            return r;
        }
        let v = self.visible();
        let (x0, y0) = (r.x.max(v.x - margin), r.y.max(v.y - margin));
        let (x1, y1) = (r.right().min(v.right() + margin), r.bottom().min(v.bottom() + margin));
        Rect::new(x0, y0, x1 - x0, y1 - y0)
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

    /// How `clip` (logical px) leaves a path whose device pixels lie within `reach`. A path
    /// wholly inside the pixels a clip surely keeps is drawn as it is, and one wholly outside
    /// those it might keep is not drawn at all: both come out as they would through the mask,
    /// and most things inside a clipped slot are one or the other. Only a path the clip cuts
    /// across is drawn through the mask.
    fn clipping<'m>(&self, held: &'m mut Option<ClipMask>, clip: Option<Rect>, reach: PxBounds) -> Clipping<'m> {
        let Some(clip) = clip else { return Clipping::Whole };
        // Only the part of the clip on this canvas matters, and a huge one would not rasterise.
        let clip = clip.intersect(&self.visible()).unwrap_or_default();
        let (kept, touched) = self.clip_pixels(clip);
        if kept.x0 < kept.x1 && kept.y0 < kept.y1 && reach.within(&kept) {
            return Clipping::Whole;
        }
        if !reach.meets(&touched) {
            return Clipping::Nothing;
        }
        let key = [clip.x.to_bits(), clip.y.to_bits(), clip.w.to_bits(), clip.h.to_bits()];
        if held.is_none() {
            let Some(mask) = Mask::new(self.pm.width(), self.pm.height()) else { return Clipping::Nothing };
            *held = Some(ClipMask { mask, holds: None });
        }
        let Some(held) = held.as_mut() else { return Clipping::Nothing };
        if held.holds.is_some_and(|(k, _)| k == key) {
            return Clipping::Through(&held.mask);
        }
        if let Some((_, set)) = held.holds.take() {
            clear(&mut held.mask, set);
        }
        if let Some(r) = tiny_skia::Rect::from_xywh(clip.x, clip.y, clip.w.max(0.001), clip.h.max(0.001)) {
            held.mask.fill_path(&PathBuilder::from_rect(r), FillRule::Winding, false, self.base());
        }
        held.holds = Some((key, touched));
        Clipping::Through(&held.mask)
    }

    /// The device pixels a clip's mask surely sets, and those it may set. tiny-skia fills a
    /// rect without antialiasing from round(x0) to round(x1), rounding in 1/64 px (pinned by
    /// tests::a_clip_mask_sets_the_pixels_clip_pixels_says).
    fn clip_pixels(&self, clip: Rect) -> (PxBounds, PxBounds) {
        let (x0, y0) = self.to_device(clip.x, clip.y);
        let (x1, y1) = self.to_device(clip.right(), clip.bottom());
        let slop = 1.0 / 32.0;
        let from = |v: f64| (v + 0.5 + slop).floor() as i64;
        let to = |v: f64| (v + 0.5 - slop).floor() as i64;
        let kept = PxBounds { x0: from(x0), y0: from(y0), x1: to(x1), y1: to(y1) };
        let touched = PxBounds { x0: x0.floor() as i64 - 1, y0: y0.floor() as i64 - 1, x1: x1.ceil() as i64 + 1, y1: y1.ceil() as i64 + 1 };
        (kept, touched)
    }

    /// A logical point in this pixmap's device pixels.
    fn to_device(&self, x: f32, y: f32) -> (f64, f64) {
        ((x * self.scale) as f64 - self.origin.0 as f64, (y * self.scale) as f64 - self.origin.1 as f64)
    }

    /// The device pixels a path's paint can touch: its bounds under `transform`, grown by
    /// `pad` device px. Antialiasing only shades pixels the path reaches into.
    fn reach(bounds: tiny_skia::Rect, transform: Transform, pad: f32) -> PxBounds {
        let mut corners = [
            Point::from_xy(bounds.left(), bounds.top()),
            Point::from_xy(bounds.right(), bounds.top()),
            Point::from_xy(bounds.left(), bounds.bottom()),
            Point::from_xy(bounds.right(), bounds.bottom()),
        ];
        transform.map_points(&mut corners);
        let (mut x0, mut y0, mut x1, mut y1) = (f64::INFINITY, f64::INFINITY, f64::NEG_INFINITY, f64::NEG_INFINITY);
        for c in corners {
            (x0, y0, x1, y1) = (x0.min(c.x as f64), y0.min(c.y as f64), x1.max(c.x as f64), y1.max(c.y as f64));
        }
        let pad = pad as f64;
        PxBounds { x0: (x0 - pad).floor() as i64, y0: (y0 - pad).floor() as i64, x1: (x1 + pad).ceil() as i64, y1: (y1 + pad).ceil() as i64 }
    }

    pub fn fill_path(&mut self, path: &Path, shader: Shader, rule: FillRule, local: Transform, clip: Option<Rect>) {
        let transform = self.base().pre_concat(local);
        if !within_reach(path.bounds(), transform, 0.0) {
            return;
        }
        let paint = tiny_skia::Paint { shader, anti_alias: true, ..tiny_skia::Paint::default() };
        let mut held = self.clip_mask.take();
        match self.clipping(&mut held, clip, Canvas::reach(path.bounds(), transform, 0.0)) {
            Clipping::Nothing => {}
            Clipping::Whole => self.pm.fill_path(path, &paint, rule, transform, None),
            Clipping::Through(mask) => self.pm.fill_path(path, &paint, rule, transform, Some(mask)),
        }
        self.clip_mask = held;
    }

    pub fn stroke_path(&mut self, path: &Path, shader: Shader, stroke: &Stroke, local: Transform, clip: Option<Rect>) {
        let transform = self.base().pre_concat(local);
        if !within_reach(path.bounds(), transform, stroke.width) {
            return;
        }
        let paint = tiny_skia::Paint { shader, anti_alias: true, ..tiny_skia::Paint::default() };
        // Joins and caps reach at most miter-limit half-widths past the path.
        let stretch = (transform.sx.abs() + transform.kx.abs()).max(transform.ky.abs() + transform.sy.abs());
        let pad = stroke.width.max(1.0) * stroke.miter_limit.max(1.0) * stretch;
        let mut held = self.clip_mask.take();
        match self.clipping(&mut held, clip, Canvas::reach(path.bounds(), transform, pad)) {
            Clipping::Nothing => {}
            Clipping::Whole => self.pm.stroke_path(path, &paint, stroke, transform, None),
            Clipping::Through(mask) => self.pm.stroke_path(path, &paint, stroke, transform, Some(mask)),
        }
        self.clip_mask = held;
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

    /// A rounded rect's path, cut down to what tiny-skia can rasterise (`reachable`).
    pub fn rect_path(&self, rect: Rect, radius: f32, stroke_width: f32) -> Option<Path> {
        shapes::rounded_rect(self.reachable(rect, radius.max(0.0) + stroke_width.max(0.0) + 2.0), radius)
    }

    pub fn fill_rect(&mut self, rect: Rect, color: Color, clip: Option<Rect>) {
        if let Some(path) = self.rect_path(rect, 0.0, 0.0) {
            self.fill(&path, color, clip);
        }
    }

    pub fn fill_rounded(&mut self, rect: Rect, radius: f32, color: Color, clip: Option<Rect>) {
        if let Some(path) = self.rect_path(rect, radius, 0.0) {
            self.fill(&path, color, clip);
        }
    }

    /// A 1px-style outline drawn inside `rect`, so it stays crisp.
    pub fn stroke_rounded(&mut self, rect: Rect, radius: f32, color: Color, width: f32, clip: Option<Rect>) {
        let half = width / 2.0;
        let inner = Rect::new(rect.x + half, rect.y + half, rect.w - width, rect.h - width);
        if let Some(path) = self.rect_path(inner, (radius - half).max(0.0), width) {
            self.stroke(&path, color, width, clip);
        }
    }

    pub fn fill_gradient(&mut self, rect: Rect, radius: f32, top: Color, bottom: Color, clip: Option<Rect>) {
        let Some(path) = self.rect_path(rect, radius, 0.0) else { return };
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

/// Zeroes the device pixels `set` covers, within the mask.
fn clear(mask: &mut Mask, set: PxBounds) {
    let (w, h) = (mask.width() as i64, mask.height() as i64);
    let (x0, x1) = (set.x0.clamp(0, w) as usize, set.x1.clamp(0, w) as usize);
    let (y0, y1) = (set.y0.clamp(0, h), set.y1.clamp(0, h));
    let data = mask.data_mut();
    for y in y0..y1 {
        let row = y as usize * w as usize;
        data[row + x0..row + x1].fill(0);
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
fn on_screen(node: &crate::doc::Node, lbox: &crate::layout::LBox, window: Rect) -> bool {
    let area = match lbox.clip {
        Some(clip) => match clip.intersect(&window) {
            Some(a) => a,
            None => return false,
        },
        None => window,
    };
    let r = lbox.rect;
    let slack = if node.kind.is_art() { r.w.max(r.h) / 2.0 + 8.0 + shapes::overhang(node) } else { 8.0 };
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
    if !on_screen(node, lbox, window) {
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
                let mode = scene.text.fonts.text_mode;
                if mode == crate::text::TextMode::Shoes3 {
                    text::draw_para_selection(canvas, node, tb, clip, text::SHOES3_SELECTION);
                }
                text::draw_shaped(canvas, scene.text, &tb.shaped, tb.x, tb.y, clip, hover);
                text::draw_para_cursor(canvas, node, tb, clip, mode);
            }
        }
        _ => elements::paint(canvas, node, lbox, layout.texts.get(&id), scene.view, scene.text, scene.images),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A small deterministic stream of numbers in [0, 1).
    struct Numbers(u64);

    impl Numbers {
        fn next(&mut self) -> f32 {
            self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            (self.0 >> 40) as f32 / (1u64 << 24) as f32
        }
    }

    /// The mask tiny-skia makes of a clip on its own, as the old mask per clip was made.
    fn fresh_mask(canvas: &Canvas, clip: Rect) -> Mask {
        let clip = clip.intersect(&canvas.visible()).unwrap_or_default();
        let mut mask = Mask::new(canvas.pm.width(), canvas.pm.height()).unwrap();
        if let Some(r) = tiny_skia::Rect::from_xywh(clip.x, clip.y, clip.w.max(0.001), clip.h.max(0.001)) {
            mask.fill_path(&PathBuilder::from_rect(r), FillRule::Winding, false, canvas.base());
        }
        mask
    }

    #[test]
    fn a_clip_mask_sets_the_pixels_clip_pixels_says() {
        let mut n = Numbers(7);
        for scale in [1.0, 1.25, 1.5, 2.0, 3.0] {
            for origin in [(0, 0), (7, 13)] {
                let mut pm = Pixmap::new(200, 150).unwrap();
                let canvas = Canvas::at(&mut pm, scale, origin);
                for _ in 0..200 {
                    let clip = Rect::new(n.next() * 80.0, n.next() * 60.0, n.next() * 60.0, n.next() * 50.0);
                    let mask = fresh_mask(&canvas, clip);
                    let (kept, touched) = canvas.clip_pixels(clip.intersect(&canvas.visible()).unwrap_or_default());
                    for y in 0..150i64 {
                        for x in 0..200i64 {
                            let set = mask.data()[(y * 200 + x) as usize];
                            let at = PxBounds { x0: x, y0: y, x1: x + 1, y1: y + 1 };
                            if at.within(&kept) {
                                assert_eq!(set, 255, "{clip:?} at {scale}x {origin:?}: pixel {x},{y} is kept");
                            }
                            if !at.meets(&touched) {
                                assert_eq!(set, 0, "{clip:?} at {scale}x {origin:?}: pixel {x},{y} is outside");
                            }
                        }
                    }
                }
            }
        }
    }

    /// Whatever a clip does to a path (nothing, all of it, or across it through the one reused
    /// mask), the pixels come out as they did through a mask of its own.
    #[test]
    fn drawing_through_clips_matches_a_mask_per_clip() {
        let mut n = Numbers(11);
        for scale in [1.0, 1.5, 2.0] {
            let (mut ours, mut theirs) = (Pixmap::new(240, 180).unwrap(), Pixmap::new(240, 180).unwrap());
            ours.fill(BACKGROUND.to_skia());
            theirs.fill(BACKGROUND.to_skia());
            let mut canvas = Canvas::new(&mut ours, scale);
            let clips: Vec<Rect> = (0..6).map(|_| Rect::new(n.next() * 100.0, n.next() * 80.0, 10.0 + n.next() * 60.0, 10.0 + n.next() * 50.0)).collect();
            for i in 0..300 {
                let clip = clips[i % clips.len()];
                let r = Rect::new(n.next() * 150.0, n.next() * 110.0, 1.0 + n.next() * 40.0, 1.0 + n.next() * 30.0);
                let color = Color::rgba((i * 37 % 255) as u8, (i * 91 % 255) as u8, 200, 160);
                let path = if i % 2 == 0 { shapes::rounded_rect(r, 4.0) } else { shapes::ellipse(r) }.unwrap();
                let stroke = Stroke { width: 1.0 + (i % 4) as f32, ..Stroke::default() };
                let paint = tiny_skia::Paint { shader: Shader::SolidColor(color.to_skia()), anti_alias: true, ..tiny_skia::Paint::default() };
                let mask = fresh_mask(&canvas, clip);
                let transform = canvas.base();
                if i % 3 == 0 {
                    canvas.stroke(&path, color, stroke.width, Some(clip));
                    theirs.stroke_path(&path, &paint, &stroke, transform, Some(&mask));
                } else {
                    canvas.fill(&path, color, Some(clip));
                    theirs.fill_path(&path, &paint, FillRule::Winding, transform, Some(&mask));
                }
            }
            drop(canvas);
            assert!(ours.data() == theirs.data(), "at {scale}x the pixels differ from a mask per clip");
        }
    }
}
