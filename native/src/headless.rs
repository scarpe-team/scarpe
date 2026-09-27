//! Headless mode: the same Runtime drawing into offscreen pixmaps, reading
//! stdin on the main thread. Nothing ever appears on screen.

use crate::protocol::Outbox;
use crate::runtime::{Options, Runtime};
use std::io::BufRead;

pub fn run(opts: Options) -> i32 {
    let trace = opts.trace;
    let mut rt = Runtime::new(opts, Outbox::stdout(trace));
    let stdin = std::io::stdin();
    let mut reader = stdin.lock();
    let mut line = String::new();
    loop {
        line.clear();
        match reader.read_line(&mut line) {
            Ok(0) | Err(_) => break,
            Ok(_) => rt.handle_line(&line),
        }
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
