# Scarpe Native: performance

Nick's brief: performance is critical, so measure, optimise, measure again. This page has the
numbers, how each was taken, and what moved them. Everything here can be run again with the
commands under "Running the benchmarks".

## How these were measured

- **Machine:** Apple M5 (10 cores), 32 GB, macOS 26.2, built-in Liquid Retina XDR display
  (120 Hz ProMotion, 2x). Windows are 600x500 logical, 1200x1000 pixels, opened inactive
  (`SCARPE_NATIVE_INACTIVE=1`) and visible. The benches have opened ghost windows since
  (see "Windows as ghosts" below).
- **Build:** `cargo build --release` with Rust 1.93.1. Ruby 4.0.1 without YJIT unless a row says
  otherwise (4.0.1 on this machine has no YJIT; the YJIT rows use 4.0.5, with and without it).
- **Before** is commit 32a2b47: the measurement layer alone, on top of native-rust 36c6282.
  **After** is w3/perf. Both ran the same harness (the after tree's `examples/native/bench`).
- Other work ran on the machine throughout (load average 7 to 14). Before and after ran
  interleaved, three rounds of the whole suite; the table shows the median of the three.

## The numbers

| benchmark | measure | before | after |
|---|---|---|---|
| **500 ovals, animate(60), window** (`ovals`) | frames per second | 60.0 | 60.0 |
| | frame interval p50 / p95 / max | 16.7 / 18.9 / 30.8 ms | 16.6 / 18.8 / 28.5 ms |
| | Rust CPU / Ruby CPU | 53.8% / 24.7% | **41.1%** / 25.4% |
| | Rust present per frame | 2.70 ms | **0.79 ms** |
| | Rust parse, apply, layout, paint per frame | 0.25, 0.15, 0.22, 5.09 ms | 0.25, 0.16, 0.22, 5.30 ms |
| **500 ovals, headless 2x** (`ovals_headless`, each tick painted) | frames per second / Rust CPU | 60.1 / 35.3% | 59.7 / 35.7% |
| **One ball over a busy still window** (`backdrop`) | frames per second | 34.3 | **60.0** |
| | frame interval p50 / p95 | 28.6 / 32.3 ms | 16.6 / 19.5 ms |
| | Rust CPU | 99.7% | **15.5%** |
| | Rust paint per frame | 26.4 ms | **0.47 ms** |
| **Keystroke to pixels, window** (`typing`) | key in, to the frame showing it (p50 / p95) | 9.1 / 14.5 ms | **3.8 / 6.5 ms** |
| | key, Ruby handler, form redrawn (p50 / p95) | 16.4 / 25.7 ms | **7.9 / 10.5 ms** |
| **Keystroke to pixels, headless** (`typing_headless`) | key in, to the frame showing it (p50 / p95) | 2.5 / 4.4 ms | 2.0 / 5.1 ms |
| **Cold start, hello world** (`startup`, median of 5 a round) | spawn to first frame on screen | 244 ms | **191 ms** |
| | Ruby VM boot | 45 ms | 52 ms |
| | Ruby: load Scarpe, Lacci and the shim, start the app | 83 ms | **41 ms** |
| | Rust: event loop running and hello answered (from its start) | 66 ms | **47 ms** |
| | Rust: system fonts loaded (from its start) | 45 ms, blocking | 14 ms, on its own thread |
| | Ruby: app built and `run` sent (from spawn) | 73 ms (waited on hello) | **2 ms** |
| | Rust: window open (after `run`) | 35 ms | 44 ms |
| | first layout, paint and present | 4.9 ms | 1.0 ms |
| **Idle, a still app** (`idle`, 10 s) | Ruby CPU / Rust CPU | 0.32% / 0% | **0.035%** / 0% |
| **A clock, every(1)** (`clock`, 10 s) | Ruby CPU / Rust CPU | 0.49% / 1.0% | **0.054% / 0.2%** |
| **Clear and rebuild 2000 paras** (`rebuild`) | Rust parse, apply per rebuild | 1.70, 1.16 ms | 1.64, 1.21 ms |
| | Rust layout, paint, present per rebuild | 41.5, 1.18, 3.04 ms | 38.0, 1.50, **0.64 ms** |
| | click to rebuilt frame (Lacci's unsubscribes, see below) | 4367 ms | 4347 ms |
| **Memory, footprint / RSS** (`memory`) | hello world: Ruby | 20 / 27.6 MB | **13** / 20.7 MB |
| | hello world: Rust | 32 / 98.7 MB | **27** / 94.5 MB |
| | 2000 drawables: Ruby | 35 / 42.7 MB | **28** / 35.6 MB |
| | 2000 drawables: Rust | 67 / 134 MB | **49** / 116 MB |

Footprint is what Activity Monitor calls Memory (dirty and compressed pages). RSS also counts
AppKit's and CoreAnimation's shared pages, which is most of the Rust process's 94 MB.

Single changes, measured as interleaved A/B pairs on their own (numbers from the commits):

| change | measure | before | after |
|---|---|---|---|
| window in DeviceRGB (b844dd9) | present per 1200x1000 frame | 2.75-2.99 ms | 0.76-0.79 ms |
| fonts on their own thread (f6d9636) | Rust start to first frame, hello world, warm | ~80 ms | ~72 ms |
| lazy requires, no handshake wait (6dc4f07) | spawn to first frame, quiet machine, median of 7, twice | 198-200 ms | 149-151 ms |
| batched stdin (f6e46da) | Rust CPU, 500 ovals | 42-44% | 40.5-41% |
| frame pacing (1075123) | 100 ovals at animate(240) on 120 Hz: presents / Rust CPU | 240/s, 54% | 116/s, 34-35% |
| looks-only changes (48a0a06) | recolouring one shape over 2000 paras, per frame | 1.45 ms | 0.32 ms |
| kept JSON::State (493db5e) | JSON per tick, Ruby 3.2.2 / 4.0.1 | 0.55 / 0.24 ms | 0.36 / 0.22 ms |

YJIT (Ruby 4.0.5, the after tree, two rounds each):

| measure | 4.0.5 | 4.0.5 with RUBY_YJIT_ENABLE=1 |
|---|---|---|
| 500 ovals, window: Ruby CPU | 24.0-25.2% | 18.7-19.2% |
| 500 ovals: Ruby handler per tick | 3.68-3.96 ms | 3.04-3.26 ms |
| 500 ovals: JSON per tick | 0.25 ms | 0.18 ms |
| 500 ovals, headless: Ruby CPU | 23.4-25.0% | 17.6-18.4% |
| cold start, hello world | 163-181 ms | 161-174 ms |

YJIT takes a quarter off the Ruby side of an animation and does nothing for cold start.

Rust alone, no Ruby and no window (`native/tests/bench.rs`), per frame at 2x, the same binary
with partial repaints off and on (`SCARPE_NATIVE_DAMAGE=off`), two runs each, load about 11:

| scene | repaint everything | repaint what changed |
|---|---|---|
| 500 moving ovals | 11.6-12.2 ms | 12.0-12.1 ms (all of it changes) |
| one ball over a still window | 4.69-4.86 ms | 0.17 ms |
| one ball over 2000 paras | 3.95-4.02 ms | 2.85-2.94 ms (2.3 ms is layout) |
| one shape changing colour over 2000 paras | 1.65 ms | 0.63 ms |
| clearing and rebuilding 2000 paras | 96 ms | 95 ms (all of it changes) |

On a quieter machine the same benches ran about twice as fast (6.2 ms for the ovals, 0.09 ms
for the ball); compare the columns, not these numbers with the tables above.

## Where a frame's time goes

500 ovals moving at 60 fps, after. Ruby and Rust work side by side, each on its own frame:

| side | step | per frame |
|---|---|---|
| Ruby | animate handler: Lacci moves 500 ovals, the shim normalises 1000 prop changes | 3.9 ms, 57% of it GC |
| Ruby | JSON encoding, 1001 lines | 0.23 ms |
| pipe | one write of 43 KB; a ping round trip is 0.02 ms | 0.03 ms |
| Rust | parse, apply | 0.25, 0.16 ms |
| Rust | layout | 0.22 ms |
| Rust | paint: tiny-skia antialiased fills of 500 translucent ovals at 2x | 5.3 ms |
| Rust | present: softbuffer's new 4.8 MB buffer (0.47), conversion (0.19), CoreAnimation | 0.8 ms |

So at 60 fps the Ruby side is 25% busy and the Rust side 41%. Paint is the biggest single step
and is real rasterising: every oval moves, so nothing can be skipped.

## What changed, and what each bought

Each is its own commit on w3/perf with its own before and after in the message.

1. **Frames presented in the window's own colour space** (b844dd9). Sampling the ovals showed
   vImage lookup tables and matrix multiplies inside CoreAnimation's commit: softbuffer tags
   frames DeviceRGB, the window was in the display's colour space, so every frame was
   colour-matched on the CPU (2.4 ms of a 2.7 ms present). The window now uses DeviceRGB and the
   window server converts while compositing, on the GPU. The colours on screen are the same.
2. **Repaint only what changed** (f34f6b1, `src/paint/damage.rs`). The window keeps its last
   frame and repaints the rects of nodes whose box, props, text or widget state changed, each
   into a pixmap of its own under a translated transform. Whatever cannot be bounded repaints
   everything: first frame, new size or scale, scrolling, popups and modals, paint order
   changes, and art under rotate, scale, skew or translate. A change to a node that is not
   painted on its own counts against its nearest painted ancestor (f84cf7b).
3. **System fonts loaded while the window opens** (f6d9636). The font database, 11 ms warm and
   85 to 190 ms with a cold disk cache, no longer sits in front of the handshake.
4. **The shim starts without waiting** (6dc4f07). net/http, digest, uri and tmpdir (about 45 ms)
   load on the first download; minitest (10 to 45 ms) loads for Shoes-Spec runs only; hello goes
   out and Ruby builds the app while Rust starts.
5. **An idle app sleeps** (7ae4272, f245d77). The pump woke every 50 ms. A wake pipe now ends its
   wait for posts from other threads and for Ctrl-C (the INT trap is chained), so its own loop
   waits up to a second when no timer is due.
6. **One event-loop wake per batch of lines** (f6e46da), instead of 60,000 a second.
7. **Floods held to the refresh rate** (1075123, `src/window/pacing.rs`). A frame that would be
   the third within two refreshes waits for the next one. A lone frame never waits.
8. **The layout kept when a change only alters looks** (48a0a06): a check's `checked`, a field's
   echoed `text`, a shape's colour, a bar's fraction, a para's caret.
9. **A kept JSON::State per thread** (493db5e) instead of one built per message.
10. **A stale-pixel bug in the shaped-text cache** (299cdbd): a para whose `fill` changed kept
    painting the old one, because the cache key left the fill out.

## Looked at and left alone

- **Moving art without laying everything out.** Art never moves anything else, so a moved shape
  could be re-placed alone: a ball over 2000 paras spends 1.16 ms of its 1.44 ms frame laying the
  paras out again (quiet machine). It is not done here because the layout lane is changing
  placement right now and the new layout push-back (Rust tells Ruby every rect that moved) would
  have to see such updates, or Lacci's `left`/`top` getters would go stale. After the merge:
  re-place art whose only changed keys are geometry, from the LBox's stored origin (less its own
  displacement) and parent size, and push that rect back.
- **A sprite cache for art.** Paint is 5.3 ms of the ovals' frame, nearly all of it tiny-skia's
  antialiased fills. Caching each shape's raster needs a key covering everything its paint reads,
  and the art lane is adding transforms now; not worth a stale sprite.
- **softbuffer's present.** It allocates and zero-fills a new 4.8 MB buffer every frame (0.47 ms
  of page faults). Its API gives no way to reuse one.
