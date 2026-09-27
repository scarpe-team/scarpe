//! Headless mode: the same Runtime drawing into offscreen pixmaps. Nothing ever appears on
//! screen.

use crate::protocol::{read_batches, Outbox};
use crate::runtime::{Options, Runtime, QUIT_GRACE};
use std::io::Read;
use std::sync::mpsc::{self, RecvTimeoutError};
use std::time::{Duration, Instant};

/// `exit_after` (`--exit-after`): when the time is up every canvas closes the way a window
/// does, so Ruby hears `closed` and quits cleanly.
pub fn run(opts: Options, exit_after: Option<Duration>) -> i32 {
    let trace = opts.trace;
    let mut rt = Runtime::new(opts, Outbox::stdout(trace));
    serve(&mut rt, std::io::stdin(), exit_after)
}

/// Answers every line `input` has until it ends, Ruby quits the last app or stdout closes.
/// Returns the exit code.
///
/// `input` is read on a thread of its own, as in a window. This thread blocks writing stdout
/// whenever Ruby is busy and not reading (Shoes-Spec's `advance` reads only at its next
/// request); meanwhile stdin keeps draining into memory, so Ruby never blocks writing to us
/// and neither side waits on the other for good.
pub fn serve(rt: &mut Runtime, input: impl Read + Send + 'static, exit_after: Option<Duration>) -> i32 {
    let (batches, arrived) = mpsc::channel();
    std::thread::spawn(move || read_batches(input, |batch| batches.send(batch).is_ok()));
    let mut closing_at = exit_after.map(|after| Instant::now() + after);
    let mut orphaned_at: Option<Instant> = None;
    loop {
        let due = closing_at.or(orphaned_at.map(|at| at + QUIT_GRACE));
        let batch = match due {
            None => arrived.recv().map_err(|_| RecvTimeoutError::Disconnected),
            Some(at) => arrived.recv_timeout(at.saturating_duration_since(Instant::now())),
        };
        match batch {
            Ok(lines) => {
                for line in lines {
                    rt.handle_line(&line);
                    rt.effects.clear();
                    rt.out.flush();
                    if rt.out.broken {
                        return 0;
                    }
                    if let Some(code) = rt.exit {
                        return code;
                    }
                }
            }
            Err(RecvTimeoutError::Timeout) if closing_at.take().is_some() => {
                let running: Vec<_> = rt.views.iter().filter(|(_, view)| view.running).map(|(app, _)| *app).collect();
                if running.is_empty() {
                    return 0;
                }
                for app in running {
                    rt.window_closed(app);
                }
                orphaned_at = Some(Instant::now());
            }
            // Ruby never answered `closed` with `quit`.
            Err(RecvTimeoutError::Timeout) => return 0,
            Err(RecvTimeoutError::Disconnected) => break,
        }
    }
    rt.out.flush();
    0
}
