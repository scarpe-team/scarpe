//! Images: decoding (png, jpeg, gif first frame, bmp) into premultiplied
//! pixmaps, caller-owned RGBA bitmaps, and drawing them into their box.

use crate::doc::Node;
use crate::layout::{LBox, Rect};
use crate::limits;
use crate::paint::Canvas;
use crate::style::{Color, Paint};
use base64::Engine;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::time::SystemTime;
use tiny_skia::{FilterQuality, IntSize, Pixmap, PixmapPaint, Transform};

/// Decoded pictures by path. Each is read again when its file changes (its modification time
/// or its length), so an app that rewrites a picture and shows it again sees the new one, and
/// a file that did not read (not there yet, not a picture) is tried again once it changes.
/// A file is looked at once a batch at most (`next_batch`), not on every paint. Runtime::flush
/// lets go of files nothing shows any more (`retain`). `memory:` originals remain until
/// explicitly released, so removing a drawable does not discard caller-owned pixels.
///
/// A picture shown bigger or smaller than its pixels is resampled once for the size it is shown
/// at, and the copy kept with it (`at_size`): resampling a 211 px glow up to 844 device pixels
/// on every paint cost five times what drawing it did.
#[derive(Default)]
pub struct ImageCache {
    entries: HashMap<PathBuf, Entry>,
    batch: u64,
    /// Copies made at a new size since the runtime last asked (`take_resampled`).
    resampled: u64,
    memory_bytes: usize,
    memory_sized_bytes: usize,
    memory_entries: usize,
}

struct Entry {
    /// The file as it was when read; None when there was none.
    file: Option<FileStamp>,
    image: Option<Rc<Pixmap>>,
    /// The batch the file was last looked at in.
    looked: u64,
    /// The picture resampled to the device sizes it is drawn at, the last used first.
    sized: Vec<Rc<Pixmap>>,
}

/// How many sizes of one picture are kept, for a picture shown at several sizes at once.
const SIZES_KEPT: usize = 4;
/// A copy bigger than this many pixels is not kept; the picture is drawn resampled as it goes.
const MOST_KEPT_PIXELS: u64 = 16 * 1024 * 1024;

#[derive(Clone, Copy, PartialEq, Eq)]
struct FileStamp {
    modified: Option<SystemTime>,
    len: u64,
}

impl FileStamp {
    fn of(path: &Path) -> Option<FileStamp> {
        let meta = std::fs::metadata(path).ok()?;
        Some(FileStamp { modified: meta.modified().ok(), len: meta.len() })
    }
}

impl ImageCache {
    /// Upload tightly packed, row-major, straight-alpha RGBA8. Validation and decoding finish
    /// before replacing an existing key, so a rejected upload leaves its old pixels intact.
    pub fn insert_rgba(&mut self, key: &str, width: u32, height: u32, encoded: &str) -> Result<(), String> {
        validate_bitmap_key(key)?;
        if width == 0 || height == 0 || width > limits::MAX_IMAGE_SIDE || height > limits::MAX_IMAGE_SIDE {
            return Err(format!("bitmap dimensions must be integers in 1..={}", limits::MAX_IMAGE_SIDE));
        }
        let length = width as u64 * height as u64 * 4;
        if length > limits::MAX_BITMAP_BYTES as u64 {
            return Err("bitmap exceeds the 64 MiB upload limit".into());
        }
        let length = length as usize;
        if encoded.len() != length.div_ceil(3) * 4 {
            return Err("bitmap RGBA length does not match its dimensions".into());
        }
        let path = Path::new(key);
        let old = self.entries.get(path);
        let old_bytes = old.and_then(|entry| entry.image.as_ref()).map_or(0, |image| image.data().len());
        if self.memory_bytes - old_bytes + length > limits::MAX_BITMAP_CACHE_BYTES {
            return Err("bitmap cache exceeds 128 MiB; release unused bitmaps first".into());
        }
        if old.is_none() && self.memory_entries >= limits::MAX_BITMAP_ENTRIES {
            return Err("bitmap cache exceeds 1024 keys; release unused bitmaps first".into());
        }
        let mut data = base64::engine::general_purpose::STANDARD.decode(encoded).map_err(|_| "bitmap RGBA is not valid base64")?;
        if data.len() != length {
            return Err("bitmap RGBA length does not match its dimensions".into());
        }
        premultiply(&mut data);
        let image = Pixmap::from_vec(data, IntSize::from_wh(width, height).unwrap()).ok_or("invalid bitmap dimensions")?;
        self.forget(path);
        self.entries.insert(path.to_path_buf(), Entry { file: None, image: Some(Rc::new(image)), looked: self.batch, sized: Vec::new() });
        self.memory_bytes += length;
        self.memory_entries += 1;
        Ok(())
    }