- **Opening the window.** At 31 to 44 ms it is now the largest step of Rust's startup, and it is
  AppKit's.
- **The 2000-para rebuild** is 38 ms of layout on the Rust side, and sampling shows harfrust
  shaping new text. The 4.3 s a click takes is Lacci unsubscribing 6000 handlers (the Lacci lane
  is on it).
- **String buffer instead of Array#join** for the outbox: 67 against 73 µs per 1000 lines.

## For the Lacci lane

Measured on the ovals, in a scratch copy:

- `Shoes::DisplayService.dispatch_event` always builds its debug string (`args.inspect` and all):
  11 objects and 1.1 µs per dispatch. Without it the animate handler fell from 3.88-3.96 to
  3.39-3.54 ms per tick and Ruby's CPU from 25% to 21-22%.
- `move(x, y)` sends two prop changes (left, then top). One message would cut the pipe from 43 to
  27 KB per tick and Rust's parse and apply from 0.41 to 0.27 ms; `style(left:, top:)` is heavier
  in Ruby than the two setters, so it wants a lean combined setter.
- Garbage collection is 57% of Ruby's CPU in the oval animation (stackprof).

## Keeping partial repaints honest

A stale pixel is worse than a slow one, so partial repaints are checked three ways.

- `SCARPE_NATIVE_DAMAGE=check` verifies every partial repaint, in a window or headless: outside
  the repainted rects a full paint must equal the previous full paint bit for bit (anything else
  is a stale pixel), and inside them the frame must equal the same rects painted with no node
  skipped. A rect is not compared with a full paint: tiny-skia approximates a curve the pixmap
  edge cuts through a shade differently, and both shades are right. Mismatches go to stderr and
  the full paint goes on screen. `SCARPE_NATIVE_DAMAGE=off` repaints everything.
