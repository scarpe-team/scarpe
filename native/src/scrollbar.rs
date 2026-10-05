//! Overlay scrollbar geometry shared by painting and pointer input.

use crate::layout::{Layout, Rect};
use crate::props::Id;

#[derive(Clone, Copy)]
pub(crate) struct Geometry {
    /// The wider, invisible target around the painted thumb.
    pub track: Rect,
    pub thumb: Rect,
    pub clip: Rect,
    max_top: f32,
}

impl Geometry {
    pub fn for_slot(layout: &Layout, id: Id) -> Option<Self> {
        let s = layout.scrollers.get(&id)?;
        let v = s.viewport;
        if s.max_top() <= 0.5 || v.h <= 4.0 || v.w <= 0.0 {
            return None;
        }
        let track = Rect::new(v.right() - v.w.min(12.0), v.y + 2.0, v.w.min(12.0), v.h - 4.0);
        let height = (track.h * v.h / s.content_height).max(24.0).min(track.h);
        let y = track.y + (track.h - height) * (s.top / s.max_top());
        let thumb = Rect::new(v.right() - 8.0, y, 5.0, height);
        let clip = v.intersect(&layout.boxes.get(&id)?.clip.unwrap_or(v))?
            .intersect(&Rect::new(0.0, 0.0, layout.size.0, layout.size.1))?;
        track.intersect(&clip)?;
        Some(Self { track, thumb, clip, max_top: s.max_top() })
    }

    pub fn contains(&self, x: f32, y: f32) -> bool {
        self.track.contains(x, y) && self.clip.contains(x, y)
    }

    pub fn travel(&self) -> f32 {
        self.track.h - self.thumb.h
    }

    pub fn top_at(&self, y: f32, grab: f32) -> f32 {
        ((y - self.track.y - grab.min(self.thumb.h)) / self.travel()).clamp(0.0, 1.0) * self.max_top
    }
}

#[derive(Clone, Copy)]
pub(crate) struct Drag {
    pub id: Id,
    pub grab: f32,
}

/// A track press, or a canceled drag, still owns the eventual primary release.
#[derive(Clone, Copy)]
pub(crate) struct Press {
    pub drag: Option<Drag>,
}
