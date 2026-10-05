//! Numeric visual transitions sampled once per frame, independently of Ruby's
//! timers. Late frames use elapsed time; missed frames are never replayed.

use super::Runtime;
use crate::doc::Kind;
use crate::props::Id;
use crate::protocol::Outgoing;
use serde_json::{Map, Value};
use std::collections::BTreeMap;
use std::time::Instant;

const PROPERTIES: &[&str] = &["opacity", "displace_left", "displace_top", "fraction"];

struct Transition {
    id: Id,
    app: Id,
    from: Map<String, Value>,
    to: Map<String, Value>,
    duration: f64,
    started: Option<f64>,
    /// Keep a completed job cancellable until its final frame is presented.
    finished: bool,
}

pub(super) struct Motion {
    origin: Instant,
    frozen: Option<f64>,
    jobs: BTreeMap<u64, Transition>,
}

impl Default for Motion {
    fn default() -> Self {
        Self { origin: Instant::now(), frozen: None, jobs: BTreeMap::new() }
    }
}

impl Motion {
    fn now(&self) -> f64 { self.frozen.unwrap_or_else(|| self.origin.elapsed().as_secs_f64()) }

    pub(super) fn forget(&mut self, ids: &[Id]) {
        self.jobs.retain(|_, job| !ids.contains(&job.id) && !ids.contains(&job.app));
    }

    pub(super) fn presented(&mut self, app: Id) -> Vec<Outgoing> {
        let tokens: Vec<_> = self.jobs.iter().filter(|(_, job)| job.app == app && job.finished).map(|(token, _)| *token).collect();
        tokens.into_iter().map(|token| {
            let job = self.jobs.remove(&token).unwrap();
            Outgoing::TransitionEnd { token, id: job.id, props: job.to, completed: true }
        }).collect()
    }
}

impl Runtime {
    pub fn transitions_running(&self, app: Option<Id>) -> bool {
        !self.mid_batch && self.motion.frozen.is_none() && self.motion.jobs.values().any(|job|
            app.is_none_or(|app| job.app == app) && self.views.get(&job.app).is_some_and(|view| view.running))
    }

    fn transition_values(&self, id: Id) -> Map<String, Value> {
        let Some(node) = self.doc.get(id) else { return Map::new() };
        PROPERTIES.iter().filter(|key| **key != "fraction" || node.kind == Kind::Progress).map(|key| {
            let value = match *key {
                "opacity" => crate::paint::opacity(node),
                "fraction" => node.props.f32(key).unwrap_or(0.0).clamp(0.0, 1.0),
                _ => node.props.f32(key).filter(|v| v.is_finite()).unwrap_or(0.0),
            };
            (key.to_string(), Value::from(value))
        }).collect()
    }

    pub fn start_transition(&mut self, id: Id, token: u64, duration: f64, to: Map<String, Value>) -> Result<(), String> {
        let node = self.doc.get(id).ok_or("transition target does not exist")?;
        if node.kind.is_span() || matches!(node.kind, Kind::App | Kind::SubscriptionItem | Kind::Unknown(_)) {
            return Err("transition target must be a drawable in an app".into());
        }
        let app = self.doc.app_of(id).filter(|app| self.views.contains_key(app)).ok_or("transition target has no app")?;
        if self.motion.jobs.contains_key(&token) { return Err("transition token is already active".into()); }
        if !duration.is_finite() || duration < 0.0 || to.is_empty() {
            return Err("transition needs a finite nonnegative duration and properties".into());
        }
        for (key, value) in &to {
            let valid = value.as_f64().filter(|v| v.is_finite() && (*v as f32).is_finite());
            if !PROPERTIES.contains(&key.as_str()) || valid.is_none() ||
                (key == "fraction" && node.kind != Kind::Progress) ||
                (matches!(key.as_str(), "opacity" | "fraction") && !valid.is_some_and(|v| (0.0..=1.0).contains(&v))) {
                return Err(format!("unsupported transition property or value: {key}"));
            }
        }
        // Read the last sampled properties, including rendering defaults. Do not
        // extrapolate an old job to a value that has never been painted.
        let from = self.transition_values(id).into_iter().filter(|(key, _)| to.contains_key(key)).collect();
        self.cancel_overlapping_transitions(id, &to);
        let started = self.motion.frozen.filter(|_| self.views[&app].running);
        self.motion.jobs.insert(token, Transition { id, app, from, to, duration, started, finished: false });
        self.request_redraw(app);
        Ok(())
    }

