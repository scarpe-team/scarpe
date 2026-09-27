# Scarpe Native: design

Status: v1 design, 27 Sep 2026. This document is the contract every builder codes against.
If the code and this document disagree, fix one of them in the same change.

Research behind every decision lives in `native/research/` (01 contract, 02 visuals, 03 manual
inventory, 04 examples and specs, 05 integration, 06 discrepancy ledger seed, 07/08 stack spikes).

## 1. Goal

A display service for Scarpe that draws Shoes apps natively with Rust. No HTML, no webview.
It must be fast, beautiful by default, packageable as one binary, and testable headlessly
by "looking" (PNG snapshots, layout dumps) and "clicking" (synthetic input through the same
hit-testing path a real mouse uses).

Selected with `SCARPE_DISPLAY_SERVICE=native` (or `scarpe --native app.rb`).

## 2. Shape: Ruby thinks, Rust draws

```
 Ruby process                                   Rust process (native/target/release/scarpe-native)
 ------------                                   -------------------------------------------------
 app code + Lacci (lacci/)                      stdin reader thread --> EventLoopProxy / channel
 Scarpe::Native::DisplayService (the shim)      Runtime
   create_display_drawable_for  --create-->       Doc: id -> Node {kind, props, parent, children}
   bus: prop_change/destroy/...  --props-->       layout (Shoes stack/flow engine, logical px)
   builtin (sync)               --req/reply-->    paint (tiny-skia + cosmic-text) -> softbuffer | PNG
   pump (at_exit): IO.select,   <--event--        input: hit-test, hover, focus, keys, text editing
     timers, heartbeat, flush   <--reply--        dialogs (rfd), automation ops (tests, peek)
```

- The child speaks NDJSON on stdin/stdout. Stdout carries protocol only; logs go to stderr.
- All Procs and user blocks stay in Ruby. Only data crosses.
- Timers (`animate`, `every`, `timer`) tick in the Ruby pump. Rust has no timer logic.
- A Rust panic or exit is reported by the shim as a Ruby error with the child's stderr tail.
  The Ruby side survives handler exceptions (log and continue), so a bad handler never blanks the window.

Why a child process and not a native extension: no GVL puzzles around winit's main-thread loop,
crash isolation, a build that does not depend on the Ruby version, and the same binary serves
the window, the headless test runner and packaging. Noah designed the display service to live
out of process; the relay (`lib/scarpe/wv/webview_relay_*`) is the precedent, but it is bit-rotted
and its framing is wrong, so we copy its shape and not its code.

## 3. Repository layout

```
native/                         Rust crate `scarpe-native` (bin + lib, so tests can use the lib)
  Cargo.toml
  DESIGN.md                     this file
  assets/fonts/                 bundled Inter (deterministic mode, OFL)
  src/...                       see section 7
  tests/                        Rust integration tests (protocol fixtures, golden PNGs)
lib/scarpe/native.rb            registers the service (section 5.1)
lib/scarpe/native/              the Ruby shim
  display_service.rb            Shoes::DisplayService subclass
  child.rb                      spawn/find/build the binary, NDJSON transport, request/reply
  normalize.rb                  Ruby value -> wire value (section 5.3)
  pump.rb                       at_exit event loop, timers, heartbeat, flush
  shoes_spec.rb                 Shoes::Spec implementation + native test API (section 8)
  peek.rb                       `scarpe peek` driver
exe/scarpe                      gains `--native` and the `peek` subcommand
spec/                           the consolidated Shoes spec suite (section 9)
test/native/                    Ruby integration tests for the backend (minitest)
```

## 4. Protocol v1 (NDJSON, UTF-8, one JSON object per line)

Every message has `"t"` (type). Integers are Drawable linkable ids (Ruby Integers, JSON numbers).

### 4.1 Ruby -> Rust

