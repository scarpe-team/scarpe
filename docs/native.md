---
layout: default
title: Native display service
---

# The native display service

Scarpe can draw a Shoes app without a browser. The native display service keeps your app, Lacci
and every block you write in Ruby, and hands the drawing to a small Rust program that paints the
window itself. You write the same Shoes code; it opens in about a fifth of a second and stays light
while it runs.

It is dedicated to the late Noah Gibbs. Scarpe's display services can be swapped because he built
them that way, his relay first put a display in a separate process, and his Shoes-Spec format is
how every case in our spec suite is written.

This page is the guide. The exact contract, message by message, is
[`native/DESIGN.md`](https://github.com/scarpe-team/scarpe/blob/main/native/DESIGN.md).

## How it fits together

```
  your app.rb
      |
  Lacci (the Shoes API, in Ruby)
      |  create, props, destroy ...
  the shim (lib/scarpe/native)  ----- one JSON object per line ----->  scarpe-native (Rust)
      ^   timers tick here,                                             lays out, paints,
      |   handlers run here      <------- events, layout, replies ----  hit-tests, reads keys
      |
  your blocks run, change things, and the loop goes round
```

Ruby thinks and Rust draws. When your app calls `button "OK"`, Lacci makes a `Shoes::Button`, and
the shim sends one line to the Rust process: create node 7, a Button, inside node 5, with these
styles. When someone clicks it, Rust works out what was under the pointer and sends back one line:
event `click` on node 7. The shim hands that to Lacci, and Lacci runs your block.

Only data crosses. Procs, blocks and timers stay in Ruby, where your objects live. The Rust side
keeps a copy of the drawable tree, so it can repaint without asking Ruby anything, and after each
layout it tells Ruby where things landed, so `left`, `top`, `width` and `height` answer in pixels.

The Rust program is a separate process, not a Ruby extension. That keeps it out of Ruby's way (the
window's event loop wants the main thread), lets one binary serve every Ruby version, and means a
Rust crash arrives in Ruby as an ordinary error that carries the end of Rust's stderr. The same
binary opens windows, runs headless for tests, and ships inside packaged apps.

## Quick start

You need Ruby 3.2 or newer and a Rust toolchain (`cargo`, Rust 1.89 or newer). The work has been
done and tested on macOS, on Apple silicon. The window code sits on winit and softbuffer, which
also run on Linux and Windows, but nobody has tried those yet.

From a checkout of Scarpe:

```sh
bundle install
bundle exec ruby exe/scarpe --native examples/button.rb
```

The first run builds the Rust binary (`cargo build --release`, about a minute) and says so on
stderr. After that the shim rebuilds it only when something under `native/src`, or a Cargo file,
changes. The installed `scarpe` command takes the same `--native` flag, and
`SCARPE_DISPLAY_SERVICE=native` picks the native service the same way for anything that runs an app.
Outside a git checkout nothing is built: the shim runs `SCARPE_NATIVE_BIN`, or a `scarpe-native`
on your `PATH`. One on your `PATH` wins in a checkout too, so set `SCARPE_NATIVE_BIN` when you
want a particular build.

A window closes the way any Mac window does. When the last one goes, the app exits.

## Looking and clicking with `scarpe peek`

`scarpe peek` runs an app headless (no window at all), does what you ask in order, prints what it
saw, and exits. It is the quickest way to check a change, and it is how agents look at apps.

```sh
SCARPE_NATIVE_ARGS='--fonts bundled' bundle exec ruby exe/scarpe peek examples/button.rb \
  --scale 2 --shot before.png --click "Push me" --shot after.png --layout
```

```
shot before.png (1200x1000)
click "Push me" -> #3 at 41,14
shot after.png (1200x1000)
#2 DocumentRoot 0,0 600x500
#3 Button 0,0 82x28 "Push me"
#4 Para 86,4 111x14.4 "Aha! Click! Go back"
#5 Link 149.8,4 47.2x14.4 "Go back"
```

The click went through the same hit-testing a real mouse uses, so it proves the button was visible
and on top, and the button's block ran before the second shot. Every layout line is a node's id,
kind, position and size in window pixels, and its text.

| option | what it does |
|---|---|
| `--shot OUT.png` | save a picture of the window |
| `--scale 2` | draw pictures at 2x, like a Retina screen |
| `--size WxH` | resize the window first |
| `--click TEXT` | click whatever shows that text (exact first, then the first that contains it) |
| `--click-at X,Y` | click a point |
| `--drag X,Y,X,Y...` | press at the first point, move through the rest a frame apart, release at the last |
| `--type TEXT`, `--key NAME` | type into the focused field, or press one key (`"\n"`, `left`, `control_a`) |
| `--wheel DY[,X,Y]` | scroll; positive `DY` scrolls down |
| `--wait SECS` | let timers and animations run |
| `--window N`, `--app ID` | send the steps after it to another window |
| `--layout` | print every laid-out node |

With no `--shot` and no `--layout`, peek saves `peek.png` in the current directory. It exits 1 when
a step failed (a click on something covered, say) or the script never started an app.
`--fonts bundled` swaps the system fonts for Inter and Fira Mono, which ship with Scarpe, so a
picture comes out the same on every machine.

## Tests, the spec suite and the ledger

There are four kinds of test. All of them run headless.

```sh
cd native && cargo test --release          # the Rust side: layout, protocol, pictures, repaints
bundle exec rake native_test               # the shim, against the real binary and a fake one
bundle exec rake lacci_test                # Lacci itself
spec/run --display native spec/manual      # the Shoes spec suite, on the native display
```

The spec suite in `spec/` is a set of claims about Shoes, each checked against a display service.
Most come from the Shoes manual, one or more per entry; the rest are imported from Noah's
Shoes-Spec corpus. A case is one `.sspec` file with the app and the test code side by side:

```
---
manual: progress.default_width
lines: [3245, 3246]
testability: visual
display: native
ledger: C4
----------- app code
Shoes.app do
  @bar = progress
end
----------- test code
assert_in_delta 200, layout_of(progress).w, 2, "a simple progress bar is 200 pixels wide"
```

`spec/run` runs cases in parallel, each in its own sandbox with its own home directory, stubbed
dialogs and a private clipboard, and prints a scoreboard:

```
spec/run: 3 cases on native, 8 jobs, 1.4s

directory             pass    fail   error    skip   xfail   xpass     n/a timeout
manual/_examples         3       .       .       .       .       .       .       .
total (3)                3       .       .       .       .       .       .       .
```

`xfail` is a case marked `expect: fail`: the manual says one thing, Scarpe does another today, and
the case says why in its `reason:`. When someone fixes it, the case reports `xpass` and fails the run
until the mark comes off, so a fix can never go unnoticed. `n/a` is a case that needs layout or real
input, run on Niente, which has neither. `spec/README.md` explains how to write a case.

On 27 Sep 2026, when the fourth build wave merged, the suite had 983 cases. On the native display
958 pass and 24 are expected failures, each pointing at its ledger row; none fail. On Niente 534
pass.

`spec/run --examples --display native` smoke-runs every example under `examples/`: it loads, it
draws something that is not one flat colour, and neither side crashes. 317 pass and none fail
unexpectedly; 90 are skipped (the network, mostly) and 23 are marked as failing on native, each
with its reason in `spec/examples.yml`: dialog-only scripts, scripts that never open an app, and
apps that only log or paint one flat colour.
Each run also writes `spec/results/gallery/index.html`, a page of every example's picture.

### Reading the ledger

The manual, Shoes 3, Shoes 4, the examples and Lacci do not always agree. `spec/LEDGER.md` writes
down every place they differ and which one the spec follows. Each row gives the evidence from every
source with line numbers, one ruling, what the spec asserts, and what the native display does.
The rulings:

| ruling | meaning |
|---|---|
| MANUAL | the spec asserts what the manual says |
| S3 | the manual is silent or contradicts itself, so the Shoes 3 source decides |
| BOTH | the spec asserts only what both behaviours satisfy |
| EXT | not in the manual (Shoes 3.3, Shoes 4 or Scarpe additions), specced under an extension tag |
| ERRATA | the manual is wrong, and the spec follows the verified behaviour |
| OOS | out of scope |

The default is simple: the manual wins, unless a large body of working examples needs the other
behaviour. A few questions were close enough to need a person. They are at the bottom of the
ledger with their rulings, and a case that depends on a row names it in its front matter
(`ledger: C4`). The Shoes 3 and Shoes 4 sources the rows cite are in `native/research/sources/`.

## Packaging an app

```sh
scarpe package myapp.rb --native --dmg
```

That writes `MyApp.app` and `MyApp.dmg`: a macOS app that needs no Ruby on the machine it runs on.
Inside are a stripped Ruby 3.4.7 (Traveling Ruby), Scarpe, Lacci and the shim copied from source,
your app, and the Rust binary, all ad-hoc signed. A button app is 32.4 MB (13.4 MB as a disk image),
or 17.7 MB with `--minimal`, which leaves out optional Ruby libraries, OpenSSL among them.

Two things make packaged apps start and run faster:

- **Bytecode.** At package time the bundled Ruby compiles Lacci, the shim, your app and the standard
  library files they load, and at launch `require` takes the compiled form. Compiled Ruby remembers
  the path it was compiled for, so it is compiled for where the app will be installed
  (`/Applications` unless you pass `--install-dir`). Run from anywhere else, or after a file changed,
  the app quietly loads source instead. `SCARPE_BYTECODE=0` turns it off for one launch.
- **YJIT after the first frame.** YJIT makes per-frame Ruby (an `animate` block) about a quarter
  cheaper, but switched on at launch it delays the first frame, so the app turns it on once the
  window is up. The Ruby that ships today is built without YJIT, so this waits for a runtime that
  has it. `RUBY_YJIT_ENABLE=0` keeps it off.

Only macOS apps can be built so far, without notarisation. `docs/native_packaging.md` has the details
and the numbers.

## Environment variables

| variable | effect |
|---|---|
| `SCARPE_DISPLAY_SERVICE=native` | use the native display (`--native` and `peek` set it) |
| `SCARPE_NATIVE_ARGS` | extra arguments for the Rust program: `--fonts bundled`, `--scale 2`, `--exit-after 3`, `--inactive`, `--trace` |
| `SCARPE_NATIVE_HEADLESS=1` | no windows; pictures are drawn offscreen (`peek` and the spec suite set it) |
| `SCARPE_NATIVE_INACTIVE=1` | windows open without taking focus from what you are doing |
| `SCARPE_NATIVE_GHOST=1` | ghost windows (the same as `--ghost`): real windows that nobody can see or click, and the app never takes focus; for running windowed tests on a machine someone is using |
| `SCARPE_NATIVE_BIN` | run this binary instead of building `native/target/release/scarpe-native` |
| `SCARPE_NATIVE_TRACE=1` | print every message in both directions to stderr |
| `SCARPE_NATIVE_LOG_LEVEL` | `debug`, `info`, `warn` (the default) or `error` |
| `SCARPE_NATIVE_CACHE` | where downloaded images and fonts are kept; by default your own cache folder (`~/Library/Caches/scarpe-native` on a Mac), never the shared temp folder |
| `SCARPE_NATIVE_SNAPSHOT_DIR` | where a spec's `snapshot("name")` writes its picture |
| `SCARPE_NATIVE_STATS=DIR` | each process writes where its time went (`ruby.json`, `rust.json`) when it exits |
| `SCARPE_NATIVE_DAMAGE` | `off` repaints every frame whole; `check` verifies every partial repaint pixel by pixel |
| `SCARPE_NATIVE_WINDOWED_TESTS=1` | let `rake native_test` open real windows, as ghosts |
| `SCARPE_BYTECODE=0` | a packaged app loads source instead of bytecode |
| `RUBY_YJIT_ENABLE=0` | a packaged app leaves YJIT off |

Ghost windows are new with this round of work; the rest are in DESIGN section 13.

## How fast it is

Measured on an Apple M5 with a 120 Hz Retina display, 27 Sep 2026, with other work running on the
machine (so compare within a row). Everything here can be run again: `native/PERF.md` has the
commands, the before and after of each change, and where a frame's time goes.

| what | measured |
|---|---|
| 500 ovals moving at 60 fps, in a window | 60 fps; Rust 41% of a core, Ruby 25% |
| one ball moving over a busy, still window | 60 fps at 15% of a core (34 fps at 100% before this round) |
| a key press to the frame that shows it, in a window | 3.8 ms typical, 6.5 ms slow (95th percentile) |
| hello world, launch to first frame on screen | 191 ms (149 ms on a quiet machine) |
| a still app, idle | Ruby 0.035% of a core, Rust 0% |
| memory, hello world | Ruby 13 MB, Rust 27 MB |
| a packaged button app, launch to first frame | 117 ms headless, 157 ms in a window |

Three changes did most of that. A window only repaints the parts of the frame that changed, and a
checking mode (`SCARPE_NATIVE_DAMAGE=check`) compares every partial repaint with a full one, which
it matched across every example. Frames go to the screen in the colour space the screen expects,
so macOS no longer converts every one on the CPU. And nothing waits that does not have to: fonts
load while the window opens, Ruby builds the app while Rust starts, and an idle app sleeps.

## Adding a new drawable

A drawable touches four places: Lacci, sometimes the shim, the Rust program, and the spec suite.
The smallest real one to copy is `progress`, and its trail is below.

1. **Find out what it should do.** Look it up in the manual (`docs/static/manual.md`) and in
   `native/research/manual_inventory.json`, which gives each claim an id. If the manual, Shoes 3
   and the examples disagree, write that down as a new row in `spec/LEDGER.md` with a ruling
   before writing code.
2. **Lacci.** A class in `lacci/lib/shoes/drawables/`, required from
   `lacci/lib/shoes/drawables.rb`. Its DSL method comes from its name: `Shoes::Progress` gives
   `progress`, `Shoes::EditLine` gives `edit_line`.

   ```ruby
   class Shoes
     class Progress < Shoes::Drawable
       shoes_styles :fraction
       Shoes::Drawable.drawable_default_styles[Shoes::Progress][:fraction] = 0.0
       shoes_events

       init_args
       def initialize(**kwargs)
         super
         create_display_drawable
       end
     end
   end
   ```

   `create_display_drawable` sends the create, with every style. Add a test under `lacci/test/`
   and run `rake lacci_test`. Niente, the test display, needs nothing. The Webview display needs a
   class of its own in `lib/scarpe/wv/` if it should draw the new drawable too.
3. **The shim.** Usually nothing. Every style already travels as plain data. Only a style that is
   not plain data needs a line in `lib/scarpe/native/normalize.rb`: a colour under a new key (add it
   to `COLOR_KEYS`), a file path (see `url` and `icon`), or a Ruby object that should become an id.
   Test it in `test/native/normalize_test.rb`.
4. **Rust.**
   - `native/src/doc.rs`: a `Kind::Progress` variant, with its arm in `Kind::from_wire` (the class
     name Lacci sends) and in `Kind::name`.
   - `native/src/elements/progress.rs`: a `paint` function that reads the node's props and draws
     through the `Canvas` it is given, inside the node's box. (A drawable that paints outside its box
     must grow `paint::damage::paint_bounds` too, or partial repaints will leave stale pixels; the
     damage check tells you.)
   - `native/src/elements/mod.rs`: `pub mod progress;`, its size in `intrinsic_size`
     (`Kind::Progress => (200.0, 14.0)`), and its arm in `paint`. Layout needs nothing more:
     anything with an intrinsic size flows like any other element.
   - If it takes the mouse or keys, give it a case in `pointer_down` or `key_input` in
     `native/src/input.rs`, and in `Kind::is_focusable` if it can hold focus. If a style only
     changes how it looks, list it in `changes_only_looks` in `native/src/runtime.rs` (progress
     lists `fraction`), so changing it repaints without laying the window out again.
   - A Rust test: `native/src/layout/tests.rs` checks progress is 200x14.
     `cd native && cargo test --release`.
