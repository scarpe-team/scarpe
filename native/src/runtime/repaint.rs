//! Repainting a window's frame in part (paint::damage), and SCARPE_NATIVE_DAMAGE=check, which
//! verifies every partial repaint against full paints, in a window or headless.

use super::stats::Phase;
use super::{AppView, Runtime};
use crate::paint::damage::{self, FrameMemory, Repaint};
use crate::paint::{self, Scene};
use crate::props::Id;
use std::time::Instant;
use tiny_skia::Pixmap;

/// SCARPE_NATIVE_DAMAGE: `off` paints every frame in full; `check` repaints partially and
/// compares with a full paint each time, reporting any pixel that differs (paint::damage).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DamageMode {
    On,
    Off,
    Check,
}

impl DamageMode {
    pub fn from_env() -> Self {
        match std::env::var("SCARPE_NATIVE_DAMAGE").as_deref() {
            Ok("off") => DamageMode::Off,
            Ok("check") => DamageMode::Check,
            _ => DamageMode::On,
        }
    }
}

impl Runtime {
    /// Brings a window's last frame up to date, repainting only what changed since `memory`
    /// last saw it (paint::damage). The view is clean afterwards.
    pub fn repaint(&mut self, app: Id, frame: &mut Pixmap, scale: f32, memory: &mut FrameMemory) -> Repaint {
        if self.damage == DamageMode::Off {
            memory.forget();
            self.render(app, frame, scale);
            return Repaint::Everything;
        }
        self.ensure_layout(app);
        let started = Instant::now();
        let Some(view) = self.views.get_mut(&app) else { return Repaint::Nothing };
        let AppView { layout, ui, frames, dirty, .. } = view;
        let Some(layout) = layout.as_ref() else { return Repaint::Nothing };
        let mut scene = Scene { doc: &self.doc, layout, view: ui, text: &mut self.text, images: &mut self.images };
        let plan = damage::repaint(&mut scene, frame, scale, memory, &self.revisions);
        *frames += 1;
        *dirty = false;
        self.stats.since(Phase::Paint, started);
        self.stats.mark("first_paint");
        self.count_resampled_images();
        self.count_repaint(&plan, (frame.width(), frame.height()));
        if self.damage == DamageMode::Check {
            self.check_repaint(app, &plan, frame, scale);
        }
        plan
    }

    /// SCARPE_NATIVE_DAMAGE=check: verifies a repaint against full paints, says so on stderr
    /// when it went wrong, and puts the full paint on screen instead.
    fn check_repaint(&mut self, app: Id, plan: &Repaint, frame: &mut Pixmap, scale: f32) {
        let Some(full) = self.full_picture(app, scale) else { return };
        let before = self.last_full.remove(&app).filter(|b| b.width() == full.width() && b.height() == full.height());
        if let Some(before) = before {
            self.stats.count("damage_checks", 1);
            if let Err(problem) = self.verify_repaint(app, plan, frame, scale, &full, &before) {
                eprintln!("[scarpe-native] damage check: {problem}");
                self.stats.count("damage_mismatches", 1);
                frame.data_mut().copy_from_slice(full.data());
            }
        }
        self.last_full.insert(app, full);
    }

    /// paint::damage::verify for one app's current scene.
    pub fn verify_repaint(&mut self, app: Id, plan: &Repaint, frame: &Pixmap, scale: f32, full: &Pixmap, before: &Pixmap) -> Result<(), String> {
        let Some(view) = self.views.get_mut(&app) else { return Ok(()) };
        let AppView { layout, ui, .. } = view;
        let Some(layout) = layout.as_ref() else { return Ok(()) };
        let mut scene = Scene { doc: &self.doc, layout, view: ui, text: &mut self.text, images: &mut self.images };
        damage::verify(&mut scene, plan, frame, scale, full, before)
    }

    fn count_repaint(&mut self, plan: &Repaint, frame: (u32, u32)) {
        let kind = match plan {
            Repaint::Nothing => "repaints_of_nothing",
            Repaint::Rects(_) => "repaints_in_part",
            Repaint::Everything => "repaints_in_full",
        };
        self.stats.count(kind, 1);
        self.stats.count("repainted_pixels", plan.pixels(frame));
    }

    /// Headless SCARPE_NATIVE_DAMAGE=check: repaints a kept frame in part, as a window would,
    /// and verifies it whenever a picture is painted.
    pub(super) fn check_partial_repaint(&mut self, app: Id, full: &Pixmap, scale: f32) {
        let (mut frame, mut memory) = match self.checked_frames.remove(&app) {
            Some(kept) if kept.0.width() == full.width() && kept.0.height() == full.height() => kept,
            _ => (full.clone(), FrameMemory::default()),
        };
        let plan = {
            let Some(view) = self.views.get_mut(&app) else { return };
            let AppView { layout, ui, .. } = view;
            let Some(layout) = layout.as_ref() else { return };
            let mut scene = Scene { doc: &self.doc, layout, view: ui, text: &mut self.text, images: &mut self.images };
            damage::repaint(&mut scene, &mut frame, scale, &mut memory, &self.revisions)
        };
        self.count_repaint(&plan, (frame.width(), frame.height()));
        self.check_repaint(app, &plan, &mut frame, scale);
        self.checked_frames.insert(app, (frame, memory));
    }

    /// A full paint that leaves the view's frame count alone.
    fn full_picture(&mut self, app: Id, scale: f32) -> Option<Pixmap> {
        let view = self.views.get_mut(&app)?;
        let (w, h) = crate::limits::picture_size(view.size, scale)?;
        let mut pm = Pixmap::new(w, h)?;
        let AppView { layout, ui, .. } = view;
        let mut scene = Scene { doc: &self.doc, layout: layout.as_ref()?, view: ui, text: &mut self.text, images: &mut self.images };
        paint::paint(&mut scene, &mut pm, scale);
        Some(pm)
    }

}