| t | fields | meaning |
|---|---|---|
| `hello` | `v` (=1), `pid` | first line; Rust answers `ready` |
| `create` | `id`, `kind` (sent class name, e.g. "Para", "Button", or the widget subclass name), `parent` (id or null), `index` (int or null = append), `widget` (bool), `props` {normalised} | new node. `kind:"App"` also carries `doc_root` (= id+1) and `owner` (id or null). DocumentRoot is created before App; Rust must accept that order |
| `props` | `id`, `props` {changes} | property changes. Unknown id: ignore silently (Para sends text_items before its create) |
| `destroy` | `id` | remove node and its whole subtree. Unknown id: ignore. Idempotent |
| `reparent` | `id`, `parent`, `index` | move node |
| `run` | `app` | the app is complete enough to show: open its window (or headless canvas) |
| `quit` | `app` (id or null = all) | close window(s); when none remain Rust exits 0 |
| `focus` | `id` | give keyboard focus to an input |
| `scroll_to` | `id`, `top` | set a scrollable slot's scroll offset |
| `font` | `path` (absolute) | register a font file; family name(s) become usable |
| `flush` | | end of a batch: Rust applies everything received, relayouts, redraws once |
| `req` | `req` (int), `op`, op fields | request that must get exactly one `reply` with the same `req` |

`req` ops:

| op | fields | reply `value` |
|---|---|---|
| `dialog` | `kind` (alert confirm ask ask_color ask_open_file ask_save_file ask_open_folder ask_save_folder), `message`, `default` | alert: null; confirm: bool; ask: String or null on cancel; ask_color: [r,g,b,a] or null; file/folder: path or null. `cancelled` bool alongside |
| `layout` | `app` (optional) | array of `{id, kind, x, y, w, h, visible, text?}` in window coordinates, paint order |
| `snapshot` | `path`, `app` (optional), `scale` (optional) | writes a PNG; value = `{path, w, h}` |
| `click` | `target`: `{id}` or `{text}` or `{x,y}`, `button` (1 default), `app` | synthesises press+release at the target's centre through the real input path. value = `{hit: id or null, x, y}`. Error if the target is not visible or something else is on top (value says what) |
| `mouse` | `action` (move down up), `x`, `y`, `button` | low-level pointer event through the real path |
| `type` | `text` | inserts text into the focused input as real key/IME events |
| `key` | `key` (Shoes name, e.g. "left", "return", "a", "control_a"), | synthesises a key press |
| `wheel` | `dy`, `x`, `y` | wheel event |
| `resize` | `app`, `w`, `h` | resize the window/canvas |
| `pixel` | `x`, `y`, `app` | `[r,g,b,a]` at logical point |
| `frames` | `n` | reply after n frames have been laid out and painted (sync point) |
| `focused` | | id of the focused input or null |
| `ping` | | `"pong"` |

Ordering guarantee: every `event` caused by a request is written before that request's `reply`.
Rust processes `req`s after an implicit flush of everything received before them.

### 4.2 Rust -> Ruby

| t | fields | shim action |
|---|---|---|
| `ready` | `v`, `version` | handshake done |
| `event` | `name`, `target` (id or null), `args` (array) | `Shoes::DisplayService.dispatch_event(name, target, *args)` |
| `mouse` | `state` [button, x, y] | `Shoes::DisplayService.mouse_state = state` |
| `para_hit` | `id`, `value` | `para_hit_cache[id] = value` (Integer keys) |
| `resize` | `app`, `w`, `h` | set the App's `@width`/`@height` ivars directly (no prop_change echo) |
| `scroll` | `id`, `top` | set the slot's `@scroll_top` directly |
| `closed` | `app` | user closed a window: destroy that app (all apps if it was the last) |
| `reply` | `req`, `value`, `error` (null or String), plus op extras like `cancelled` | answers a `req` |
| `log` | `level`, `msg` | forwarded to Shoes::Log |

### 4.3 Events Rust emits (exact names and args; see research 01 section 5)