5. **A spec case** for each claim, like `spec/manual/widgets-text/progress.default_width.sspec`
   above. `spec/run --check` validates the front matter; then run it on both displays. A claim
   that needs pixels or a real click is `display: native`, and one Scarpe cannot meet yet is
   `expect: fail` with a `reason` and its ledger row.
6. **DESIGN.** Its intrinsic size goes in section 6 and its file in section 7, with any choice you
   made that the manual left open in section 12.

## Known gaps

As of 27 Sep 2026. Each has more detail in the ledger or in DESIGN.

- **Windows on screen.** The spec suite and peek never open a window. The windowed tests and
  benches open ghosts, which present real frames nobody can see, so nothing has been checked by
  eye on screen: the tooltip wake-up with frame pacing, window opacity with the colour space, and
  input methods, whose composing text shows in their own panel rather than in the field. Cmd-Q
  from the app menu has never been pressed in a test.
- **Platforms.** Only macOS is tested, and only macOS apps can be packaged: no Linux, Windows or
  universal builds, no notarisation. Window opacity works on macOS only.
- **Drawing.** Radial gradients, dash styles, and `blur`, `glow` and `shadow` are not drawn. Video
  shows a placeholder frame and does not play. The bundled fonts have no emoji.
- **Art.** `right:` and `bottom:` place art from the slot's far edges, but Lacci always sends
  `left` and `top` with them, and those win (ledger C10); Shoes 3 read them on art as end points.
  Pens set inside a `shape` block style that shape only, where Shoes 3 carries them on to the
  shapes after it (E7). `scale` and `skew` set their value outright, where Shoes 3 multiplies
  them into what came before; only `rotate` adds up (E10).