    /// Return current values even if completion is already on its way to Ruby.
    /// Cancellation never advances time or jumps to the destination.
    pub fn cancel_transition(&mut self, id: Id, token: u64) -> Map<String, Value> {
        let props = self.transition_values(id);
        if self.motion.jobs.get(&token).is_some_and(|job| job.id == id) {
            let job = self.motion.jobs.remove(&token).unwrap();
            let values = props.iter().filter(|(key, _)| job.to.contains_key(*key)).map(|(k, v)| (k.clone(), v.clone())).collect();
            self.out.send(Outgoing::TransitionEnd { token, id, props: values, completed: false });
        }
        props
    }

    pub(super) fn cancel_overlapping_transitions(&mut self, id: Id, props: &Map<String, Value>) {
        let tokens: Vec<_> = self.motion.jobs.iter().filter(|(_, job)| job.id == id && job.to.keys().any(|key| props.contains_key(key)))
            .map(|(token, _)| *token).collect();
        for token in tokens { self.cancel_transition(id, token); }
    }

    /// Reparenting across apps cannot leave a job waiting on its former window.
    pub(super) fn cancel_reparented_transitions(&mut self) {
        let tokens: Vec<_> = self.motion.jobs.iter().filter(|(_, job)| self.doc.app_of(job.id) != Some(job.app))
            .map(|(token, job)| (*token, job.id)).collect();
        for (token, id) in tokens { self.cancel_transition(id, token); }
    }

    pub fn set_motion_clock(&mut self, at: Option<f64>) {
        if at.is_some_and(|v| !v.is_finite() || v < 0.0) { return; }
        let before = self.motion.now();
        let was_frozen = self.motion.frozen.is_some();
        if was_frozen && at.is_some_and(|v| v < before) { return; }
        self.motion.frozen = at;
        let after = self.motion.now();
        // Freeze/thaw changes the origin, preserving elapsed time. Travel while
        // already frozen advances it; sampling still waits for a frame.
        if at.is_none() || !was_frozen {
            for job in self.motion.jobs.values_mut() {
                if let Some(started) = &mut job.started { *started += after - before; }
            }
        }
    }

    pub fn advance_transitions(&mut self, app: Id) {
        if self.mid_batch || !self.views.get(&app).is_some_and(|view| view.running) { return; }
        let now = self.motion.now();
        let mut updates = Vec::new();
        for job in self.motion.jobs.values_mut().filter(|job| job.app == app && !job.finished) {
            let started = *job.started.get_or_insert(now);
            let elapsed = if job.duration == 0.0 { 1.0 } else { ((now - started) / job.duration).clamp(0.0, 1.0) };
            let amount = 1.0 - (1.0 - elapsed).powi(3);
            let props = job.to.iter().map(|(key, to)| {
                let from = job.from[key].as_f64().unwrap();
                let value = if elapsed == 1.0 { to.clone() } else { Value::from(from + (to.as_f64().unwrap() - from) * amount) };
                (key.clone(), value)
            }).collect();
            updates.push((job.id, props));
            job.finished = elapsed == 1.0;
        }
        for (id, props) in updates { self.set_props(id, props); }
        if self.views.get(&app).is_some_and(|view| view.layout_moved) { self.push_layout(app); }
    }
}