- `native/tests/damage.rs` (15 tests, including a 150-step random walk at three scales) runs that
  check after every change; each of five deliberately broken versions of the damage code fails it.
- All 424 examples, headless, in check mode, with clicks, keys, typing and waits: 1400 repaints
  verified (398 of them partial), no mismatch, no panic.

A node must never paint outside `paint::damage::paint_bounds`. Code that makes a node draw
further (a new transform, a shadow) grows that function too; check mode says when it did not.

After the lanes merged (27 Sep), `damage.rs` has 19 tests: a tooltip, a masked slot, a shape block
member and an image canvas child each move and repaint in part, and the mask and canvas tests
also compare the whole frame with a full paint, which catches a layer that forgets where its rect
sits. A tooltip now repaints the whole frame, like a popup, from the moment the pointer rests on
its owner. The check-mode sweep over all 434 examples (the 424 plus the bench apps) verified 1441
repaints (413 partial): no mismatch, no panic.

## After the merge: the layout push-back

The layout lane's push-back (contract a) sends Ruby every rect that moved after each layout pass.
On the 500 ovals, headless at 2x, two interleaved rounds against the perf branch (1fd904a) on a
loaded machine (load average 20 to 40), with `bench.rb ovals_headless --seconds 5`:

| | perf branch | merged |
|---|---|---|
| Rust layout per frame | 0.45-0.46 ms | 0.57 ms |
| Ruby handler per tick | 7.82-8.21 ms | 7.97 ms |
| Ruby CPU | 39.1-39.4% | 39.7% |
| frame interval p50 | 20.6-20.9 ms | 21.0-21.1 ms |