    /// A missing key is already released. Never interprets a key as a filesystem path.
    pub fn release_bitmap(&mut self, key: &str) -> Result<bool, String> {
        validate_bitmap_key(key)?;
        let path = Path::new(key);
        let existed = self.entries.contains_key(path);
        self.forget(path);
        Ok(existed)
    }

    pub fn bitmap_size(&self, key: &str) -> Result<Option<(u32, u32)>, String> {
        validate_bitmap_key(key)?;
        Ok(self
            .entries
            .get(Path::new(key))
            .and_then(|entry| entry.image.as_ref())
            .map(|image| (image.width(), image.height())))
    }

    pub fn get(&mut self, path: &Path) -> Option<Rc<Pixmap>> {
        if is_memory(path) {
            return self.entries.get(path).and_then(|entry| entry.image.clone());
        }
        let batch = self.batch;
        if let Some(entry) = self.entries.get_mut(path).filter(|entry| entry.looked == batch) {
            return entry.image.clone();
        }
        let file = FileStamp::of(path);
        if let Some(entry) = self.entries.get_mut(path).filter(|entry| entry.file == file) {
            entry.looked = batch;
            return entry.image.clone();
        }
        let image = file.and_then(|_| decode(path)).map(Rc::new);
        self.entries.insert(path.to_path_buf(), Entry { file, image: image.clone(), looked: batch, sized: Vec::new() });
        image
    }

    /// The picture at `path` resampled to exactly `w` x `h` pixels, made the first time and kept
    /// after. None for a size too big to keep, or a picture not read.
    pub fn at_size(&mut self, path: &Path, w: u32, h: u32) -> Option<Rc<Pixmap>> {
        if w == 0 || h == 0 || w as u64 * h as u64 > MOST_KEPT_PIXELS {
            return None;
        }
        let entry = self.entries.get_mut(path)?;
        let image = entry.image.clone()?;
        if let Some(i) = entry.sized.iter().position(|copy| copy.width() == w && copy.height() == h) {
            let copy = entry.sized.remove(i);
            entry.sized.insert(0, copy.clone());
            return Some(copy);
        }
        let memory = is_memory(path);
        let bytes = w as usize * h as usize * 4;
        let evicted = entry.sized.get(SIZES_KEPT - 1).map_or(0, |copy| copy.data().len());
        if memory && self.memory_sized_bytes + bytes - evicted > limits::MAX_BITMAP_SIZED_BYTES {
            // Draw from the original instead; a cache limit must not make an image disappear.
            return None;
        }
        let mut copy = Pixmap::new(w, h)?;
        let (sx, sy) = (w as f32 / image.width() as f32, h as f32 / image.height() as f32);
        let paint = PixmapPaint { quality: FilterQuality::Bicubic, ..PixmapPaint::default() };
        copy.draw_pixmap(0, 0, image.as_ref().as_ref(), &paint, Transform::from_scale(sx, sy), None);
        let copy = Rc::new(copy);
        entry.sized.insert(0, copy.clone());
        entry.sized.truncate(SIZES_KEPT);
        if memory {
            self.memory_sized_bytes = self.memory_sized_bytes + bytes - evicted;
        }
        self.resampled += 1;
        Some(copy)
    }

