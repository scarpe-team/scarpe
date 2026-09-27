//! No more frames than the display can show (native/PERF.md). An app that flushed 240 times a
//! second on a 120 Hz screen painted and presented twice what anyone could see. A frame that
//! would make three within two refreshes now waits, and whatever changes arrive meanwhile go
//! into it. A lone frame (a keystroke, a click) never waits: pacing only reins in a flood.

use std::time::{Duration, Instant};

/// Paces one window's frames to its display's refresh rate.
#[derive(Clone, Debug)]
pub struct Pacing {
    interval: Duration,
    /// When the last two frames started, newest first.
    started: [Option<Instant>; 2],
    /// A frame is wanted but waits until then.
    due: Option<Instant>,
}

/// Displays that do not say how fast they refresh are paced as ProMotion ones.
const UNKNOWN_REFRESH_HZ: f64 = 120.0;

impl Pacing {
    /// `refresh_millihertz` as winit's MonitorHandle reports it.
    pub fn new(refresh_millihertz: Option<u32>) -> Self {
        let hz = refresh_millihertz.filter(|m| *m > 0).map_or(UNKNOWN_REFRESH_HZ, |m| m as f64 / 1000.0);
        Pacing { interval: Duration::from_secs_f64(1.0 / hz), started: [None, None], due: None }
    }

    /// A frame is wanted at `now`: true when it may be drawn at once; otherwise it is `due`
    /// later and the event loop should wake then.
    pub fn want_frame(&mut self, now: Instant) -> bool {
        match self.started[1] {
            Some(before_last) if now < before_last + 2 * self.interval => {
                self.due.get_or_insert(before_last + 2 * self.interval);
                false
            }
            _ => true,
        }
    }

    /// Whether the frame that waited may be drawn now.
    pub fn take_due(&mut self, now: Instant) -> bool {
        if self.due.is_some_and(|due| now >= due) {
            self.due = None;
            return true;
        }
        false
    }

    pub fn due(&self) -> Option<Instant> {
        self.due
    }

    /// A frame started drawing.
    pub fn drawing(&mut self, now: Instant) {
        self.started = [Some(now), self.started[0]];
        self.due = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ms(t0: Instant, ms: u64) -> Instant {
        t0 + Duration::from_millis(ms)
    }

    #[test]
    fn a_flood_of_frames_is_held_to_the_refresh_rate() {
        let mut pacing = Pacing::new(Some(60_000));
        let t0 = Instant::now();
        assert!(pacing.want_frame(t0));
        pacing.drawing(t0);
        assert!(pacing.want_frame(ms(t0, 4)), "a second frame soon after is fine");
        pacing.drawing(ms(t0, 4));
        assert!(!pacing.want_frame(ms(t0, 8)), "a third within two refreshes waits");
        assert!(!pacing.want_frame(ms(t0, 9)), "asking again changes nothing");
        let due = pacing.due().expect("the frame is due later");
        assert!(due > ms(t0, 33) && due <= ms(t0, 34), "two refreshes after the first");
        assert!(!pacing.take_due(ms(t0, 20)));
        assert!(pacing.take_due(due));
        assert!(pacing.due().is_none());
    }

    #[test]
    fn a_lone_frame_after_a_steady_animation_goes_at_once() {
        let mut pacing = Pacing::new(Some(120_000));
        let t0 = Instant::now();
        pacing.drawing(t0);
        pacing.drawing(ms(t0, 17));
        assert!(pacing.want_frame(ms(t0, 19)), "a keystroke just after a 60 fps frame");
        assert!(pacing.due().is_none());
    }

    #[test]
    fn an_unknown_refresh_rate_is_paced_as_a_promotion_display() {
        let mut pacing = Pacing::new(None);
        let t0 = Instant::now();
        pacing.drawing(t0);
        pacing.drawing(ms(t0, 1));
        assert!(!pacing.want_frame(ms(t0, 16)));
        assert!(pacing.want_frame(ms(t0, 17)));
    }
}
