//! Protocol v1 (DESIGN section 4): one JSON object per line on stdin/stdout.

use crate::props::Id;
use serde::Serialize;
use serde_json::{json, Map, Value};
use std::io::Write;

pub const VERSION: u32 = 1;

#[derive(Clone, Debug, PartialEq)]
pub enum Incoming {
    Hello { v: u64 },
    Create(Create),
    Props { id: Id, props: Map<String, Value> },
    Destroy { id: Id },
    Reparent { id: Id, parent: Option<Id>, index: Option<usize> },
    Run { app: Option<Id> },
    Quit { app: Option<Id> },
    Focus { id: Id },
    ScrollTo { id: Id, top: f32 },
    Font { path: String },
    Flush,
    Req { req: u64, op: Op },
}

#[derive(Clone, Debug, PartialEq)]
pub struct Create {
    pub id: Id,
    pub kind: String,
    pub parent: Option<Id>,
    pub index: Option<usize>,
    pub widget: bool,
    pub props: Map<String, Value>,
    pub doc_root: Option<Id>,
    pub owner: Option<Id>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Target {
    Id(Id),
    Text(String),
    Point(f32, f32),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MouseAction {
    Move,
    Down,
    Up,
}

/// What `ask` adds to its message (ledger K1): `secret` masks the answer as it is typed, and
/// `title` heads the dialog.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct AskOptions {
    pub secret: bool,
    pub title: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Op {
    Dialog { kind: String, message: String, default: Value, ask: AskOptions },
    Layout { app: Option<Id> },
    Snapshot { path: String, app: Option<Id>, scale: Option<f32> },
    Click { target: Target, button: u8, app: Option<Id> },
    Mouse { action: MouseAction, x: f32, y: f32, button: u8, app: Option<Id> },
    Type { text: String, app: Option<Id> },
    Key { key: String, app: Option<Id> },
    Wheel { dy: f32, x: Option<f32>, y: Option<f32>, app: Option<Id> },
    Resize { app: Option<Id>, w: f32, h: f32 },
    Pixel { x: f32, y: f32, app: Option<Id> },
    Frames { n: u32, app: Option<Id> },
    Focused { app: Option<Id> },
    Ping,
    /// Anything we cannot run still gets a reply, with this error.
    Invalid(String),
}

#[derive(Debug)]
pub enum ParseError {
    Json(String),
    Message(String),
}

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ParseError::Json(e) => write!(f, "bad JSON: {e}"),
            ParseError::Message(e) => write!(f, "bad message: {e}"),
        }
    }
}

fn id(obj: &Map<String, Value>, key: &str) -> Option<Id> {
    obj.get(key).and_then(Value::as_i64)
}

fn f(obj: &Map<String, Value>, key: &str) -> Option<f32> {
    obj.get(key).and_then(Value::as_f64).map(|v| v as f32)
}

fn s(obj: &Map<String, Value>, key: &str) -> Option<String> {
    obj.get(key).and_then(Value::as_str).map(str::to_string)
}

fn required<T>(v: Option<T>, what: &str) -> Result<T, ParseError> {
    v.ok_or_else(|| ParseError::Message(format!("missing or invalid `{what}`")))
}

/// The next line of `input` without its newline, or None at the end or on a read error. Bytes
/// that are not UTF-8 become U+FFFD, so one bad line is a parse error and not the end of input.
pub fn read_line_lossy(input: &mut impl std::io::BufRead, buf: &mut Vec<u8>) -> Option<String> {
    buf.clear();
    match input.read_until(b'\n', buf) {
        Ok(0) | Err(_) => None,
        Ok(_) => Some(String::from_utf8_lossy(buf).into_owned()),
    }
}