The push costs Rust about 0.11 ms a frame here; the Ruby side stays within the noise. The windowed
benches were not rerun: no windows were opened for the merge. They ran later as ghost windows
(next section).

## Windows as ghosts (27 Sep, after the merge)

From 18:15 on 27 Sep a watchdog killed any `scarpe-native` that could show a window, so the merged
tree's windowed benches never ran. The benches now open ghost windows (native/DESIGN.md section
12): real windows whose frames are laid out, painted and presented, at alphaValue 0 and
click-through. Below is the merged tree (native-rust 877e262 plus the ghost commits) in ghost
windows. Each cell is the median of four interleaved rounds taken while the 1-minute load
average was 6 to 12 (the tables above ran at 7 to 14). A round is `bench.rb ovals ovals_headless`,
`typing typing_headless`, `startup` and `idle`, each under Ruby 4.0.1, 4.0.5 and 4.0.5 `--yjit`
(`--ruby`), in an order that rotated from round to round, so each windowed bench ran back to back
with its headless twin. The visible column repeats the perf lane's `after` numbers from the
tables above, Ruby 4.0.1.

| benchmark | measure | visible window (above, 4.0.1) | ghost window, 4.0.1 | ghost window, 4.0.5 | ghost window, 4.0.5 + YJIT |
|---|---|---|---|---|---|
| **500 ovals, animate(60)** (`ovals`) | frames per second | 60.0 | 60.0 | 60.0 | 60.0 |
| | frame interval p50 / p95 / max | 16.6 / 18.8 / 28.5 ms | 16.3 / 21.5 / 26.5 ms | 16.6 / 21.4 / 23.7 ms | 16.5 / 22.3 / 29.9 ms |
| | Ruby CPU / Rust CPU | 25.4% / 41.1% | 30.4% / 47.6% | 29.3% / 45.2% | 25.4% / 44.8% |
| | Ruby handler per tick | 3.9 ms | 4.8 ms | 4.6 ms | 4.0 ms |
| | Rust parse, apply, layout, paint per frame | 0.25, 0.16, 0.22, 5.30 ms | 0.27, 0.18, 0.32, 5.86 ms | 0.26, 0.18, 0.31, 5.56 ms | 0.26, 0.18, 0.29, 5.54 ms |
| | Rust present per frame | 0.79 ms | 1.08 ms | 1.01 ms | 1.07 ms |
| | headless twin: Rust CPU / paint per frame | 35.7% / n/a | 40.1% / 5.92 ms | 39.2% / 5.63 ms | 38.5% / 5.52 ms |
| **Keystroke to pixels** (`typing`) | key in, to the frame showing it (p50 / p95) | 3.8 / 6.5 ms | 1.38 / 1.87 ms | 1.28 / 1.68 ms | 1.38 / 1.74 ms |
| | key, Ruby handler, form redrawn (p50 / p95) | 7.9 / 10.5 ms | 2.78 / 3.29 ms | 2.56 / 3.15 ms | 2.80 / 3.70 ms |
| | headless twin: key in, to the frame (p50 / p95) | 2.0 / 5.1 ms | 0.90 / 2.00 ms | 0.88 / 1.28 ms | 0.98 / 2.13 ms |
| **Cold start, hello world** (`startup`, median of 5 a round) | spawn to first frame presented | 191 ms (149-151 quiet) | 155 ms | 149 ms | 148 ms |
| | Ruby: load Scarpe, Lacci and the shim, start the app | 41 ms | 38 ms | 32 ms | 35 ms |
| | Rust: event loop running and hello answered | 47 ms | 49 ms | 50 ms | 47 ms |
| | Rust: window open (after `run`) | 44 ms | 37 ms | 35 ms | 36 ms |
| | first layout, paint and present | 1.0 ms | 1.06 ms | 1.04 ms | 1.04 ms |
| **Idle, a still app** (`idle`, 10 s) | Ruby CPU / Rust CPU | 0.035% / 0% | 0.02% / 0% | 0.02% / 0% | 0.05% / 0% |

