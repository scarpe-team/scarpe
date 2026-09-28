//! Where the Rust side's time goes, for native/PERF.md. The counters are always
//! on (a couple of clock reads per message and per frame); they are written to
//! `<dir>/rust.json` when the process ends, if SCARPE_NATIVE_STATS names a directory.

use serde_json::{json, Map, Value};
use std::path::PathBuf;
use std::sync::OnceLock;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

/// The work a frame is made of, in pipeline order.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Phase {
    /// JSON line -> message.
    Parse,
    /// A document change (create, props, destroy...) applied to the tree.
    Apply,
    Layout,
    Paint,
    /// Pixmap -> window surface, and the present itself.
    Present,
    /// A `req` answered (clicks, snapshots, layout dumps...).
    Req,
}

impl Phase {
    const ALL: [Phase; 6] = [Phase::Parse, Phase::Apply, Phase::Layout, Phase::Paint, Phase::Present, Phase::Req];

    fn name(self) -> &'static str {
        match self {
            Phase::Parse => "parse",
            Phase::Apply => "apply",
            Phase::Layout => "layout",
            Phase::Paint => "paint",
            Phase::Present => "present",
            Phase::Req => "req",
        }
    }
}

#[derive(Clone, Copy, Debug, Default)]
struct Tally {
    count: u64,
    total: Duration,
    max: Duration,
}

/// Keeps a long run's frame log bounded; a minute at 120 fps fits.
const MAX_SAMPLES: usize = 10_000;

/// When this process started, as early as anyone asked (window::run asks first).
pub fn process_started() -> (Instant, SystemTime) {
    static STARTED: OnceLock<(Instant, SystemTime)> = OnceLock::new();
    *STARTED.get_or_init(|| (Instant::now(), SystemTime::now()))
}

pub struct Stats {
    dir: Option<PathBuf>,
    started: Instant,
    started_unix: f64,
    tallies: [Tally; 6],
    /// Work done since the last frame was shown, per phase.
    since_frame: [Duration; 6],
    /// Milestones (first layout, first present...), seconds since start, first time only.
    marks: Vec<(&'static str, f64)>,
    /// One row per frame shown: seconds since start, then ms per phase since the frame before.
    frames: Vec<[f64; 7]>,
    /// Input that has not been drawn yet.
    input_at: Option<Instant>,
    /// Input -> the frame that showed it, in ms.
    input_latency: Vec<f64>,
    counters: std::collections::BTreeMap<&'static str, u64>,
}

impl Default for Stats {
    fn default() -> Self {
        Stats::new(std::env::var_os("SCARPE_NATIVE_STATS").filter(|d| !d.is_empty()).map(PathBuf::from))
    }
}

impl Stats {
    pub fn new(dir: Option<PathBuf>) -> Self {
        let (started, wall) = process_started();
        let started_unix = wall.duration_since(UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0);
        Stats {
            dir,
            started,
            started_unix,
            tallies: [Tally::default(); 6],
            since_frame: [Duration::ZERO; 6],
            marks: vec![("main", 0.0)],
            frames: Vec::new(),
            input_at: None,
            input_latency: Vec::new(),
            counters: Default::default(),
        }
    }

    fn since_start(&self, at: Instant) -> f64 {
        at.saturating_duration_since(self.started).as_secs_f64()
    }

    pub fn add(&mut self, phase: Phase, took: Duration) {
        let tally = &mut self.tallies[phase as usize];
        tally.count += 1;
        tally.total += took;
        tally.max = tally.max.max(took);
        self.since_frame[phase as usize] += took;
    }

    /// Adds the time since `from` to `phase`.
    pub fn since(&mut self, phase: Phase, from: Instant) {
        self.add(phase, from.elapsed());
    }

    /// Adds to a named counter (repaints in part and in full, pixels repainted...).
    pub fn count(&mut self, name: &'static str, by: u64) {
        *self.counters.entry(name).or_insert(0) += by;
    }

    pub fn counter(&self, name: &str) -> u64 {
        self.counters.get(name).copied().unwrap_or(0)
    }

    /// Records a milestone the first time it happens.
    pub fn mark(&mut self, name: &'static str) {
        self.mark_at(name, Instant::now());
    }

    /// Records a milestone that happened at `at` (on another thread, say).
    pub fn mark_at(&mut self, name: &'static str, at: Instant) {
        if !self.marks.iter().any(|(n, _)| *n == name) {
            let at = self.since_start(at);
            self.marks.push((name, at));
        }
    }

    /// Input arrived; the next frame shown is the one that answers it.
    pub fn input(&mut self) {
        self.input_at.get_or_insert_with(Instant::now);
    }

