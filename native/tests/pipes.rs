//! The real binary under the pipe pressure the Ruby shim puts on it. Nothing here opens a window.

use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc;
use std::time::Duration;

fn scarpe_native(args: &[&str]) -> Child {
    Command::new(env!("CARGO_BIN_EXE_scarpe-native"))
        .args(["--headless", "--fonts", "bundled"])
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .expect("scarpe-native runs")
}

fn send(stdin: &mut ChildStdin, message: Value) -> std::io::Result<()> {
    writeln!(stdin, "{message}")
}

/// An app of one oval, running.
fn oval_app(stdin: &mut ChildStdin) -> std::io::Result<()> {
    for message in [
        json!({"t": "hello", "v": 1, "pid": 1}),
        json!({"t": "create", "id": 2, "kind": "DocumentRoot", "parent": null, "props": {}}),
        json!({"t": "create", "id": 1, "kind": "App", "parent": null, "props": {"width": 400, "height": 300}, "doc_root": 2}),
        json!({"t": "create", "id": 3, "kind": "Oval", "parent": 2, "props": {"left": 0, "top": 0, "width": 10}}),
        json!({"t": "run", "app": 1}),
        json!({"t": "flush"}),
    ] {
        send(stdin, message)?;
    }
    Ok(())
}

/// Reads stdout until the reply to `req`, or gives up at `deadline`.
fn reply_to(out: impl std::io::Read + Send + 'static, req: u64, wait: Duration) -> Option<Value> {
    let (found, reply) = mpsc::channel();
    std::thread::spawn(move || {
        for line in BufReader::new(out).lines().map_while(Result::ok) {
            let Ok(message) = serde_json::from_str::<Value>(&line) else { continue };
            if message["t"] == "reply" && message["req"] == json!(req) {
                let _ = found.send(message);
                return;
            }
        }
    });
    reply.recv_timeout(wait).ok()
}

/// Shoes-Spec's `advance` under the frozen clock fires thousands of animation ticks, flushing
/// after each, and reads the child's output only at its next request. Every tick moves an oval,
/// so every flush makes Rust push a layout line back. Headless Rust once read stdin on the
/// thread that writes stdout: once Ruby had not read for a pipe's worth of layout lines, Rust
/// blocked writing, stopped reading, and Ruby blocked writing too, for good (the showcase
/// lane's repro: `advance 60` on an `animate(60)` oval never returned).
#[test]
fn a_writer_that_reads_only_at_the_end_is_answered() {
    let mut child = scarpe_native(&[]);
    let mut stdin = child.stdin.take().expect("stdin");
    let stdout = child.stdout.take().expect("stdout");
    let (wrote, written) = mpsc::channel();
    std::thread::spawn(move || {
        let writing = (|| {
            oval_app(&mut stdin)?;
            for frame in 0..5000 {
                send(&mut stdin, json!({"t": "props", "id": 3, "props": {"left": frame % 300, "top": frame % 200}}))?;
                send(&mut stdin, json!({"t": "flush"}))?;
            }
            send(&mut stdin, json!({"t": "req", "req": 1, "op": "ping"}))
        })();
        let _ = wrote.send(writing.is_ok());
        // Stays open until the test is done with the child.
        std::thread::sleep(Duration::from_secs(30));
        drop(stdin);
    });
    let finished = written.recv_timeout(Duration::from_secs(20));
    let reply = finished.is_ok().then(|| reply_to(stdout, 1, Duration::from_secs(20))).flatten();
    let _ = child.kill();
    let _ = child.wait();
    assert_eq!(finished, Ok(true), "Ruby's side finished writing 5000 frames without reading");
    assert_eq!(reply.map(|r| r["value"].clone()), Some(json!("pong")), "and the ping after them was answered");
}

/// `--exit-after` ends a headless run the way it ends a window: every running app is reported
/// `closed`, Ruby quits them, and the child exits 0. Headless used to call exit(0) mid-run,
/// which the shim reported as a crash (ChildDied) and the launcher exited 1.
#[test]
fn exit_after_closes_the_canvas_like_a_window() {
    let mut child = scarpe_native(&["--exit-after", "0.3"]);
    let mut stdin = child.stdin.take().expect("stdin");
    oval_app(&mut stdin).expect("the app is written");
    let (heard, closed) = mpsc::channel();
    let stdout = child.stdout.take().expect("stdout");
    std::thread::spawn(move || {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            if serde_json::from_str::<Value>(&line).is_ok_and(|m| m["t"] == "closed") {
                let _ = heard.send(line);
            }
        }
    });
    let said = closed.recv_timeout(Duration::from_secs(10));
    if said.is_ok() {
        send(&mut stdin, json!({"t": "quit", "app": null})).expect("quit is written");
    }
    let status = child.wait().expect("the child exits");
    assert_eq!(said.ok().map(|line| serde_json::from_str::<Value>(&line).unwrap()), Some(json!({"t": "closed", "app": 1})), "Rust said the app closed");
    assert_eq!(status.code(), Some(0), "and left cleanly once Ruby quit it");
}