| user action | event | target | args |
|---|---|---|---|
| click Button, Check, Radio, Image, Link | `click` | that id | `[]` (Check/Radio: Lacci toggles and echoes `checked`; Rust shows the echo, it does not toggle on its own) |
| edit EditLine / EditBox | `change` | that id | `[new_text]` on every edit. Lacci echoes `props {text}`: apply idempotently, keep caret |
| pick in ListBox | `change` | that id | `[item_string]` |
| pointer enters / leaves a drawable | `hover` / `leave` | that id | `[]`, on transitions only, for every drawable in the hovered chain |
| press / release on a drawable that has `has_click` / `has_release` true | `click` / `release` | that id | `[button, x, y]` window coordinates |
| SubscriptionItem `click`/`release` | same | item id | `[button, x, y]`, x/y relative to the item's parent slot. Fires for presses inside the parent slot unless an input widget or link consumed the press |
| SubscriptionItem `motion` | `motion` | item id | `[x, y, ctrl, shift]` (booleans), parent-relative, on pointer move inside the parent slot |
| SubscriptionItem `hover`/`leave` | same | item id | `[]` on entering/leaving the parent slot box |
| SubscriptionItem `keypress` | `keypress` | item id | `[key]`, see 4.4. Not sent while a text input has focus, except escape and modified keys |
| SubscriptionItem `wheel` | `wheel` | item id | `[delta, x, y]`, delta > 0 = up |

Mouse buttons are 1 = left, 2 = middle, 3 = right (manual numbering).

### 4.4 Key names (manual, research 06 ledger "keypress" rows)

- Printable characters: the String itself (`"a"`, `"A"`, `" "`, `"&"`).
- Return: `"\n"`. Tab `:tab`, Backspace `:backspace`, Delete `:delete`, arrows `:left :right :up :down`, `:home :end :page_up :page_down :escape :insert :f1`..`:f12`.
- Modifiers prefix in the order `control_`, `shift_`, `alt_` (shift only for non-printables). A modified printable key is a Symbol: `:control_a`, `:alt_q`. Modified return: `:control_enter`.
- On the wire a Symbol travels as a String starting with `":"` (`":left"`); Lacci's SubscriptionItem turns it back into a Symbol. Plain printable keys travel as themselves.
- On macOS, Cmd maps to `control_` as well (Shoes 3 did this), so `:control_q` works with Cmd-Q.

## 5. The Ruby shim

### 5.1 `lib/scarpe/native.rb`

Mirrors `lib/scarpe/wv.rb` and `lacci/lib/scarpe/niente.rb`: set `Shoes::Log.instance` once,
add the SegmentedFileLoader, push `:multi_app` into `Shoes::FEATURES`, set `Shoes::Spec.instance`,
then `Shoes::DisplayService.set_display_service_class(Scarpe::Native::DisplayService)`.
Must never load `scarpe/wv` (set-once globals collide).

### 5.2 DisplayService

- Spawns the child lazily on first `create_display_drawable_for` (the first DocumentRoot).
  Binary: `ENV["SCARPE_NATIVE_BIN"]`, else `native/target/release/scarpe-native` in the repo,
  else next to the packaged app. In a dev checkout, if the binary is missing or older than any
  file under `native/src`, run `cargo build --release` first (print one line to stderr).