- Ghost windows hold 60 fps on every Ruby, at the visible window's median frame interval (their
  p95 runs 2.6 to 3.5 ms longer).
- Rust spends about a millisecond more per oval frame than the perf lane's `after`. Layout is
  0.1 ms of it, the layout push-back measured above. The headless twin, seconds apart, paints the
  same frame in the same 5.5 to 5.9 ms, so the extra paint is not the window. Present is
  discussed below.
- The Ruby handler is 0.7 to 0.9 ms slower than the perf lane measured, and 4.1 to 4.4 ms in the
  headless twin, so that is the merged Lacci or the machine, not the window.
- YJIT cuts the animation's Ruby CPU from 29.3% to 25.4% and its handler from 4.6 to 4.0 ms,
  13% each (the perf lane saw 23% and 17% before the merge). Cold start does not move.
- Typing is faster than the perf lane's columns in the ghost and in its headless twin alike, so
  that gain is not the ghost's.
- Four earlier rounds, started at load 12 to 25 and running past 30, were slower: the ovals fell
  as low as 23 fps (Ruby 4.0.1), and in three of them paint took 10 to 13 ms a frame. The
  Rust-only frame bench, run in the same session at load 60, painted the same 500 ovals in
  12.2 ms, so that was the machine.

### What a ghost changes