- **Lacci.** `left` and `top` answer in window coordinates, where Shoes 3 answers from the
  parent's content origin. `font(url)` returns the file's name before the font is fetched.
  A slot's `start` fires on the first heartbeat after it appears. Image downloads happen at create
  time and hold up building the tree. `download` reads the whole body before its one `progress`.
  Ledger rows A8 (closing one window), B1 (a slot block's `self`) and K6 (`exit` at once) are
  still open.
- **Packaging.** No YJIT in the shipped Ruby yet. Bytecode only helps when the app runs from where it
  was compiled for. Only the app file and its assets are copied, not other `.rb` files it requires.
- **Text.** The stretch (condensed, expanded) and small-caps styles are not drawn (ledger F4, F5),
  and Enter on a focused check or radio does not click it (G9).
- **Examples.** The ones marked failing on native in `spec/examples.yml` each say why (see above),
  and `rotate_shapes.rb` turns its shapes about their corners, as the manual says, where it was
  written for the centre.

## Where to read more

- [`native/DESIGN.md`](https://github.com/scarpe-team/scarpe/blob/main/native/DESIGN.md): the
  contract, message by message, and every layout rule.
- [`native/PERF.md`](https://github.com/scarpe-team/scarpe/blob/main/native/PERF.md): the
  performance numbers and how to run them again.
- [`spec/README.md`](https://github.com/scarpe-team/scarpe/blob/main/spec/README.md) and
  [`spec/LEDGER.md`](https://github.com/scarpe-team/scarpe/blob/main/spec/LEDGER.md): writing cases,
  and the rulings.
- [`docs/native_packaging.md`](native_packaging): packaging in detail.
- [`native/research/`](https://github.com/scarpe-team/scarpe/tree/main/native/research): the
  reports the design was built from, with a README saying what each one is.