- Headless when `ENV["SCARPE_NATIVE_HEADLESS"]` is set (passes `--headless` to the child).
- `create_display_drawable_for(name, id, props, parent_id:, is_widget:)`:
  registers a lightweight pairing object (`set_drawable_pairing`) so Shoes-Spec proxies work,
  handles that id's `prop_change`, `destroy`, `parent`, `focus`, `scroll_top` (through one `:any`
  subscription per event name, since Lacci's unsubscribe scans every subscription), computes
  `index` (position in the Lacci parent's children, or null), normalises props, queues `create`.
- Nil-target bus events: `init`, `run` (send `run` for `Shoes.APPS.last`; answer
  `custom_event_loop "return"` before `run` returns), `destroy` (app quit), `builtin`,
  `full_redraw_request` (ignore: Rust is retained).
- `builtin` is answered synchronously: send `req dialog`, block on the reply (queue incoming
  events meanwhile, dispatch them after), then `set_builtin_response(value)`. It must never leave
  a builtin unanswered (Lacci would pop an osascript dialog). `font` registers the absolute path.
  In headless mode dialogs never open: alert returns nil, confirm false, ask "" and file dialogs nil,
  unless a test stubbed them.
- Outgoing messages are buffered and written on `flush`; the pump flushes once per iteration and
  before every `req`. A Mutex guards writes (downloads call back on threads).

### 5.3 Normalisation (Ruby value -> wire value), in one place

- Colors: `[r,g,b,a]` ints 0-255 or floats 0-1 -> `{"rgba":[r,g,b,a]}` with ints 0-255 and alpha 0-255
  (float channels scale by 255 each, per component). `"#rgb"` (x17), `"#rrggbb"`, `"#rrggbbaa"`, named colours
  (`Shoes::COLORS` table) -> rgba. `Shoes::Colors::Gradient` or a color `Range` ->
  `{"gradient":[c1,c2],"angle":deg}`. Strings that are paths/URLs of images -> `{"image":"/abs/path"}`.
  `nil` stays null. Symbols -> the String.
- Paths (`url`, image backgrounds, `font`) -> absolute (`File.expand_path` against `Dir.pwd`).
  `http(s)` image URLs are downloaded once into a cache dir and sent as local paths.
- Ruby objects: `owner` -> its linkable id; `attach: Shoes::App` (the Window constant) -> `"window"`;
  `attach: drawable` -> its id; Procs -> dropped (and `has_block: true` where relevant).
- `shape_commands` must arrive complete (Lacci fix, section 10).
- Everything else via `JSON.generate`-safe conversion (Symbols to Strings, Ranges handled above).

### 5.4 Pump (the event loop)

`run` answers `custom_event_loop "return"`; an `at_exit` hook runs the pump (Niente/space_shoes pattern),
which is the only mode that supports `window()`:

```
loop until no apps remain or the child exited:
  timeout = time until the next timer deadline, capped at 50 ms
  IO.select([child_out], nil, nil, timeout) -> read and dispatch every complete message
  tick due timers: animate (frame starts at 0), every (count starts at 1), timer (one shot);
    honour `stopped` and destroyed items; timers can be created at any time
  dispatch "heartbeat" (nil target) at most every 50 ms (Shoes-Spec hooks run on the first one)
  flush
```

Handler exceptions are rescued per dispatch, logged with the app file/line, and the loop continues.

## 6. Layout rules (canonical)

Units are logical pixels (f32). Window content size = App `width` x `height` (Lacci default 480x420).

- **Dimensions** for width/height/left/top/margins: Integer = px; negative Integer = parent inner size
  minus |v|; Float between 0 and 1 exclusive = fraction of parent inner size (1.0 = 100%); String
  `"N%"` = percent; String `"Npx"` = px.
- **DocumentRoot** is a flow filling the window. If content is taller than the window, the root
  scrolls vertically (wheel + a thin overlay scrollbar).
- **Flow**: default width 100% of parent inner width. In-flow children are packed left to right;
  a child that does not fit on the current row starts a new row (unless the row is empty). Row height =
  tallest child; children top-aligned.
- **Stack**: children top to bottom, each on its own row, left-aligned. Default width: the
  remaining width on the current line of its parent (Shoes 3; in a stack parent that is the full
  inner width).
- Slot height = content height unless `height` given. `scroll: true` with a height clips and scrolls.
- **Text blocks** (para and family) with no width: in a stack, full inner width; in a flow,
  shrink-to-fit (max-content width capped at the remaining row width, wrapping at that width).
  Line height = 1.2 x size (plus `leading` if given).
- **Widgets** have intrinsic sizes (research 02 section 13): button = label + padding (min 22 high),
  edit_line 200x28, edit_box 200x108, list_box 160x28, progress 160x14, check/radio 18x18.
  Explicit width/height override.
- **Margins** add outside the box (`margin`, `margin_left/top/right/bottom`; arrays are
  [left, top, right, bottom]). `padding` (Scarpe extension) adds inside slots.
- **Absolute placement**: any child with `left` or `top` set, and every art shape, is out of flow,
  placed at (left, top) relative to its slot's content origin, does not affect siblings or slot height.
  `displace_left/top` shifts a laid-out element visually without affecting others.
- `hidden: true` removes the element from layout and painting.
- `attach: "window"` positions relative to the window instead of the slot.
- **Paint order** is tree order (creation order, respecting `index`): a background declared
  first paints under later siblings. Backgrounds and borders fill their slot's box
  (or their own width/height), with `curve` radius. Borders are stroked inside the box.

## 7. Rust crate

```
src/main.rs        CLI: scarpe-native [--headless] [--scale F] [--fonts system|bundled] [--trace]
src/lib.rs         pub mods below
src/protocol.rs    serde types for 4.1/4.2; Outbox (buffered stdout writer, flush per message batch)
src/doc.rs         Doc { nodes: HashMap<Id, Node>, apps: Vec<AppState> }, Node { id, kind: Kind, props: Props,
                   parent, children }, Kind enum (App DocumentRoot Stack Flow Widget Mask Para TextDrawable Code Del Em
                   Strong Span Sub Sup Ins Link Button Check Radio EditLine EditBox ListBox Progress Slider Image Video
                   Background Border Rect Oval Line Arrow Star Arc Shape SubscriptionItem Unknown(String))
src/props.rs       typed getters over serde_json::Value: dim, color/paint, margin, f32, bool, str, text_items
src/style/         color.rs (Color, Paint = Solid | Linear{c1,c2,angle} | Image(path)), dim.rs, font.rs (size names, font string parse)
src/layout/        mod.rs: layout(doc, app, viewport) -> Layout { rects: HashMap<Id, Rect>, order: Vec<Id>, text: ... }
src/text/          fonts.rs (FontSystem: system or bundled; set sans/serif/mono families; `font` registration),
                   rich.rs (resolve Para text_items tree -> spans with Attrs + metadata id per span),
                   shape_cache.rs (cache Buffers keyed by content hash + width), raster.rs (own glyph rasteriser
                   with slight embolden, HiDPI via glyph.physical)
src/paint/         mod.rs (walk layout, clip, transforms), shapes.rs (rect oval line arrow star arc shape),
                   decor.rs (background, border), text.rs (draw shaped text, decorations, selection, caret)
src/elements/      one file per widget: button.rs check.rs radio.rs edit_line.rs edit_box.rs list_box.rs progress.rs
                   slider.rs image.rs video.rs. Each exposes: intrinsic size, paint, pointer handling, key handling
src/input.rs       hit-test (topmost in reverse paint order), hover chain diffing, press/release routing,
                   focus + tab order, keyboard -> Shoes key names, text editing via cosmic-text Editor
src/runtime.rs     Runtime: owns Doc + per-app view state (scroll, focus, hover, editors, popups); apply(msg);
                   handle(req) -> reply; emits events into the Outbox. Shared by window.rs and headless.rs
src/window.rs      winit 0.30 ApplicationHandler; one Window + softbuffer Surface per App; ControlFlow::Wait;
                   stdin reader thread -> EventLoopProxy<UserEvent>
src/headless.rs    same Runtime with offscreen pixmaps; main thread reads stdin directly
src/automation.rs  req ops that synthesise input (click, mouse, type, key, wheel), layout dump, snapshot, pixel
src/dialogs.rs     rfd message/file dialogs; in-window modal for `ask` and `ask_color` fallback
```

Stack: tiny-skia 0.12, cosmic-text 0.19, swash 0.2, winit 0.30.x (not the 0.31 beta), softbuffer 0.4,
image 0.25 (png jpeg gif bmp), serde/serde_json, rfd 0.17, arboard. Rust 1.93 is installed; do not
require a newer toolchain. `[profile.dev.package."*"] opt-level = 3`.

Hard-won API notes (from research 07, spike code in the session scratchpad `spikes/a/src`):
- cosmic-text's default families do not exist on macOS: call `db_mut().set_sans_serif_family`,
  `set_serif_family`, `set_monospace_family` at startup.
- `Buffer::render` is not HiDPI-correct: iterate `layout_runs` and call `glyph.physical((x*s, y*s), s)`.
- `set_rich_text` drops spans whose Attrs equal the defaults: give every span a non-zero `metadata`.
- `Buffer::hit` always returns a cursor: bounds-check before treating it as a link hit.
- `Action::Motion` does not manage selection; set `Selection` yourself for shift/plain arrows.
- On macOS create windows with `.with_active(false)` in automated runs and never steal focus in
  headless tests.
- softbuffer on macOS copies the frame on present: redraw only when dirty.

### Look and feel (beautiful by default)

Default background white, text #1d1d1f, system sans (San Francisco on macOS) at the Shoes sizes
(banner 48, title 34, subtitle 26, tagline 18, caption 14, para 12, inscription 10). Buttons: rounded
6 px, subtle vertical gradient, 1 px border, soft shadow, pressed and hover states. Inputs: white,
1 px #c7c7cc border, 6 px radius, blue focus ring. Check/radio: drawn, accent blue when on.
Links: #0066ee, underline, darker on hover, pointer cursor. Everything antialiased. Spike A
(`native/research/07_spike_skia.md`, scene PNG) is the reference look.

## 8. Testing

Three levels, all headless, all deterministic with `--fonts bundled`:

1. **Rust unit/integration tests** (`cargo test`): dims/colors parsing, layout math on hand-built docs,
   protocol fixtures (feed NDJSON, assert layout and events), golden PNGs with a small tolerance.
2. **Ruby integration tests** (`test/native/`, minitest, `rake native_test`): real Lacci against the
   real child (`end_to_end_test.rb`: headless, bundled fonts, the binary rebuilt first when a crate
   source is newer), and against a scripted fake child (`fake_child.rb`) for exact wire checks and
   failure paths such as crashes and signals. Tests that open real windows run only with
   `SCARPE_NATIVE_WINDOWED_TESTS=1`.
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
| `wheel(dy, x:, y:)` | scroll |
| `layout_of(proxy)` | `Rect(x, y, w, h)` in window coordinates |
| `layout_tree` | array of hashes from `req layout` |
| `snapshot(name)` | writes `spec/results/snapshots/<name>.png` (or an absolute path), returns the path |
| `pixel_at(x, y)` | `[r, g, b, a]` |
| `wait_frames(n = 1)`, `advance(seconds)` | pump the loop (timers fire, events dispatch) |
| `focused_drawable` | proxy or nil |
| `stub_dialog(kind, value)` | answer the next `kind` builtin with `value` |

`scarpe peek APP.rb [--size WxH] [--scale 2] [--wait SECS] [--click TEXT | --click-at X,Y]
[--type TEXT] [--key NAME] [--shot OUT.png] [--layout]` runs an app headless, performs the steps in
order, and exits. It is the quick "look and click" tool for humans and agents.

## 9. The spec suite (`spec/`)

- `spec/manual/<section>/<entry-id>.sspec`: generated from `native/research/manual_inventory.json`,
  one or more cases per manual entry, in Noah's `.sspec` format with YAML front matter
  (`manual: <id>`, `lines: [a, b]`, `testability: api|visual|interactive|dialog`, `display: any|native`,
  `ledger: <row>` when a ruling applies).
- `spec/examples.yml`: every example under `examples/` with its expected status and optional
  interaction steps; the runner smoke-tests each one (loads, renders non-blank, no Ruby error,
  no Rust panic) and saves a snapshot for the gallery.
- `spec/LEDGER.md`: every place where the manual, Shoes 3, Shoes 4, the examples and Lacci disagree,
  with the ruling. Default rule: the manual wins, unless a large body of working examples depends on
  the other behaviour, then accept both.
- `spec/run [--display native|niente] [--jobs N] [paths...]` runs cases in parallel, sandboxed
  (HOME, LOCALAPPDATA, cwd in a temp dir, dialogs stubbed), writes `spec/results/<display>.json`
  and prints a scoreboard. Exit code non-zero on failures.

## 10. Lacci fixes this work depends on (each gets a LEDGER row and a test)

1. `SubscriptionItem` fires every callback twice (`subscription_item.rb:89-91`): delete the generic rebind.
2. `Shape` sends `shape_commands: []` then mutates it: send a `prop_change` with the full list after the block.
3. `prepend` reverses multiple children, and the display is not told positions: fix order; shim sends `index`.
4. `ListBox#choose` sends no `prop_change`; `list_box { }` block dropped: fix both.
5. `link(click: proc)` never fires: make it fire.
6. Builtin `nil` answer is treated as "unhandled": distinguish via the existing `@has_builtin_response` flag.
7. `#rgb` hex expands x16: must be x17. `rgb()` decides int vs float per component.
8. `ins` is aliased to inscription: make it the underline fragment (`Shoes::Ins`).
9. `Drawable#click`/`#release` on non-widgets bind nothing: bind the event and send
   `prop_change {"has_click"=>true}` / `{"has_release"=>true}` so the display knows to route presses there.
10. Oval third positional argument is a diameter (manual, Shoes 3, Shoes 4 agree; research 06).

## 11. Packaging

`scarpe package` gains a native path: bundle the release binary into the app (macOS: `Contents/MacOS`,
signed explicitly), drop `require 'scarpe/wv'` from the boot script, set `SCARPE_DISPLAY_SERVICE=native`
(the packager currently sets the dead `SCARPE_DISPLAY`), skip WebKitGTK/WebView2 checks.

Ruby speed in packaged apps (Nick's call, 27 Sep 2026). Two cheap wins, both measured before and after:

1. **YJIT on by default.** The packaged launcher starts Ruby with `--yjit` (or `RUBY_YJIT_ENABLE=1`).
   It ships inside CRuby; it helps method-heavy per-frame code such as `animate` handlers.
2. **Precompiled bytecode for startup.** At package time, compile Lacci, the shim and the app with
   `RubyVM::InstructionSequence.compile_file(...).to_binary` and load them with `load_from_binary`
   at boot (the bootsnap trick), falling back to source on any version mismatch. The target is cold
   start to first frame, which is the speed people feel.

Transpiling Ruby to Rust is out of scope: the DSL depends on `instance_eval`, `method_missing` and
open classes. The hot paths (layout, text, paint, hit-testing, input) are already Rust.

## 12. Clarifications from the Rust M1 build

Where the sections above left a choice open, the Rust side does this. Lanes that disagree should
change the code and this list together.

- **Margins and relative sizes.** A relative width or height (a fraction, `"N%"`, a negative number,
  or a slot's default fill) sizes the margin box, so two `width: 0.5, margin: 10` flows share a row.
  A px size is the box itself, and margins add outside it.
- **Text in a flow** is as wide as its longest line (max-content). If that does not fit in the rest
  of the row and the row is not empty, it starts a new row and wraps at the full width there.
  Text with `align: center/right` fills the rest of the row so the alignment shows. Positioned
  text (`left`/`top`) shrinks to fit the same way. `right:` and `bottom:` place from the far edges.
- **Widget** (a `Shoes::Widget` subclass) lays its children out as a flow; its default width
  fills the rest of the line, like a stack. **Mask** is not drawn yet.
- **Art geometry.** `star` follows Shoes 3 exactly (centred on left/top, first point straight
  down, radii outer/inner). `arrow` is centred on left/top, points right, is 0.8 x width tall with a
  head 0.42 x width long. `arc` sits in its (left, top, width, height) box like `oval` (Shoes 3
  centred it on left/top; the manual's "mimic oval" and Shoes 4 say box), sweeps clockwise from
  3 o'clock, and fills as a chord (`wedge: true` fills a pie). `rotate`, `scale` and `skew` from the
  draw context turn a shape about its top-left corner (manual 1857-1860, ledger E10), or about its
  centre when the draw context says `transform: "center"` or the shape has `center: true`; positive
  `rotate` turns counter-clockwise. The draw context's `translate: [x, y]` (Lacci's running total)
  moves shapes before they turn. A shape's layout box is its transformed box, so hit-testing follows.
  `cap` is `"curve"` (round), `"rect"` (flat, the default) or `"project"` (square, half the stroke
  width longer). Unset fill and stroke are black, strokewidth 1.
- **Gradients** follow Shoes 3: angle 0 runs top to bottom, 90 left to right, across the shape's
  box. A wire gradient without `angle` gets 0.
- **Wheel.** `req wheel` takes `dy` in logical px with DOM sign: positive scrolls down (content
  moves up). The `wheel` event sent to subscription items carries `delta = -dy` (positive = up)
  and window coordinates. Scrolling a slot or the window also sends `scroll {id, top}`.
- **Hit-testing.** Nothing is hit outside the window, so moving the pointer to (-1, -1) leaves every
  drawable including the DocumentRoot. Backgrounds and borders never catch the pointer.
- **Headless dialogs** reply with `cancelled: true` for everything but `alert`.
- **Windowed dialogs.** `alert`, `confirm` and the file/folder pickers are native (rfd); `ask` and
  `ask_color` draw an in-window modal (a text field, or twelve swatches) and reply when the user
  presses OK/Return (`cancelled: false`) or Cancel/Escape (`value: null, cancelled: true`).
- **`layout`** lists every laid-out node in paint order; each text fragment (Link, Strong, Em...)
  follows its Para as its own entry, with the box of its first line of glyphs and its text, and
  `click {id}` on a fragment clicks there. Fragments are hit-tested like drawables: a press inside
  one walks fragment, para, slots for `has_click`, and hover/leave include the fragments. **`frames`** replies with the number
  of frames painted so far. **`snapshot`** defaults to the app's scale (the window's, or `--scale`
  headless, else 1). **`click {text}`** also picks an item of an open list_box popup.
- **`para_hit {id, value}`** is sent while the pointer moves over a para (the character index), and
  with `value: null` when it leaves.
- **Focus.** Text fields show a focus ring whenever focused; buttons, checks, radios and list boxes
  only when focus came from the keyboard (tab or a `focus` message).
- **`state: "disabled"`** greys a control out and it ignores the pointer, keys and tab;
  **`"readonly"`** fields can be focused, selected and copied but not edited.
- **Bundled fonts** (`--fonts bundled`) are Inter (sans, and the serif fallback) and Fira Mono
  (monospace), all OFL, in `native/assets/fonts`. With system fonts on macOS the sans face is San
  Francisco, and text under 20px gets a little extra tracking to stand in for SF Text's optical size,
  which cosmic-text never selects.
- **Closing a window** sends `closed {app}`; the window goes at once, and if no `quit` follows
  within 3 seconds the process exits by itself. `--exit-after SECS` closes every window that way
  when the time is up, so a Ruby app quits cleanly (headless it is a hard stop). It and `--inactive`
  (or `SCARPE_NATIVE_INACTIVE=1`) open windows without activating the app or taking keyboard focus.
- **Backgrounds and borders** fill their slot less the edges they name: `left`/`top`/`right`/`bottom`
  place them, a missing `width` or `height` runs to the far edge (`top: 50` covers from 50 down),
  and margins inset them.
- **`wrap: "trim"`** keeps a para on one line and clips it at the para's own box (no ellipsis yet).
- **Para `cursor` and `marker`** count from the end when negative (`-1` sits after the last
  character, as Shoes 3 editors use it). The caret takes the text's colour, so it shows on dark
  backgrounds.

## 13. Environment

| variable | effect |
|---|---|
| `SCARPE_DISPLAY_SERVICE=native` | selects this backend (`scarpe --native` sets it) |
| `SCARPE_NATIVE_BIN` | the child binary to run instead of `native/target/release/scarpe-native` |
| `SCARPE_NATIVE_HEADLESS` | passes `--headless` (`scarpe peek` sets it) |
| `SCARPE_NATIVE_ARGS` | extra child arguments, e.g. `--fonts bundled` or `--exit-after 3` |
| `SCARPE_NATIVE_INACTIVE` | windows open without activating the app or taking keyboard focus |
| `SCARPE_NATIVE_TRACE` | prints every NDJSON line both ways to stderr (Ruby side) |
| `SCARPE_NATIVE_LOG_LEVEL` | `debug`, `info`, `warn` (default) or `error` |
| `SCARPE_NATIVE_CACHE` | where downloaded images and fonts are kept |
| `SCARPE_NATIVE_SNAPSHOT_DIR` | where relative `snapshot(name)` paths go (default `spec/results/snapshots`) |
| `SCARPE_NATIVE_WINDOWED_TESTS` | lets `rake native_test` open real, inactive windows |
