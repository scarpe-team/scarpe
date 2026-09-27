//! Headless mode: the same Runtime drawing into offscreen pixmaps. Nothing ever appears on
//! screen.

use crate::protocol::{read_batches, Outbox};
use crate::runtime::{Options, Runtime};
use std::io::Read;
use std::sync::mpsc;

pub fn run(opts: Options) -> i32 {
    let trace = opts.trace;
    let mut rt = Runtime::new(opts, Outbox::stdout(trace));
    serve(&mut rt, std::io::stdin())
}

/// Answers every line `input` has until it ends, Ruby quits the last app or stdout closes.
/// Returns the exit code.
///
/// `input` is read on a thread of its own, as in a window. This thread blocks writing stdout
/// whenever Ruby is busy and not reading (Shoes-Spec's `advance` reads only at its next
/// request); meanwhile stdin keeps draining into memory, so Ruby never blocks writing to us
/// and neither side waits on the other for good.
pub fn serve(rt: &mut Runtime, input: impl Read + Send + 'static) -> i32 {
    let (batches, arrived) = mpsc::channel();
    std::thread::spawn(move || read_batches(input, |batch| batches.send(batch).is_ok()));
    for line in arrived.into_iter().flatten() {
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
    rt.out.flush();
    0
}
