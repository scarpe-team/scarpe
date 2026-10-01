# Scarpe Native: design

Status: v1.2, 28 Sep 2026: the w10 scarpe lane added programs in a process of their own
(`Shoes.run_program`, 5.5), `Shoes.on_error` and the Shoes console (5.6), and Nick's Q10 ruling
(section 6). v1.1, 27 Sep 2026, after the fourth build wave merged and the orchestrator ruled Q1 to Q8
(under "Rulings on the questions" in `spec/LEDGER.md`, Q8 on `clear` and timers also in 5.4; Nick
may overrule any of them). This document is the contract every builder codes against. If the
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
                                art and input, dialogs, relayout, text cache, screen readers,
                                benches (ignored)
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
  programs.rb                   Shoes.run_program's side in the app that runs a program (5.5)
  program_child.rb              and in the program: reports to the parent, stops when it goes
  log.rb                        Shoes::Log to stderr and the Shoes console
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
| `text_mode` | `mode` (`scarpe` or `shoes3`) | how text is sized and set from now on (Lacci's `Shoes.text_mode`, ledger M14): `shoes3` reads text sizes as points at 96 dpi and gives text blocks that name no face Arial; every window is laid out again. The shim sends it after `hello` when a program set it before its first window, and again whenever it changes |
| `flush` | | end of a batch: Rust applies everything received, relayouts, redraws once |
| `req` | `req` (int), `op`, op fields | request that must get exactly one `reply` with the same `req` |

`req` ops. Every op that acts on a window takes an optional `app`; without it Rust uses the app
that last ran or had input, else the first running one.

| op | fields | reply `value` |
|---|---|---|
| `dialog` | `kind` (alert confirm ask ask_color ask_open_file ask_save_file ask_open_folder ask_save_folder), `message`, `default`; for `ask`, optional `title` (a heading, and the title of a window of its own) and `secret` (typed as bullets), sent when the app gives them (ledger K1) | alert: null; confirm: bool; ask: String, or null on Cancel in a window (headless: `""`); ask_color: [r,g,b,a] or null; file/folder: path or null. `cancelled` bool alongside. The shim hands Lacci `""` for a cancelled ask either way (ledger K1, Q6) |
| `layout` | `app` | array of `{id, kind, x, y, w, h, visible, text?}` in window coordinates, rounded to 1/100, paint order; text fragments follow their para |
| `snapshot` | `path`, `app`, `scale` (default: the app's scale) | writes a PNG; value = `{path, w, h}` in pixels |
| `click` | `target`: `{id}` or `{text}` or `{x,y}`, `button` (1 default), `app` | synthesises press+release at the target's centre through the real input path. value = `{hit: id or null, x, y}`, `hit` being the drawable whose click block the press runs (the one with a block of its own, else the innermost slot whose `click` runs), or else what was hit. Error if the target is not visible, or a real press there would not reach it: a control or link on top, or above it a drawable that takes the press itself (a control, or one with a click block); an empty slot on top lets it through, as it lets a real press through (the value says what was hit). `{id}` goes to the drawable's own window whatever `app` says. `{text}` matches exact text first, then text that contains it, links included, and also picks an item of an open list_box popup |
| `mouse` | `action` (move down up), `x`, `y`, `button` | low-level pointer event through the real path |
| `type` | `text` | inserts text into the focused input as real key events, one character at a time |
| `key` | `key` (a Shoes name, e.g. "left", "\n", "a", ":control_a"; also `command_`, `cmd_`, `super_`, `ctrl_`, `option_` prefixes) | synthesises a key press |
| `wheel` | `dy`, `x`, `y` (optional) | wheel event, section 12 |
| `resize` | `w`, `h` | resize the window/canvas; Rust answers with a `resize` message too |
| `pixel` | `x`, `y` | `[r,g,b,a]` at logical point; error outside the window |
| `frames` | `n` | reply after n frames have been laid out and painted (sync point); value = frames painted so far |
| `focused` | | id of the focused input or null |
| `clipboard` | `text` (optional) | Shoes' `app.clipboard`: without `text`, the clipboard's text (`""` when empty); with it, `app.clipboard=`, replying null. The clipboard text fields cut and paste through: the system's in a window (arboard: macOS, Windows, X11, Wayland), a private one headless, or the file `SCARPE_CLIPBOARD_FILE` names |
| `para_hit` | `id` (a para's), `x`, `y` (window coordinates) | the index of the character under the point, as Pango's `xy_to_index` gives Shoes 3's `Para#hit`: the first of the line left of the text, the last past its end; null off the para's box (ledger F14) |
| `para_caret` | `id` (a para's) | `{left, top, height}` of the para's caret in whole pixels, measured from the content origin of the slot that scrolls the para (the window's when none does), so `top` compares with that slot's `scroll_top`; null when the para has no `text_cursor` (ledger F14) |
| `a11y` | `app`, `platform` (default false) | the accessibility tree as a screen reader meets it (section 12, "Screen readers"): the window's node with its `children`. Each node has `id` and `role` (AccessKit's, snake_case: `button`, `check_box`, `label`...) and, when set, `name`, `value`, `description`, `toggled`, `numeric` `{value, min, max}`, `expanded`, `selected`, `url`, `level`, `focused`, `disabled`, `read_only`, `modal`, `actions`, `bounds` `[x, y, w, h]` (window coordinates). `platform: true` in a macOS window reads what AppKit hands VoiceOver instead: `role`, `subrole`, `title`, `value`, `help`; elsewhere it is an error |
| `a11y_action` | `id` (a node's), `action` (click focus set_value expand collapse), `value` (for set_value), `app`; or `platform: true` with `name` (an element's title) | acts on the node as a screen reader does, through the path a click or key takes; the events it causes come first. Error when the node cannot do it (disabled, readonly, no such item). `platform: true` acts through AppKit in a macOS window |
| `ping` | | `"pong"` |

An unknown op, or one missing a field, gets a reply whose `error` says so.

Ordering guarantee: every `event` caused by a request is written before that request's `reply`.
Rust processes `req`s after an implicit flush of everything received before them.

### 4.2 Rust -> Ruby

| t | fields | shim action |
|---|---|---|
| `ready` | `v`, `version` | handshake done |
| `event` | `name`, `target` (id or null), `args` (array) | `Shoes::DisplayService.dispatch_event(name, target, *args)`; a ListBox `change` gets back the item whose `to_s` Rust sent |
| `mouse` | `app`, `state` [held, x, y] (held is 1 while the left button is down; window px, rounded) | `Shoes::DisplayService.mouse_state = state`, and the app's own in `app_mouse_states`: each app's `mouse` reads the pointer as it was last over its window, [0, 0, 0] before it ever was, as Shoes 3 keeps `app->mousex` |
| `para_hit` | `id`, `value` | `para_hit_cache[id] = value` (Integer keys) |
| `resize` | `app`, `w`, `h` (Integers) | set the App's `@width`/`@height` ivars directly (no prop_change echo) |
| `scroll` | `id`, `top` (Integer) | set the slot's `@scroll_top` directly |
| `layout` | `app`, `rects`: `[[id, x, y, w, h, scroll_h], ...]` | `Shoes::DisplayService.layout_cache[id] = [x, y, w, h, scroll_h]` (Integer keys; the shim defines the accessor if Lacci lacks it and deletes ids on destroy). Sent after every layout pass, before its frame is presented and before the reply of any request that caused it: every laid-out node on an app's first layout, then only those whose rect changed, sorted by id. Window logical px, rounded to 1/100; `scroll_h` is a slot's content height, padding included, else `h`. Art reports its transformed box. Destroyed ids are simply not sent again (contract a; ledger A4, C5) |
| `closed` | `app` | user closed a window: close that app, as `App#close` does (`quit {app}`, and it leaves `Shoes.APPS`), or every app if it was the last |
| `console` | `app` | Alt-/ was pressed in that app's window (Cmd-/ on a Mac, 4.4): `Shoes.show_console` (5.6). The app hears no keypress for it |
| `reply` | `req`, `value`, `error` (null or String), plus op extras like `cancelled` | answers a `req` |
| `log` | `level`, `msg` | forwarded to Shoes::Log (`scarpe-native` component) |

### 4.3 Events Rust emits (exact names and args; see research 01 section 5)

| user action | event | target | args |
|---|---|---|---|
| click Button, Check, Radio, Link | `click` | that id | `[]`, on release over the same drawable (Check/Radio: Lacci toggles and echoes `checked`; Rust shows the echo, it does not toggle on its own). Return or Space on a focused button, check or radio clicks it too (ledger G9) |
| edit EditLine / EditBox | `change` | that id | `[new_text]` on every edit. Lacci echoes `props {text}`: apply idempotently, keep caret. Echoes can trail later edits, so any text the field reported and has not seen echoed yet counts as an echo |
| Return in a focused EditLine (no Control, Option, Command or Shift) | `finish` | that id | `[]`, for `edit_line.finish = proc` (Shoes 3.2.15, ledger G16). An EditBox takes Return as a new line |
| pick in ListBox (popup, or Up/Down while focused) | `change` | that id | `[item_string]` |
| pointer enters / leaves a drawable | `hover` / `leave` | that id | `[]`, on transitions only, for every drawable in the hovered chain |
| press / release on a drawable that has `has_click` / `has_release` true | `click` / `release` | the innermost such id under the pointer: a text fragment's first, then the topmost drawable under the pointer that has one, so a label or icon with no block passes the press to a clickable shape beneath it (Shoes 3's `shoes_canvas_send_click2`, ledger E8). An image with a click block is heard this way too, and an empty slot over it passes the press on. A control on top keeps the press | `[button, x, y]` window coordinates, Integers |
| SubscriptionItem `click`/`release` | same | item id | `[button, x, y]` in window coordinates, like drawable clicks (ledger H3, Q4, contract g). Fires for presses inside the parent slot unless a control, text field or link consumed the press. Slots' events come before the drawable's own: the window's first, then inner slots, the topmost of two side by side first, as Shoes 3 runs a slot's block while the press walks down the canvas to what it lands on (ledger E8) |
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
- On the wire a Symbol travels as a String starting with `":"` (`":left"`); Lacci's SubscriptionItem turns it back into a Symbol. Plain printable keys travel as themselves, the colon key as `":"` (ledger H1).
- On macOS, Cmd is named `alt_`, as Shoes 3's Cocoa backend did (ledger H1, Q5 ruled 27 Sep 2026):
  Cmd-q arrives as `:alt_q`, which is what the example editors bind. In text fields Cmd still works
  like Control (copy, paste, select all, line ends, undo and redo); Option moves by words. The default app menu
  still quits on Cmd-Q before the app sees the key; Rust then reports every open window `closed`.
  The `key` op accepts `command_` (or `cmd_`, `super_`) for Cmd.
- `:alt_/` is Shoes' own (manual 2239-2240, ledger H10): Rust sends `console` for it (4.2) and
  neither a focused field nor a `keypress` block hears it, as Shoes 3's `shoes_app_keypress` opens
  its console for it first (`s3_app.c:773-776`). Alt-. and Alt-? still reach the app.

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
  Binary: `ENV["SCARPE_NATIVE_BIN"]`; else a packaged binary beside the running script or in
  `../MacOS`; else `scarpe-native` on `PATH`; else, only in a git checkout of Scarpe (`.git` and
  `native/Cargo.toml` at the root), `native/target/release/scarpe-native`, running
  `cargo build --release` first (one line to stderr) when it is missing or older than any file
  under `native/src`, `Cargo.toml` or `Cargo.lock`. An installed gem ships the crate (not
  `native/research` or `native/tests`) but never builds it at launch.
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
  `full_redraw_request` need nothing: Rust is retained. An app counts as open from its `run`, not
  its `create`: a `window` whose block raised never runs, so after the handler's error the shim
  sends `quit {app}` for it, forgets its drawables and takes it out of `Shoes.APPS`. One window
  closing while another is open (Rust's `closed`, or a `destroy` aimed at an App, which is what
  `App#close` sends, ledger A8) goes the same way; the last one quits everything.
- `builtin` is answered synchronously: a stubbed answer first, then a quiet answer when nobody can
  click (headless, or a Shoes-Spec run), else `req dialog`, blocking on the reply while incoming
  events queue for the pump. Then `set_builtin_response(value)`. It must never leave a builtin
  unanswered. `font` registers the absolute path; an unknown builtin logs a warning and answers nil.
  The quiet answers: alert nil, confirm false, ask `""`, ask_color and file dialogs nil. A cancelled
  `ask` in a window answers `""` too (ledger K1, Q6).
- Outgoing messages are buffered and written on `flush`; the pump flushes once per iteration, and a
  `req` writes the buffer ahead of itself. A Mutex guards writes (downloads call back on threads),
  and a post from another thread wakes the pump.
- If the child has not answered `hello` within 20 s of the pump's first step, the pump raises
  `ChildTimeout`. The clock starts there and not at the spawn, because the app body runs in
  between with the answer unread in the pipe, so a slow body is not a stuck child.

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
  `http(s)` image and font URLs are downloaded once into the user's own cache and sent as local
  paths; net/http loads on the first download only. A non-Image `url` with a scheme stays as it is.
  The cache is `SCARPE_NATIVE_CACHE`, else `~/Library/Caches/scarpe-native` on macOS,
  `scarpe-native` under `$XDG_CACHE_HOME` (default `~/.cache`) on Linux, or
  `%LOCALAPPDATA%\scarpe-native\cache` on Windows, and never the shared temp dir: a directory
  that is a link or someone else's is refused, and ours is kept 0700. An entry counts only as a
  plain file of the user's that starts like an image or font, else it is fetched again; a
  download goes to a new file and is renamed over the entry, so a link planted at either name is
  never followed. An https download never follows a redirect to plain http.
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
  hand what programs Shoes.run_program started said to their blocks (5.5), at most 500 items
  tick due timers: animate (frame starts at 0), every (count starts at 0, ledger I1), timer (one shot);
    honour `stopped` and destroyed items; timers can be created at any time; an `every` or `timer`
    shorter than a millisecond (0 included) waits one, as Shoes 3 clamps it; before such a
    next-turn timer runs, if changes went to Rust since, a `ping` settles the layout (Rust lays
    out and pushes the rects before it answers), so it measures what was just made (ledger I1)
  dispatch "heartbeat" (nil target) at most every 50 ms; Shoes-Spec tests and peek's steps start
    once the first one's handlers are done, so the slot start blocks Lacci hangs on it have run
  flush
```

Handler exceptions are rescued per dispatch (`DisplayService#guarded`), logged with the app
file/line, handed to `Shoes.on_error` (5.6) and the Shoes console, and the loop continues. That
covers a failed `require` (ScriptError) and a runaway recursion (SystemStackError) as well as
StandardError; only `exit` (SystemExit), a signal and NoMemoryError end the app.

Deadlines are `origin + n * interval`, so ten 0.1 s frames land on one second instead of drifting.
A timer that fell behind skips the deadlines it missed rather than firing a burst, and a restarted
timer waits a whole interval. `clear` keeps the timers a slot started (ledger B7, Q8 ruled 27 Sep
2026): Lacci's `clear` destroys every child except SubscriptionItems, so they keep ticking, as in
Shoes 3 (`s3_canvas.c:781`) and as the examples that clear their app from inside its own `animate`
need. Removing or destroying the slot stops them with it.

An idle pump sleeps. Besides the child's output, the select watches a wake pipe that a post from
another thread (a download) and Ctrl-C (the pump chains Lacci's INT trap) write to, so nothing
waits on the timeout (native/PERF.md). Every `Shoes::App` traps INT afresh as it is made (a
`window` is one), so the pump chains itself again at every run. A second Ctrl-C ends the child
outright, since Ruby may be stuck writing to a child that stopped reading, where asking it to quit
changes nothing. Hello goes out without waiting for `ready`. When the loop
ends the shim sends `quit`, closes the child's stdin and gives it 2 s before TERM and KILL; if the
child died while an app was still open, it raises `ChildDied`. A TERM to Ruby ends the child at
once (its whole process group) before Ruby goes on to die of it, because a child stuck in layout
never reads that EOF and a harness that follows TERM with KILL never waits out the grace. While the
child runs, `SCARPE_NATIVE_PID_FILE` (when set) holds its pid, so a harness that had to kill Ruby
can kill the child's group too: `spec/run` and `rake native_test` do.

### 5.5 Programs in a process of their own (`Shoes.run_program`)

`Shoes.run_program(path, dir: File.dirname(path), args: [])` returns a `Shoes::Program` (Lacci,
`lacci/lib/shoes/program.rb`; ledger K10). The native display runs the program in a new process
on the Ruby and Scarpe it runs on (`Programs`, `lib/scarpe/native/programs.rb`), so an endless
loop freezes only the program, and `stop` ends it. Hackety Hack's Run needs exactly that: Shoes 3
evaluated a child's program inside Hackety Hack, and `while true` took Hackety Hack with it.

- **The handle:** `pid`, `running?`, `status` (a `Process::Status` once it has ended), `stop`
  (TERM to the program's process group, KILL a second later if it is still there; its renderer
  goes with it), `on_exit { |status| }`, `on_error { |err| }` (err is the Hash of 5.6) and
  `on_output { |stream, line| }` (stream `"stdout"` or `"stderr"`, the line without its
  newline). Every block runs on the pump, never on a thread. A block added late still hears the
  errors reported so far (the last 100) and, once the program has ended, its status.
- **The command.** From a checkout: `ruby -I lib -I lacci/lib -I scarpe-components/lib
  exe/scarpe --native PATH` on `RbConfig.ruby`, in `dir`, with this process's environment
  (Bundler's included), so headless and ghost modes carry over to the program. From a packaged
  app: its own launcher again (`SCARPE_LAUNCHER`, which the launcher exports), which runs
  `SCARPE_RUN_FILE` with the bundled Ruby and Scarpe instead of the app (section 11). The
  command's first word goes to `spawn` as `[name, argv0]`, so a lone launcher is never read as
  a command line and split at the space in `Hackety Hack.app`. The program runs in its own
  process group, with stdin `/dev/null` and this process's stdout and stderr.
  A spec run's settings stay the parent's: `SHOES_SPEC_TEST`, the minitest exports,
  `SCARPE_NATIVE_PID_FILE` and `SCARPE_NATIVE_STATS` are unset for it.
- **The settings** (read once by `ProgramChild.run` and taken out of its ENV, so a program it
  starts gets its own): `SCARPE_RUN_FILE` (the file), `SCARPE_RUN_DIR` (the directory it runs
  in), `SCARPE_RUN_ARGS` (its ARGV, JSON), `SCARPE_REPORT_FD` and `SCARPE_PARENT_FD`.
  `exe/scarpe` and a packaged app's `boot.rb` hand the file to `ProgramChild.run` instead of
  `Shoes.run_app` when `SCARPE_RUN_FILE` is set; without `SCARPE_REPORT_FD` it simply runs.
- **The report pipe** is fd 3 (`SCARPE_REPORT_FD`), one JSON object a line, in the order the
  program did things:

  | t | fields | parent does |
  |---|---|---|
  | `renderer` | `pid` (Integer, or null once it has gone) | keeps it, to end a renderer its program could not |
  | `output` | `stream` (`stdout` or `stderr`), `line` | `on_output` |
  | `error` | `error` (the 5.6 Hash) | `on_error` |

  The program's `$stdout` and `$stderr` become line forwarders (`ProgramChild::Output`, a
  StringIO whose `write` sends each whole line; every String is made valid UTF-8, bytes that are
  not become `?`). Scarpe's own lines, and its renderer's stderr, go to the real stderr instead
  (`Scarpe::Native.diagnostics`), so `on_output` hears only the program. Both descriptors are
  close-on-exec in the program, so neither its renderer nor what it starts holds them open.
- **Errors.** The program's `Shoes.on_error` block sends every report: its startup (`Shoes.run_app`
  reports what stops the file loading, then the program exits 1 without printing it again), its
  handlers and timers (5.4), and `exit` for an error that escapes its event loop (its renderer
  died, say), after which it exits 1.
- **The parent's side.** Two threads a program: one reads the report pipe into the inbox, one
  waits for the process, then for the last report, then posts the exit, so a final error comes
  before `on_exit`. The pump hands out at most 500 items a turn and does not sleep while any
  wait; more than 10,000 lines of output waiting are dropped and counted, and the count arrives
  as one last `stderr` line before the exit. `on_exit` comes once, with the `Process::Status`.
- **No orphans.** The program holds the read end of a pipe (fd 4, `SCARPE_PARENT_FD`) whose other
  end only the parent has. When the parent ends, however it ends (KILL included), the program
  reads the end of it and sends itself TERM, which ends its renderer first (5.4); one that
  ignores TERM ends its renderer and exits a second later. A renderer whose Ruby has gone reads
  the end of its stdin and exits, and the parent KILLs one the program said it started and never
  said had gone. When the parent's own event loop ends it stops its programs (TERM, a second, KILL).
- **Other displays.** Niente and the webview cannot start a process, so `Shoes.run_program` runs
  the program inside the app (`Shoes::Program::InProcess`), as Shoes 3 did, and logs a warning
  saying an endless loop will stop the app too: its windows open in this process and stay, a
  startup error reaches `on_error`, `on_exit` hears nil at once, `on_output` hears nothing (its
  output is the app's), errors in its handlers go to `Shoes.on_error`, and `stop` closes the
  windows it opened.

### 5.6 Errors and the Shoes console

- **`Shoes.on_error { |err| }`** (Lacci, ledger K9): every block given it hears each error a
  handler, a timer or the startup raises, on the pump, besides the log line; with no block the
  error is logged and the app goes on, as before. A block that raises is logged and the others
  still run. `err` is `Shoes::ErrorReport`'s Hash with String keys: `"class"`, `"message"`,
  `"backtrace"` (Strings), `"path"` and `"line"` (the innermost frame outside Scarpe's own code
  and Ruby's library, or for a SyntaxError the place Ruby names; nil when there is none; for a
  startup error, a frame in the program's own file first, its path compared through links, as
  Ruby names a loaded file by its real path), and
  `"during"`: `"startup"` (`Shoes.run_app` reports what stops the file loading, then lets it go
  on up), `"handler"` (an event, the heartbeat, a program's block), `"timer"` (`animate`,
  `every`, `timer`) or `"exit"` (only a program reports it, 5.5). Test code that clicks or
  advances still has its errors raised in the test instead (section 8).
- **The log line.** A timer that raises raises every frame, often in words that change, so
  the log says an error in full the first time it comes from a place (its class, the
  program's line, the kind of block) and then once as the count there reaches 10, 100, 1000
  and so on, with the latest words (`report_handler_error`, ledger K9). `Shoes.on_error` and
  the console hear every one.
- **The Shoes console** (`Shoes::Console`, `lacci/lib/shoes/console.rb`; ledger K8) is a Shoes
  window titled "Shoes Console" that lists, newest first, the program's `debug`, `info` and
  `error` lines (which still print as before), every error `Shoes.on_error` hears, with where it
  happened and the program's own backtrace frames, and Scarpe's log lines at its log level
  (Rust's included). Alt-/ opens it (Cmd-/ on a Mac, 4.4), and so does `Shoes.show_console`
  (Shoes 3's `Shoes.show_log` is the same); it never opens by itself. Lines wait in a queue any
  thread or signal trap may add to, and the window, one per process, draws them on the pump
  (a 0.25 s timer). It keeps the last 500. A program `run_program` started has a console of its
  own, which Cmd-/ in its window opens.

## 6. Layout rules (canonical)

Units are logical pixels (f32). Window content size = App `width` x `height`; an App that sends
neither opens at 600x500, titled "Shoes" (Shoes 3 and Shoes 4, ledger A1, Q1). Lacci's own default
moved there the same day, so apps normally send it.

- **Dimensions** for width/height/margins: Integer = px; negative Integer = parent inner
  size minus |v|; Float in (0, 1] = fraction of parent inner size (1.0 = 100%); Float in (-1, 0) =
  the parent less that fraction; any other Float is px, because Ruby code often computes widths like
  `w / 2.0`. String `"N%"` = percent (negative: 100% less N%); `"Npx"` or a numeric String = px.
  Shoes 3 treats every Float as a fraction, 1.5 included (ledger C1); native keeps the Floats
  above 1 as pixels. **Positions** (`left`, `top`, `right`, `bottom`) read the same forms but keep
  their sign, as Shoes 3's `shoes_px2` reads them (`nv` 0, s3_ruby.c:298-337; ledger C10, C18,
  ruled by Nick 28 Sep 2026): a negative number or share lies past the edge the position counts
  from, so `top: -400` is 400 px above the slot and `left: -0.25` a quarter of it to the left.
  On art (`rect`, `oval`, `line`, `star`, `arrow`, `arc`, `shape`) every number is pixels, as the
  manual's "pixel coordinates" and Shoes 3 (`shoes_place_exact`, s3_ruby.c:385-392) have it: a
  negative `left`, `top` or line end moves art off the left and top edges (ruled 27 Sep 2026), and
  a Float up to 1 is a coordinate or size in pixels, not a share of the slot (28 Sep 2026, ledger
  C15), so art animated through a slot's corner never jumps across it. Only a percentage String
  is of the slot on art, and a negative size keeps the rule above.
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
- Slot height = content height unless `height` given. In a flow, a slot with no `height` placed
  beside what came before it on the row reaches down at least to that row's bottom, as Shoes 3
  grows a slot to its parent's end while drawing it (s3_canvas.c:639-642): its backgrounds fill
  that height and `bottom:` places against it. The first on a row has nothing to reach down to.
  (Hackety Hack's lesson pane beside its content flow is dark to the window's foot.) A slot with a fixed `height` clips what
  does not fit, scrolling or not (manual 345-352: it becomes a "nested window"; ledger C13); `scroll: true`
  with a height also scrolls. `scroll: true` without a height does nothing.
- **Text blocks** (para and family) with no width: in a stack, full inner width. In a flow they
  read as one paragraph with what came before them on the line (manual 1610-1612, ledger C7, Q2,
  Shoes 3 s3t_textblock.c:134-228): text that fits on the rest of the line sits there as a box
  as wide as its text; longer text starts its first line where the line stands (a first-line
  indent) and wraps its later lines back to the flow's left edge, its box spanning the flow.
  The next element carries on from the end of the last line; after text that ends in a newline,
  from the start of the empty line below it, as Pango lays it out. After text the line goes on from
  the end of the text plus whatever its right margin adds to its left one, so two paras sit one
  margin apart. Text starts a new row instead when not even its first word fits on the rest of
  the line, or when something earlier on the line reaches more than half a line below its first
  line (a picture, a title), where Shoes 3 would wrap lines under it. The indent is a blank
  wide as the indent at the head of the cosmic-text buffer; hit-testing and a para's `fill`
  leave its corner to what came before. Centred, right-aligned, justified, trimmed and sized
  text keeps the box rule of section 12, but for one case Shoes 3 draws otherwise: sized or
  trimmed left-aligned text too wide as a box for the rest of the line, whose text fits there on
  one line and inside its own width, sits on that line as wide as its text (ledger C7). A text block's `fill` is a highlighter over its text,
  line by line (manual 1208-1210; Shoes 3's Pango background), not paint over its box.
  Line height = 1.2 x size. `leading` (default 4 px, manual 1286, ledger F10) goes between lines
  only, as Pango's spacing does: one line is 1.2 x size tall, two are 2.4 x size + 4.
- **Text sizes** are logical pixels (ledger M14): a para is 12 px, a title 34. Under the `shoes3`
  text mode (`text_mode`, section 4.1) a size is points at 96 dpi, as Shoes 3 hands Pango
  `size * 96/72` (s3t_textblock.c:293): a para is 16 px and a title 45.3. That covers the size
  names, numeric sizes and a `font` string's size; a relative size word still scales the size it
  would otherwise have, and "18px" (in `size` or a `font` string) stays pixels, as Pango reads
  a font string's px. A text block that names no face, or names one the machine lacks, gets Arial
  there, Shoes 3's default (s3_world.c:46-48). Controls, margins and leading keep their pixels.
  Each line is then as tall as its own text, as Pango sets lines, where the default keeps every
  line at least the block's line height (so a lone `sub` cannot shrink one).
  A para's `marker` range is then bright yellow behind the text and its caret black, as Shoes 3
  drew them (s3t_textblock.c:187-197, 479-483), where the default is a blue tint over the text
  and a caret in the text's colour.
- **Widgets** have intrinsic sizes (research 02 section 13): button = its label's width plus 14 px
  each side by its line height plus 12 px, at least 28 px each way (more with an icon); edit_line 200x28, edit_box 200x108,
  list_box 200x28, progress 200x14 (manual sizes, ledger C4), check/radio 18x18, slider 160x20,
  video 300x150 (a placeholder frame; playback is not built). An image is its file's size, or keeps its aspect when given only
  a width or a height. Shadows stay inside a control's box. Explicit width/height override.
- **Margins** add outside a size the element finds for itself, and sit inside a width or height
  the app gives it, which is the margin box (ledger C14, Q9 ruled 27 Sep 2026; section 12)
  (`margin`, `margin_left/top/right/bottom`; arrays are
  [left, top, right, bottom], and a short array keeps the default for the sides it leaves out,
  ledger C3). Text blocks default to Shoes 3's margins: 4 px on every side, and 12 px below
  unless `margin` or `margin_bottom` is given (ledger C9, Q3, s3t_textblock.c:108-110); everything
  else defaults to 0. `padding` (Scarpe extension) adds inside slots and the root.
- **Absolute placement**: any child with `left`, `top`, `right`, `bottom` or `attach` set, every
  art shape, and every background and border is out of flow: placed relative to its slot's content
  origin, it does not affect siblings or slot height. `right: n` puts the element's right margin
  edge n px in from the slot's right edge, `bottom: n` likewise from the bottom (manual 1100-1106,
  1356-1364, ledger C10); `left` and `top` win when both are given. A negative position lies past
  the edge it counts from, as Shoes 3 reads positions (`shoes_px2`, s3_ruby.c:327-337): `top: -400`
  starts the element 400 px above the slot and `bottom: -3` hangs it 3 px below (ledger C10, C18). A slot with no `height` placed by `bottom` is measured
  by its margins alone, its top `bottom` and its margins above the foot, as Shoes 3 places a
  canvas it has not drawn yet (ledger C10). Backgrounds and borders read them the same way, but for
  one case: one with a size of its own along the axis is measured from the far edge by its
  pattern's size, 1 px for a colour or a gradient, as Shoes 3 places a tile (PATTERN_DIM, ledger
  M19), so `background ..., height: 150, bottom: 150` runs along the slot's foot with its top
  151 px up, and a picture keeps the size it is given as its measure.
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
src/window.rs      winit 0.30 ApplicationHandler; one Window + softbuffer Surface + AccessKit adapter per App;
                   ControlFlow::Wait; stdin reader thread -> EventLoopProxy<UserEvent>, one wake per batch
                   of lines; window/pacing.rs holds floods of frames to the display's refresh rate;
                   window/voiceover.rs reads a window as AppKit hands it to VoiceOver (a11y, `platform`)
src/headless.rs    same Runtime with offscreen pixmaps; stdin read on its own thread too, so Rust
                   blocked writing to a Ruby that is not reading yet never stops Ruby writing
src/automation.rs  req ops that synthesise input (click, mouse, type, key, wheel), layout dump, snapshot, pixel
src/dialogs.rs     rfd message/file dialogs; the modal for `ask` and `ask_color`, in an app's window or its own
src/a11y.rs        screen readers: the AccessKit tree built from Doc + Layout + view state, the actions a
                   screen reader asks for, the Mirror that sends a window only what changed, and the read
                   back through accesskit_consumer for the `a11y` op
```

Stack: tiny-skia 0.12, cosmic-text 0.19, swash 0.2, winit 0.30.x (not the 0.31 beta), softbuffer 0.4,
image 0.25 (png jpeg gif bmp), serde/serde_json, rfd 0.17, arboard, objc2 0.6 on macOS (already
in the tree through softbuffer and rfd), and for screen readers accesskit 0.24, accesskit_consumer 0.38
and accesskit_winit 0.32 (the adapter for winit 0.30). Rust 1.93 is installed and the crate asks for 1.89; do not
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
1 px #c7c7cc border, 6 px radius, blue focus ring and caret; `fill:` and `border_color:` repaint the
box and its edge, and a `stroke:` that colours the text colours the caret and focus ring too
(ledger G17). Check/radio: drawn, accent blue (#0a84ff) when on.
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
   `SCARPE_NATIVE_WINDOWED_TESTS=1`, and their windows are ghosts (section 12). `rake package_test`
   builds and boots a real packaged app headless.
3. **The spec suite** (`spec/`, section 9), run by `spec/run`.

Native test API available inside Shoes-Spec test code (`lib/scarpe/native/shoes_spec.rb`),
on top of the Niente-compatible finders and proxies (`button`, `para`, `edit_line`, plural forms,
`drawable(Class)`, selectors `"@ivar"`, `"$global"`, `"id:N"`):

| method | does |
|---|---|
| `proxy.trigger_click` / `trigger_hover` / `trigger_leave` / `trigger_change(v)` | Shoes-Spec compat. `trigger_click` goes through Rust (`req click {id}`), so it proves layout and hit-testing |
| `click_on(proxy_or_text)`, `click_at(x, y, button: 1)` | synthetic click through the real path |
| `hover_at(x, y)`, `move_mouse(x, y)` | pointer motion |
| `drag([x, y], [x, y], ...)` | press at the first point, move through the rest with the button down, release at the last |
| `type_text(str)`, `press_key(name)` | keyboard into the focused widget / app |
| `wheel(dy, x:, y:)` | scroll; without `x:`/`y:` at the middle of the first window |
| `layout_of(proxy)` | `Rect(x, y, w, h)` in window coordinates |
| `layout_tree` | array of hashes from `req layout`, Symbol keys |
| `snapshot(name)` | writes `spec/results/snapshots/<name>.png` (or `SCARPE_NATIVE_SNAPSHOT_DIR`, or an absolute path), returns the path |
| `pixel_at(x, y)` | `[r, g, b, a]` |
| `wait_frames(n = 1)`, `advance(seconds)` | pump the loop. `wait_frames` beats the heart as the pump does, so a slot made since starts (ledger H8), and then waits for the frames. The clock is frozen in spec runs, so `advance` steps from one timer deadline to the next and fires exactly the timers due |
| `resize_window(w, h)` | resize the window |
| `focused_drawable` | proxy or nil |
| `a11y_tree(platform: false)`, `a11y_nodes` | the `a11y` op's tree with Symbol keys, or every node of it in a flat list, window first |
| `a11y_action(target, action, value = nil, platform: false)` | a screen reader's act on a drawable, an id or a tree node (with `platform: true`, on the element with that title, through AppKit) |
| `stub_dialog(kind, value)`, `dialogs_seen` | answer the next `kind` builtin with `value`; every `[kind, message]` asked for |
| `wait_until(timeout = 10) { cond }` | turn the loop in real time until the block is true, else fail: for news from outside the app, such as a program `Shoes.run_program` started (5.5) |

A handler that raises while test code is clicking or advancing fails the test instead of being logged.

`scarpe peek APP.rb [--size WxH] [--scale 2] [--wait SECS] [--click TEXT | --click-at X,Y]
[--drag X,Y,X,Y...] [--type TEXT] [--key NAME] [--wheel DY[,X,Y]] [--window N | --app ID]
[--shot OUT.png] [--layout] [--a11y]` runs an app headless, performs the steps in order once the
first heartbeat has started the slots, prints one line per click, drag, wheel, window, shot,
laid-out node and accessibility node (`--a11y`: `#5 text_input "Name" = "Nick" (focused)`, indented
under its parent), and exits (1 when a step failed or no app started). With no `--shot`, `--layout`
or `--a11y` it saves `peek.png` in the current directory. `--drag` presses at its first point and
moves through the rest a frame apart, so an app that reads `mouse` in a timer sees the button
down at each. It is the quick
"look and click" tool for humans and agents. `--window N` (counting from 1 in `Shoes.APPS`) or
`--app ID` sends every later step to that window.

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
- `spec/accessibility/`: what a screen reader meets and does in a native window (ledger N1, an
  extension: the manual is silent on screen readers).
- `spec/examples.yml`: every example under `examples/` with its expected status and optional
  interaction steps; the runner smoke-tests each one (loads, renders non-blank, no Ruby error,
  no Rust panic), saves a snapshot and writes a gallery page.
- `spec/LEDGER.md`: every place where the manual, Shoes 3, Shoes 4, the examples and Lacci disagree,
  with the ruling. Default rule: the manual wins, unless a large body of working examples depends on
  the other behaviour, then accept both.
- `spec/run [--display native|niente] [--jobs N] [paths...]` runs cases in parallel, sandboxed
  (HOME, LOCALAPPDATA, cwd, TMPDIR and the download cache in a temp dir, dialogs stubbed, clipboard
  kept in a file), writes `spec/results/<display>.json` and prints a scoreboard. Exit code
  non-zero on failures.

With the eighth build wave's Kids apps (28 Sep 2026) the suite holds 1042 cases: native 1026
pass, 0 fail, 1 skip and 15 expected failures, each citing its ledger row; niente 540 pass and 12
expected failures (489 need layout or input and are n/a there). The ten Kids checks run with the
suite from `spec/kids`; the twelve checks beside the apps in `examples/native/legendary` run only
when named, and pass 12 of 12. Examples on native, on
Ruby 4.0: 360 pass, 0 fail, 90 skipped, and 23 that `spec/examples.yml` expects to fail there,
each with its reason (dialog-only apps, scripts that never start an app or stop on a missing
library, apps that only log or paint one flat colour, and `colours.rb`, whose colours `flatten`
dissolves, ledger D1). Two of the 23 name Ruby 4.0 in a `ruby:` field and load on Ruby 3.2.

After the Hackety Hack lane (w9, 28 Sep 2026) the suite holds 1038 cases: native 1023 pass, 0 fail,
1 skip and 14 expected failures; niente 545 pass and 11 expected failures (481 n/a). The legendary
checks and the examples on both displays pass as before.

After the w10 scarpe lane (28 Sep 2026, Q10's two cases) the suite holds 1062 cases: native
1047 pass, 0 fail, 1 skip and 14 expected failures; niente 545 pass and 11 expected failures
(505 n/a). The legendary checks (the Typewriter's check moved to where its lever is in reach,
ledger C18) and the examples on both displays pass.

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
Ruby, `lib`, `lacci/lib` and `scarpe-components/lib` copied from source (no installed gems and no
webview; FastImage and base64 go in as plain source for image sizes, except with `--minimal`), the
release binary stripped into `Contents/MacOS` and signed explicitly, a boot script that never loads
`scarpe/wv` and sets `SCARPE_DISPLAY_SERVICE=native`, and an ad-hoc signature on the whole bundle.
A button app is 32.4 MB (13.4 MB as a `.dmg`), or 17.7 MB with `--minimal`. Linux, Windows and
universal native packages are not built yet, and nothing is notarised.

The launcher exports `SCARPE_LAUNCHER` (its own path), and `boot.rb` runs `SCARPE_RUN_FILE`
instead of the app when that is set, with the bundled Ruby and Scarpe: a packaged app's
`Shoes.run_program` starts the launcher again that way (5.5), double-clicked or not. Traveling
Ruby hands a process the environment it started with (`RUBYLIB`, `RUBYOPT` and two more), so
going back through the launcher is what gives the program the bundle's load path.

Ruby speed in packaged apps (Nick's call, 27 Sep 2026). Two cheap wins, both measured before and after:

1. **YJIT on by default, after the first frame.** It helps method-heavy per-frame code such as
   `animate` handlers, but switched on at process start (`--yjit`, `RUBY_YJIT_ENABLE=1`) it made the
   first frame 28 to 57 ms later on a YJIT build of Ruby (docs/native_packaging.md has the table),
   while `RubyVM::YJIT.enable` at the first heartbeat cost nothing measurable. So `boot.rb` does
   that (`lib/scarpe/package/yjit.rb`), and `RUBY_YJIT_ENABLE=0` opts out. The bundled Traveling
   Ruby 3.4.7 is built without YJIT, so packaged apps run without it until the runtime has it.
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

- **Margins and sizes.** A width or height the app gives, px or relative (a fraction, `"N%"`, a
  negative number), sizes the margin box, as Shoes 3 does (s3_ruby.c:506, 537, s3t_textblock.c:125-126;
  ledger C14, Q9 ruled 27 Sep 2026): two `width: 0.5, margin: 10` flows share a row, `stack width:
  100, margin: 10` is an 80 px box, and `para "x", width: 200` wraps at 192 inside its 4 px
  margins. So do a slot's default fill and a text block's. A size the element finds for itself (a
  button's label, a check's 18 px, an image's pixels) is the box, and margins add outside it.
- **Text in a flow** flows as a paragraph (section 6). Text that does not (centred, right-aligned,
  justified, trimmed, or given a width or height) is a box: as wide as its longest line
  (max-content) if that fits in the rest of the row, else it starts a new row and wraps at the
  full width there. Sized or trimmed left-aligned text whose one line fits on the rest of the row
  and inside its own width sits there instead, as wide as its text (section 6, ledger C7). Text with `align: center/right` fills the rest of the row so the alignment
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
  `center: true`; a star and an arrow, whose left/top are their centre, turn about that centre
  (28 Sep 2026); positive `rotate` turns counter-clockwise. The Shoes 3 source defaults to the
  centre for every shape (ledger Q11), so an example written for a centre pivot
  (`rotate_shapes.rb`) swings about its corner here.
  The draw context's `translate: [x, y]` (Lacci's running total) moves shapes before they turn.
  Turns add up: `rotate` in the draw context is Lacci's running total too (ledger E10).
  A shape's layout box is its transformed box, so hit-testing and the layout push follow.
  `cap` is `"curve"` (round), `"rect"` (flat, the default) or `"project"` (square, half the stroke
  width longer). Unset fill and stroke are black, strokewidth 1. `right:` and `bottom:` put art's
  far edges that far in from the slot's far edges, as for every element (ledger C10): art with a
  far edge and no near one sits against it, and a rect, oval or arc that names both edges and no
  size runs from one to the other; `left` and `top` win over them, as elsewhere. (Shoes 3 read
  them on art as absolute coordinates, `s3_ruby.c:396-399`; no example uses either.)
- **Shape blocks.** Art drawn inside a `shape` block joins the shape's path, measured from the
  shape's left/top: the group is filled once (nonzero winding) and stroked once with the shape's own
  fill and stroke, and turns as one (ledger E7, M21): about the group's corner, by the shape's own
  draw context, whatever transforms its members carry. The layout boxes of the shape and of every
  member are where that turn puts them, so hit-testing matches the picture.
- **Image canvases.** An Image with children (`image(w, h) { ... }`, ledger E9, contract c) lays them
  out inside its own box, like a flow, in image-local coordinates, and clips them to it. A blank
  canvas with no size of its own (only `left`/`top`) fills the rest of its line and its parent's
  height. Effects (`blur`, `glow`, `shadow`) are not drawn: the manual never documents them.
- **Image files** are decoded once and read again when the file changes (its modification time
  or length, looked at once a batch), so an app that rewrites a picture and sets its path again
  shows the new one, and a file that was not there yet shows once it is. Pictures no drawable
  shows any more are let go at the next flush. A picture drawn at another size than its own is
  resampled once for that size in device pixels and the copy kept with it (four sizes at most,
  none past 16 M pixels), and an unturned picture lands on whole device pixels.
- **Gradients** follow Shoes 3: angle 0 runs top to bottom, 90 left to right, across the shape's
  box. A wire gradient without `angle` gets 0. Radial gradients are not drawn (Lacci's `gradient()`
  cannot ask for one).
- **Wheel.** `req wheel` takes `dy` in logical px with DOM sign: positive scrolls down (content
  moves up). The `wheel` event sent to subscription items carries `delta = -dy` (positive = up)
  and window coordinates. Scrolling a slot or the window also sends `scroll {id, top}`. A scroll
  (wheel or `scroll_to`) moves what the slot holds within the layout that stands, from where it
  was laid out by the scrollers' offsets, rather than laying the window out again; Ruby still
  hears every rect that moved (contract a), so a slot of 5000 rows re-sends 5000 rects a tick.
  A layout with anything `attach`ed lays out again instead.
- **Hit-testing.** Nothing is hit outside the window, so moving the pointer to (-1, -1) leaves every
  drawable including the DocumentRoot. Backgrounds and borders never catch the pointer. A clipped
  slot's hidden part catches nothing.
- **Headless dialogs** reply with `cancelled: true` for everything but `alert`.
- **Windowed dialogs.** `alert`, `confirm` and the file/folder pickers are native (rfd); `ask` and
  `ask_color` draw a modal (a text field, or twelve swatches) and reply when the user
  presses OK/Return (`cancelled: false`) or Cancel/Escape (`value: null, cancelled: true`; the shim
  turns a null `ask` into `""`). The modal sits in a running app's window, the active one first.
  Asked while no app window is up (inside `Shoes.app` or `start` before `run`, or before any app),
  it gets a small window of its own, sized to it; closing that window is a Cancel, and Ruby never
  hears of the window. `ask`'s `title` heads the modal and names that window; `secret` types bullets.
  A ghost answers either kind the headless way.
- **`layout`** lists every laid-out node in paint order; each text fragment (Link, Strong, Em...)
  follows its Para as its own entry, with the box of its first line of glyphs and its text, and
  `click {id}` on a fragment clicks there. Fragments are hit-tested like drawables: a press inside
  one walks fragment, then whatever lies under the pointer, topmost first, for `has_click`, then
  the para's slots, and hover/leave include the fragments. **`frames`** replies with the number
  of frames painted so far. **`snapshot`** defaults to the app's scale (the window's, or `--scale`
  headless, else 1). **`click {text}`** also picks an item of an open list_box popup.
- **`para_hit {id, value}`** is sent while the pointer moves over a para (the character index), and
  with `value: null` when it leaves.
- **Focus.** Text fields show a focus ring whenever focused; buttons, checks, radios and list boxes
  only when focus came from the keyboard (tab or a `focus` message), and only then do they take
  keys: one the mouse pressed leaves Space, Return and the arrows to `keypress`, as a Mac's controls
  do (28 Sep 2026, ledger G9). Text fields draw `font:`'s family, size, weight and slant (G11). On a focused list box Up and
  Down choose the previous and next item without opening the popup (manual 3221-3224); Return and
  Space open it.
- **`state: "disabled"`** greys a control out and it ignores the pointer, keys and tab;
  **`"readonly"`** fields can be focused, selected and copied but not edited.
- **Bundled fonts** (`--fonts bundled`) are Inter (sans, and the serif fallback) and Fira Mono
  (monospace), all OFL, in `native/assets/fonts`. With system fonts on macOS the sans face is San
  Francisco, and text under 20px gets a little extra tracking to stand in for SF Text's optical size,
  which cosmic-text never selects. The bundled fonts have no emoji.
- **`sub` and `sup`** draw x-small, 10 px below or above the baseline.
- **`variant: "smallcaps"`** (or `font_variant`) draws small capitals: the face's own (OpenType
  `smcp`) when it has them, else lower-case letters as capitals at 0.78 of the size, one letter for
  one, so indexes, the layout dump and `click {text}` still read the text as written. `stretch`
  (condensed, expanded) is not drawn: cosmic-text varies only a font's weight axis.
- **Closing a window** sends `closed {app}`; the window goes at once, and if no `quit` follows
  within 3 seconds the process exits by itself. Ruby may be blocked on that window, so an `ask`
  open in it is answered as cancelled, and a `frames` request with an error, before `closed`.
  `--exit-after SECS` closes every window that way when the time is up, so a Ruby app quits
  cleanly; headless, every running app's canvas closes the same way. It and `--inactive` (or
  `SCARPE_NATIVE_INACTIVE=1`) open windows without activating the app or taking keyboard focus.
- **Ghost windows** (`--ghost`, which the shim passes for `SCARPE_NATIVE_GHOST=1`; implies
  `--inactive`) lay out, paint and present real frames, but nobody can see or touch them. Every
  automated windowed run opens them: the test helpers, the benches, `native_cold_start.rb
  --windowed` and the package test. On macOS a ghost is created hidden and only shown once it
  reads back as alphaValue 0 and click-through (else the process exits 1); it has no shadow, stays
  out of Mission Control, the window cycle and the Window menu, and the app is an accessory that
  never activates (a packaged app checks in with LaunchServices as an LSUIElement, so its Dock
  icon never shows). Elsewhere it opens far off-screen. App `opacity` leaves it clear, links stay
  shut, and a `dialog` request gets the headless answer; the shim answers a ghost's builtins
  quietly before they reach Rust. Snapshots and automation read our own pixmap, so they are unchanged.
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
  paint order, and a turned image. Art under rotate, scale or skew is bounded by its turned box,
  grown by its stroke and points as the transform stretches them. Past eight damaged rects, the
  two whose union is the smallest box are joined, again and again, until eight remain; more than
  half the frame repaints it whole. Headless pictures and snapshots are always painted whole. A node must never paint outside `paint::damage::paint_bounds`: code that
  makes a node draw further (a new transform, a bigger shadow) grows that function too, or
  `SCARPE_NATIVE_DAMAGE=check` will say so. A masked slot's layers cover only the repainted rect,
  so masks repaint in part like anything else.
- **Looks-only changes keep the layout.** A check's `checked`, a field's echoed `text`, a shape's
  `fill`, `stroke` or `cap`, a background's or border's `fill`, `stroke`, `strokewidth` or `curve`,
  a bar's `fraction` and a para's cursor and marker repaint without laying anything out again (`runtime.rs` `changes_only_looks`).
  Any other prop change lays out again only the app the node is drawn in (every app for a text
  span, which has no parent). The shaped-text cache keeps what each app's last layout used, so
  one window laying out never throws away another's text.
- **Text fields** keep an undo history: Cmd-Z (`:alt_z` by Shoes' name, Q5) or Control-Z undoes,
  Cmd-Shift-Z, Control-Shift-Z or Control-Y redoes. A run of typing, or of deleting, is one step,
  as in a Mac or GTK field; a paste, a cut or a caret move ends it, and the caret and selection
  come back with the text. Lacci's echo keeps the history; text the app sets itself starts a new
  one. Readonly fields refuse both. Input methods are on while a field that takes text has focus,
  with their candidates at its caret: a commit (a dead key's accent, a word of Japanese) is one
  edit and one `change`, or keypresses when no field has focus; text still being composed shows
  in the input method's own panel, not in the field. **Secret fields** never give their text away:
  copy and cut do nothing (cut would throw it away), input methods stay off, and automation's
  `layout` reads bullets, so `click {text}` cannot find one by its secret.
- **Untrusted input** (`src/limits.rs`, wave 4). Nothing on stdin can make Rust panic, hang or
  allocate without bound: a bad line is logged (bytes that are not UTF-8 included) and the next
  one is read. App and window sides are finite and at most 10,000 logical px (a NaN, zero or
  negative one keeps the last size, and `resize` answers with an error); a headless picture is
  at most 64 megapixels at a scale of 0.1 to 8, else `snapshot` says so; a `frames` request waits
  for at most 1,000. A node is never attached inside itself, so the tree has no loops; layout
  stops 128 slots deep and masks stop masking 4 deep, so no document overflows the stack or piles
  up layers. Paths reaching more than a million device pixels out are not drawn (tiny-skia's
  fixed point panicked on a stroke 2^31 px wide); rects (backgrounds, borders, controls) are
  cut to the window first, so the part of a box millions of pixels tall that is on screen draws. Image and font files are read only when they
  are plain files (a FIFO would block, /dev/zero never ends) within 256 MB, and images within
  16,384 px a side, whatever their extension says. `tests/fuzz.rs` feeds generated hostile
  sessions through the real entry point (SCARPE_NATIVE_FUZZ_RUNS, SCARPE_NATIVE_FUZZ_SEED).
- **Text spans** (`strong`, `em`, `link` and the rest) have no parent: a para names them in its
  `text_items`. Lacci makes a new span for every `strong(...)` and destroys none, and may name an
  old one again, so Rust keeps a span while any text names it, and after that until more than
  `limits::LOOSE_SPANS` (10,000) such loose spans pile up, when the oldest go. A clock that shows
  `strong(Time.now)` every tick stays bounded, and `@p.replace(@bold)` still finds `@bold`.
- **Para `cursor` and `marker`** count from the end when negative (`-1` sits after the last
  character, as Shoes 3 editors use it). The caret takes the text's colour, so it shows on dark
  backgrounds. Text that ends in a newline has an empty line under it, as Pango lays it out: it
  counts in the text's height, a caret after the newline sits at that line's start, and
  `para_hit` on it names the place after the newline (cosmic-text keeps no line there, so
  `ShapedText::closing_newline` stands in for it).
- **Screen readers** (`src/a11y.rs`, ledger N1). Scarpe draws its own controls (Nick, 27 Sep 2026:
  "our buttons are OUR buttons"), so it tells screen readers what they are, through AccessKit. The
  tree follows the document: the window (named by the App's title) holds the laid-out slots as
  containers a screen reader looks through; a text block is static text, its words its `value`,
  or a heading at 48 px and up (level 1), 34 (2) and 26 (3), the sizes Scarpe's webview theme
  (Tiranti) tags h1 to h3; a text block with links is a paragraph of its runs of text and its
  links, each link a node with its URL. Buttons are named by their label; checks and radios carry
  `toggled` and are named by the text block just after them in the same slot; edit lines and
  boxes carry their live text (bullets when `secret`, and never the secret itself) and are named
  by the text block just before them, as are list boxes, which are popup buttons valued at their
  choice and holding their items (with bounds while the popup is open). Progress is a fraction
  from 0 to 1, none when indeterminate. An image is named by its `alt:` (a Lacci style since 27
  Sep). A `tooltip` is every node's description. `state: "disabled"` dims a node and takes its
  actions away; `"readonly"` fields take no new value. Art, backgrounds, borders, masks, timers,
  hidden and blank things stay out. The ask and ask_color dialogs are modal dialogs, named by
  their `title` or else their message, holding the message, their field or twelve named swatches,
  and Cancel and OK; a dialog's own window (an ask with no app window up) is named by that title
  and holds the dialog alone. Focus is the focused control,
  the popup's highlighted item, or the dialog's field or swatch. Actions go through the paths a
  click or a key takes: `click` sends a control's `click` (a check still waits for Lacci's echo),
  opens or closes a list box's popup, or picks an item; `focus` moves keyboard focus with the ring
  showing; `set_value` replaces a field's text as one edit and one `change`, or chooses a list
  box's item; `expand` and `collapse` open and close a popup. Each window creates its adapter while
  still hidden (AccessKit panics on a visible window), then shows the way winit showed it: key and
  in front, or with `--inactive` in front without the keyboard. That last holds on macOS; elsewhere
  the window shows through winit's `set_visible`, which may activate it (no automated run opens a
  window off macOS yet). The adapter asks for nothing until
  a screen reader does; after that each presented frame builds the tree and sends only the nodes
  that changed (`Mirror`), and the whole tree again when a screen reader starts again (the
  adapter's own handlers mark that as it happens, so no partial update reaches a new adapter). Not exposed yet: a field's caret and selection (a screen reader reads a
  field whole), click handlers on slots and art, radio groups, scrolling a node into view.

## 13. Environment

| variable | effect |
|---|---|
| `SCARPE_DISPLAY_SERVICE=native` | selects this backend (`scarpe --native` and `scarpe peek` set it) |
| `SCARPE_NATIVE_BIN` | the child binary to run instead of `native/target/release/scarpe-native` |
| `SCARPE_NATIVE_HEADLESS` | passes `--headless` unless empty, `0`, `false` or `no` (`scarpe peek` sets it) |
| `SCARPE_NATIVE_ARGS` | extra child arguments, e.g. `--fonts bundled` or `--exit-after 3` |
| `SCARPE_NATIVE_INACTIVE` | windows open without activating the app or taking keyboard focus |
| `SCARPE_NATIVE_GHOST` | passes `--ghost` (scarpe-native honours it too): windows present real frames but are invisible, click-through and never in front (section 12). Every automated windowed run sets it; `0` turns it off |
| `SCARPE_NATIVE_TRACE` | prints every NDJSON line both ways to stderr (Ruby side; the child's `--trace` does it from Rust) |
| `SCARPE_NATIVE_LOG_LEVEL` | `debug`, `info`, `warn` (default; `debug` under `SCARPE_DEBUG`) or `error` |
| `SCARPE_NATIVE_CACHE` | where downloaded images and fonts are kept (default: the user's cache directory, 5.3) |
| `SCARPE_NATIVE_SNAPSHOT_DIR` | where relative `snapshot(name)` paths go (default `spec/results/snapshots`) |
| `SCARPE_CLIPBOARD_FILE` | a file that stands in for the system clipboard, for Rust's clipboard and Lacci's alike, so a sandboxed run never touches the real one (spec/run sets it) |
| `SCARPE_NATIVE_PID_FILE` | a file that holds the child's pid while it runs, for harnesses that may have to kill it (5.4) |
| `SCARPE_NATIVE_WINDOWED_TESTS` | lets `rake native_test` open real windows, as ghosts |
| `SCARPE_NATIVE_STATS` | a directory: each process writes where its time went (`ruby.json`, `rust.json`) as it exits (native/PERF.md) |
| `SCARPE_NATIVE_DAMAGE` | `off` repaints every window frame whole; `check` also paints each one whole and reports any pixel a partial repaint got wrong (headless too) |
| `CARGO` | the cargo that builds a stale dev binary (default: on `PATH`, else `~/.cargo/bin/cargo`) |
| `SCARPE_RUN_FILE`, `SCARPE_RUN_DIR`, `SCARPE_RUN_ARGS` | run this file (in this directory, with this JSON ARGV) as a program `Shoes.run_program` started: `exe/scarpe` and a packaged app's launcher both honour it (5.5) |
| `SCARPE_REPORT_FD`, `SCARPE_PARENT_FD` | the program's report pipe and its parent's lifeline, inherited descriptors (5.5) |
| `SCARPE_LAUNCHER` | set by a packaged app's launcher to its own path, for `Shoes.run_program` |
| `SCARPE_BYTECODE=0` | a packaged app loads source instead of its precompiled bytecode |
| `RUBY_YJIT_ENABLE=0` | a packaged app leaves YJIT off (it turns it on after the first frame when the Ruby has it) |
