//! A headless Runtime you can feed NDJSON and read messages back from.
#![allow(dead_code)]

use scarpe_native::protocol::Outbox;
use scarpe_native::runtime::{Options, Runtime};
use scarpe_native::text::FontMode;
use serde_json::{json, Value};

pub struct Harness {
    pub rt: Runtime,
    next_req: u64,
}

impl Harness {
    pub fn new() -> Self {
        let opts = Options { headless: true, scale: Some(1.0), fonts: FontMode::Bundled, trace: false };
        Harness { rt: Runtime::new(opts, Outbox::capture()), next_req: 1000 }
    }

    /// Feeds NDJSON lines and returns every message Rust sent in response.
    pub fn feed(&mut self, ndjson: &str) -> Vec<Value> {
        for line in ndjson.lines() {
            self.rt.handle_line(line);
        }
        self.rt.out.take_captured()
    }

    /// Just the app from a fixture: no requests, no quit.
    pub fn scene(&mut self, name: &str) -> Vec<Value> {
        self.fixture_lines(name, |t| t != "quit" && t != "req")
    }

    /// The whole fixture, requests included, except its final quit.
    pub fn fixture(&mut self, name: &str) -> Vec<Value> {
        self.fixture_lines(name, |t| t != "quit")
    }

    fn fixture_lines(&mut self, name: &str, keep: impl Fn(&str) -> bool) -> Vec<Value> {
        let text = std::fs::read_to_string(format!("tests/fixtures/{name}.ndjson")).expect("fixture");
        let lines: String = text
            .lines()
            .filter(|l| serde_json::from_str::<Value>(l).ok().is_some_and(|v| keep(v["t"].as_str().unwrap_or(""))))
            .map(|l| format!("{l}\n"))
            .collect();
        self.feed(&lines)
    }

    /// Sends one req and returns (events before the reply, the reply).
    pub fn req(&mut self, mut op: Value) -> (Vec<Value>, Value) {
        self.next_req += 1;
        let req = self.next_req;
        op["t"] = json!("req");
        op["req"] = json!(req);
        let msgs = self.feed(&op.to_string());
        let at = msgs.iter().position(|m| m["t"] == "reply" && m["req"] == json!(req)).expect("a reply");
        (msgs[..at].to_vec(), msgs[at].clone())
    }

    pub fn value(&mut self, op: Value) -> Value {
        let (_, reply) = self.req(op);
        assert_eq!(reply["error"], Value::Null, "{reply}");
        reply["value"].clone()
    }

    pub fn layout(&mut self) -> Vec<Value> {
        self.value(json!({"op": "layout"})).as_array().cloned().unwrap_or_default()
    }

    pub fn node(&mut self, pred: impl Fn(&Value) -> bool) -> Value {
        self.layout().into_iter().find(|n| pred(n)).expect("a matching node")
    }

    pub fn id_of_kind(&mut self, kind: &str) -> i64 {
        self.node(|n| n["kind"] == kind)["id"].as_i64().unwrap()
    }
}

/// Only the `event` messages, as (name, target, args).
pub fn events(msgs: &[Value]) -> Vec<(String, Value, Value)> {
    msgs.iter()
        .filter(|m| m["t"] == "event")
        .map(|m| (m["name"].as_str().unwrap().to_string(), m["target"].clone(), m["args"].clone()))
        .collect()
}

pub fn named<'a>(evs: &'a [(String, Value, Value)], name: &str) -> Vec<&'a (String, Value, Value)> {
    evs.iter().filter(|e| e.0 == name).collect()
}

/// A tiny app: DocumentRoot 2, App 1 (w x h), then `body` lines.
pub fn app(w: u32, h: u32, body: &[Value]) -> String {
    let mut lines = vec![
        json!({"t":"hello","v":1,"pid":1}),
        json!({"t":"create","id":2,"kind":"DocumentRoot","parent":null,"props":{"width":"100%","height":"100%"}}),
        json!({"t":"create","id":1,"kind":"App","parent":null,"props":{"width":w,"height":h,"title":"test"},"doc_root":2}),
    ];
    lines.extend(body.iter().cloned());
    lines.push(json!({"t":"run","app":1}));
    lines.push(json!({"t":"flush"}));
    lines.iter().map(|l| format!("{l}\n")).collect()
}

pub fn create(id: i64, kind: &str, parent: i64, props: Value) -> Value {
    json!({"t":"create","id":id,"kind":kind,"parent":parent,"index":null,"widget":false,"props":props})
}

/// A scratch PNG path for snapshot requests, one per test process.
pub fn snapshot_path() -> String {
    std::env::temp_dir().join(format!("scarpe-native-test-{}.png", std::process::id())).display().to_string()
}

/// The display still answers after swallowing whatever came before.
pub fn still_answers(h: &mut Harness) {
    let (_, reply) = h.req(json!({"op": "ping"}));
    assert_eq!(reply["value"], json!("pong"));
}
