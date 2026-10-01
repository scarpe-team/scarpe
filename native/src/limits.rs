//! Bounds on what input from Ruby can make Rust allocate or compute. Everything on stdin is
//! untrusted: a size of 1e9, a NaN scale or a chain of ten thousand slots is clamped or
//! refused here, never handed to an allocator or the stack (DESIGN 12, robustness).

use std::ops::RangeInclusive;

/// The widest or tallest a window or canvas can be, in logical px. macOS caps windows at
/// 10,000 points, and no screen is larger.
pub const MAX_SIDE: f32 = 10_000.0;

/// The most pixels one offscreen picture may hold: 64 megapixels, 256 MB of RGBA.
pub const MAX_PICTURE_PIXELS: u64 = 1 << 26;

/// Scales a snapshot or a headless canvas may be painted at.
pub const SCALES: RangeInclusive<f32> = 0.1..=8.0;

/// How deep a slot tree is laid out. Nodes further down are left out of the layout, so they
/// neither draw nor take clicks; no Shoes app nests anywhere near this deep, and the stack
/// the layout recursion needs stays small.
pub const MAX_DEPTH: usize = 128;

/// How deep masks may nest while painting: each level holds two layers the size of the frame.
pub const MAX_MASK_DEPTH: usize = 4;

/// Frames one `frames` request can wait for.
pub const MAX_FRAMES: u32 = 1_000;

/// An image file larger than this is not decoded.
pub const MAX_IMAGE_BYTES: u64 = 256 * 1024 * 1024;

/// The widest or tallest image that is decoded, in pixels.
pub const MAX_IMAGE_SIDE: u32 = 16_384;

/// Text spans no text names any more that are kept in case Lacci names one again (Doc's span
/// names): a few megabytes at most.
pub const LOOSE_SPANS: usize = 10_000;

/// The largest font file `font` registers.
pub const MAX_FONT_BYTES: u64 = 256 * 1024 * 1024;

/// Whether `path` is a plain file of at most `max_bytes` that can be read to its end: not a
/// directory, a FIFO (which blocks whoever opens it) or a device (/dev/zero never ends).
pub fn readable_file(path: &std::path::Path, max_bytes: u64) -> bool {
    std::fs::metadata(path).is_ok_and(|meta| meta.is_file() && meta.len() <= max_bytes)
}

/// A window or canvas side: finite and positive, at most MAX_SIDE. None for a size that
/// cannot be one (NaN, zero, negative), so the caller keeps what it had.
pub fn side(v: f32) -> Option<f32> {
    (v.is_finite() && v >= 1.0).then(|| v.min(MAX_SIDE))
}

/// The pixel size of a picture of a `size` canvas at `scale`, when it is small enough to make.
pub fn picture_size(size: (f32, f32), scale: f32) -> Option<(u32, u32)> {
    if !SCALES.contains(&scale) {
        return None;
    }
    let (w, h) = ((size.0 * scale).ceil().max(1.0), (size.1 * scale).ceil().max(1.0));
    let fits = w.is_finite() && h.is_finite() && (w as u64).saturating_mul(h as u64) <= MAX_PICTURE_PIXELS;
    fits.then_some((w as u32, h as u32))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sides_are_positive_finite_and_capped() {
        assert_eq!(side(480.0), Some(480.0));
        assert_eq!(side(1e9), Some(MAX_SIDE));
        assert_eq!(side(f32::INFINITY), None);
        assert_eq!(side(f32::NAN), None);
        assert_eq!(side(0.0), None);
        assert_eq!(side(-40.0), None);
    }

    #[test]
    fn pictures_stay_small_enough_to_allocate() {
        assert_eq!(picture_size((600.0, 500.0), 2.0), Some((1200, 1000)));
        assert_eq!(picture_size((MAX_SIDE, MAX_SIDE), 1.0), None, "100 megapixels is too many");
        assert_eq!(picture_size((600.0, 500.0), 1e6), None);
        assert_eq!(picture_size((600.0, 500.0), f32::NAN), None);
        assert_eq!(picture_size((600.0, 500.0), -1.0), None);
        assert_eq!(picture_size((0.0, 0.0), 1.0), Some((1, 1)));
    }
}
