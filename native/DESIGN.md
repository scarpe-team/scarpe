# Scarpe Native: design

Status: v1.1, 27 Sep 2026, after the third build wave merged and the orchestrator ruled Q1 to Q8
(Q1 to Q7 under "Rulings on the questions" in `spec/LEDGER.md`, Q8 on `clear` and timers in 5.4;
Nick may overrule any of them). This document is the contract every builder codes against. If the
code and this document disagree, fix one of them in the same change. The user guide is
`docs/native.md`; performance lives in `native/PERF.md`.

Research behind every decision lives in `native/research/` (01 contract, 02 visuals, 03 manual
inventory, 04 examples and specs, 05 integration and prior art, 06 discrepancy ledger seed, 07/08
stack spikes, 09 Lacci fixes, `sources/` for the Shoes 3 and Shoes 4 excerpts the ledger cites).
`native/research/README.md` says what each one is and when it was written.

## 1. Goal

A display service for Scarpe that draws Shoes apps natively with Rust. No HTML, no webview.
It must be fast, beautiful by default, packageable as one app, and testable headlessly
by "looking" (PNG snapshots, layout dumps) and "clicking" (synthetic input through the same
hit-testing path a real mouse uses).

Selected with `SCARPE_DISPLAY_SERVICE=native` (or `scarpe --native app.rb`). `scarpe peek` runs an
app headless on it (section 8).

This backend exists because Noah Gibbs made Scarpe's display services swappable: Lacci keeps the
Shoes API and talks to whatever `Shoes::DisplayService.set_display_service_class` names, over
the event bus he designed (2023). His relay (`wv_relay`) first put a display in another process,
and his Shoes-Spec gave every display the same tests. This design follows all three.

## 2. Shape: Ruby thinks, Rust draws

```
 Ruby process                                   Rust process (native/target/release/scarpe-native)
 ------------                                   -------------------------------------------------
 app code + Lacci (lacci/)                      stdin reader thread --> EventLoopProxy (window)
 Scarpe::Native::DisplayService (the shim)      Runtime
   create_display_drawable_for  --create-->       Doc: id -> Node {kind, props, parent, children}
   bus: prop_change/destroy/...  --props-->       layout (Shoes stack/flow engine, logical px)
   Lacci's left/top/width/height <--layout--        ...and the rects that moved, pushed back
   builtin (sync)               --req/reply-->    paint (tiny-skia + cosmic-text) -> softbuffer | PNG
   pump (at_exit): IO.select,   <--event--        input: hit-test, hover, focus, keys, text editing
     timers, heartbeat, flush   <--reply--        dialogs (rfd), automation ops (tests, peek)
```

- The child speaks NDJSON on stdin/stdout. Stdout carries protocol only; logs go to stderr.
- All Procs and user blocks stay in Ruby. Only data crosses.
- Timers (`animate`, `every`, `timer`) tick in the Ruby pump. Rust has no timer logic.
- A Rust panic or exit is reported by the shim as a Ruby error (`Scarpe::Native::ChildDied`) with
  the last 40 lines of the child's stderr. The Ruby side survives handler exceptions (log and
  continue), so a bad handler never blanks the window.

Why a child process and not a native extension: no GVL puzzles around winit's main-thread loop,
crash isolation, a build that does not depend on the Ruby version, and the same binary serves
the window, the headless test runner and packaging. Noah designed the display service to live
out of process; the relay (`lib/scarpe/wv/webview_relay_*`) is the precedent, but it is bit-rotted
and its framing is wrong (it counts characters, not bytes), so we copy its shape and not its code.

## 3. Repository layout

```
native/                         Rust crate `scarpe-native` (bin + lib, so tests can use the lib)
  Cargo.toml
  DESIGN.md                     this file
  PERF.md                       performance: the numbers, how they were taken, what moved them
  assets/fonts/                 bundled Inter and Fira Mono (deterministic mode, OFL)
  research/                     the reports behind this design (research/README.md)
  src/...                       see section 7
  tests/                        Rust integration tests: protocol fixtures, golden PNGs, damage,
                                art and input, dialogs, relayout, text cache, benches (ignored)
lib/scarpe/native.rb            registers the service (section 5.1)
lib/scarpe/native/              the Ruby shim
  display_service.rb            Shoes::DisplayService subclass: Lacci's bus <-> the protocol
  display_drawable.rb           the pairing object: a mirror of what Rust was told
  child.rb                      find, build and spawn the binary; NDJSON transport; request/reply; Stats
  normalize.rb                  Ruby value -> wire value (section 5.3)
  pump.rb                       the at_exit event loop (section 5.4)
  timers.rb                     animate, every, timer, and a clock tests can freeze
  builtins.rb                   dialogs and `font`, answered synchronously
  automation.rb                 look-and-click requests shared by Shoes-Spec and peek
  shoes_spec.rb                 Shoes::Spec implementation + native test API (section 8)
  peek.rb                       `scarpe peek` driver
  log.rb                        Shoes::Log to stderr
lib/scarpe/package/native.rb    `scarpe package --native` (section 11), with bytecode.rb and yjit.rb
templates/package/              the packaged app's launcher and boot.rb
exe/scarpe                      gains `--native` and the `peek` subcommand
spec/                           the consolidated Shoes spec suite (section 9)
test/native/                    Ruby integration tests for the backend (minitest)
test/package/                   packaging tests
examples/native/bench/          benchmark apps and their driver (native/PERF.md)
docs/native.md                  the user guide
```

## 4. Protocol v1 (NDJSON, UTF-8, one JSON object per line)

Every message has `"t"` (type). Integers are Drawable linkable ids (Ruby Integers, JSON numbers).
A line Rust cannot parse is answered with a `log` warning and otherwise ignored.

### 4.1 Ruby -> Rust