pub fn parse_line(line: &str) -> Result<Incoming, ParseError> {
    let value: Value = serde_json::from_str(line).map_err(|e| ParseError::Json(e.to_string()))?;
    let Value::Object(obj) = value else {
        return Err(ParseError::Message("not an object".into()));
    };
    let t = obj.get("t").and_then(Value::as_str).unwrap_or("");
    Ok(match t {
        "hello" => Incoming::Hello { v: obj.get("v").and_then(Value::as_u64).unwrap_or(1) },
        "create" => Incoming::Create(Create {
            id: required(id(&obj, "id"), "id")?,
            kind: required(s(&obj, "kind"), "kind")?,
            parent: id(&obj, "parent"),
            index: obj.get("index").and_then(Value::as_u64).map(|i| i as usize),
            widget: obj.get("widget").and_then(Value::as_bool).unwrap_or(false),
            props: obj.get("props").and_then(Value::as_object).cloned().unwrap_or_default(),
            doc_root: id(&obj, "doc_root"),
            owner: id(&obj, "owner"),
        }),
        "props" => Incoming::Props {
            id: required(id(&obj, "id"), "id")?,
            props: obj.get("props").and_then(Value::as_object).cloned().unwrap_or_default(),
        },
        "destroy" => Incoming::Destroy { id: required(id(&obj, "id"), "id")? },
        "reparent" => Incoming::Reparent {
            id: required(id(&obj, "id"), "id")?,
            parent: id(&obj, "parent"),
            index: obj.get("index").and_then(Value::as_u64).map(|i| i as usize),
        },
        "run" => Incoming::Run { app: id(&obj, "app") },
        "quit" => Incoming::Quit { app: id(&obj, "app") },
        "focus" => Incoming::Focus { id: required(id(&obj, "id"), "id")? },
        "scroll_to" => Incoming::ScrollTo { id: required(id(&obj, "id"), "id")?, top: f(&obj, "top").unwrap_or(0.0) },
        "font" => Incoming::Font { path: required(s(&obj, "path"), "path")? },
        "flush" => Incoming::Flush,
        "req" => {
            let req = required(obj.get("req").and_then(Value::as_u64), "req")?;
            Incoming::Req { req, op: parse_op(&obj) }
        }
        other => return Err(ParseError::Message(format!("unknown message type `{other}`"))),
    })
}

fn parse_op(obj: &Map<String, Value>) -> Op {
    match op_fields(obj) {
        Ok(op) => op,
        Err(e) => Op::Invalid(e.to_string()),
    }
}

fn op_fields(obj: &Map<String, Value>) -> Result<Op, ParseError> {
    let app = id(obj, "app");
    let op = obj.get("op").and_then(Value::as_str).unwrap_or("");
    Ok(match op {
        "dialog" => Op::Dialog {
            kind: required(s(obj, "kind"), "kind")?,
            message: obj.get("message").map(crate::props::value_text).unwrap_or_default(),
            default: obj.get("default").cloned().unwrap_or(Value::Null),
            ask: AskOptions { secret: obj.get("secret").and_then(Value::as_bool).unwrap_or(false), title: s(obj, "title") },
        },
        "layout" => Op::Layout { app },
        "snapshot" => Op::Snapshot { path: required(s(obj, "path"), "path")?, app, scale: f(obj, "scale") },
        "click" => Op::Click { target: target(obj.get("target"))?, button: button(obj), app },
        "mouse" => Op::Mouse {
            action: match obj.get("action").and_then(Value::as_str) {
                Some("move") => MouseAction::Move,
                Some("down") => MouseAction::Down,
                Some("up") => MouseAction::Up,
                other => return Err(ParseError::Message(format!("mouse action {other:?}"))),
            },
            x: required(f(obj, "x"), "x")?,
            y: required(f(obj, "y"), "y")?,
            button: button(obj),
            app,
        },
        "type" => Op::Type { text: required(s(obj, "text"), "text")?, app },
        "key" => Op::Key { key: required(s(obj, "key"), "key")?, app },
        "wheel" => Op::Wheel { dy: required(f(obj, "dy"), "dy")?, x: f(obj, "x"), y: f(obj, "y"), app },
        "resize" => Op::Resize { app, w: required(f(obj, "w"), "w")?, h: required(f(obj, "h"), "h")? },
        "pixel" => Op::Pixel { x: required(f(obj, "x"), "x")?, y: required(f(obj, "y"), "y")?, app },
        "frames" => Op::Frames { n: obj.get("n").and_then(Value::as_u64).unwrap_or(1).min(u32::MAX as u64) as u32, app },
        "focused" => Op::Focused { app },
        "ping" => Op::Ping,
        other => Op::Invalid(format!("unknown op `{other}`")),
    })
}