    /// How many copies at a new size were made since the last call (stats' images_resampled).
    pub fn take_resampled(&mut self) -> u64 {
        std::mem::take(&mut self.resampled)
    }

    /// A new batch of changes arrived: files are worth looking at again.
    pub fn next_batch(&mut self) {
        self.batch += 1;
    }

    pub fn forget(&mut self, path: &Path) {
        if let Some(entry) = self.entries.remove(path) {
            if is_memory(path) {
                self.memory_bytes -= entry.image.as_ref().map_or(0, |image| image.data().len());
                self.memory_sized_bytes -= entry
                    .sized
                    .iter()
                    .map(|copy| copy.data().len())
                    .sum::<usize>();
                self.memory_entries -= 1;
            }
        }
    }

    /// Discard unshown files and resized copies. Caller-owned originals need explicit release.
    pub fn retain(&mut self, shown: impl Fn(&Path) -> bool) {
        self.entries.retain(|path, entry| {
            if shown(path) {
                return true;
            }
            if is_memory(path) {
                self.memory_sized_bytes -= entry
                    .sized
                    .iter()
                    .map(|copy| copy.data().len())
                    .sum::<usize>();
                entry.sized.clear();
                return true;
            }
            false
        });
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}

/// Decodes an image file, whatever its extension says, within limits::MAX_IMAGE_SIDE and
/// MAX_IMAGE_BYTES. None for anything else, including what is not a plain file: a FIFO
/// would block the display on open and /dev/zero would never end.
fn decode(path: &Path) -> Option<Pixmap> {
    if !crate::limits::readable_file(path, crate::limits::MAX_IMAGE_BYTES) {
        return None;
    }
    let mut reader = image::ImageReader::open(path).ok()?.with_guessed_format().ok()?;
    let mut bounds = image::Limits::default();
    bounds.max_image_width = Some(crate::limits::MAX_IMAGE_SIDE);
    bounds.max_image_height = Some(crate::limits::MAX_IMAGE_SIDE);
    bounds.max_alloc = Some(crate::limits::MAX_IMAGE_BYTES);
    reader.limits(bounds);
    let rgba = reader.decode().ok()?.to_rgba8();
    let (w, h) = rgba.dimensions();
    let mut data = rgba.into_raw();
    premultiply(&mut data);
    Pixmap::from_vec(data, IntSize::from_wh(w, h)?)
}

fn is_memory(path: &Path) -> bool {
    path.to_str().is_some_and(|key| key.starts_with("memory:"))
}

/// No path separators: keys stay distinct under Path's platform-specific normalization.
fn validate_bitmap_key(key: &str) -> Result<(), String> {
    let suffix = key.strip_prefix("memory:").unwrap_or("");
    if suffix.is_empty()
        || key.len() > limits::MAX_BITMAP_KEY_BYTES
        || !suffix
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || b"._:-".contains(&c))
    {
        return Err("bitmap key must be memory: followed by ASCII letters, digits, '.', '_', ':', or '-', at most 200 bytes total".into());
    }
    Ok(())
}

fn premultiply(data: &mut [u8]) {
    for px in data.chunks_exact_mut(4) {
        let a = px[3] as u32;
        if a < 255 {
            for c in &mut px[..3] {
                *c = ((*c as u32 * a + 127) / 255) as u8;
            }
        }
    }
}

