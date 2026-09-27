//! tooltip: the bubble a drawable's `tooltip:` text shows once the pointer rests on it,
//! like Shoes 3.3's native control tooltips (s3_gtk.c:1664, s3_cocoa.m:1427). Lacci
//! gives every drawable the style. A press hides it until the pointer moves on.

use crate::doc::Doc;
use crate::layout::Rect;
use crate::paint::text::draw_shaped;
use crate::paint::Canvas;
use crate::props::Id;
use crate::style::Color;
use crate::text::rich::{TextStyle, INK};
use crate::text::{RichText, TextEngine};
use std::time::{Duration, Instant};

/// How long the pointer rests before a window shows the bubble.
pub const DELAY: Duration = Duration::from_millis(600);
const TEXT_SIZE: f32 = 12.0;
const MAX_WIDTH: f32 = 280.0;
const PAD: (f32, f32) = (8.0, 5.0);

#[derive(Clone, Debug, PartialEq)]
pub struct Tooltip {
    pub owner: Id,
    pub text: String,
    /// Where the pointer arrived; the bubble hangs below it.
    pub at: (f32, f32),
    pub due: Instant,
    pub dismissed: bool,
    /// Drawn at least once, so a window stops waking up for it.
    pub shown: bool,
}

impl Tooltip {
    pub fn new(owner: Id, text: String, at: (f32, f32), due: Instant) -> Self {
        Tooltip { owner, text, at, due, dismissed: false, shown: false }
    }

    pub fn visible(&self, now: Instant) -> bool {
        !self.dismissed && now >= self.due
    }

    /// When a window must wake to draw it, if it is still to come.
    pub fn pending(&self) -> Option<Instant> {
        (!self.dismissed && !self.shown).then_some(self.due)
    }
}

/// The innermost drawable under the pointer with tooltip text, and that text.
pub fn owner(doc: &Doc, hover_chain: &[Id]) -> Option<(Id, String)> {
    hover_chain.iter().find_map(|&id| {
        let text = doc.get(id)?.props.text("tooltip")?;
        (!text.trim().is_empty()).then_some((id, text))
    })
}

pub fn paint(canvas: &mut Canvas, tip: Option<&mut Tooltip>, text: &mut TextEngine, window: (f32, f32)) {
    let Some(tip) = tip.filter(|t| t.visible(Instant::now())) else { return };
    tip.shown = true;
    let shaped = text.shape(&RichText::plain(&tip.text, TextStyle::new(TEXT_SIZE, INK)), Some(MAX_WIDTH));
    let (w, h) = (shaped.width.ceil() + PAD.0 * 2.0, shaped.height.ceil() + PAD.1 * 2.0);
    let r = bubble_rect(tip.at, (w, h), window);
    for (grow, alpha) in [(3.0, 10), (1.0, 22)] {
        canvas.fill_rounded(Rect::new(r.x - grow, r.y - grow + 2.0, r.w + grow * 2.0, r.h + grow * 2.0), 5.0 + grow, Color::rgba(0, 0, 0, alpha), None);
    }
    canvas.fill_rounded(r, 5.0, Color::rgb(0xfb, 0xfb, 0xf6), None);
    canvas.stroke_rounded(r, 5.0, Color::rgba(0, 0, 0, 46), 1.0, None);
    draw_shaped(canvas, text, &shaped, r.x + PAD.0, r.y + PAD.1, Some(r), None);
}

/// Below and right of the pointer, kept inside the window; above it when there is no room below.
fn bubble_rect(at: (f32, f32), size: (f32, f32), window: (f32, f32)) -> Rect {
    let x = (at.0 + 4.0).min(window.0 - size.0 - 4.0).max(4.0);
    let below = at.1 + 22.0;
    let y = if below + size.1 <= window.1 - 4.0 { below } else { (at.1 - size.1 - 8.0).max(4.0) };
    Rect::new(x, y, size.0, size.1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_window_waits_before_showing_it() {
        let now = Instant::now();
        let tip = Tooltip::new(3, "Save".into(), (10.0, 10.0), now + DELAY);
        assert!(!tip.visible(now));
        assert_eq!(tip.pending(), Some(now + DELAY));
        assert!(tip.visible(now + DELAY));
    }

    #[test]
    fn the_bubble_stays_in_the_window() {
        assert_eq!(bubble_rect((10.0, 10.0), (100.0, 20.0), (300.0, 200.0)), Rect::new(14.0, 32.0, 100.0, 20.0));
        let r = bubble_rect((290.0, 190.0), (100.0, 20.0), (300.0, 200.0));
        assert_eq!((r.right(), r.bottom()), (296.0, 182.0), "pushed left, and up to 8 px above the pointer");
    }
}