fn button(obj: &Map<String, Value>) -> u8 {
    obj.get("button").and_then(Value::as_u64).unwrap_or(1).clamp(1, 3) as u8
}

fn target(v: Option<&Value>) -> Result<Target, ParseError> {
    let obj = v.and_then(Value::as_object).ok_or_else(|| ParseError::Message("missing `target`".into()))?;
    if let Some(i) = id(obj, "id") {
        return Ok(Target::Id(i));
    }
    if let Some(t) = s(obj, "text") {
        return Ok(Target::Text(t));
    }
    match (f(obj, "x"), f(obj, "y")) {
        (Some(x), Some(y)) => Ok(Target::Point(x, y)),
        _ => Err(ParseError::Message("target needs id, text or x and y".into())),
    }
}

#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(tag = "t", rename_all = "snake_case")]
pub enum Outgoing {
    Ready { v: u32, version: String },
    Event { name: String, target: Option<Id>, args: Vec<Value> },
    Mouse { state: [i64; 3] },
    ParaHit { id: Id, value: Option<i64> },
    Resize { app: Id, w: i64, h: i64 },
    Scroll { id: Id, top: i64 },
    /// Where laid-out nodes landed, `[id, x, y, w, h, scroll_h]` in window px: all of them
    /// after an app's first layout, then those whose rect changed (cross-lane contract a).
    Layout { app: Id, rects: Vec<(Id, f64, f64, f64, f64, f64)> },
    Closed { app: Id },
    Reply {
        req: u64,
        value: Value,
        error: Option<String>,
        #[serde(flatten)]
        extra: Map<String, Value>,
    },
    Log { level: String, msg: String },
}

impl Outgoing {
    pub fn event(name: &str, target: Option<Id>, args: Vec<Value>) -> Self {
        Outgoing::Event { name: name.to_string(), target, args }
    }

    pub fn reply(req: u64, value: Value) -> Self {
        Outgoing::Reply { req, value, error: None, extra: Map::new() }
    }

    pub fn error(req: u64, error: impl Into<String>, value: Value) -> Self {
        Outgoing::Reply { req, value, error: Some(error.into()), extra: Map::new() }
    }

    pub fn ready() -> Self {
        Outgoing::Ready { v: VERSION, version: env!("CARGO_PKG_VERSION").to_string() }
    }
}

enum Sink {
    Stdout,
    Capture,
}

/// Buffered writer for Rust -> Ruby messages. Messages go out in the order
/// they were sent, so events caused by a request always precede its reply.
pub struct Outbox {
    pending: Vec<Outgoing>,
    sink: Sink,
    captured: Vec<Value>,
    trace: bool,
    /// Set when stdout is gone (the Ruby side exited).
    pub broken: bool,
}

impl Outbox {
    pub fn stdout(trace: bool) -> Self {
        Outbox { pending: Vec::new(), sink: Sink::Stdout, captured: Vec::new(), trace, broken: false }
    }

    /// For tests: keeps every message as JSON instead of writing it.
    pub fn capture() -> Self {
        Outbox { pending: Vec::new(), sink: Sink::Capture, captured: Vec::new(), trace: false, broken: false }
    }

    pub fn send(&mut self, msg: Outgoing) {
        self.pending.push(msg);
    }

    pub fn event(&mut self, name: &str, target: Option<Id>, args: Vec<Value>) {
        self.send(Outgoing::event(name, target, args));
    }

    pub fn has_pending(&self) -> bool {
        !self.pending.is_empty()
    }