Our two processes do the same work for a ghost as for a visible window. Ruby's handlers, the pipe,
Rust's parse, apply, layout and paint, softbuffer's copy and CoreAnimation's commit all run every
frame, and `frames` counts every present. The differences are on the window server's side:

- A ghost's alphaValue is 0, so compositing it blends nothing. The DeviceRGB conversion that
  b844dd9 moved onto the GPU happens there too. None of that was ever on our CPU, so the Ruby and
  Rust CPU columns compare with a visible window's; the window server's and the GPU's load do not.
- A film played full screen in Chrome's own Space throughout these runs, so every ghost opened
  on another Space: the window list had it off screen and nothing composited it at all. When the
  user came back to the desktop for a minute, a ghost there was on screen, at alpha 0 in all 120
  samples the window list gave.
- Present is the one number where a ghost could look better than a visible window, since the
  commit still hands every frame to the window server but nothing shows it. It came out 0.2 to
  0.3 ms slower than the perf lane's visible window, not faster. Why is not known: the merged tree,
  or a window server busy with a full-screen film.
- macOS may App Nap an app nobody can see (timers coalesced, low priority). It did not: an idle
  ghost kept a background app's scheduling priority, 46 in `ps -o pri` (processes the system runs
  in the background show 4), for 40 s, and the animation held 60 fps.
- Frame pacing holds a ghost to 120 Hz, as it does a visible window on this display. A ghost is
  never key, as the inactive windows before were not, so keys arrive through automation, which is
  how `typing` has always measured.

## Wave 5 (27 Sep, late)

Measured on the same machine, often at a load average of 10 to 45 while other lanes ran, so each
before and after ran interleaved. The review's drivers are Python scripts feeding the release
binary headless; "before" is native-rust 98ad233's binary.

| change | measure | before | after |
|---|---|---|---|
| shaped text kept per app, a prop change lays out its own window only (fff74e9) | one para changing in window 1, 300 paras a window: 1 / 3 / 4 windows | 0.42 / 50.2 / 63.8 ms | 0.45 / 0.46 / 0.48 ms |
| one reused clip mask, used only for paths a clip cuts across (a58b49b) | 48 rows of `stack(height: 20)` at 2x, full paint (median of 5) / RSS | 11.7 ms / 174 MB | 7.7 ms / 29 MB (free rows: 7.2 to 7.8 ms, 26 MB) |
| a scroll moves the layout that stands (45e887c) | 5000 paras in a scrolling stack, 50 wheel ticks: layouts / wheel request / one tick's round trip | 51 / 1.96 ms / 5.4 ms | 1 / 0.67 ms / 3.0 ms |

The scroll still pushes every rect that moved to Ruby (5000 rects, 210 KB a tick for that list),
as contract a asks; only a wire change on the Lacci side can shrink that.

