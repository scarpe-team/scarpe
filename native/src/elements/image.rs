//! Images: decoding (png, jpeg, gif first frame, bmp) into premultiplied
//! pixmaps, cached by path, and drawing them into their box.

use crate::doc::Node;
use crate::layout::{LBox, Rect};
use crate::paint::Canvas;
use crate::style::Color;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use tiny_skia::{FilterQuality, IntSize, Pixmap, PixmapPaint, Transform};

#[derive(Default)]
pub struct ImageCache {
    entries: HashMap<PathBuf, Option<Rc<Pixmap>>>,
}

impl ImageCache {
    pub fn get(&mut self, path: &Path) -> Option<Rc<Pixmap>> {
        self.entries.entry(path.to_path_buf()).or_insert_with(|| decode(path).map(Rc::new)).clone()
    }

    pub fn forget(&mut self, path: &Path) {
        self.entries.remove(path);
    }
}

fn decode(path: &Path) -> Option<Pixmap> {
    let rgba = image::open(path).ok()?.to_rgba8();
    let (w, h) = rgba.dimensions();
    let mut data = rgba.into_raw();
    for px in data.chunks_exact_mut(4) {
        let a = px[3] as u32;
        if a < 255 {
            for c in &mut px[..3] {
                *c = ((*c as u32 * a + 127) / 255) as u8;
            }
        }
    }
    Pixmap::from_vec(data, IntSize::from_wh(w, h)?)
}

fn url(node: &Node) -> Option<PathBuf> {
    let u = node.props.str("url")?;
    if u.is_empty() || u.starts_with("http://") || u.starts_with("https://") || u.starts_with("data:") {
        return None;
    }
    Some(PathBuf::from(u.strip_prefix("file://").unwrap_or(u)))
}

/// The image's own pixel size (0x0 when it has no url or does not load).
pub fn natural_size(node: &Node, images: &mut ImageCache) -> (f32, f32) {
    match url(node).and_then(|p| images.get(&p)) {
        Some(img) => (img.width() as f32, img.height() as f32),
        None => (0.0, 0.0),
    }
}

/// One side given: the other keeps the aspect ratio.
pub fn height_for_width(natural: (f32, f32), width: f32) -> f32 {
    if natural.0 > 0.0 {
        width * natural.1 / natural.0
    } else {
        natural.1
    }
}

pub fn width_for_height(natural: (f32, f32), height: f32) -> f32 {
    if natural.1 > 0.0 {
        height * natural.0 / natural.1
    } else {
        natural.0
    }
}

pub fn paint(canvas: &mut Canvas, node: &Node, lbox: &LBox, images: &mut ImageCache) {
    let r = lbox.rect;
    if r.w <= 0.0 || r.h <= 0.0 {
        return;
    }
    let Some(img) = url(node).and_then(|p| images.get(&p)) else {
        if node.props.str("url").is_some_and(|u| !u.is_empty()) {
            placeholder(canvas, r, lbox.clip);
        }
        return;
    };
    let sx = r.w / img.width() as f32;
    let sy = r.h / img.height() as f32;
    let mut transform = Transform::from_row(sx, 0.0, 0.0, sy, r.x, r.y);
    if let Some(deg) = node.props.f32("rotate_angle").filter(|d| *d != 0.0) {
        let (cx, cy) = if node.props.str("transform_origin") == Some("center") { r.center() } else { (r.x, r.y) };
        transform = Transform::from_rotate_at(deg, cx, cy).pre_concat(transform);
    }
    let paint = PixmapPaint { quality: FilterQuality::Bicubic, ..PixmapPaint::default() };
    let base = canvas.base();
    let mask_clip = lbox.clip;
    // draw_pixmap has no clip rect of its own: clip by drawing through a pattern-filled rect.
    if mask_clip.is_some() {
        let shader = tiny_skia::Pattern::new(img.as_ref().as_ref(), tiny_skia::SpreadMode::Pad, FilterQuality::Bicubic, 1.0, transform);
        if let Some(path) = crate::paint::shapes::rounded_rect(r, 0.0) {
            canvas.fill_path(&path, shader, tiny_skia::FillRule::Winding, Transform::identity(), mask_clip);
        }
        return;
    }
    canvas.pm.draw_pixmap(0, 0, img.as_ref().as_ref(), &paint, base.pre_concat(transform), None);
}

fn placeholder(canvas: &mut Canvas, r: Rect, clip: Option<Rect>) {
    canvas.fill_rounded(r, 4.0, Color::rgb(0xf2, 0xf2, 0xf7), clip);
    canvas.stroke_rounded(r, 4.0, Color::rgb(0xd1, 0xd1, 0xd6), 1.0, clip);
}