    pub fn flush(&mut self) {
        if self.pending.is_empty() {
            return;
        }
        let pending = std::mem::take(&mut self.pending);
        match self.sink {
            Sink::Capture => self.captured.extend(pending.iter().map(|m| serde_json::to_value(m).unwrap_or(json!(null)))),
            Sink::Stdout => {
                let mut out = String::new();
                for msg in &pending {
                    if let Ok(line) = serde_json::to_string(msg) {
                        if self.trace {
                            eprintln!("[scarpe-native] >> {line}");
                        }
                        out.push_str(&line);
                        out.push('\n');
                    }
                }
                let stdout = std::io::stdout();
                let mut lock = stdout.lock();
                if lock.write_all(out.as_bytes()).and_then(|_| lock.flush()).is_err() {
                    self.broken = true;
                }
            }
        }
    }

    /// Everything sent so far (capture mode), flushed first.
    pub fn take_captured(&mut self) -> Vec<Value> {
        self.flush();
        std::mem::take(&mut self.captured)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_every_ruby_message() {
        assert_eq!(parse_line(r#"{"t":"hello","v":1,"pid":42}"#).unwrap(), Incoming::Hello { v: 1 });
        let create = parse_line(r#"{"t":"create","id":1,"kind":"App","parent":null,"index":null,"widget":false,"props":{"width":480},"doc_root":2,"owner":null}"#).unwrap();
        match create {
            Incoming::Create(c) => {
                assert_eq!((c.id, c.kind.as_str(), c.parent, c.doc_root), (1, "App", None, Some(2)));
                assert_eq!(c.props["width"], json!(480));
            }
            other => panic!("{other:?}"),
        }
        assert!(matches!(parse_line(r#"{"t":"props","id":5,"props":{"text_items":["x"]}}"#).unwrap(), Incoming::Props { id: 5, .. }));
        assert_eq!(parse_line(r#"{"t":"destroy","id":5}"#).unwrap(), Incoming::Destroy { id: 5 });
        assert_eq!(
            parse_line(r#"{"t":"reparent","id":5,"parent":3,"index":0}"#).unwrap(),
            Incoming::Reparent { id: 5, parent: Some(3), index: Some(0) }
        );
        assert_eq!(parse_line(r#"{"t":"run","app":1}"#).unwrap(), Incoming::Run { app: Some(1) });
        assert_eq!(parse_line(r#"{"t":"quit","app":null}"#).unwrap(), Incoming::Quit { app: None });
        assert_eq!(parse_line(r#"{"t":"focus","id":9}"#).unwrap(), Incoming::Focus { id: 9 });
        assert_eq!(parse_line(r#"{"t":"scroll_to","id":9,"top":40}"#).unwrap(), Incoming::ScrollTo { id: 9, top: 40.0 });
        assert_eq!(parse_line(r#"{"t":"font","path":"/a/b.ttf"}"#).unwrap(), Incoming::Font { path: "/a/b.ttf".into() });
        assert_eq!(parse_line(r#"{"t":"flush"}"#).unwrap(), Incoming::Flush);
    }

    #[test]
    fn parses_every_req_op() {
        let op = |line: &str| match parse_line(line).unwrap() {
            Incoming::Req { op, .. } => op,
            other => panic!("{other:?}"),
        };
        assert_eq!(
            op(r#"{"t":"req","req":1,"op":"dialog","kind":"ask","message":"Name?","default":null}"#),
            Op::Dialog { kind: "ask".into(), message: "Name?".into(), default: Value::Null, ask: AskOptions::default() }
        );
        assert_eq!(
            op(r#"{"t":"req","req":1,"op":"dialog","kind":"ask","message":"Pin?","default":null,"secret":true,"title":"Log in"}"#),
            Op::Dialog {
                kind: "ask".into(),
                message: "Pin?".into(),
                default: Value::Null,
                ask: AskOptions { secret: true, title: Some("Log in".into()) },
            }
        );
        assert_eq!(op(r#"{"t":"req","req":1,"op":"layout"}"#), Op::Layout { app: None });
        assert_eq!(
            op(r#"{"t":"req","req":1,"op":"snapshot","path":"/tmp/a.png","scale":2}"#),
            Op::Snapshot { path: "/tmp/a.png".into(), app: None, scale: Some(2.0) }
        );
        assert_eq!(op(r#"{"t":"req","req":1,"op":"click","target":{"id":4}}"#), Op::Click { target: Target::Id(4), button: 1, app: None });
        assert_eq!(
            op(r#"{"t":"req","req":1,"op":"click","target":{"text":"OK"},"button":3}"#),
            Op::Click { target: Target::Text("OK".into()), button: 3, app: None }
        );
        assert_eq!(
            op(r#"{"t":"req","req":1,"op":"click","target":{"x":5,"y":6.5}}"#),
            Op::Click { target: Target::Point(5.0, 6.5), button: 1, app: None }
        );
        assert_eq!(
            op(r#"{"t":"req","req":1,"op":"mouse","action":"move","x":1,"y":2}"#),
            Op::Mouse { action: MouseAction::Move, x: 1.0, y: 2.0, button: 1, app: None }
        );
        assert_eq!(op(r#"{"t":"req","req":1,"op":"type","text":"hi"}"#), Op::Type { text: "hi".into(), app: None });
        assert_eq!(op(r#"{"t":"req","req":1,"op":"key","key":"left"}"#), Op::Key { key: "left".into(), app: None });
        assert_eq!(op(r#"{"t":"req","req":1,"op":"wheel","dy":30}"#), Op::Wheel { dy: 30.0, x: None, y: None, app: None });
        assert_eq!(op(r#"{"t":"req","req":1,"op":"resize","w":300,"h":200}"#), Op::Resize { app: None, w: 300.0, h: 200.0 });
        assert_eq!(op(r#"{"t":"req","req":1,"op":"pixel","x":1,"y":2}"#), Op::Pixel { x: 1.0, y: 2.0, app: None });
        assert_eq!(op(r#"{"t":"req","req":1,"op":"frames","n":3}"#), Op::Frames { n: 3, app: None });
        assert_eq!(op(r#"{"t":"req","req":1,"op":"focused"}"#), Op::Focused { app: None });
        assert_eq!(op(r#"{"t":"req","req":1,"op":"ping"}"#), Op::Ping);
        assert!(matches!(op(r#"{"t":"req","req":1,"op":"teleport"}"#), Op::Invalid(_)));
        assert!(matches!(op(r#"{"t":"req","req":1,"op":"click"}"#), Op::Invalid(_)));
    }

    #[test]
    fn serialises_every_rust_message() {
        let v = |m: Outgoing| serde_json::to_value(m).unwrap();
        assert_eq!(v(Outgoing::ready())["t"], "ready");
        assert_eq!(v(Outgoing::event("click", Some(4), vec![])), json!({"t":"event","name":"click","target":4,"args":[]}));
        assert_eq!(v(Outgoing::Mouse { state: [1, 20, 30] }), json!({"t":"mouse","state":[1,20,30]}));
        assert_eq!(v(Outgoing::ParaHit { id: 3, value: None }), json!({"t":"para_hit","id":3,"value":null}));
        assert_eq!(v(Outgoing::Resize { app: 1, w: 500, h: 400 }), json!({"t":"resize","app":1,"w":500,"h":400}));
        assert_eq!(v(Outgoing::Scroll { id: 2, top: 40 }), json!({"t":"scroll","id":2,"top":40}));
        assert_eq!(
            v(Outgoing::Layout { app: 1, rects: vec![(3, 4.0, 4.0, 292.0, 14.4, 14.4)] }),
            json!({"t":"layout","app":1,"rects":[[3,4.0,4.0,292.0,14.4,14.4]]})
        );
        assert_eq!(v(Outgoing::Closed { app: 1 }), json!({"t":"closed","app":1}));
        let mut extra = Map::new();
        extra.insert("cancelled".into(), json!(true));
        assert_eq!(
            v(Outgoing::Reply { req: 7, value: Value::Null, error: None, extra }),
            json!({"t":"reply","req":7,"value":null,"error":null,"cancelled":true})
        );
        assert_eq!(v(Outgoing::error(8, "nope", Value::Null)), json!({"t":"reply","req":8,"value":null,"error":"nope"}));
        assert_eq!(v(Outgoing::Log { level: "warn".into(), msg: "m".into() }), json!({"t":"log","level":"warn","msg":"m"}));
    }
}
