//! Headless mode: the same Runtime drawing into offscreen pixmaps, reading
//! stdin on the main thread. Nothing ever appears on screen.

use crate::protocol::{read_line_lossy, Outbox};
use crate::runtime::{Options, Runtime};
use std::io::BufRead;

pub fn run(opts: Options) -> i32 {
    let trace = opts.trace;
    let mut rt = Runtime::new(opts, Outbox::stdout(trace));
    serve(&mut rt, std::io::stdin().lock())
}

/// Answers every line `input` has until it ends, Ruby quits the last app or stdout closes.
/// Returns the exit code.
pub fn serve(rt: &mut Runtime, mut input: impl BufRead) -> i32 {
    let mut bytes = Vec::new();
    while let Some(line) = read_line_lossy(&mut input, &mut bytes) {
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