Partial repaints were measured again against whole ones on the showcase lane's starfield traces,
replayed through `Runtime::repaint` at 2x (paint p50, partial / whole): the shipped starfield 3.57 /
3.46 ms, `no_nebula` 7.09 / 7.34, `oneglow` 6.92 / 6.51, `twograd` 14.5 / 13.8, `solid` 2.36 /
2.75, `bare` 6.14 / 6.35. The lane's 19.9 against 12.9 ms (`no_nebula`, before the wave-4 merge)
no longer happens: those frames mostly move more than half the window, which the existing rules
(more than half the frame, or more than 8 rects whose bounding box is) already paint whole. A few
stars twinkling over a 72-circle nebula (`bench.rs`, `stars_twinkling_over_a_nebula`) paints in
0.93 ms in part and 58.3 ms whole, so the thresholds stay as they are.

## Screen readers (27 Sep, wave 5)

Every window carries an AccessKit adapter (DESIGN 12, "Screen readers"). It asks for nothing
until a screen reader does, so an app nobody reads aloud builds no tree and sends nothing; each
presented frame costs it one look at the adapter's state. While a screen reader listens, every
presented frame builds the app's tree and sends only the nodes that changed.
`a_screen_reader_listening_to_2000_paras` in `tests/bench.rs`, three runs at load 16 to 30:

| measure | time |
|---|---|
| the whole tree, 2003 nodes (a screen reader starting, or starting again) | 0.64-0.65 ms |
| a frame in which one check toggles | 0.50-0.55 ms, 1 node sent |

That is about a fifth of the 2.9 ms a frame of "one ball over 2000 paras" costs, paid only while
VoiceOver is on. Two runs at load 48 took 1.1 and 4.9 ms a frame.

Creating each window's adapter costs nothing measurable. From `run` to the first frame on screen
(SCARPE_NATIVE_STATS marks, hello world in a ghost window, six runs of each binary interleaved):
29.3 to 34.2 ms with the adapter, median 30.0, and 29.4 to 50.3 ms at 98ad233 without it, median
31.7. The release binary grew from 7.65 MB to 8.08 MB.

## Typing in Hackety Hack's editor (28 Sep, w9)

Hackety Hack's editor draws a program as one para and, on every key, tokenises the whole
program again and replaces the para's text with a fresh span for each coloured token. Measured
headless against Hackety Hack's own editor with a 303-line program (its samples, one after
another), at load 40 to 55 from other work on the machine, so the Ruby times wander by half:

| measure | time |
|---|---|
| pieces in the code para | 2709, of them 976 spans |
| Ruby's key handler (`onkey`), per key | a run's median 87 to 208 ms over eleven runs, once 434 ms at the busiest |
| of which tokenising and making the spans | 55 to 150 ms (tokenising alone about 14 ms) |
| of which `para.replace` | 22 to 80 ms |
| making 1000 bare spans | 51 to 140 ms |
| key to the next frame, 20 keys through Rust (`peek --type`) | 5.8 s, about 290 ms a key |