/// Every picture file `node` shows: an image's own, a button's icon, and a picture it is
/// filled or stroked with.
pub fn shown_by(node: &Node) -> impl Iterator<Item = PathBuf> + '_ {
    let icon = node.props.str("icon").filter(|p| !p.is_empty()).map(PathBuf::from);
    let patterns = ["fill", "stroke"].into_iter().filter_map(|key| match node.props.art_paint(key) {
        Some(Paint::Image(path)) => Some(path),
        _ => None,
    });
    url(node).into_iter().chain(icon).chain(patterns)
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
    let path = url(node);
    let Some(mut img) = path.as_ref().and_then(|p| images.get(p)) else {
        if node.props.str("url").is_some_and(|u| !u.is_empty()) {
            placeholder(canvas, r, lbox.clip);
        }
        return;
    };
    let base = canvas.base();
    let turned = node.props.f32("rotate_angle").filter(|d| *d != 0.0);
    // Unturned, it lands on whole device pixels; a picture of another size is drawn from its
    // copy at that size, kept from paint to paint, one pixel for each.
    let (x0, y0) = ((r.x * base.sx + base.tx).round(), (r.y * base.sy + base.ty).round());
    let (w, h) = ((r.right() * base.sx + base.tx).round() - x0, (r.bottom() * base.sy + base.ty).round() - y0);
    let same_size = w as u32 == img.width() && h as u32 == img.height();
    if let (None, Some(p), false) = (turned, &path, same_size) {
        if let Some(copy) = images.at_size(p, w as u32, h as u32) {
            img = copy;
        }
    }
    let mut transform = if turned.is_none() && w as u32 == img.width() && h as u32 == img.height() {
        // In device pixels already: `base` is taken off again below.
        Transform::from_translate((x0 - base.tx) / base.sx, (y0 - base.ty) / base.sy).pre_scale(1.0 / base.sx, 1.0 / base.sy)
    } else {
        Transform::from_row(r.w / img.width() as f32, 0.0, 0.0, r.h / img.height() as f32, r.x, r.y)
    };
    if let Some(deg) = turned {
        let (cx, cy) = if node.props.str("transform_origin") == Some("center") { r.center() } else { (r.x, r.y) };
        transform = Transform::from_rotate_at(deg, cx, cy).pre_concat(transform);
    }
    let paint = PixmapPaint { quality: FilterQuality::Bicubic, ..PixmapPaint::default() };
    let mask_clip = lbox.clip;
    // draw_pixmap has no clip rect of its own: clip by drawing through a pattern-filled rect.
    if mask_clip.is_some() {
        let shader = tiny_skia::Pattern::new(img.as_ref().as_ref(), tiny_skia::SpreadMode::Pad, FilterQuality::Bicubic, 1.0, transform);
        if let Some(path) = canvas.rect_path(r, 0.0, 0.0) {
            canvas.fill_path(&path, shader, tiny_skia::FillRule::Winding, Transform::identity(), mask_clip);
        }
        return;
    }
    let whole = tiny_skia::Rect::from_xywh(0.0, 0.0, img.width() as f32, img.height() as f32);
    if whole.is_some_and(|b| crate::paint::within_reach(b, base.pre_concat(transform), 0.0)) {
        canvas.pm.draw_pixmap(0, 0, img.as_ref().as_ref(), &paint, base.pre_concat(transform), None);
    }
}

/// Draws `img` as large as fits in `r`, keeping its shape, centred (a button's icon).
pub fn draw_fitted(canvas: &mut Canvas, img: &Pixmap, r: Rect, clip: Option<Rect>) {
    let (iw, ih) = (img.width() as f32, img.height() as f32);
    let s = (r.w / iw).min(r.h / ih);
    let (w, h) = (iw * s, ih * s);
    let at = Rect::new(r.x + (r.w - w) / 2.0, r.y + (r.h - h) / 2.0, w, h);
    let shader = tiny_skia::Pattern::new(img.as_ref(), tiny_skia::SpreadMode::Pad, FilterQuality::Bicubic, 1.0, Transform::from_row(s, 0.0, 0.0, s, at.x, at.y));
    if let Some(path) = crate::paint::shapes::rounded_rect(at, 0.0) {
        canvas.fill_path(&path, shader, tiny_skia::FillRule::Winding, Transform::identity(), clip);
    }
}

fn placeholder(canvas: &mut Canvas, r: Rect, clip: Option<Rect>) {
    canvas.fill_rounded(r, 4.0, Color::rgb(0xf2, 0xf2, 0xf7), clip);
    canvas.stroke_rounded(r, 4.0, Color::rgb(0xd1, 0xd1, 0xd6), 1.0, clip);
}