    /// A frame reached the screen (or, headless, a picture was painted).
    pub fn frame_shown(&mut self) {
        let now = Instant::now();
        let work = std::mem::take(&mut self.since_frame);
        if self.frames.len() < MAX_SAMPLES {
            let mut row = [self.since_start(now), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
            for (cell, took) in row[1..].iter_mut().zip(work) {
                *cell = took.as_secs_f64() * 1000.0;
            }
            self.frames.push(row);
        }
        if let Some(at) = self.input_at.take() {
            if self.input_latency.len() < MAX_SAMPLES {
                self.input_latency.push(now.duration_since(at).as_secs_f64() * 1000.0);
            }
        }
    }

    pub fn to_json(&self) -> Value {
        let ms = |d: Duration| (d.as_secs_f64() * 1_000_000.0).round() / 1000.0;
        let phases: Map<String, Value> = Phase::ALL
            .iter()
            .map(|p| {
                let t = self.tallies[*p as usize];
                (p.name().to_string(), json!({"n": t.count, "total_ms": ms(t.total), "max_ms": ms(t.max)}))
            })
            .collect();
        let marks: Map<String, Value> = self.marks.iter().map(|(n, at)| (n.to_string(), json!(at))).collect();
        json!({
            "pid": std::process::id(),
            "started_unix": self.started_unix,
            "uptime": self.since_start(Instant::now()),
            "marks": marks,
            "phases": phases,
            "frame_columns": ["at", "parse", "apply", "layout", "paint", "present", "req"],
            "frames": self.frames,
            "input_latency_ms": self.input_latency,
            "counters": self.counters,
        })
    }

    /// Writes `<dir>/rust.json` if SCARPE_NATIVE_STATS asked for it.
    pub fn write(&self) {
        let Some(dir) = &self.dir else { return };
        let _ = std::fs::create_dir_all(dir);
        let path = dir.join("rust.json");
        if let Err(e) = std::fs::write(&path, self.to_json().to_string()) {
            eprintln!("[scarpe-native] could not write {}: {e}", path.display());
        }
    }
}

/// Written when the Runtime goes away, which is how both the window and the headless loop end.
impl Drop for Stats {
    fn drop(&mut self) {
        self.write();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tallies_phases_and_marks_milestones_once() {
        let mut stats = Stats::new(None);
        stats.add(Phase::Paint, Duration::from_millis(3));
        stats.add(Phase::Paint, Duration::from_millis(5));
        stats.mark("first_paint");
        stats.mark("first_paint");
        let json = stats.to_json();
        assert_eq!(json["phases"]["paint"]["n"], 2);
        assert_eq!(json["phases"]["paint"]["total_ms"], 8.0);
        assert_eq!(json["phases"]["paint"]["max_ms"], 5.0);
        assert_eq!(json["marks"].as_object().unwrap().keys().filter(|k| *k == "first_paint").count(), 1);
    }

    #[test]
    fn input_latency_ends_at_the_next_frame_shown() {
        let mut stats = Stats::new(None);
        stats.frame_shown();
        stats.input();
        stats.input(); // a second key before the frame: latency counts from the first
        stats.frame_shown();
        stats.frame_shown();
        let json = stats.to_json();
        assert_eq!(json["frames"].as_array().unwrap().len(), 3);
        assert_eq!(json["input_latency_ms"].as_array().unwrap().len(), 1);
    }

    #[test]
    fn each_frame_row_holds_the_work_done_since_the_frame_before() {
        let mut stats = Stats::new(None);
        stats.add(Phase::Paint, Duration::from_millis(4));
        stats.add(Phase::Present, Duration::from_millis(2));
        stats.frame_shown();
        stats.add(Phase::Layout, Duration::from_millis(1));
        stats.frame_shown();
        let frames = stats.to_json()["frames"].clone();
        assert_eq!(frames[0][4], 4.0);
        assert_eq!(frames[0][5], 2.0);
        assert_eq!(frames[1][3], 1.0);
        assert_eq!(frames[1][4], 0.0);
    }

    #[test]
    fn writes_rust_json_into_the_stats_directory() {
        let dir = std::env::temp_dir().join(format!("scarpe-native-stats-{}", std::process::id()));
        let stats = Stats::new(Some(dir.clone()));
        drop(stats);
        let written: Value = serde_json::from_str(&std::fs::read_to_string(dir.join("rust.json")).unwrap()).unwrap();
        assert_eq!(written["pid"], std::process::id());
        let _ = std::fs::remove_dir_all(dir);
    }
}
