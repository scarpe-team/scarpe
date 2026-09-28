//! Our own glyph rasteriser (cosmic-text's swash path, cached by CacheKey) and
//! a blitter that honours a clip rectangle and darkens coverage slightly.
//!
//! Grayscale text reads lighter than CoreText's (research 07). swash's
//! embolden closes the gap for single-contour glyphs but thins glyphs built
//! from overlapping contours (Inter's "f"), so we lift edge coverage with a
//! gamma curve instead, which treats every glyph alike.

use cosmic_text::{CacheKey, CacheKeyFlags, FontSystem, SwashContent, SwashImage};
use std::collections::HashMap;
use swash::scale::{Render, ScaleContext, Source, StrikeWith};
use swash::zeno::{Angle, Format, Transform, Vector};
use tiny_skia::Pixmap;

use crate::style::Color;

/// Physical-pixel clip, half-open: x0 <= x < x1.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PxClip {
    pub x0: i32,
    pub y0: i32,
    pub x1: i32,
    pub y1: i32,
}

pub struct GlyphRaster {
    context: ScaleContext,
    cache: HashMap<CacheKey, Option<SwashImage>>,
}

impl Default for GlyphRaster {
    fn default() -> Self {
        GlyphRaster { context: ScaleContext::new(), cache: HashMap::new() }
    }
}

impl GlyphRaster {
    pub fn image(&mut self, fs: &mut FontSystem, key: CacheKey) -> Option<&SwashImage> {
        let context = &mut self.context;
        self.cache.entry(key).or_insert_with(|| render(fs, context, key)).as_ref()
    }

    pub fn len(&self) -> usize {
        self.cache.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cache.is_empty()
    }

    /// Glyph images are cheap to rebuild; cap the cache so long sessions stay small.
    pub fn trim(&mut self) {
        if self.cache.len() > 20_000 {
            self.cache.clear();
        }
    }
}

fn render(fs: &mut FontSystem, context: &mut ScaleContext, key: CacheKey) -> Option<SwashImage> {
    let font = fs.get_font(key.font_id, key.font_weight)?;
    let swash_font = font.as_swash();
    let mut builder = context
        .builder(swash_font)
        .size(f32::from_bits(key.font_size_bits))
        .hint(!key.flags.contains(CacheKeyFlags::DISABLE_HINTING));
    let wght = swash::Tag::from_be_bytes(*b"wght");
    if let Some(axis) = swash_font.variations().find_by_tag(wght) {
        let weight = f32::from(key.font_weight.0).clamp(axis.min_value(), axis.max_value());
        builder = builder.normalized_coords(swash_font.variations().normalized_coords([(wght, weight)]));
    }
    let mut scaler = builder.build();
    let transform = key
        .flags
        .contains(CacheKeyFlags::FAKE_ITALIC)
        .then(|| Transform::skew(Angle::from_degrees(14.0), Angle::from_degrees(0.0)));
    Render::new(&[Source::ColorOutline(0), Source::ColorBitmap(StrikeWith::BestFit), Source::Outline])
        .format(Format::Alpha)
        .offset(Vector::new(key.x_bin.as_float(), key.y_bin.as_float()))
        .transform(transform)
        .render(&mut scaler, key.glyph_id)
}

/// cov' = 255 * (cov / 255) ^ 0.8: edges a touch darker, solid stems unchanged.
fn coverage() -> &'static [u8; 256] {
    static LUT: std::sync::OnceLock<[u8; 256]> = std::sync::OnceLock::new();
    LUT.get_or_init(|| {
        let mut lut = [0u8; 256];
        for (i, v) in lut.iter_mut().enumerate() {
            *v = (255.0 * (i as f32 / 255.0).powf(0.8)).round() as u8;
        }
        lut
    })
}

#[inline(always)]
fn mul255(a: u32, b: u32) -> u32 {
    let t = a * b + 128;
    (t + (t >> 8)) >> 8
}

/// Source-over of a straight colour with coverage `sa` onto premultiplied RGBA8.
#[inline(always)]
fn blend(px: &mut [u8], r: u32, g: u32, b: u32, sa: u32) {
    let inv = 255 - sa;
    px[0] = (mul255(r, sa) + mul255(px[0] as u32, inv)) as u8;
    px[1] = (mul255(g, sa) + mul255(px[1] as u32, inv)) as u8;
    px[2] = (mul255(b, sa) + mul255(px[2] as u32, inv)) as u8;
    px[3] = (sa + mul255(px[3] as u32, inv)) as u8;
}

/// Blits a glyph image whose origin (the PhysicalGlyph x/y) is at (gx, gy).
pub fn blit(pm: &mut Pixmap, img: &SwashImage, gx: i32, gy: i32, color: Color, clip: Option<PxClip>) {
    let (pw, ph) = (pm.width() as i32, pm.height() as i32);
    let bounds = clip.unwrap_or(PxClip { x0: 0, y0: 0, x1: pw, y1: ph });
    let (bx0, by0, bx1, by1) = (bounds.x0.max(0), bounds.y0.max(0), bounds.x1.min(pw), bounds.y1.min(ph));
    let (w, h) = (img.placement.width as i32, img.placement.height as i32);
    let (x0, y0) = (gx + img.placement.left, gy - img.placement.top);
    let (cr, cg, cb, ca) = (color.r as u32, color.g as u32, color.b as u32, color.a as u32);
    let lut = coverage();
    let data = pm.data_mut();
    for row in 0..h {
        let y = y0 + row;
        if y < by0 || y >= by1 {
            continue;
        }
        for col in 0..w {
            let x = x0 + col;
            if x < bx0 || x >= bx1 {
                continue;
            }
            let i = ((y * pw + x) * 4) as usize;
            match img.content {
                SwashContent::Mask => {
                    let cov = lut[img.data[(row * w + col) as usize] as usize] as u32;
                    if cov != 0 {
                        blend(&mut data[i..i + 4], cr, cg, cb, mul255(cov, ca));
                    }
                }
                SwashContent::Color => {
                    let s = ((row * w + col) * 4) as usize;
                    let a = img.data[s + 3] as u32;
                    if a != 0 {
                        blend(
                            &mut data[i..i + 4],
                            img.data[s] as u32,
                            img.data[s + 1] as u32,
                            img.data[s + 2] as u32,
                            mul255(a, ca),
                        );
                    }
                }
                SwashContent::SubpixelMask => {}
            }
        }
    }
}