| t | fields | meaning |
|---|---|---|
| `hello` | `v` (=1), `pid` | first line; Rust answers `ready`. Ruby sends it without waiting and builds the app meanwhile |
| `create` | `id`, `kind` (the class's `display_class_name`, e.g. "Para", "Button", or the widget subclass name), `parent` (id or null), `index` (int or null = append), `widget` (bool), `props` {normalised} | new node. `kind:"App"` also carries `doc_root` (= id+1) and `owner` (id or null). The DocumentRoot is created before its App; Rust must accept that order. Create props leave out nil values: absent means unset. Title, Banner and the other text block names draw as Para, LinkHover as Link; a kind Rust does not know is kept and not laid out |
| `props` | `id`, `props` {changes} | property changes; an explicit null unsets. Unknown id: ignore silently (Para sends text_items before its create) |
| `destroy` | `id` | remove node and its whole subtree; an App's id closes its window. Unknown id: ignore. Idempotent |
| `reparent` | `id`, `parent`, `index` | move node |
| `run` | `app` (or null = the newest) | the app is complete enough to show: open its window (or headless canvas) |
| `quit` | `app` (id or null = all) | close window(s); when none remain Rust exits 0 |
| `focus` | `id` | give keyboard focus to a control, with a visible focus ring |
| `scroll_to` | `id`, `top` | set a scrollable slot's scroll offset (clamped at the next layout) |
| `font` | `path` (absolute) | register a font file; family name(s) become usable |
| `flush` | | end of a batch: Rust applies everything received, relayouts, redraws once |
| `req` | `req` (int), `op`, op fields | request that must get exactly one `reply` with the same `req` |

`req` ops. Every op that acts on a window takes an optional `app`; without it Rust uses the app
that last ran or had input, else the first running one.

| op | fields | reply `value` |
|---|---|---|
| `dialog` | `kind` (alert confirm ask ask_color ask_open_file ask_save_file ask_open_folder ask_save_folder), `message`, `default` | alert: null; confirm: bool; ask: String, or null on Cancel in a window (headless: `""`); ask_color: [r,g,b,a] or null; file/folder: path or null. `cancelled` bool alongside. The shim hands Lacci `""` for a cancelled ask either way (ledger K1, Q6) |
| `layout` | `app` | array of `{id, kind, x, y, w, h, visible, text?}` in window coordinates, rounded to 1/100, paint order; text fragments follow their para |
| `snapshot` | `path`, `app`, `scale` (default: the app's scale) | writes a PNG; value = `{path, w, h}` in pixels |
| `click` | `target`: `{id}` or `{text}` or `{x,y}`, `button` (1 default), `app` | synthesises press+release at the target's centre through the real input path. value = `{hit: id or null, x, y}`. Error if the target is not visible or something else is on top (the value says what was hit). `{id}` goes to the drawable's own window whatever `app` says. `{text}` matches exact text first, then text that contains it, links included, and also picks an item of an open list_box popup |
| `mouse` | `action` (move down up), `x`, `y`, `button` | low-level pointer event through the real path |
| `type` | `text` | inserts text into the focused input as real key events, one character at a time |
| `key` | `key` (a Shoes name, e.g. "left", "\n", "a", ":control_a"; also `command_`, `cmd_`, `super_`, `ctrl_`, `option_` prefixes) | synthesises a key press |
| `wheel` | `dy`, `x`, `y` (optional) | wheel event, section 12 |
| `resize` | `w`, `h` | resize the window/canvas; Rust answers with a `resize` message too |
| `pixel` | `x`, `y` | `[r,g,b,a]` at logical point; error outside the window |
| `frames` | `n` | reply after n frames have been laid out and painted (sync point); value = frames painted so far |
| `focused` | | id of the focused input or null |
| `ping` | | `"pong"` |

An unknown op, or one missing a field, gets a reply whose `error` says so.

Ordering guarantee: every `event` caused by a request is written before that request's `reply`.
Rust processes `req`s after an implicit flush of everything received before them.

### 4.2 Rust -> Ruby

| t | fields | shim action |
|---|---|---|
| `ready` | `v`, `version` | handshake done |
| `event` | `name`, `target` (id or null), `args` (array) | `Shoes::DisplayService.dispatch_event(name, target, *args)`; a ListBox `change` gets back the item whose `to_s` Rust sent |
| `mouse` | `state` [held, x, y] (held is 1 while the left button is down; window px, rounded) | `Shoes::DisplayService.mouse_state = state` |
| `para_hit` | `id`, `value` | `para_hit_cache[id] = value` (Integer keys) |
| `resize` | `app`, `w`, `h` (Integers) | set the App's `@width`/`@height` ivars directly (no prop_change echo) |
| `scroll` | `id`, `top` (Integer) | set the slot's `@scroll_top` directly |
| `layout` | `app`, `rects`: `[[id, x, y, w, h, scroll_h], ...]` | `Shoes::DisplayService.layout_cache[id] = [x, y, w, h, scroll_h]` (Integer keys; the shim defines the accessor if Lacci lacks it and deletes ids on destroy). Sent after every layout pass, before its frame is presented and before the reply of any request that caused it: every laid-out node on an app's first layout, then only those whose rect changed, sorted by id. Window logical px, rounded to 1/100; `scroll_h` is a slot's content height, padding included, else `h`. Art reports its transformed box. Destroyed ids are simply not sent again (contract a; ledger A4, C5) |
| `closed` | `app` | user closed a window: destroy that app (all apps if it was the last) |
| `reply` | `req`, `value`, `error` (null or String), plus op extras like `cancelled` | answers a `req` |
| `log` | `level`, `msg` | forwarded to Shoes::Log (`scarpe-native` component) |

### 4.3 Events Rust emits (exact names and args; see research 01 section 5)

| user action | event | target | args |
|---|---|---|---|
| click Button, Check, Radio, Image, Link | `click` | that id | `[]`, on release over the same drawable (Check/Radio: Lacci toggles and echoes `checked`; Rust shows the echo, it does not toggle on its own). Return or Space on a focused button, or Space on a focused check or radio, clicks it too |
| edit EditLine / EditBox | `change` | that id | `[new_text]` on every edit. Lacci echoes `props {text}`: apply idempotently, keep caret |
| pick in ListBox (popup, or Up/Down while focused) | `change` | that id | `[item_string]` |
| pointer enters / leaves a drawable | `hover` / `leave` | that id | `[]`, on transitions only, for every drawable in the hovered chain |
| press / release on a drawable that has `has_click` / `has_release` true | `click` / `release` | the innermost such id under the pointer | `[button, x, y]` window coordinates, Integers |
| SubscriptionItem `click`/`release` | same | item id | `[button, x, y]` in window coordinates, like drawable clicks (ledger H3, Q4, contract g). Fires for presses inside the parent slot unless a control, text field or link consumed the press |
| SubscriptionItem `motion` | `motion` | item id | `[x, y, ctrl, shift]` (booleans) in window coordinates, on pointer move inside the parent slot |
| SubscriptionItem `hover`/`leave` | same | item id | `[]` on entering/leaving the parent slot box |
| SubscriptionItem `keypress` | `keypress` | item id | `[key]`, see 4.4. Not sent while a text input has focus, except escape and modified keys; not sent for keys a focused control used |
| SubscriptionItem `wheel` | `wheel` | item id | `[delta, x, y]`, delta > 0 = up |

A SubscriptionItem hears events only while its parent slot is laid out and its `stopped` prop is
not true. Mouse buttons are 1 = left, 2 = middle, 3 = right (manual numbering).

### 4.4 Key names (manual, research 06 ledger "keypress" rows)

- Printable characters: the String itself (`"a"`, `"A"`, `" "`, `"&"`).
- Return: `"\n"`. Tab `:tab`, Backspace `:backspace`, Delete `:delete`, arrows `:left :right :up :down`, `:home :end :page_up :page_down :escape :insert :f1`..`:f12`.
- Modifiers prefix in the order `control_`, `shift_`, `alt_` (shift only for non-printables). A modified printable key is a Symbol: `:control_a`, `:alt_q`. Modified return: `:control_enter`, `:shift_enter`.
- Shift folds into characters the way a US keyboard types them (manual 2223-2227): Shift-7 is `"&"`,
  Shift-Alt-7 is `:alt_&`, Control-Shift-a is `:control_A`. Automation's `key` op folds `shift_7` the same way.
- On the wire a Symbol travels as a String starting with `":"` (`":left"`); Lacci's SubscriptionItem turns it back into a Symbol. Plain printable keys travel as themselves.
- On macOS, Cmd is named `alt_`, as Shoes 3's Cocoa backend did (ledger H1, Q5 ruled 27 Sep 2026):
  Cmd-q arrives as `:alt_q`, which is what the example editors bind. In text fields Cmd still works
  like Control (copy, paste, select all, line ends); Option moves by words. The default app menu
  still quits on Cmd-Q before the app sees the key; Rust then reports every open window `closed`.
  The `key` op accepts `command_` (or `cmd_`, `super_`) for Cmd.

### 4.5 Wire contracts settled on 27 Sep 2026

Seven cross-lane contracts from the rulings (ledger "Where DESIGN.md disagrees", item 9). Each is
built on both sides.

| | contract | where |
|---|---|---|
| a | Rust pushes laid-out rects back; Lacci's `left`, `top`, `width`, `height`, `scroll_height`, `scroll_max` read them | 4.2 `layout`; ledger A4, C5 |
| b | the draw context carries `translate: [x, y]` (Lacci's running total), `transform: "center" or "corner"` and `cap: "curve", "rect" or "project"`; a shape's own `cap` wins | 5.3, 12 art geometry; ledger E10 |
| c | an `image(w, h) { }` block runs with the Image as the current slot, so what it draws arrives as the Image's children | 12 image canvases; ledger E9 |
| d | a style that turns `underline` or `strikethrough` off (nil or false) sends `"none"`, since create props drop nils; Rust draws no decoration for `"none"` | ledger F7 |
| e | `animate`, `every` and `timer` return `Shoes::Animation`, `Shoes::Every` and `Shoes::Timer`, and all three still announce themselves as `kind: "SubscriptionItem"` with `shoes_api_name` | 5.4; ledger I2 |
| f | `every`'s count starts at 0, and `animate`'s first frame is 0 | 5.4; ledger I1 |
| g | SubscriptionItem `click`, `release` and `motion` carry window coordinates, like drawable clicks | 4.3; ledger H3 |

## 5. The Ruby shim

### 5.1 `lib/scarpe/native.rb`

Mirrors `lib/scarpe/wv.rb` and `lacci/lib/scarpe/niente.rb`: set `Shoes::Log.instance` once,
add the SegmentedFileLoader, push `:multi_app` into `Shoes::FEATURES` and the usual family names
into `Shoes::FONTS`, then `Shoes::DisplayService.set_display_service_class(Scarpe::Native::DisplayService)`.
`Shoes::Spec.instance` is set only when `SHOES_SPEC_TEST` is set, because minitest costs 10 to 45 ms
to load and only a spec run uses it (a packaged app without minitest loses Shoes-Spec only).
The nil-target `builtin` subscription is made here, at require time, so a builtin called before
any `Shoes.app` (the manual allows a top-level `ask_open_file`) is answered. Lacci's osascript
fallback is switched off, because every builtin has an answer and a real dialog in a test run
is the one bug we never want. Must never load `scarpe/wv` (set-once globals collide).

### 5.2 DisplayService

- Spawns the child lazily, the first time something needs it: the first `create_display_drawable_for`,
  or a windowed builtin before any app.
  Binary: `ENV["SCARPE_NATIVE_BIN"]`; else, in a dev checkout (one with `native/Cargo.toml`),
  `native/target/release/scarpe-native`, running `cargo build --release` first (one line to stderr)
  when it is missing or older than any file under `native/src`, `Cargo.toml` or `Cargo.lock`;
  else a packaged binary beside the running script, in `../MacOS`, or on `PATH`.
  Extra child arguments come from `SCARPE_NATIVE_ARGS`. The child runs in its own process group,
  so a terminal Ctrl-C reaches Ruby, which quits it.
- Headless when `SCARPE_NATIVE_HEADLESS` is set to anything but `""`, `0`, `false` or `no` (passes
  `--headless` to the child).
- `create_display_drawable_for(name, id, props, parent_id:, is_widget:)`:
  registers a lightweight pairing object (`set_drawable_pairing`) so Shoes-Spec proxies work,
  handles that id's `prop_change`, `destroy`, `parent`, `focus`, `scroll_top` (through one `:any`
  subscription per event name, since Lacci's unsubscribe used to scan every subscription), computes
  `index` (position in the Lacci parent's children, or null when it is the last), normalises props,
  queues `create`, and hands timers (`kind: "SubscriptionItem"` with `animate`, `every` or `timer`)
  to the pump.
- Nil-target bus events: `run` (answer `custom_event_loop "return"`, then send `run` for the newest
  app not yet started, normally `Shoes.APPS.last`), `destroy` (quit every app; it may arrive from a
  signal trap, so it only flips flags and the pump sends the quit) and `builtin`. `init` and
  `full_redraw_request` need nothing: Rust is retained.
- `builtin` is answered synchronously: a stubbed answer first, then a quiet answer when nobody can
  click (headless, or a Shoes-Spec run), else `req dialog`, blocking on the reply while incoming
  events queue for the pump. Then `set_builtin_response(value)`. It must never leave a builtin
  unanswered. `font` registers the absolute path; an unknown builtin logs a warning and answers nil.
  The quiet answers: alert nil, confirm false, ask `""`, ask_color and file dialogs nil. A cancelled
  `ask` in a window answers `""` too (ledger K1, Q6).
- Outgoing messages are buffered and written on `flush`; the pump flushes once per iteration, and a
  `req` writes the buffer ahead of itself. A Mutex guards writes (downloads call back on threads),
  and a post from another thread wakes the pump.
- If the child has not answered `hello` within 20 s, the pump raises `ChildTimeout`.

### 5.3 Normalisation (Ruby value -> wire value), in one place

- Colors: `[r,g,b,a]` ints 0-255 or floats 0-1 -> `{"rgba":[r,g,b,a]}` with ints 0-255 and alpha 0-255
  (float channels scale by 255 each, per component). `"#rgb"` and `"#rgba"` (x17), `"#rrggbb"`,
  `"#rrggbbaa"`, CSS `rgb()`/`rgba()`, named colours (`Shoes::COLORS`, plus gray and grey) -> rgba.
  `"transparent"` and `"none"` -> `[0,0,0,0]`. `Shoes::Colors::Gradient` or a color `Range` ->
  `{"gradient":[c1,c2],"angle":deg}` (a Range, or a Gradient without one, gets angle 0: top to
  bottom). Strings that are paths/URLs of images -> `{"image":"/abs/path"}`. A colour it cannot read
  logs one warning and stays unset. `nil` stays null. Symbols -> the String.
- The draw context: `fill` and `stroke` as colours, everything else (`translate`, `transform`, `cap`,
  `strokewidth`, `rotate`...) as plain values (contract b).
- Paths (`url`, image backgrounds, `icon`, `font`) -> absolute (`File.expand_path` against `Dir.pwd`).
  `http(s)` image and font URLs are downloaded once into a cache dir (`SCARPE_NATIVE_CACHE`) and sent
  as local paths; net/http loads on the first download only. A non-Image `url` with a scheme stays as it is.
- Ruby objects: `owner` -> its linkable id; `attach: Shoes::App` (the Window constant) -> `"window"`;
  `attach: drawable` -> its id; Procs -> dropped (a dropped `click` sets `has_block: true`).
  ListBox `items` and `chosen` travel as Strings.
- `shape_commands` must arrive complete (Lacci fix, section 10).
- Everything else via `JSON.generate`-safe conversion (Symbols to Strings, Ranges to pairs, a
  non-finite Float to null, other objects through `to_s`).

### 5.4 Pump (the event loop)

`run` answers `custom_event_loop "return"`; an `at_exit` hook runs the pump (Niente/space_shoes pattern),
which is the only mode that supports `window()`. A script that died with an exception, or called
`exit`, does not start it.

```
loop until no app is open or the child's stdout ended:
  wait for input, at most until the next timer deadline, and at most 1 s when idle
    (Automation#advance and other callers of Pump#step wait at most 50 ms)
  dispatch every complete message
  tick due timers: animate (frame starts at 0), every (count starts at 0, ledger I1), timer (one shot);
    honour `stopped` and destroyed items; timers can be created at any time
  dispatch "heartbeat" (nil target) at most every 50 ms (Shoes-Spec hooks run on the first one)
  flush
```

Handler exceptions are rescued per dispatch, logged with the app file/line, and the loop continues.

Deadlines are `origin + n * interval`, so ten 0.1 s frames land on one second instead of drifting.
A timer that fell behind skips the deadlines it missed rather than firing a burst, and a restarted
timer waits a whole interval. `clear` keeps the timers a slot started (ledger B7, Q8 ruled 27 Sep
2026): Lacci's `clear` destroys every child except SubscriptionItems, so they keep ticking, as in
Shoes 3 (`s3_canvas.c:781`) and as the examples that clear their app from inside its own `animate`
need. Removing or destroying the slot stops them with it.

An idle pump sleeps. Besides the child's output, the select watches a wake pipe that a post from
another thread (a download) and Ctrl-C (the pump chains Lacci's INT trap) write to, so nothing
waits on the timeout (native/PERF.md). Hello goes out without waiting for `ready`. When the loop
ends the shim sends `quit`, closes the child's stdin and gives it 2 s before TERM and KILL; if the
child died while an app was still open, it raises `ChildDied`.

## 6. Layout rules (canonical)

Units are logical pixels (f32). Window content size = App `width` x `height`; an App that sends
neither opens at 600x500, titled "Shoes" (Shoes 3 and Shoes 4, ledger A1, Q1). Lacci's own default
moved there the same day, so apps normally send it.

- **Dimensions** for width/height/left/top/margins: Integer = px; negative Integer = parent inner
  size minus |v|; Float in (0, 1] = fraction of parent inner size (1.0 = 100%); Float in (-1, 0) =
  the parent less that fraction; any other Float is px, because Ruby code often computes widths like
  `w / 2.0`. String `"N%"` = percent (negative: 100% less N%); `"Npx"` or a numeric String = px.
  Shoes 3 treats every Float as a fraction, 1.5 included (ledger C1); native keeps the Floats
  above 1 as pixels.
- **DocumentRoot** is a flow filling the window. If content is taller than the window, the root
  scrolls vertically (wheel + a thin overlay scrollbar), and the window's own backgrounds scroll
  with it.
- **Flow**: default width 100% of parent inner width. In-flow children are packed left to right;
  a child that does not fit on the current row starts a new row (unless the row is empty). Row height =
  tallest child, margins included; children top-aligned.
- **Stack**: children top to bottom, each on its own row, left-aligned. Default width: its
  parent's inner width, like a flow's, so an unsized slot after anything else on a line starts a
  row (ledger C8: Shoes 3 s3_canvas.c:468 with s3_ruby.c:505-532, Shoes 4 s4_slot.rb:48). Widgets
  and masks lay their children out as flows and take the same default width.
- Slot height = content height unless `height` given. A slot with a fixed `height` clips what
  does not fit, scrolling or not (manual 345-352: it becomes a "nested window"; ledger C13); `scroll: true`
  with a height also scrolls. `scroll: true` without a height does nothing.
- **Text blocks** (para and family) with no width: in a stack, full inner width. In a flow they
  read as one paragraph with what came before them on the line (manual 1610-1612, ledger C7, Q2,
  Shoes 3 s3t_textblock.c:134-228): text that fits on the rest of the line sits there as a box
  as wide as its text; longer text starts its first line where the line stands (a first-line
  indent) and wraps its later lines back to the flow's left edge, its box spanning the flow.
  The next element carries on from the end of the last line. After text the line goes on from
  the end of the text plus whatever its right margin adds to its left one, so two paras sit one
  margin apart. Text starts a new row instead when not even its first word fits on the rest of
  the line, or when something earlier on the line reaches more than half a line below its first
  line (a picture, a title), where Shoes 3 would wrap lines under it. The indent is a blank
  wide as the indent at the head of the cosmic-text buffer; hit-testing and a para's `fill`
  leave its corner to what came before. Centred, right-aligned, justified, trimmed and sized
  text keeps the box rule of section 12. A text block's `fill` is a highlighter over its text,
  line by line (manual 1208-1210; Shoes 3's Pango background), not paint over its box.
  Line height = 1.2 x size. `leading` (default 4 px, manual 1286, ledger F10) goes between lines
  only, as Pango's spacing does: one line is 1.2 x size tall, two are 2.4 x size + 4.
- **Widgets** have intrinsic sizes (research 02 section 13): button = its label's width plus 14 px
  each side by its line height plus 12 px, at least 28 px each way (more with an icon); edit_line 200x28, edit_box 200x108,
  list_box 200x28, progress 200x14 (manual sizes, ledger C4), check/radio 18x18, slider 160x20,
  video 300x150 (a placeholder frame; playback is not built). An image is its file's size, or keeps its aspect when given only
  a width or a height. Shadows stay inside a control's box. Explicit width/height override.
- **Margins** add outside the box (`margin`, `margin_left/top/right/bottom`; arrays are
  [left, top, right, bottom], and a short array keeps the default for the sides it leaves out,
  ledger C3). Text blocks default to Shoes 3's margins: 4 px on every side, and 12 px below
  unless `margin` or `margin_bottom` is given (ledger C9, Q3, s3t_textblock.c:108-110); everything
  else defaults to 0. `padding` (Scarpe extension) adds inside slots and the root.
- **Absolute placement**: any child with `left`, `top`, `right`, `bottom` or `attach` set, every
  art shape, and every background and border is out of flow: placed relative to its slot's content
  origin, it does not affect siblings or slot height. `right: n` puts the element's right margin
  edge n px in from the slot's right edge, `bottom: n` likewise from the bottom (manual 1100-1106,
  1356-1364, ledger C10); `left` and `top` win when both are given.
  `displace_left/top` shifts a laid-out element (and what it holds) visually without affecting others.
- `hidden: true` removes the element from layout and painting.
- `attach: "window"` positions relative to the window instead of the slot; `attach` with a
  drawable's id positions relative to that drawable's top-left corner (ledger C11).
- **Paint order** is tree order (creation order, respecting `index`): a background declared
  first paints under later siblings. Backgrounds and borders fill their slot's box
  (or their own width/height), with `curve` radius. Borders are stroked inside the box.

## 7. Rust crate

```
src/main.rs        CLI: scarpe-native [--headless] [--scale F] [--fonts system|bundled] [--trace]
                   [--exit-after SECS] [--inactive] [--ghost] [--version] [--help]
src/lib.rs         pub mods below
src/protocol.rs    serde types for 4.1/4.2; Outbox (buffered stdout writer, flush per message batch)
src/doc.rs         Doc { nodes, apps }, Node { id, kind: Kind, class, props: Props, parent, children },
                   Kind enum (App DocumentRoot Stack Flow Widget Mask Para TextDrawable Code Del Em
                   Strong Span Sub Sup Ins Link Button Check Radio EditLine EditBox ListBox Progress Slider
                   Image Video Background Border Rect Oval Line Arrow Star Arc Shape SubscriptionItem Unknown(String))
src/props.rs       typed getters over serde_json::Value: dim, color/paint, margin, f32, bool, str, text_items
src/style/         color.rs (Color, Paint = Solid | Linear{c1,c2,angle} | Image(path)), dim.rs, font.rs (size names, font string parse)
src/layout/        mod.rs: layout(inputs, root, size) -> Layout { boxes: HashMap<Id, LBox>, order, texts,
                   scrollers, content_heights, subscriptions }; tests.rs
src/text/          mod.rs (TextEngine), fonts.rs (FontSystem: system or bundled; set sans/serif/mono
                   families; `font` registration), rich.rs (resolve Para text_items tree -> styled runs with
                   a metadata id per span), shape_cache.rs (cache Buffers keyed by content hash + width;
                   first-line indents), raster.rs (own glyph rasteriser with slight embolden, HiDPI via glyph.physical)
src/paint/         mod.rs (Canvas with an origin; paint_nodes, the region painter; paint_run, the mask-aware
                   walk; clip; scrollbars and overlays), shapes.rs (rect oval line arrow star arc shape,
                   shape groups, transforms), decor.rs (background, border, scrollbars),
                   text.rs (draw shaped text, decorations, selection, caret), damage.rs (partial repaints, section 12)
src/elements/      one file per widget: button.rs check.rs radio.rs edit_line.rs edit_box.rs (both on
                   text_field.rs) list_box.rs progress.rs slider.rs image.rs video.rs. Each exposes what it
                   has of: intrinsic size, paint, pointer handling, key handling; mod.rs dispatches.
                   tooltip.rs draws the tooltip bubble over any drawable
src/input.rs       hit-test (topmost in reverse paint order), hover chain diffing, press/release routing,
                   focus + tab order, keyboard -> Shoes key names, text editing via cosmic-text Editor
src/runtime.rs     Runtime: owns Doc + per-app view state (scroll, focus, hover, editors, popups); apply(msg);
                   handle(req) -> reply; emits events into the Outbox; pushes layouts. Shared by window.rs and
                   headless.rs. runtime/repaint.rs (a window's partial repaint and its check), runtime/startup.rs
                   (system fonts load on their own thread), runtime/stats.rs (SCARPE_NATIVE_STATS)
src/window.rs      winit 0.30 ApplicationHandler; one Window + softbuffer Surface per App; ControlFlow::Wait;
                   stdin reader thread -> EventLoopProxy<UserEvent>, one wake per batch of lines;
                   window/pacing.rs holds floods of frames to the display's refresh rate
src/headless.rs    same Runtime with offscreen pixmaps; main thread reads stdin directly
src/automation.rs  req ops that synthesise input (click, mouse, type, key, wheel), layout dump, snapshot, pixel
src/dialogs.rs     rfd message/file dialogs; in-window modal for `ask` and `ask_color`
```

Stack: tiny-skia 0.12, cosmic-text 0.19, swash 0.2, winit 0.30.x (not the 0.31 beta), softbuffer 0.4,
image 0.25 (png jpeg gif bmp), serde/serde_json, rfd 0.17, arboard, and objc2 0.6 on macOS (already
in the tree through softbuffer and rfd). Rust 1.93 is installed and the crate asks for 1.89; do not
require a newer toolchain. `[profile.dev.package."*"] opt-level = 3`, since a debug frame is about
60 times slower without optimised dependencies.

Hard-won API notes (from research 07):
- cosmic-text's default families do not exist on macOS: call `db_mut().set_sans_serif_family`,
  `set_serif_family`, `set_monospace_family` at startup.
- `Buffer::render` is not HiDPI-correct: iterate `layout_runs` and call `glyph.physical((x*s, y*s), s)`.
- `set_rich_text` drops spans whose Attrs equal the defaults: give every span a non-zero `metadata`.
- `Buffer::hit` always returns a cursor: bounds-check before treating it as a link hit.
- `Action::Motion` does not manage selection; set `Selection` yourself for shift/plain arrows.
- On macOS create windows with `.with_active(false)` in automated runs and never steal focus in
  headless tests.
- softbuffer on macOS copies the frame on present: redraw only when dirty.
- softbuffer tags macOS frames DeviceRGB; the window is given the same colour space, or CoreAnimation
  colour-matches every frame on the CPU (2.4 ms of a 2.7 ms present at 1200x1000, native/PERF.md).
- Any code that writes pixels goes through `Canvas` (`base()`, `blit()`, `fill_px()`), and any new
  layer pixmap through `Canvas::at(.., canvas.origin)`, or a partial repaint draws it offset.

### Look and feel (beautiful by default)

Default background white, text #1d1d1f, system sans (San Francisco on macOS) at the Shoes sizes
(banner 48, title 34, subtitle 26, tagline 18, caption 14, para 12, inscription 10). Buttons: rounded
6 px, subtle vertical gradient, 1 px border, soft shadow, pressed and hover states. Inputs: white,
1 px #c7c7cc border, 6 px radius, blue focus ring. Check/radio: drawn, accent blue (#0a84ff) when on.
Links: #0066ee, underline, #003399 on hover, pointer cursor. Buttons, checks, radios and list boxes
also show the pointing hand and text fields an I-beam; a drawable's own `cursor` style
(`:hand_cursor`, `:text_cursor`, `:watch_cursor`, `:arrow_cursor`) wins, and the App's `cursor`
covers the rest. Everything antialiased. Spike A
(`native/research/07_spike_skia.md`, scene PNG) is the reference look.

## 8. Testing

Three levels, all headless, all deterministic with `--fonts bundled`:

1. **Rust unit/integration tests** (`cd native && cargo test --release`): dims/colors parsing,
   layout math on hand-built docs, protocol fixtures (feed NDJSON, assert layout and events),
   golden PNGs with a small tolerance (`UPDATE_GOLDEN=1` rewrites them; look at them before
   committing), partial-repaint checks (`tests/damage.rs`), and frame benches (`tests/bench.rs`,
   ignored unless asked for).
2. **Ruby integration tests** (`test/native/`, minitest, `rake native_test`): real Lacci against the
   real child (`end_to_end_test.rb`: headless, bundled fonts, the binary rebuilt first when a crate
   source is newer), and against a scripted fake child (`fake_child.rb`) for exact wire checks and
   failure paths such as crashes and signals. Tests that open real windows run only with
   `SCARPE_NATIVE_WINDOWED_TESTS=1`. `rake package_test` builds and boots a real packaged app headless.
3. **The spec suite** (`spec/`, section 9), run by `spec/run`.

Native test API available inside Shoes-Spec test code (`lib/scarpe/native/shoes_spec.rb`),
on top of the Niente-compatible finders and proxies (`button`, `para`, `edit_line`, plural forms,
`drawable(Class)`, selectors `"@ivar"`, `"$global"`, `"id:N"`):

| method | does |
|---|---|
| `proxy.trigger_click` / `trigger_hover` / `trigger_leave` / `trigger_change(v)` | Shoes-Spec compat. `trigger_click` goes through Rust (`req click {id}`), so it proves layout and hit-testing |
| `click_on(proxy_or_text)`, `click_at(x, y, button: 1)` | synthetic click through the real path |
| `hover_at(x, y)`, `move_mouse(x, y)` | pointer motion |
| `type_text(str)`, `press_key(name)` | keyboard into the focused widget / app |
| `wheel(dy, x:, y:)` | scroll; without `x:`/`y:` at the middle of the first window |
| `layout_of(proxy)` | `Rect(x, y, w, h)` in window coordinates |
| `layout_tree` | array of hashes from `req layout`, Symbol keys |
| `snapshot(name)` | writes `spec/results/snapshots/<name>.png` (or `SCARPE_NATIVE_SNAPSHOT_DIR`, or an absolute path), returns the path |
| `pixel_at(x, y)` | `[r, g, b, a]` |
| `wait_frames(n = 1)`, `advance(seconds)` | pump the loop. The clock is frozen in spec runs, so `advance` steps from one timer deadline to the next and fires exactly the timers due |
| `resize_window(w, h)` | resize the window |
| `focused_drawable` | proxy or nil |
| `stub_dialog(kind, value)`, `dialogs_seen` | answer the next `kind` builtin with `value`; every `[kind, message]` asked for |

A handler that raises while test code is clicking or advancing fails the test instead of being logged.

`scarpe peek APP.rb [--size WxH] [--scale 2] [--wait SECS] [--click TEXT | --click-at X,Y]
[--type TEXT] [--key NAME] [--wheel DY[,X,Y]] [--window N | --app ID] [--shot OUT.png] [--layout]`
runs an app headless, performs the steps in order from the first heartbeat, prints one line per
click, wheel, window, shot and laid-out node, and exits (1 when a step failed or no app started). With no
`--shot` and no `--layout` it saves `peek.png` in the current directory. It is the quick "look and
click" tool for humans and agents. `--window N` (counting from 1 in `Shoes.APPS`) or `--app ID`
sends every later step to that window.

Automation aimed at one drawable (`trigger_click`, `layout_of`, `trigger_hover`) goes to the window
that drawable is in; Rust also routes `click {id}` to the drawable's own app, whatever `app` says.

## 9. The spec suite (`spec/`)

The cases use Noah Gibbs' Shoes-Spec `.sspec` format, the one his display-agnostic test system
used, so any Scarpe display service can run them. `spec/README.md` is the writer's guide.

- `spec/manual/<group>/<entry-id>.sspec`: written from `native/research/manual_inventory.json`,
  one or more cases per manual entry, with YAML front matter
  (`manual: <id>`, `lines: [a, b]`, `testability: api|visual|interactive|dialog`, `display: any|native`,
  `ledger: <row>` when a ruling applies, and `expect: fail` with a `reason` where Scarpe is known wrong).
- `spec/shoes_spec/`: the cases imported from Noah's Shoes-Spec corpus that make a real assertion,
  regenerated by `spec/import_shoes_spec.rb`.
- `spec/examples.yml`: every example under `examples/` with its expected status and optional
  interaction steps; the runner smoke-tests each one (loads, renders non-blank, no Ruby error,
  no Rust panic), saves a snapshot and writes a gallery page.
- `spec/LEDGER.md`: every place where the manual, Shoes 3, Shoes 4, the examples and Lacci disagree,
  with the ruling. Default rule: the manual wins, unless a large body of working examples depends on
  the other behaviour, then accept both.
- `spec/run [--display native|niente] [--jobs N] [paths...]` runs cases in parallel, sandboxed
  (HOME, LOCALAPPDATA, cwd in a temp dir, dialogs stubbed, clipboard kept in a file), writes
  `spec/results/<display>.json` and prints a scoreboard. Exit code non-zero on failures.

At `877e262` (27 Sep 2026) the suite holds 978 cases: native 887 pass, 0 fail, 4 skip and 87
expected failures, each citing its ledger row; niente 488 pass. Examples on native: 305 pass, 23 fail
(dialog-only apps, blank timer apps, the network, scripts that never start an app), 89 skipped.

## 10. Lacci fixes this work depends on (each has a LEDGER row and a test)

All ten landed on 27 Sep 2026; `native/research/09_lacci_fixes.md` records each defect, ruling,
change and test.

1. `SubscriptionItem` fired every callback twice (`subscription_item.rb:89-91`): the generic rebind is gone.
2. `Shape` sent `shape_commands: []` then mutated it: it sends a `prop_change` with the full list after the block.
3. `prepend` reversed multiple children, and the display was not told positions: order fixed; the shim sends `index`.
4. `ListBox#choose` sent no `prop_change`; the `list_box { }` block was dropped: both fixed.
5. `link(click: proc)` never fired: it fires.
6. A builtin's `nil` answer was treated as "unhandled": the existing `@has_builtin_response` flag tells them apart.
7. `#rgb` hex expanded x16: it is x17. `rgb()` decides int vs float per component.
8. `ins` was aliased to inscription: it is the underline fragment (`Shoes::Ins`).
9. `Drawable#click`/`#release` on non-widgets bound nothing: they bind the event and send
   `prop_change {"has_click"=>true}` / `{"has_release"=>true}` so the display knows to route presses there.
10. Oval's third positional argument is a diameter (manual, Shoes 3, Shoes 4 agree; research 06).

The third wave's Lacci lane built its side of contracts a to e (section 4.5), the 600x500 "Shoes"
default, and a `clear` that keeps the slot's handlers and timers (ledger H9, B7).

## 11. Packaging

`scarpe package --native` (or `SCARPE_DISPLAY_SERVICE=native scarpe package`) builds a macOS `.app`,
and with `--dmg` a disk image (`lib/scarpe/package/native.rb`, docs/native_packaging.md): Traveling
Ruby, `lib`, `lacci/lib` and `scarpe-components/lib` copied from source (no gems, no webview), the
release binary stripped into `Contents/MacOS` and signed explicitly, a boot script that never loads
`scarpe/wv` and sets `SCARPE_DISPLAY_SERVICE=native`, and an ad-hoc signature on the whole bundle.
A button app is 32.4 MB (13.4 MB as a `.dmg`), or 17.7 MB with `--minimal`. Linux, Windows and
universal native packages are not built yet, and nothing is notarised.

Ruby speed in packaged apps (Nick's call, 27 Sep 2026). Two cheap wins, both measured before and after:

1. **YJIT on by default, after the first frame.** It helps method-heavy per-frame code such as
   `animate` handlers, but switched on at process start (`--yjit`, `RUBY_YJIT_ENABLE=1`) it made the
   first frame 22 to 57 ms later on a YJIT build of Ruby, while `RubyVM::YJIT.enable` at the first
   heartbeat cost nothing measurable. So `boot.rb` does that (`lib/scarpe/package/yjit.rb`), and
   `RUBY_YJIT_ENABLE=0` opts out. The bundled Traveling Ruby 3.4.7 is built without YJIT, so
   packaged apps run without it until the runtime has it.
2. **Precompiled bytecode for startup.** At package time the bundled Ruby compiles Lacci, the shim,
   scarpe-components, the app and the standard library files `require "scarpe"` loads, and boot
   hands them to `require` through `RubyVM::InstructionSequence.load_iseq` (the bootsnap hook;
   `lib/scarpe/package/bytecode.rb`). An instruction sequence keeps the path it was compiled for
   (`__FILE__`, `__dir__`, `require_relative`, backtraces), so each file is compiled for where the
   app will be installed (`/Applications/Name.app` unless `--install-dir`). Run from anywhere else,
   by another Ruby (`RUBY_REVISION`), or after a source changed (size, mtime), the app loads source.
   `SCARPE_BYTECODE=0` skips it for one launch. The target is cold start to first frame, which is
   the speed people feel: bytecode took `require "scarpe"` from 43 to 28 ms (docs/native_packaging.md).

Transpiling Ruby to Rust is out of scope: the DSL depends on `instance_eval`, `method_missing` and
open classes. The hot paths (layout, text, paint, hit-testing, input) are already Rust.

## 12. Clarifications from the Rust build

Where the sections above left a choice open, the Rust side does this. Lanes that disagree should
change the code and this list together.

- **Margins and relative sizes.** A relative width or height (a fraction, `"N%"`, a negative number,
  or a slot's default fill) sizes the margin box, so two `width: 0.5, margin: 10` flows share a row.
  A px size is the box itself, and margins add outside it.
- **Text in a flow** flows as a paragraph (section 6). Text that does not (centred, right-aligned,
  justified, trimmed, or given a width or height) is a box: as wide as its longest line
  (max-content) if that fits in the rest of the row, else it starts a new row and wraps at the
  full width there. Text with `align: center/right` fills the rest of the row so the alignment
  shows. Positioned text (`left`/`top`) shrinks to fit the same way. `right:` and `bottom:`
  place from the far edges.
- **Widget** (a `Shoes::Widget` subclass) lays its children out as a flow; its default width is
  its parent's, like any slot. **Mask** is a slot in the flow, laid out like a flow; the slot
  holding it paints all its other contents (backgrounds included) through the alpha of what the
  mask draws, and the window shows through everywhere else (Shoes 3, `s3_canvas.c:531-613`).
- **Art geometry.** `star` follows Shoes 3 exactly (centred on left/top, first point straight
  down, radii outer/inner). `arrow` is centred on left/top, points right, is 0.8 x width tall with a
  head 0.42 x width long. `arc` sits in its (left, top, width, height) box like `oval` (Shoes 3
  centred it on left/top; the manual's "mimic oval" and Shoes 4 say box), sweeps clockwise from
  3 o'clock, and fills as a chord (`wedge: true` fills a pie). `rotate`, `scale` and `skew` from the
  draw context turn a shape about its top-left corner (manual 1857-1860, ledger E10, confirmed 27
  Sep 2026), or about its centre when the draw context says `transform: "center"` or the shape has
  `center: true`; positive `rotate` turns counter-clockwise. The Shoes 3 source defaults to the
  centre, so an example written for a centre pivot (`rotate_shapes.rb`) swings about its corner here.
  The draw context's `translate: [x, y]` (Lacci's running total) moves shapes before they turn.
  A shape's layout box is its transformed box, so hit-testing and the layout push follow.
  `cap` is `"curve"` (round), `"rect"` (flat, the default) or `"project"` (square, half the stroke
  width longer). Unset fill and stroke are black, strokewidth 1.
- **Shape blocks.** Art drawn inside a `shape` block joins the shape's path, measured from the
  shape's left/top: the group is filled once (nonzero winding) and stroked once with the shape's own
  fill and stroke, and turns as one (ledger E7, M21). The shape's layout box holds all of it.
- **Image canvases.** An Image with children (`image(w, h) { ... }`, ledger E9, contract c) lays them
  out inside its own box, like a flow, in image-local coordinates, and clips them to it. A blank
  canvas with no size of its own (only `left`/`top`) fills the rest of its line and its parent's
  height. Effects (`blur`, `glow`, `shadow`) are not drawn: the manual never documents them.
- **Gradients** follow Shoes 3: angle 0 runs top to bottom, 90 left to right, across the shape's
  box. A wire gradient without `angle` gets 0. Radial gradients are not drawn (Lacci's `gradient()`
  cannot ask for one).
- **Wheel.** `req wheel` takes `dy` in logical px with DOM sign: positive scrolls down (content
  moves up). The `wheel` event sent to subscription items carries `delta = -dy` (positive = up)
  and window coordinates. Scrolling a slot or the window also sends `scroll {id, top}`.
- **Hit-testing.** Nothing is hit outside the window, so moving the pointer to (-1, -1) leaves every
  drawable including the DocumentRoot. Backgrounds and borders never catch the pointer. A clipped
  slot's hidden part catches nothing.
- **Headless dialogs** reply with `cancelled: true` for everything but `alert`.
- **Windowed dialogs.** `alert`, `confirm` and the file/folder pickers are native (rfd); `ask` and
  `ask_color` draw an in-window modal (a text field, or twelve swatches) and reply when the user
  presses OK/Return (`cancelled: false`) or Cancel/Escape (`value: null, cancelled: true`; the shim
  turns a null `ask` into `""`).
- **`layout`** lists every laid-out node in paint order; each text fragment (Link, Strong, Em...)
  follows its Para as its own entry, with the box of its first line of glyphs and its text, and
  `click {id}` on a fragment clicks there. Fragments are hit-tested like drawables: a press inside
  one walks fragment, para, slots for `has_click`, and hover/leave include the fragments. **`frames`** replies with the number
  of frames painted so far. **`snapshot`** defaults to the app's scale (the window's, or `--scale`
  headless, else 1). **`click {text}`** also picks an item of an open list_box popup.
- **`para_hit {id, value}`** is sent while the pointer moves over a para (the character index), and
  with `value: null` when it leaves.
- **Focus.** Text fields show a focus ring whenever focused; buttons, checks, radios and list boxes
  only when focus came from the keyboard (tab or a `focus` message). On a focused list box Up and
  Down choose the previous and next item without opening the popup (manual 3221-3224); Return and
  Space open it.
- **`state: "disabled"`** greys a control out and it ignores the pointer, keys and tab;
  **`"readonly"`** fields can be focused, selected and copied but not edited.
- **Bundled fonts** (`--fonts bundled`) are Inter (sans, and the serif fallback) and Fira Mono
  (monospace), all OFL, in `native/assets/fonts`. With system fonts on macOS the sans face is San
  Francisco, and text under 20px gets a little extra tracking to stand in for SF Text's optical size,
  which cosmic-text never selects. The bundled fonts have no emoji.
- **`sub` and `sup`** draw x-small, 10 px below or above the baseline.
- **Closing a window** sends `closed {app}`; the window goes at once, and if no `quit` follows
  within 3 seconds the process exits by itself. `--exit-after SECS` closes every window that way
  when the time is up, so a Ruby app quits cleanly (headless it is a hard stop). It and `--inactive`
  (or `SCARPE_NATIVE_INACTIVE=1`) open windows without activating the app or taking keyboard focus.
- **Ghost windows** (`--ghost`; the shim passes it when `SCARPE_NATIVE_GHOST` is set, and the
  child reads the variable too) are real windows that lay out, paint and present frames where
  nobody can see or touch them, so windowed tests, benches and agents can run the real window path
  on a machine someone is using. On macOS a ghost is fully transparent (alphaValue 0), lets every
  mouse event through, has no shadow, stays out of Mission Control and the window cycle, and goes
  on screen only once it reads back as invisible; the app never activates and has no Dock icon.
  Elsewhere it opens off screen (Wayland ignores that). Snapshots and `pixel` read the app's own
  pixmap, so they work the same. The fourth build wave's ghost lane adds the flag; headless stays
  the default for tests.
- **Backgrounds and borders** fill their slot less the edges they name: `left`/`top`/`right`/`bottom`
  place them, a missing `width` or `height` runs to the far edge (`top: 50` covers from 50 down),
  and margins inset them.
- **`wrap`**: `"word"` (the default) breaks lines only between words, and a word too long for
  its line runs past it, as under Shoes 3's PANGO_WRAP_WORD; `"char"` breaks anywhere;
  `"trim"` keeps a para on one line and cuts it off with an ellipsis at the para's own box
  (manual 1552-1556). The ellipsis takes the style of the para's first run.
- **Button icons** (Shoes 3.3 `icon:`, ledger G7): a 16 px image beside the label, on the side
  `icon_pos` names (`left`, the default, `right`, `top` or `bottom`); the button grows to hold both.
  The shim sends `icon` as an absolute path.
- **App `opacity`** (0.0 to 1.0) makes the whole window see-through: NSWindow's alphaValue on macOS
  (other platforms stay opaque), and snapshots and `pixel` keep that share of every pixel's alpha.
- **Tooltips.** A drawable's `tooltip` text (Shoes 3.3; Lacci gives every drawable the style) shows
  in a bubble below the pointer once it rests on that drawable: at once headless, so snapshots are
  deterministic, and after 600 ms in a window. A press hides it until the pointer moves on.
- **Partial repaints.** A window keeps its last frame and repaints only the rects of nodes whose box,
  props, text or widget state changed (`paint::damage`). Anything it cannot bound repaints the whole
  frame: the first frame, a new size or scale, scrolling, a popup, modal or tooltip, a change of
  paint order, and art under rotate, scale, skew or translate. Headless pictures and snapshots are
  always painted whole. A node must never paint outside `paint::damage::paint_bounds`: code that
  makes a node draw further (a new transform, a bigger shadow) grows that function too, or
  `SCARPE_NATIVE_DAMAGE=check` will say so. A masked slot's layers cover only the repainted rect,
  so masks repaint in part like anything else.
- **Looks-only changes keep the layout.** A check's `checked`, a field's echoed `text`, a shape's
  `fill`, `stroke` or `cap`, a background's or border's `fill`, `stroke`, `strokewidth` or `curve`,
  a bar's `fraction` and a para's cursor and marker repaint without laying anything out again (`runtime.rs` `changes_only_looks`).
- **Para `cursor` and `marker`** count from the end when negative (`-1` sits after the last
  character, as Shoes 3 editors use it). The caret takes the text's colour, so it shows on dark
  backgrounds.

## 13. Environment

| variable | effect |
|---|---|
| `SCARPE_DISPLAY_SERVICE=native` | selects this backend (`scarpe --native` and `scarpe peek` set it) |
| `SCARPE_NATIVE_BIN` | the child binary to run instead of `native/target/release/scarpe-native` |
| `SCARPE_NATIVE_HEADLESS` | passes `--headless` unless empty, `0`, `false` or `no` (`scarpe peek` sets it) |
| `SCARPE_NATIVE_ARGS` | extra child arguments, e.g. `--fonts bundled` or `--exit-after 3` |
| `SCARPE_NATIVE_INACTIVE` | windows open without activating the app or taking keyboard focus |
| `SCARPE_NATIVE_GHOST` | windows are ghosts: real, but invisible and click-through, and the app never activates (section 12) |
| `SCARPE_NATIVE_TRACE` | prints every NDJSON line both ways to stderr (Ruby side; the child's `--trace` does it from Rust) |
| `SCARPE_NATIVE_LOG_LEVEL` | `debug`, `info`, `warn` (default; `debug` under `SCARPE_DEBUG`) or `error` |
| `SCARPE_NATIVE_CACHE` | where downloaded images and fonts are kept |
| `SCARPE_NATIVE_SNAPSHOT_DIR` | where relative `snapshot(name)` paths go (default `spec/results/snapshots`) |
| `SCARPE_NATIVE_WINDOWED_TESTS` | lets `rake native_test` open real, inactive windows |
| `SCARPE_NATIVE_STATS` | a directory: each process writes where its time went (`ruby.json`, `rust.json`) as it exits (native/PERF.md) |
| `SCARPE_NATIVE_DAMAGE` | `off` repaints every window frame whole; `check` also paints each one whole and reports any pixel a partial repaint got wrong (headless too) |
| `CARGO` | the cargo that builds a stale dev binary (default: on `PATH`, else `~/.cargo/bin/cargo`) |
| `SCARPE_BYTECODE=0` | a packaged app loads source instead of its precompiled bytecode |
| `RUBY_YJIT_ENABLE=0` | a packaged app leaves YJIT off (it turns it on after the first frame when the Ruby has it) |