Typing in a short program feels immediate; in a 300-line one it lags. The cost is in making
about a thousand drawables a key, each with its create message, and in reshaping a para of
2709 pieces, more than in any one step. One step also leaked: every drawable subscribed to its
own `hover`, `leave` and `motion` events when it was made, so each key left 2928 subscriptions
behind (3451 to 32731 over ten keys). Since 28 Sep a drawable subscribes to one of those only
when given a block for it, and ten keys leave the bus as they found it (74 subscriptions). The
old spans themselves still stay in `Shoes::Drawable`'s id registry, 976 a key: a para that drops
a fragment cannot tell whether another para still shows it (Glossb puts one link in two). Making
a span cheaper, or tokenising only the lines a key changed (Hackety Hack's side), is what is
left.

## Wave 8 (28 Sep, the Kids apps)

The Kids apps are scenes full of small scattered life (fireflies, bubbles, confetti, twinkling
stars), and their builders met three repaint costs, each now a bench in `examples/native/bench`.
Measured on the M5, quiet, in ghost windows at 2x for 5 s, each before and after run back to
back against a binary built from the tree before the fixes:

| change | bench | before | after |
|---|---|---|---|
| past 8 damaged rects, join the nearest (smallest union box) until 8 remain, not all into one box (`paint::damage::merge`) | `scattered_damage.rb`: twelve 8 px dots drifting | 150 full repaints, 4.5 ms a paint | 1 full, 148 partial, 0.45 ms |
| turned, scaled or skewed art is bounded by its turned box, grown by its stroke and points as stretched (`paint_bounds`) | `turned_star.rb`: a 12 px star turned 20 degrees, twinkling | 150 full, 5.6 ms | 1 full, 149 partial, 0.12 ms |
| a picture shown at another size is resampled once and kept (`ImageCache::at_size`) | `stretched_picture.rb`, every frame painted whole: a 211 px glow drawn 844 device px | 15.1 ms a paint (the same glow from an 844 px file: 5.8) | 5.8 ms |

The join rule was picked on a simulation of 300 random frames of twelve scattered 22 px changes
in a 1920 x 1280 frame: the smallest-union-box rule repaints 2.8% of the frame on average and
7.1% at worst, joining whatever adds the fewest pixels 2.8% and 30.2% (it lines far dots up into
long strips that later joins widen), and the old bounding box 69.5%, over the whole-frame line.
With thirty such changes every rule lands near a quarter of the frame, so crowds still pay.

`damage.rs` has 23 tests; its random walk now also turns, scales and skews art. Check mode, run
through a wrapper that sets `SCARPE_NATIVE_DAMAGE=check` for every renderer `spec/run` starts
(`SCARPE_NATIVE_BIN` pointing at it), verified 3808 repaints over the Kids, showcase and
legendary checks (2112 of them partial) and 784 over all 473 examples (72 partial): no mismatch.

## Running the benchmarks

```
bundle exec ruby examples/native/bench/bench.rb                  # everything, about 2.5 minutes
bundle exec ruby examples/native/bench/bench.rb ovals typing     # some: ovals ovals_headless backdrop
                                                                 #   typing typing_headless startup idle
                                                                 #   clock rebuild memory
ruby examples/native/bench/bench.rb --ruby ~/.local/share/mise/installs/ruby/4.0.5/bin/ruby --yjit
    # options: --seconds N (the measured stretch), --runs N (cold starts), --bundler, --json OUT
cd native && cargo test --release --test bench -- --ignored --nocapture --test-threads 1
    # prefix SCARPE_NATIVE_DAMAGE=off for the repaint-everything column
```

`bench.rb` runs each app in `examples/native/bench` through `drive.rb`, which starts it the way
`scarpe --native` does and acts on it from the first heartbeat (cold start runs the real
`exe/scarpe`). Both open ghost windows (`SCARPE_NATIVE_GHOST=1`), so a bench never puts a
window in front of anyone. Both processes report where their time went when `SCARPE_NATIVE_STATS=<dir>` is set
(`ruby.json`, `rust.json`), for any app:

```
SCARPE_NATIVE_STATS=/tmp/stats bundle exec ruby exe/scarpe --dev --native app.rb
```

To reproduce a before column, run today's harness against the old tree and its binary. A tree
older than the ghost flag opens visible windows (its shim never passes `--ghost`), so do that
only when a window on screen is fine:

```
mkdir /tmp/before
git archive 32a2b47 lib lacci/lib scarpe-components/lib exe examples docs/image.png native | tar -x -C /tmp/before
(cd /tmp/before/native && cargo build --release)
cp examples/native/bench/*.rb /tmp/before/examples/native/bench/
SCARPE_NATIVE_BIN=/tmp/before/native/target/release/scarpe-native ruby /tmp/before/examples/native/bench/bench.rb
```
