# The Shoes ledger

Shoes-Spec was Noah Gibbs' idea: write down what Shoes *is* as tests that any display service can run. Wherever the sources disagree about what Shoes is, the argument happens on this page. Each row records one disagreement, the evidence on every side, the ruling, what `spec/` asserts, and what the native Rust backend does.

Status: v1, 27 Sep 2026. Seeded from `native/research/06_discrepancy_ledger_seed.md` (rows A1 to L4, ids kept), the 37 contradictions in `native/research/03_manual_inventory.md` (rows M1 to M37, same numbers), and the Lacci divergences in reports 01, 03 and 04 (rows X1 to X19 plus new rows in each area). Contract: `native/DESIGN.md`.

## How to read this

### The sources

| Tag | Source | Where |
|---|---|---|
| Manual | The Shoes manual, `docs/static/manual.md` (3,533 lines). A Markdown copy of Shoes 3's built-in "Policeman"-era manual. Cited as `manual 1716-1722`. | this repo |
| Shoes 3 | `shoes/shoes3@master` C source (3.3.x). Files are named as fetched: `s3_ruby.c` is `shoes/ruby.c`, `s3t_shape.c` is `shoes/types/shape.c`, `s3_gtk.c` and `s3_cocoa.m` are the GTK and Cocoa backends. | fetched copies in the session scratchpad `research/probe06/src/` (not vendored; see the end of this page) |
| Shoes 4 | `shoes/shoes4@main`, `shoes-core`. `s4_dsl_art.rb` is `shoes-core/lib/shoes/dsl/art.rb`; `s4swt_key_listener.rb` is the SWT key listener. | same folder |
| Examples | `examples/` (424 `.rb` files). `legacy/working/` means "boots", not "behaves" (see G2). Counts come from report 04's inventory unless marked as a fresh count. | this repo |
| Lacci / WV | What Scarpe does today: Lacci (`lacci/lib/shoes/`), the Webview display (`lib/scarpe/wv/`) and its Calzini HTML renderer (`scarpe-components/lib/scarpe/components/calzini/`). Line numbers are as of commit `fdcee7a`. Other lanes are fixing Lacci right now, so those numbers will drift. | this repo |
| DESIGN | `native/DESIGN.md`, the contract the native backend is built to. | this repo |

### The ruling vocabulary

The default rule: **the manual wins, unless a large body of working examples depends on the other behaviour; then the spec accepts both.** When the manual is silent or contradicts itself, Shoes 3 decides, because the manual was written for it.

| Ruling | Meaning | Spec tag |
|---|---|---|
| **MANUAL** | The spec asserts what the manual says. | `core` |
| **S3** | The manual is silent or contradicts itself; the spec follows the Shoes 3 source. | `core` |
| **BOTH** | The spec only asserts what both behaviours satisfy. The row says which assertion that is. | `compat-both` |
| **EXT** | Not in the manual (Shoes 3.3, Shoes 4 or Scarpe additions). Specced under an extension tag, never in the core suite. | `ext-s33`, `ext-s4`, `ext-scarpe` |
| **ERRATA** | The manual text is wrong. The spec follows the verified behaviour, and nobody transcribes that manual snippet verbatim. | `core` |
| **OOS** | Out of scope for the spec. | none |

A ruling tagged **(Q3)** is provisional: the evidence is balanced and question 3 at the bottom of this page asks Nick to settle it. Until he does, the spec writes the provisional assertion and cites the question.

### The fields in each row

- **Behaviour**: the row's heading, stated as the behaviour the ruling settles.
- **Manual / Shoes 3 / Shoes 4 / Examples / Lacci today**: the evidence. "Silent" means the source says nothing. "Not checked" means nobody has read it yet.
- **Ruling**: one tag from the table above, with the reason.
- **Spec**: what `spec/` asserts. Cases cite the row with `ledger: E1` in their front matter (DESIGN section 9).
- **Native**: what the Rust backend and its Ruby shim do. Where DESIGN.md says something different from the ruling, the row says so under **DESIGN conflict**.
- **Lacci fix**: the fix from DESIGN section 10 this row waits on (**fix 10.N**), or **Lacci change, unscheduled** when the ruling needs a Lacci change that section 10 does not list yet.

Rows X1 to X19 are Lacci and Webview defects rather than disagreements about Shoes. Each points at the behaviour rows it poisons. Rows M1 to M39 are the manual's own errata and vague spots; where a behaviour row already argues the point, the M row is one line pointing at it.

## Contents: every row and its ruling

"Fix" names the DESIGN section 10 fix the row waits on; "unsched." means the ruling needs a Lacci change that section 10 does not list. "DESIGN" marks a row where `native/DESIGN.md` currently says something else (listed again under "Where DESIGN.md disagrees").

### A. App and window

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| A1 | Default window size and title | S3 (Q1) | unsched. | DESIGN |
| A2 | When the `Shoes.app` block runs | S3 | | |
| A3 | `window`, `dialog`, `owner` | MANUAL | | |
| A4 | Live `width`/`height` of apps and slots | MANUAL | unsched. | |
| A5 | Built-in dialogs with no app open | MANUAL | 10.6 | |
| A6 | `Shoes.app("/start/url")` | EXT | | |
| A7 | Shoes 3.3 app styles | OOS | | |
| A8 | `close` closes one window | MANUAL | unsched. | |

### B. Blocks, `self` and slot manipulation

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| B1 | Slot blocks keep the caller's `self` | MANUAL | unsched. | |
| B2 | `app { }` changes `self`; the manual's fix fails | ERRATA | | |
| B3 | Elements created in handlers land in the app's top slot | MANUAL | | |
| B4 | `prepend`/`before`/`after` keep the written order | MANUAL | 10.3 | |
| B5 | `slot.remove` removes children and fires `finish` | MANUAL | unsched. | |

### C. Layout and dimensions

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| C1 | A Float dimension is a fraction of the parent | MANUAL | unsched. | DESIGN |
| C2 | `style[:width]` returns what was asked for | MANUAL | | |
| C3 | Forms of `:margin` | MANUAL | unsched. | |
| C4 | Default sizes of native controls | MANUAL | | DESIGN |
| C5 | Missing slot and element methods | MANUAL | unsched. | |
| C6 | The window scrolls; `gutter` | MANUAL | | |
| C7 | Text side by side in a flow reads as one paragraph | MANUAL (Q2) | | DESIGN |
| C8 | Default width of a slot | S3 | | |
| C9 | Default margins of text blocks | S3 (Q3) | | DESIGN |
| C10 | `:right` and `:bottom` | MANUAL | | DESIGN |
| C11 | `attach: Window` | MANUAL | | |
| C12 | Paint order: backgrounds are layered elements | MANUAL | | |

### D. Colours and patterns

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| D1 | Colours are `Shoes::Color` objects | MANUAL | unsched. | |
| D2 | `rgb()` types each component | MANUAL | 10.7 | |
| D3 | Alpha is opacity; named colours take one | MANUAL | | |
| D4 | `rgb`/`gray`/`gradient` are built-ins; `Shoes.rgb` | MANUAL | unsched. | |
| D5 | Three-digit hex times 17 | S3 | 10.7 | |
| D6 | Gradient direction, `:angle`, Ranges | MANUAL | unsched. | |
| D7 | `nofill`/`nostroke` mean none | MANUAL | | |
| D8 | Default fill, stroke and stroke width | S3 | | |

### E. Art

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| E1 | `oval`'s third positional is a diameter | MANUAL | 10.10 | |
| E2 | `center: true` | MANUAL | | |
| E3 | `rect` takes `left, top` | ERRATA | | |
| E4 | `star` is centred; `outer` is a radius | MANUAL | | |
| E5 | `arrow` is centred and points right | S3 | | |
| E6 | `line` end points are absolute | MANUAL | | |
| E7 | `shape` is one path | MANUAL | 10.2 | |
| E8 | Mouse events on art, text and images | MANUAL | 10.9 | |
| E9 | `image(w, h) { }` is a canvas | MANUAL | unsched. | |
| E10 | Transforms | MANUAL | | |

### F. Text

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| F1 | `ins()` is an underline fragment | MANUAL | 10.8 | |
| F2 | Text blocks are distinct classes | MANUAL | unsched. | |
| F3 | Relative `:size` strings | MANUAL | | |
| F4 | `:weight`, `:variant`, `:font` | MANUAL | | |
| F5 | Text styles Lacci drops | MANUAL | unsched. | |
| F6 | `underline: true` | BOTH | | |
| F7 | Link and LinkHover defaults | MANUAL | | |
| F8 | Argument of a link's click block | S3 | | |
| F9 | `link(click: proc)` fires | MANUAL | 10.5 | |
| F10 | `:leading` defaults to 4 px | MANUAL | | DESIGN |
| F11 | `para` with non-String arguments | BOTH | | |

### G. Native controls

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| G1 | Control callbacks receive the control | MANUAL | unsched. | |
| G2 | The `list_box { }` block is the change handler | MANUAL | 10.4 | |
| G3 | List box selection, `text`, `choose` | MANUAL | 10.4, unsched. | |
| G4 | `:state` | MANUAL | unsched. | |
| G5 | Programmatic `text=` and `change` | BOTH | | |
| G6 | Radio grouping | MANUAL | | |
| G7 | Button styling | EXT | | |
| G8 | `check.checked` | MANUAL | | |
| G9 | `focus` on buttons; Enter clicks | MANUAL | unsched. | |

### H. Events

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| H1 | `keypress` values; Cmd on macOS | MANUAL (Q5) | | DESIGN |
| H2 | Mouse button numbers | S3 | | |
| H3 | Coordinate frame of mouse events | S3 (Q4) | | DESIGN |
| H4 | The extra `mods` argument | MANUAL | | |
| H5 | `hover`/`leave` get the slot | MANUAL | unsched. | |
| H6 | Registering an event twice | BOTH | | |
| H7 | `wheel` | EXT | | |
| H8 | `start` and `finish` | MANUAL | unsched. | |

### I to L. Timers, navigation, built-ins, loader

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| I1 | Timer rate and counting | MANUAL | 10.1 | DESIGN |
| J1 | `url`, `visit`, pages, `location` | BOTH | unsched. | |
| J2 | `link(click: "/path")` visits | MANUAL | | |
| K1 | `ask` on Cancel; its options | S3 (Q6) | 10.6 | |
| K2 | Option hashes on dialogs | EXT | unsched. | |
| K3 | `debug`, `info`, `warn`, `error` | MANUAL | unsched. | |
| K4 | `font(path)` returns family names | MANUAL | unsched. | |
| K5 | `download` and its events | MANUAL | unsched. | |
| L1 | App code runs at top level | S3 | | |
| L2 | Case-insensitive `require` | OOS | | |
| L3 | Constants | MANUAL | | |
| L4 | Shoes 3 only widgets | OOS | | |
| L5 | Scripts with no `Shoes.app` | MANUAL | | |

### X and M

X1 to X19 (Lacci and Webview defects) are one table. M1 to M39 (manual errata): M1 ERRATA, M2 MANUAL, M3 ERRATA, M4 ERRATA, M5 ERRATA, M6 ERRATA, M7 ERRATA, M8 ERRATA, M9 ERRATA, M10 MANUAL, M11 ERRATA, M12 ERRATA, M13 ERRATA, M14 MANUAL, M15 OOS, M16 ERRATA, M17 MANUAL, M18 S3, M19 ERRATA, M20 MANUAL, M21 S3, M22 MANUAL, M23 MANUAL, M24 MANUAL, M25 MANUAL, M26 MANUAL, M27 S3, M28 MANUAL, M29 BOTH, M30 MANUAL, M31 S3, M32 BOTH, M33 BOTH, M34 S3, M35 MANUAL, M36 OOS, M37 OOS, M38 ERRATA, M39 ERRATA.

## A. App and window

### A1. Default window size and title

**Ruling: S3 (Q1).** 600x500 and the title "Shoes". Shoes 3 and Shoes 4 agree; the manual is silent. **Lacci change, unscheduled.**

- **Manual:** silent. Examples that care pass `width:`/`height:`.
- **Shoes 3:** `#define SHOES_APP_WIDTH 600`, `SHOES_APP_HEIGHT 500` (`s3_app.h:20-21`), applied at `s3_app.c:62-63, 176`. Title comes from `ATTR(attr, title)`, or the settings app name when built with `MTITLE` (`s3_app.c:144-154`).
- **Shoes 4:** `DEFAULT_OPTIONS = { width: 600, height: 500, title: "Shoes 4", resizable: true, border: true }` (`internal_app.rb:19-25`).
- **Examples:** 95 of the 350 examples in the target set pass a size (report 04, B3). The rest take the default; Scarpe's own examples were tuned at 480x420.
- **Lacci today:** `title: 'Shoes!', width: 480, height: 420` (`app.rb:42-49`).
- **Spec:** `core` asserts only that `app.width`/`app.height` report the size the window opened at. The 600x500 assertion is written, tagged `ledger: A1`, and waits on Q1.
- **Native:** takes the App's `width`/`height` props, so it follows whatever Lacci defaults to. It has no default of its own (DESIGN section 6 says "Lacci default 480x420").

### A2. When the `Shoes.app` block runs

**Ruling: S3** as the target. The spec asserts only the handler case, under `compat-both`.

- **Manual:** apps are listed in `Shoes.APPS`, "you can run many apps at once" (manual 885-889). Silent on timing.
- **Shoes 3:** `Shoes.app` stores the block in `@main_app` and returns (`s3_app.c:142`); every app opens after the script finishes loading (`s3_app.c:391-408`). Helpers defined after `Shoes.app` are visible, and N calls give N windows.
- **Lacci today:** `Shoes.app` runs `init` and `run` inline (`shoes.rb:119-121, 192-193`). `docs/scarpe_shoes_incompatibilities.md:64-90` documents "define helpers before `Shoes.app`".
- **Spec:** a method defined after `Shoes.app` can be called from a button handler. Nothing about the app body itself.
- **Native:** passes by construction. The shim answers `custom_event_loop "return"` and runs the pump `at_exit` (DESIGN 5.4), so the whole script has loaded before the first handler fires. The body still runs inline at the `Shoes.app` call, so a helper defined later and called from the body still fails, as in Lacci today.

### A3. `window`, `dialog` and `owner`

**Ruling: MANUAL.**

- **Manual:** `window(styles) { }` opens a new app whose `owner` is the launcher; a plain `Shoes.app` has `owner == nil`; `dialog` is the same with dialog chrome (manual 1000-1004, 1958-1961, 2135-2154). Their blocks change `self` (manual 231-244).
- **Shoes 3:** `shoes_app_window(argc, argv, self, owner)` (`s3_app.c:123-143`).
- **Examples:** `legacy/for_playtest/shoes_manual/window_owner.rb`, `trigger_window.rb`.
- **Lacci today:** `App#window`/`#dialog` call `Shoes.app(**opts.merge(owner: self))` (`app.rb:577-585`). Top-level `Kernel#window` is `Shoes.app` without an owner (`builtins.rb:114-122`). Webview cannot open a second window at all (X6).
- **Spec:** `window { }` from a handler creates a second app; `Shoes.APPS.size == 2`; its `owner` is the first app; the first app's `owner` is nil.
- **Native:** declares `:multi_app` (DESIGN 5.1) and opens one OS window (or headless canvas) per App.

### A4. `app.width`, `app.height` and slot sizes at runtime

**Ruling: MANUAL.** Live pixels after layout and after the user resizes.

- **Manual:** `width()` "returns an exact pixel size" (manual 2511-2513, 2723-2732); `rect 10, 10, self.width - 20, self.height - 20` fills the box (manual 1757-1768).
- **Shoes 3:** `shoes_app_get_width` returns the live `app->width` (`s3_app.c:199-209`), updated on GTK `size-allocate` (`s3_gtk.c:736-750`).
- **Lacci today:** App `width`/`height` are static styles (`app.rb:19`); nothing feeds a resize back. Slot `width` falls back to the parent's style (`drawable.rb:649-716`): `stack(width: -100).width == 380` in a 480 app, `stack(width: "50%").width == 240`.
- **Spec:** after `resize` to 300x200, `app.width == 300` and `app.height == 200`. A laid-out `stack(width: 0.5)` reports half its parent's inner width in pixels (see C1).
- **Native:** reports resizes with the `resize` message; the shim sets `@width`/`@height` without a `prop_change` echo (DESIGN 4.2). Slot sizes need a layout query or a pushed size; DESIGN 4.2 has none yet for slots.

### A5. Built-in dialogs with no app open

**Ruling: MANUAL.** Built-ins work anywhere, including before `Shoes.app`. **Needs fix 10.6.**

- **Manual:** `ask_color`, `ask_open_file` and `confirm` examples run before any `Shoes.app` (manual 651-655, 665-669, 714-716); built-ins are "usable anywhere" (manual 571-577).
- **Lacci today:** `Shoes::Builtins#shoes_builtin` treats a `nil` answer as "nobody handled it" and falls back to `osascript` for `ask`, `confirm` and the four file/folder dialogs (`builtins.rb:66-105`, macOS only). `alert` and `ask_color` have no fallback and return nil (X8).
- **Docs:** `docs/scarpe_shoes_incompatibilities.md:44-62, 109-118` says pre-app dialogs are unsupported. Partly stale.
- **Spec:** a script that calls `confirm` before `Shoes.app`, with the dialog stubbed, receives the stubbed value and never spawns `osascript`.
- **Native:** the shim must answer a `builtin` even when no App exists yet. DESIGN 5.2 spawns the child lazily on the first DocumentRoot, so a pre-app builtin has no child to ask. The shim should spawn the child on the first `builtin` too (or answer headless stubs), or Lacci pops a real macOS dialog.

### A6. `Shoes.app("/start/url", styles)`

**Ruling: EXT** (Shoes 3). Low priority.

- **Shoes 3:** a leading String argument is the start URL (`s3_app.c:128-138`).
- **Lacci today:** keyword-only signature (`shoes.rb:138-147`); unknown keywords vanish into `**_extras`.
- **Spec:** nothing in `core`. **Native:** nothing; routing is Ruby-side.

### A7. App styles added in Shoes 3.3

**Ruling: OOS.** `fullscreen`, `decorated`, `hidden`, `menus`, `monitor` (`s3_app.c:155-168`). Lacci drops them through `**_extras`; `docs/scarpe_shoes_incompatibilities.md` lists `decoration`, `Shoes.settings` and `Shoes.monitor` as unsupported. The spec does not touch them.

### A8. `close` closes one window

**Ruling: MANUAL.** **Lacci change, unscheduled.** New row.

- **Manual:** "Closes the app window. If multiple windows are open and you want to close the entire application, use the built-in method `exit`." (manual 901-904).
- **Shoes 3:** not checked.
- **Lacci today:** `App#destroy` sends `destroy` with a **nil** target (`app.rb:280-283`), every App listens for nil-target `destroy` (`app.rb:109-113`), and `close` is an alias of `destroy` (`app.rb:287`). So `close` on any window closes every app.
- **Spec:** with two windows open, `close` on the second leaves the first open and `Shoes.APPS.size == 1`.
- **Native:** DESIGN 4.1 `quit` takes an app id or null, but a nil-target `destroy` does not say which app. It needs Lacci to target the App's id.

## B. Blocks, `self` and slot manipulation

### B1. Slot blocks keep the caller's `self`

**Ruling: MANUAL.** **Lacci change, unscheduled** (large).

- **Manual:** "The stack block ... does NOT change self" (manual 198); rule 2: blocks attached to stacks, flows or manipulation methods "do not change self. Instead, they pop the slot on to the app's editing stack" (manual 322-324).
- **Shoes 3:** slot blocks run with a plain `rb_funcall(block, s_call, 0)` inside `DRAW(...)` (`s3_canvas.c:650-653`, insert path `:713-729`); only `app { }` does an `instance_eval` (`:864-874`).
- **Lacci today:** `App#with_slot` does `instance_eval(&block)` on the App (`app.rb:200-207`), used by Stack, Flow, Mask and Shape. `append`/`prepend` special-case non-Drawable callers with `block.call` plus an "external self" fallback (`slot.rb:288-352`). `clear` is annotated `@incompatibility ... Scarpe uses the Shoes::App as self` (`slot.rb:255`). Inside a `Shoes::Widget#initialize`, `stack { self }` is the App and the widget's `@label` is nil.
- **Examples:** identical inside a plain `Shoes.app` block, where `self` is the App either way. Diverges in Widgets and user classes (8 examples use `Shoes::Widget`).
- **Spec:** inside a `Shoes::Widget` method, `stack { @label }` sees the widget's ivar, and the `para` created in that block is a child of the stack.
- **Native:** nothing; this is Ruby-side.

### B2. `app { }` changes `self`, and the manual's fix does not work

**Ruling: ERRATA.** See M39.

- **Manual:** the Messenger fix `@stack.app do @stack.append do para msg end end` (manual 300-313).
- **Shoes 3:** `app { }` is `instance_eval` on the App (`s3_canvas.c:864-874` through `mfp_instance_eval`, `s3_ruby.c:31-33`), so `@stack` inside resolves on the App, not on Messenger.
- **Lacci today:** same (`drawable.rb:447-450`). A plain `@slot.append { para msg }` from a non-Shoes class raises `NoMethodError`, as the manual says (manual 294). The manual's fix raises `NoMethodError: undefined method 'append' for nil`, as Shoes 3 would.
- **Spec:** `s = @stack; @stack.app { s.append { para msg } }` works. Do not transcribe manual 300-313.
- **Native:** nothing.

### B3. Where elements created in an event handler land

**Ruling: MANUAL.** Concordant.

- **Manual:** a button block appending with and without `append` "does the same thing" (manual 2894-2913).
- **Shoes 3:** `shoes_safe_block` does not push a slot (`s3_ruby.c:273-286`); new elements go to the top of `app->nesting`, the app's top slot.
- **Lacci today:** after `init`, `@slots` holds only the document root (`app.rb:166-178`). Same result.
- **Spec:** a `para` created in a button handler is the last child of the app's top slot, not of the button's slot.
- **Native:** follows `parent` and `index` in `create`.

### B4. `prepend`, `before` and `after` keep the order written

**Ruling: MANUAL.** **Needs fix 10.3.** New row.

- **Manual:** `prepend` "Adds elements to the beginning of a slot"; `before(element)`/`after(element)` add elements "just before/after the `element`" (manual 2315-2323, 2349-2360).
- **Shoes 3:** `shoes_canvas_insert` sets one insertion index, then runs the block, so the block's elements land in written order (`s3_canvas.c:713-743`).
- **Lacci today:** each prepended child is `unshift`ed (`slot.rb:50-51`), so `prepend { para "a"; para "b" }` gives `[b, a, ...]`, and the display is never told a position (report 01, 2c). `before`/`after` do not exist (C5).
- **Spec:** `prepend { para "a"; para "b" }` gives children `[a, b, old...]`, and the layout tree puts `a` above `b`.
- **Native:** honours `index` in `create` (DESIGN 4.1); the shim computes it from the Lacci parent's children.

### B5. `slot.remove` removes the children and fires `finish`

**Ruling: MANUAL.** **Lacci change, unscheduled.** New row.

- **Manual:** slot `remove`: "It will no longer be displayed and will not be listed in its parent's contents. It's gone." (manual 2430-2433); `finish` fires "When a slot is removed" and is handed `self` (manual 2195-2198).
- **Shoes 3:** `finish` receives the slot (`s3_canvas.c:1030-1036`).
- **Lacci today:** `alias_method :remove, :destroy` sits on `Drawable` (`drawable.rb:615`), so `slot.remove` binds `Drawable#destroy` and skips `Slot#destroy` (`slot.rb:231-235`), which is the method that cascades to children and fires `finish`. Only the slot's own `destroy` is sent (report 01, 2b, probed).
- **Spec:** `slot.remove` fires the slot's `finish` block with the slot, and none of its children can be found afterwards.
- **Native:** `destroy` removes the whole subtree already (DESIGN 4.1), so the pixels are right today; the Lacci-side children leak and `finish` is lost.

## C. Layout and dimensions

### C1. A Float dimension is a fraction of the parent

**Ruling: MANUAL.** **Lacci change, unscheduled** (getter only).

- **Manual:** a decimal width or height is a percentage, "0.0 being 0% and 1.0 being 100%" (manual 1239-1245, 1539-1545); `button "All of it", width: 1.0, height: 1.0` (manual 2702).
- **Shoes 3:** `shoes_px`: any Float is `parent * f`, a String ending in `%` is a fraction, other Strings go through `to_i` (so `"10px"` is 10), a negative Integer is `parent - |n|` (`s3_ruby.c:298-319`). Floats of 1.0 and above are fractions too.
- **Lacci today:** `compute_dimension` handles `"N%"` and negatives but returns Floats unchanged (`drawable.rb:681-700`): `stack(width: 0.5).width == 0.5`. Calzini turns a Float into `"50.0%"` (`calzini.rb:102-115`), so only the Ruby getter is wrong.
- **Spec:** a laid-out `stack(width: 0.5)` reports half its parent's inner width in pixels; `button width: 1.0` spans its slot.
- **Native:** DESIGN 6.
- **DESIGN conflict (small):** DESIGN 6 says "Float between 0 and 1 exclusive = fraction ... (1.0 = 100%)", which contradicts itself. Shoes 3 treats every Float as a fraction, including 1.0 and 1.5.

### C2. `style[:width]` returns what was asked for

**Ruling: MANUAL.** Concordant. Manual 2470-2487, 2691-2707; Lacci `shoes_style_values` returns the raw values (`drawable.rb:503-535`). **Spec:** `stack(width: 0.5).style[:width] == 0.5`, `style[:width] == "100%"` when given `"100%"`. **Native:** nothing.

### C3. Forms of `:margin`

**Ruling: MANUAL,** plus Shoes 3's tolerance of short arrays. Hash and String forms are **EXT**. **Lacci change, unscheduled.**

- **Manual:** a number, or "an array of four numbers in the form `[left, top, right, bottom]`" (manual 1298-1309). `margin: 0.1` is used as a fraction (manual 3250; see M10).
- **Shoes 3:** `ATTR_MARGINS` reads array entries 0 to 3; a missing entry falls back to the element's default margin (0 for slots, 4 for text blocks), and every entry goes through `shoes_px`, so Floats are fractions (`s3_ruby.h:147-165`).
- **Lacci today:** `MarginHelper#margin_parse` accepts a number, a Hash, a String `"1 2 3 4"`, and 1- or 4-element arrays; **2- and 3-element arrays raise `InvalidAttributeValueError`** (`margin_helper.rb:45-51`).
- **Spec:** `margin: [10, 20]` is accepted: left 10, top 20, right and bottom default. `margin: 0.1` in a 400-wide parent gives 40 px left and right.
- **Native:** DESIGN 6 reads arrays as `[left, top, right, bottom]`; missing entries use the default margin.

### C4. Default sizes of native controls

**Ruling: MANUAL.**

- **Manual:** edit_box "200 pixels by 108 pixels" (manual 3006); edit_line "200 pixels wide and 28 pixels wide. Roughly." (manual 3063, see M6); list_box "about 200 pixels wide and 28 pixels high" (manual 3183); progress "200 pixels wide" (manual 3245).
- **Lacci today:** no defaults; Calzini emits no width (`calzini/misc.rb:15-37, 65-86, 113-128`), so browser defaults apply.
- **Spec:** unstyled edit_box 200x108, edit_line 200 wide, list_box 200 wide, progress 200 wide (±2 px). Heights other than edit_box: 28 ±6.
- **Native:** DESIGN 6 gives edit_line 200x28 and edit_box 200x108.
- **DESIGN conflict:** DESIGN 6 says `list_box 160x28` and `progress 160x14`. The manual says 200 wide for both.

### C5. Slot and element methods Lacci is missing

**Ruling: MANUAL.** Alias Image `path` to `url`. **Lacci change, unscheduled.**

- **Manual:** `before(el) { }`, `after(el) { }` (manual 2315-2323); `scroll_height`, `scroll_max` (manual 2440-2453); `Image#path`, `path=`, `full_width`, `full_height` (manual 3143-3164); `location` (manual 980-982); `started?` (manual 1006-1010); `imagesize` (manual 2017-2023); `gutter` on slots (manual 2394-2410).
- **Shoes 3:** `before`/`after` exist (`s3_canvas.c:731-743`); `started?` is `shoes_app_is_started` (`s3_ruby.c:791`).
- **Examples:** `before` in 5 files, `after` 4, `scroll_max` 1, `location` 3.
- **Lacci today:** none of `before`, `after`, `scroll_max`, `scroll_height`, `location`, `started?`, `imagesize` exist; Image uses a `url` style (`image.rb:5`); `gutter` is App-only and a constant 28 (`app.rb:551-553`).
- **Spec:** each method exists and returns a plausible value (for example `scroll_max == scroll_height - height` on a scrolling stack with overflowing content).
- **Native:** `scroll_height` and `scroll_max` need the content height from Rust. DESIGN 4.2 pushes `scroll` offsets but not content height; the shim can read it from `req layout` or a new push.

### C6. The window scrolls, and `gutter` says by how much

**Ruling: MANUAL.** New row.

- **Manual:** "vertical scrolling has really become the only overflow that matters ... width is generally fixed. While height goes on and on" (manual 1584-1587); "The Shoes window itself is a flow" (manual 1621); `gutter` is "The size of the scrollbar area" (manual 2394-2399).
- **Shoes 3:** the app's top slot scrolls 32 px per wheel notch whenever it has a vertical scrollbar (`s3_app.c:743`, `s3_canvas.c:1231-1236`).
- **Lacci / WV today:** WV sets `body { overflow: hidden }`, so content past the window is clipped unless it sits in a `scroll: true` slot (report 02, section 2). `gutter` is 28 (`app.rb:551-553`).
- **Spec:** an app with content taller than its window scrolls on `wheel`, and the bottom element becomes visible. `gutter` returns an Integer of at least 0.
- **Native:** DESIGN 6: the root scrolls vertically with a thin overlay scrollbar. The overlay should be no wider than `gutter`, so the manual's `margin_right: 20 + gutter` idiom keeps text clear of it.

### C7. Text blocks side by side in a flow read as one paragraph

**Ruling: MANUAL (Q2).** **Native change** if confirmed. New row.

- **Manual:** "Text elements placed next to each other will appear as a single paragraph. Images and widgets will run together as a series." (manual 1610-1612). The window is a flow (manual 1621).
- **Shoes 3:** a text block with no width takes the remaining width of the current line (`s3t_textblock.c:125`). If it starts mid-line, it moves to the flow's left edge with a first-line indent equal to the space already used (`:134-145`), so its first line continues where the previous text ended and later lines wrap back to the left edge. Afterwards the cursor sits at the end of its last line (`:217-228`), so the next element continues from there. In a stack the cursor returns to the left edge (`:235-237`).
- **Examples:** every app that puts two `para`s at the top level relies on this, since the top slot is a flow. Single-line paras look the same under every model. Multi-line paras differ.
- **Lacci / WV today:** each para is its own flex item: shrink-to-fit, packed side by side, and a long para wraps onto a new row as its own box (report 02, 4.1).
- **Spec:** two single-line paras in a flow share a row (all models agree). The multi-line case (the second para's continuation lines start at the flow's left edge) is written, tagged `ledger: C7`, and waits on Q2.
- **Native:** DESIGN 6 today: "in a flow, shrink-to-fit (max-content width capped at the remaining row width, wrapping at that width)". That is WV's box model.
- **DESIGN conflict:** DESIGN 6 follows WV, not the manual. The rule is also ambiguous about order: if the width is capped at the remaining row width before the fit test, a long para never moves to a new row and renders as a narrow column. The layout lane should say "measure max-content; if it does not fit, start a new row; then cap at the row width".

### C8. Default width of a slot

**Ruling: S3.** New row.

- **Manual:** "A stack is also shaped like a box. So if a stack is given a width of 250, that stack is itself an element which is 250 pixels wide." (manual 1602-1603). Silent on the default.
- **Shoes 3:** a slot with no width takes the remaining width of the current line (report 02, 4.1; not re-read line by line for this ledger).
- **Lacci / WV today:** Lacci's getter says "Slots without explicit width should fill their parent (Shoes3 behavior)" (`drawable.rb:649-655`); WV makes a stack in a flow shrink-to-fit (measured 65 px for "stack in flow") and a stack in a stack full width; Flow defaults to `"100%"` (`flow.rb:9`).
- **Spec:** in a flow, `para "a"` followed by `stack { para "b" }` puts the stack on the same row, filling the rest of it.
- **Native:** DESIGN 6 follows Shoes 3. No conflict.

### C9. Default margins of text blocks

**Ruling: S3 (Q3).** New row.

- **Manual:** silent.
- **Shoes 3:** text blocks default to a 4 px margin on every side (`ATTR_MARGINS(self_t->attr, 4, canvas)`), and the bottom margin becomes 12 px when neither `margin` nor `margin_bottom` is given (`s3t_textblock.c:108-110`). A second adjustment at `:239-240` sets the bottom margin to the last line's height after placement (not traced further).
- **Examples:** Shoes 3 examples were written against the spacing; Scarpe-authored examples were written against WV's zero margins.
- **Lacci / WV today:** `p { margin: 0 }` (`calzini.rb:56-87`). Paras stack with no gap.
- **Spec:** written, tagged `ledger: C9`, and waiting on Q3. `core` asserts only that an explicit `margin: 0` gives no gap.
- **Native:** DESIGN 6 gives text blocks no default margin.

### C10. `:right` and `:bottom`

**Ruling: MANUAL.** New row.

- **Manual:** `right: 0` aligns the element's right edge with its slot's right edge; `right: 20` puts it 20 px in (manual 1356-1364). `bottom` is the same for the lower edge (manual 1100-1106).
- **Shoes 3:** `shoes_px2` computes `(parent - dr) - px` when the right/bottom key is present (`s3_ruby.c:327-337`); art shapes read `right`/`bottom` as absolute coordinates instead (`s3_ruby.c:396-399`, see E6).
- **Lacci / WV today:** declared as styles (`drawable.rb:264`) and never rendered (report 02, 4.2).
- **Spec:** `background black, width: 50, right: 50` paints a 50 px column whose right edge is 50 px in from the window's right edge (see M19).
- **Native:** DESIGN 6 does not mention `right`/`bottom`. It should: an element with `right` or `bottom` is out of flow and placed from the slot's right or bottom edge.

### C11. `attach: Window`

**Ruling: MANUAL.** Attaching to the mouse is **EXT**. New row.

- **Manual:** `attach: Window` positions the slot in the window's coordinates; attaching to an element makes the slot follow it; `nil` returns it to the flow (manual 1081-1091).
- **Shoes 3:** `attach` of `Window` is window-relative, `Mouse` is cursor-relative, anything else is sticky to that element (`s3_ruby.c:440-447, 459-465`).
- **Lacci / WV today:** Lacci defines `Window = Shoes::App` (`lacci/lib/shoes.rb:52`), which stringifies to `"Shoes::App"`, and WV matches only `/window/i`, so `attach: Window` does nothing (report 02, 4.3).
- **Spec:** `stack top: 10, left: 10, attach: Window` inside a nested, scrolled slot lands at window point (10, 10).
- **Native:** DESIGN 5.3 turns `attach: Shoes::App` into `"window"` and DESIGN 6 places it in window coordinates. Attaching to a drawable id is in the wire format; its layout rule is not in DESIGN 6 yet.

### C12. Paint order: backgrounds are layered elements

**Ruling: MANUAL.** New row.

- **Manual:** "Backgrounds are actual elements, not styles" (manual 1905); "Shoes layers background elements" (manual 1907); borders likewise (manual 1933).
- **Lacci / WV today:** backgrounds and borders are `position:absolute` divs, and CSS paints positioned boxes after in-flow ones, so a background covers every para and button in its slot regardless of order (report 02, 4.4, screenshots p1 and p3).
- **Spec:** a para declared after a background shows its text colour at a pixel inside a glyph. Nothing about a background declared after the text; Shoes 3's order in that case is not checked.
- **Native:** DESIGN 6 paints in tree order. No conflict.

## D. Colours and patterns

### D1. Colours are `Shoes::Color` objects

**Ruling: MANUAL.** Keep `to_a` and array destructuring working so Lacci callers survive. **Lacci change, unscheduled.**

- **Manual:** `ask_color` returns a `Shoes::Color` (manual 643-655); `rgb` and `gray` return `Shoes::Color` (manual 790, 815).
- **Shoes 3:** `Shoes::Color` with `red green blue alpha black? dark? light? white? opaque? transparent? invert to_s inspect to_pattern <=> ==` (`s3t_color.c:16-33`).
- **Lacci today:** plain Arrays `[r, g, b, a]` (`colors.rb:152-176`). `black(0.1)` gives `[0, 0, 0, 0.1]`, integer channels with a float alpha.
- **Spec:** `rgb(1, 2, 3).is_a?(Shoes::Color)`, `.red == 1`, `.alpha == 255`; `r, g, b, a = rgb(1, 2, 3).to_a` still works.
- **Native:** nothing. The shim's normaliser accepts both Arrays and Color objects (DESIGN 5.3).

### D2. `rgb()` reads each component's type on its own

**Ruling: MANUAL** (Shoes 3 agrees). **Needs fix 10.7.**

- **Manual:** `rgb(0, 0.4, 0)` is dark green (manual 827-832); integers 0-255 or floats 0.0-1.0.
- **Shoes 3:** `NUM2RGBINT(x)` is `ROUND(x * 255)` for a Float and `x` otherwise (`s3_ruby.h:130`), applied to r, g, b and a separately (`s3t_color.c:216-224`).
- **Examples:** `rgb(0, 0.6, 0.9)`, `rgb(0, 0.6, 0.9, 0.1)`, and 10 calls shaped `rgb(int, int, int, 0.x)` (for example `for_playtest/expert/minesweeper.rb`, `tooltips.rb`, `curve-animation.rb`).
- **Lacci today:** the mode comes from `r` alone (`colors.rb:168-176`): `rgb(0, 0.4, 0) == [0, 0.4, 0, 255]`.
- **Spec:** `rgb(0, 0.4, 0)` has green 102; `rgb(10, 20, 30, 0.5)` has alpha 128.
- **Native:** DESIGN 5.3 scales float channels per component.

### D3. Alpha is opacity, and named colours take an alpha

**Ruling: MANUAL.**

- **Manual:** `fill black(0.1)` (manual 394), `fill red(0.2)` (manual 1809).
- **Shoes 3:** a named colour's alpha goes through `NUM2RGBINT` (`s3t_color.c:445-465`); patterns use `cairo_pattern_create_rgba` (`:252-258`).
- **Examples:** `green(0.2)` 4 files, `black(0.1)` 4, `red(0.2)` 3, `red(0.1)` 2, `red(0.05)` 2, and a handful of others.
- **Lacci / WV today:** `red(0.2) == [255, 0, 0, 0.2]` (`colors.rb:152-158`). Calzini premultiplies shapes and text into black (`fill:#000000`) and hands backgrounds raw `rgba(...)`, which is right for integer arrays and wrong for float ones (X4).
- **Spec:** a `red(0.2)` rect over white reads close to `[255, 204, 204]` at its centre.
- **Native:** DESIGN 5.3 normalises the alpha.

### D4. `rgb`, `gray` and `gradient` are Kernel built-ins, and `Shoes.rgb` works

**Ruling: MANUAL.** **Lacci change, unscheduled.**

- **Manual:** built-ins that "may also be called as `Shoes.rgb`" (manual 785-834).
- **Shoes 3:** defined on `rb_mKernel` and as `Shoes::Color` singletons (`s3t_color.c:11-15, 38-40`).
- **Lacci today:** only through `include Shoes::Colors` on Drawables (`drawable.rb:15`). `Shoes.respond_to?(:rgb) == false`, and top-level `rgb(1, 2, 3)` raises `NoMethodError` (X5).
- **Spec:** `Shoes.rgb(1, 2, 3)` and a top-level `rgb(1, 2, 3)` outside any app both return a colour.
- **Native:** nothing.

### D5. Three-digit hex multiplies by 17

**Ruling: S3.** **Needs fix 10.7.**

- **Manual:** uses `"#DFA"` (manual 118) without defining it.
- **Shoes 3:** each nibble times 17: `#DFA` is `DD FF AA` (`s3t_color.c:287-293`).
- **Examples:** about 93 short-hex uses.
- **Lacci today:** `to_rgb` multiplies by 16 (`colors.rb:229-234`): `to_rgb("#DFA") == [208, 240, 160, 255]`. WV hands hex strings to CSS, so it renders right anyway.
- **Spec:** `#DFA` reads back as 221, 255, 170.
- **Native:** DESIGN 5.3 (x17).

### D6. Gradient direction, `:angle`, Ranges and radial

**Ruling: MANUAL** (Shoes 3 agrees). Radial is **EXT**. **Lacci change, unscheduled** (default angle, `Background` angle, alpha).

- **Manual:** "Normally, gradient colors range from top to bottom. If the `:angle` is set to 90, the gradient will rotate 90 degrees counter-clockwise and the gradient will go from left to right." (manual 1073-1079). `:fill`/`:stroke` accept "a range of either" (manual 1202, 1453).
- **Shoes 3:** angle defaults to 0; the direction vector is `(sin a, cos a)`, so 0 runs top to bottom and 90 runs left to right (`s3t_pattern.c:53-72`); a Range becomes a gradient (`:86-89`); `:radius` makes it radial (`:65-69`), though the radius parse checks the wrong variable and always uses 0.001.
- **Examples:** 15 files use `"#x".."#y"` Ranges; `for_playtest/shoes-contrib/styles/gradient-angle.rb` uses `gradient purple, red, :angle => 45`.
- **Lacci / WV today:** `Gradient` defaults to 45 (`colors.rb:198`); Ranges render as `linear-gradient(45deg, ...)`; the Shoes angle goes to CSS unchanged although CSS 0 runs bottom to top. `Background` has no `:angle` style, so `background r..b, angle: 30` is dropped with a warning (`background.rb:12`, `drawable.rb:385-388`). `gradient()` throws away each colour's alpha (`colors.rb:185-186`). No radial.
- **Spec:** `background red..blue` is red at the top row and blue at the bottom row; with `angle: 90` it is red on the left and blue on the right.
- **Native:** DESIGN 5.3 sends `{"gradient":[c1,c2],"angle":deg}`; angle 0 is top to bottom. A CSS-style renderer maps `css_deg = 180 - shoes_deg`. Until Lacci's default changes, the native backend receives 45 for a plain `gradient(a, b)`.

### D7. `nofill` and `nostroke` mean "none"

**Ruling: MANUAL.**

- **Manual:** no fill, no outline (manual 1701-1709).
- **Shoes 4:** sets the style to nil (`s4_dsl_style.rb:70-83`).
- **Lacci / WV today:** puts `rgb(0, 0, 0, 0)` in the draw context (`slot.rb:131-133, 157-159`); Calzini renders that as opaque black (X4).
- **Spec:** after `nofill`, an oval's centre pixel shows the background.
- **Native:** treats a fully transparent colour and null the same: paint nothing.

### D8. Default fill, stroke and stroke width of shapes

**Ruling: S3.** Black fill, black stroke, width 1, and `strokewidth` honoured on every shape.

- **Shoes 3:** `strokewidth` defaults to 1.0 (`s3t_shape.c:98`). Default fill and stroke colours: not re-checked here.
- **Shoes 4:** `STYLES = { fill: black }` for Oval and Star (`s4_oval.rb:6`, `star.rb:6`).
- **Lacci / WV today:** Oval defaults `fill: "black"`, `stroke: "black"` (`oval.rb:15-16`); Calzini uses stroke width 2 for ovals, a hard-coded 2 for stars and 4 for lines, ignoring `strokewidth` (`art_drawables.rb:78, 83, 97, 185`).
- **Spec:** a default `rect` over white has a black interior and a 1 px outline; `strokewidth 5; line ...` draws a line about 5 px thick.
- **Native:** draws every shape with the draw context's fill, stroke and width, defaulting to black, black, 1.

## E. Art

### E1. The third positional argument of `oval` is a diameter

**Ruling: MANUAL** (Shoes 3 and Shoes 4 agree). The `radius:` style stays a true radius. **Needs fix 10.10.**

- **Manual:** `oval(left, top, radius)` draws "a width and height of `radius` pixels" (manual 1716-1719); the `:radius` style is "equivalent to setting both `:width` and `:height` to double this number" (manual 1352-1354); `oval(left, top, width, height)` (manual 1734). Its own examples disagree about the style (M1).
- **Shoes 3:** positional arguments map to `left, top, width, height`; a radius variant is commented out (`s3t_shape.c:347-352`); `shoes_place_exact` doubles only the `:radius` style and defaults height to width (`s3_ruby.c:393-395`).
- **Shoes 4:** `oval(left, top, diameter)` (`s4_dsl_art.rb:98-125`); `width ||= @style[:width] || @style[:diameter] || (@style[:radius] || 0) * 2` (`s4_oval.rb:8-15`).
- **Examples:** at least 16 files draw three-argument ovals (fresh regex count; the seed counted 21). `for_playtest/expert/minesweeper.rb` draws `@app.oval(x*cell_size+3, y*cell_size+3, 13)` inside a cell; `mice-satellites.rb` centres with `oval(hor - radius, vert - radius, radius*2.0)`. Scarpe's own `examples/oval.rb` assumes radius semantics and passes `center: true` everywhere to dodge the WV bug in E2; it must change.
- **Lacci today:** the third positional is stored as `:radius` and `width = radius * 2` (`oval.rb:18-19, 33, 42`): `oval(10, 10, 50)` is 100 wide, and `oval(0, 0, 100, 100)` is 200x100 (M2). The `radius:` style is already right.
- **Spec:** `oval(10, 10, 50).width == 50`; `oval(radius: 50).width == 100`; `oval(0, 0, 100, 100)` is 100x100.
- **Native:** draws an ellipse inscribed in (left, top, width, height).

### E2. `center: true` makes (left, top) the centre

**Ruling: MANUAL.**

- **Manual:** `:center` means the coordinates are the centre (manual 1115-1121, 1745).
- **Shoes 3:** shifts by `w/2`, `h/2` (`s3_ruby.c:401-404`).
- **Lacci / WV today:** stored, but Calzini inverts it: `cx: center ? radius : 0` (`art_drawables.rb:114, 123`). Without `center`, WV shows a clipped quarter circle; with it, the oval sits where the manual's default would put it.
- **Spec:** `oval 100, 100, 50, center: true` covers pixel (100, 100) and its box is (75, 75, 50, 50).
- **Native:** centres on (left, top) when `center` is true.

### E3. `rect` arguments are `left, top`

**Ruling: ERRATA** for the heading. The two-argument form follows **Shoes 4** (`left, top`, zero size); Scarpe's `(width, height)` form is **EXT**.

- **Manual:** the heading says `rect(top, left, width, height, corners = 0)` and "starting from coordinates (top, left)" (manual 1749-1753), while `rect(styles)` lists `left`, `top`, `curve` (manual 1770-1781) and every other shape takes `left, top` (M3).
- **Shoes 3:** `left, top, width, height, curve` (`s3t_shape.c:342-345`).
- **Shoes 4:** the same, plus `rect(left, top, side)` (`s4_dsl_art.rb:127-158`).
- **Lacci today:** `init_args :left, :top, :width, :height; opt_init_args :curve` (`rect.rb:8-9`); three arguments make a square; **two arguments mean `(width, height)` at the origin**; one argument is a square at the origin (`rect.rb:17-30`).
- **Spec:** `rect(10, 20, 30, 40)` occupies x 10..40, y 20..60. `rect(10, 20, 30)` is a 30x30 square at (10, 20).
- **Native:** draws from the `left`/`top`/`width`/`height` props. Nothing to decide.

### E4. `star` is centred, and `outer` is a radius

**Ruling: MANUAL.** Geometry details follow **S3**.

- **Manual:** "positioned with its center point at coordinates (left, top)"; "The `outer` width defines the full radius of the star" (manual 1826-1831). Defaults `points = 10, outer = 100.0, inner = 50.0`.
- **Shoes 3:** centred on (left, top) with radii `outer`/`inner`. The path starts at `(left, top + outer)`, which is straight **down**, and steps by `pi / points` (`s3t_shape.c:154-175`). So a star with an odd number of points has a point at the bottom and a notch at the top. The shape's reported width and height are `outer`, not `2 * outer` (`:162`).
- **Shoes 4:** `width = outer * 2`, centred (`star.rb:9-38`).
- **Lacci / WV today:** defaults match (`[10, 100.0, 50.0]`); Calzini draws an `outer`-sized SVG at (left, top) and uses `outer / 2` as the radius (`art_drawables.rb:59-90, 217-233`), so the star is half size and offset by (+50, +50).
- **Spec:** `star(100, 100, 5, 50, 20)` fills pixel (100, 100) and paints nothing more than 51 px from it; a pixel 45 px straight below the centre is inside the bottom point.
- **Native:** reproduces the Shoes 3 path, including the downward first point.

### E5. `arrow(left, top, width)` is centred on (left, top) and points right

**Ruling: S3** (Shoes 4 agrees; the manual only says "at coordinates (left, top) with a pixel `width`", manual 1672-1674).

- **Shoes 3:** exact path (`s3t_shape.c:134-153`): with `w` the width, the tip is at `(left + w/2, top)`; the head is `0.42 w` long and `0.8 w` tall; the shaft is `0.4 w` tall and reaches back to `left - w/2`. The arrow spans x `left - w/2 .. left + w/2` and y `top - 0.4 w .. top + 0.4 w`.
- **Shoes 4:** `left` is "x-coordinate of the element center" (`s4_dsl_art.rb:12-15`).
- **Lacci / WV today:** Calzini draws from `left` to `left + width`, pointing left, in an unsized 300x150 SVG, so any arrow with `top >= 150` vanishes (`art_drawables.rb:238-289`).
- **Spec:** `arrow(100, 100, 40)` fills pixel (100, 100) and paints nothing at (123, 100) or at (100, 118).
- **Native:** reproduces the Shoes 3 path.

### E6. `line(left, top, x2, y2)` takes absolute end points

**Ruling: MANUAL** (Shoes 3 agrees).

- **Manual:** "starting at coordinates (left, top) and ending at coordinates (x2, y2)" (manual 1711-1714).
- **Shoes 3:** stores `right`/`bottom` as the absolute end point (`s3t_shape.c:354-357`, `s3_ruby.c:396-399`).
- **Lacci / WV today:** `init_args :left, :top, :x2, :y2` (`line.rb:8`); Calzini offsets the start twice and sizes the SVG `x2 × y2`, so a horizontal line gets a zero-height SVG (`art_drawables.rb:50-58`).
- **Spec:** `line(10, 150, 200, 150)` strokes pixel (100, 150) and nothing at (20, 300).
- **Native:** strokes from (left, top) to (x2, y2).

### E7. `shape { move_to; line_to; curve_to; arc_to }` is one path

**Ruling: MANUAL.** **Needs fix 10.2.**

- **Manual:** one path starting at (left, top) (manual 1799-1804); art inside a shape joins as a group "drawn as one" (manual 1820-1824); the Rules chapter's version is M21.
- **Shoes 3:** builds a cairo path and measures its extents into width/height (`s3t_shape.c:300-316`); art calls inside a shape add sub-paths to it (`:326-331`).
- **Examples:** `for_playtest/expert/curve-control-point.rb:16` calls `move_to *xy[0]` outside any shape.
- **Lacci today:** `Shape < Shoes::Slot` with `@incompatibility A Shoes3 Shape is *not* a slot; Scarpe does *not* do union shapes` (`shape.rb:11-12`). `shape_commands` is sent empty at create and mutated afterwards without a `prop_change` (`shape.rb:25-31`, X7). `move_to` and friends are ignored outside a Shape (`app.rb:509-568`).
- **Spec:** a closed `shape` fills its interior with the current fill; an oval created inside a shape paints (is not dropped).
- **Native:** builds one path from the complete `shape_commands`, offset by (left, top). Art children of the shape are unioned into the same path.

### E8. `click`, `release`, `hover` and `leave` on shapes, text blocks and images

**Ruling: MANUAL.** **Needs fix 10.9.**

- **Manual:** the `:click` style is "For: arc, arrow, banner, button, caption, check, flow, image, inscription, line, link, mask, oval, para, radio, rect, shape, stack, star, subtitle, tagline, title" (manual 1144-1151).
- **Shoes 3:** `Shape#click`, `release`, `hover`, `leave` (`s3t_shape.c:33-36`).
- **Examples:** `for_playtest/expert/curve-control-point.rb:22-30` (drag with oval `click`/`release`), `expert/colours.rb:70`.
- **Lacci today:** `Drawable#click`/`#release` store `@block`/`@release` (`drawable.rb:784-802`), but only Button, Check, Radio, Link, Image and SubscriptionItem bind a `click` event; art classes declare no events, so the handler never fires (X9).
- **Spec:** `oval(...).click { }` fires on `click_at` the oval's centre and not on a click outside it.
- **Native:** routes a press to the topmost drawable with `has_click` (DESIGN 4.3).

### E9. `image(w, h) { drawing }` is a canvas

**Ruling: MANUAL** for the canvas; effects (`blur`, `glow`, `shadow`) are **EXT**. **Lacci change, unscheduled.**

- **Manual:** `image 300, 300 do ... end` renders the shapes into one image (manual 410-426); the block form is not documented under `image` itself (M23).
- **Shoes 3:** shapes inside an image draw into its surface (`s3t_shape.c:318-323`); effects live in `shoes/types/effect.c` (not fetched).
- **Examples:** 3 files (`simple-sphere.rb`, `shoes_manual/ovals_image.rb`, ...); `blur` in 1.
- **Lacci today:** `image(w, h)` becomes a blank placeholder and the block is ignored (`image.rb:10-20`).
- **Spec:** `image(100, 100) { oval 0, 0, 50 }` paints the oval inside the image's box.
- **Native:** needs the image to act as an offscreen slot. Not in DESIGN yet.

### E10. `transform`, `translate`, `cap`, `rotate`, `scale`, `skew`

**Ruling: MANUAL,** low priority.

- **Manual:** manual 1676-1680, 1783-1797, 1857-1868. `transform`: "Shoes defaults to `:corner`", the corner of the shape (1857-1860).
- **Shoes 3:** `shoes_transform_new` starts every transform in `s_center` mode, and outside centre mode the matrix is applied about the canvas origin, not the shape's corner (`s3_canvas.c:31-41, 192-205`). The ruling keeps the manual's shape corner; nobody has checked what a real Shoes 3 draws.
- **Lacci today:** `translate` and `cap` are no-ops (`app.rb:555-573`); `transform` exists only on Image (`image.rb:74-83`); `rotate`/`scale`/`skew` go into the draw context (`slot.rb:166-193`), and WV applies them to some shapes only (report 02, 6.8). The M2 contract has Lacci send `translate: [x, y]` (running total), `transform: "center"|"corner"` and `cap: "curve"|"rect"|"project"` in the draw context.
- **Spec:** `rotate 45; rect 100, 100, 50, 10` paints a pixel off the unrotated rect's box.
- **Native:** applies the draw context's transforms to every shape, rotating about the shape's top-left corner unless `transform: "center"` (or `center: true`); `translate` moves the shape and its layout box; caps are round, flat or square (DESIGN 12).

## F. Text

### F1. `ins()` is an underline fragment

**Ruling: MANUAL.** Revert the alias. **Needs fix 10.8.**

- **Manual:** `ins(text) » Shoes::Ins`, "which Shoes styles with a single underline" (manual 2025-2028); `inscription` is the 10 px block (manual 2030-2032).
- **Shoes 4:** `ins: { underline: true }` (`s4_dsl_text.rb:108-116`).
- **Examples:** Scarpe's own `examples/span.rb:6` puts `ins("hard to read")` inside a `para`.
- **Lacci today:** `alias_method :ins, :inscription` on `Shoes::Drawable` (`para.rb:314-315`, commit `2212244`, X3). The correct `Shoes::Ins` fragment exists with `underline: "single"` but is unreachable (`text_drawable.rb:127-131`).
- **Spec:** `ins("x").class == Shoes::Ins`; its underline is `"single"`; `para "a", ins("b")` is one text block.
- **Native:** renders `Ins` as an underlined span.

### F2. Text blocks are distinct classes

**Ruling: MANUAL.** Subclasses, so a class-level `style()` targets one kind. **Lacci change, unscheduled.**

- **Manual:** `banner » Shoes::Banner`, `title » Shoes::Title`, and so on (manual 1921-2129); sizes 48, 34, 26, 18, 14, 12, 10 (manual 3378-3384).
- **Shoes 4:** `Shoes.const_get(method.capitalize)` per block type (`s4_dsl_text.rb:50-56`).
- **Lacci today:** all are `Para` with `size: :banner|:title|...` (`para.rb:258-316`): `title("T").class == Shoes::Para`. So `style(Shoes::Para, stroke: red)` restyles titles too, and `style(Shoes::Title, ...)` cannot be expressed. Sizes match the manual (`calzini.rb:24-33`).
- **Spec:** `title("T").class == Shoes::Title`; after `style(Shoes::Title, stroke: red)`, a new `para` keeps the default stroke.
- **Native:** if Lacci switches to subclasses, `create` will carry `kind: "Title"` and friends; the Rust `Kind` enum (DESIGN 7) must treat them all as Para with a default size.

### F3. `:size` accepts relative strings

**Ruling: MANUAL.** Symbol sizes (`:title`) are **EXT**.

- **Manual:** `"xx-small"` 57% up to `"xx-large"` 173% "of present size" (manual 1393-1408). `:size` is a pixel size (manual 1398).
- **Lacci / WV today:** Calzini's `text_size` maps unknown strings through `SIZES[sz.to_sym] || sz.to_i`, so `"large"` becomes 0 (`calzini.rb:88-99`).
- **Spec:** `para "x", size: "large"` lays out taller than `para "x"`.
- **Native:** maps the names to the manual's percentages of the element's default size.

### F4. `:weight`, `:variant` and `:font`

**Ruling: MANUAL.** `font_weight` and `font_variant` stay as **EXT** aliases.

- **Manual:** `:weight` names from `ultralight` (200) to `heavy` (900), or a number (manual 1521-1537); `:variant` is `"normal"` or `"smallcaps"` (manual 1511-1519); `:font` is a Pango description `"[FAMILY-LIST] [STYLE-OPTIONS] [SIZE]"` (manual 1212-1224).
- **Examples:** `weight:` in 4 files (`"bold"`, `"ultrabold"`, `"strong"`).
- **Lacci / WV today:** Para declares `:weight`, but Calzini only renders `font_weight` (`calzini/para.rb:47`), so `weight: "bold"` shows normal. `variant:` is not a style and is dropped with a warning. `FontHelper#parse_font` knows CSS names only (`font_helper.rb:15-18`).
- **Spec:** `para "x", weight: "bold"` lays out wider than `para "x"`.
- **Native:** maps weight names to numeric weights and parses the Pango-style font string (family list, style words, size).

### F5. Text styles Lacci drops

**Ruling: MANUAL.** **Lacci change, unscheduled.**

- **Manual:** `:leading` (manual 1282-1286, see F10), `:justify` (1268-1273), `:rise` (1366-1373), `:stretch` (1423-1434), `:strikecolor` (1436-1441), `:undercolor` on Para (1489-1494).
- **Lacci / WV today:** none are Para styles (`para.rb:6-36`); they hit the "Unexpected non-style keyword" warning (`drawable.rb:385-388`). TextDrawable has `:undercolor` (`text_drawable.rb:15`). Calzini already renders `rise`, `strikecolor` and `undercolor` when present (`calzini/para.rb:43-50, 79-82`).
- **Spec:** each style is accepted without a warning and reads back through `style`; `leading` and `rise` change layout.
- **Native:** honours them once Lacci sends them.

### F6. `underline` and `strikethrough` value types

**Ruling: BOTH.** Map `true` to `"single"` and `false` to `"none"`.

- **Manual:** strings (manual 1443-1451, 1496-1509).
- **Shoes 4:** booleans (`s4_dsl_text.rb:110-112`).
- **Lacci today:** the validators accept only nil or the manual's strings; `true` raises `InvalidAttributeValueError` (`para.rb:15-29`, `text_drawable.rb:17-31`).
- **Spec:** `underline: "single"` and `underline: true` both underline.
- **Native:** receives the string form.

### F7. Link and LinkHover defaults

**Ruling: MANUAL.**

- **Manual:** a link has a single underline and a `#06E` stroke; LinkHover has a single underline and a `#039` stroke (manual 2034-2039).
- **Shoes 4:** `STYLES = { underline: true, stroke: blue, fill: nil }` (`s4_link.rb:13`).
- **Examples:** `style(Shoes::Link, :underline => nil)` plus `style(Shoes::LinkHover, ...)` in `for_playtest/simple/menu.rb:25-26`, `menu1.rb:14-15`, `philippe_checked/accordion.rb:46-47`, `shoes-contrib/simple/simple-accordion.rb:39`.
- **Lacci today:** Link styles are nil; LinkHover class defaults are stored by `style()` but "The functionality isn't present in Lacci yet" (`link.rb:35-41`).
- **Spec:** an unstyled link's glyph pixels read close to `#0066EE` and it is underlined; after `style(Shoes::Link, underline: nil)` it is not.
- **Native:** DESIGN 7 uses `#0066ee` with an underline, which is `#06E`. On hover it should switch to `#039` (`#003399`) unless the app styled LinkHover; DESIGN only says "darker on hover".

### F8. The argument passed to a link's click block

**Ruling: S3** (the 3.2-era behaviour, and Lacci's today). Specced under `compat-both`.

- **Manual:** silent (`link(text, click: proc or string)`, manual 2034).
- **Shoes 3:** the 3.2-era call passed the link element; that line is commented out in 3.3, which passes `(button, x, y, mods)` (`s3_canvas.c:1113-1115`).
- **Lacci today:** passes the Link (`link.rb:29-30`, commit `19ad0d0`, for `shoes-notes.rb`'s `link('x') { |x| x.parent.remove }`).
- **Spec:** only `arg.is_a?(Shoes::Link)`, under `compat-both`.
- **Native:** sends `click` with no args for links (DESIGN 4.3); Lacci supplies the Link.

### F9. `link(text, click: proc)` fires the proc

**Ruling: MANUAL.** **Needs fix 10.5.** New row.

- **Manual:** `link(text, click: proc or string)` (manual 2034).
- **Lacci today:** only the block form works. With `click: proc`, `@block` is nil and `has_block` is false, and the click handler calls only `@block` (`link.rb:11-31`), so the proc never runs (report 01, section 9, item 6).
- **Spec:** clicking `link("x", click: proc { $hit = true })` sets `$hit`.
- **Native:** hit-tests the link span and sends `click` (DESIGN 4.3).

### F10. `:leading` defaults to 4 pixels

**Ruling: MANUAL** (Shoes 3 agrees). New row.

- **Manual:** "Sets the spacing between lines in a text block. Defaults to 4 pixels." (manual 1286).
- **Shoes 3:** `ld = ATTR2(int, self_t->attr, leading, 4)`, passed to `pango_layout_set_spacing` (`s3t_textblock.c:127, 148`).
- **Lacci / WV today:** no `leading` style (F5); CSS line height applies.
- **Spec:** a two-line para with `leading: 0` lays out shorter than the same para with default leading.
- **Native:** DESIGN 6 says "Line height = 1.2 x size (plus `leading` if given)".
- **DESIGN conflict:** the manual adds 4 px between lines when `leading` is not given.

### F11. `para` with non-String arguments

**Ruling: BOTH.** New row.

- **Manual:** silent. Its examples assign Integers to `text=` (`@counter.text = e.text.size`, manual 3025).
- **Lacci today:** Arrays are joined (`para(["a", "b"]).text == "ab"`), other objects go through `to_s`/`inspect`; `strong("0").text = 5` reads back `"5"` (report 03 probes).
- **Spec:** only `para(5).text == "5"` and `text = 5` reading back `"5"`.
- **Native:** receives Strings.

## G. Native controls

### G1. Control callbacks receive the control

**Ruling: MANUAL.** **Lacci change, unscheduled.**

- **Manual:** button `click { |self| }` (manual 2918-2921); check and radio `click { |self| }` (manual 2988-2993, 3349-3354); edit_box, edit_line and list_box `change { |self| }` (manual 3038-3042, 3086-3090, 3211-3215).
- **Shoes 3:** every control event calls its block with `rb_ary_new3(1, self)` (`s3t_native.c:189-193`).
- **Shoes 4:** `listener.call(self)` (`s4_common_changeable.rb:25-31`).
- **Examples:** `for_playtest/shoes-contrib/elements/edit_line-character-count.rb:2-3` does `edit_line do |e| @counter.text = e.text.size end`, which breaks on a String.
- **Lacci today:** Button calls its block with no arguments (`button.rb:42-45`); **EditLine passes the new String** (`edit_line.rb:15-20`); EditBox, ListBox, Check and Radio pass `self`.
- **Spec:** the button's click block receives the Button; the edit_line's change block receives the EditLine, whose `text` is the new value.
- **Native:** nothing; the argument is Ruby-side.

### G2. The `list_box(...) { }` block is the change handler

**Ruling: MANUAL.** **Needs fix 10.4.**

- **Manual:** manual 3186-3206.
- **Shoes 3:** `ATTRSET(args.a[0], change, args.a[1])` (`s3t_list_box.c:106-107`).
- **Shoes 4:** passes the block (`s4_dsl_element.rb:90-91`).
- **Examples:** `for_playtest/shoes-contrib/basic/list_box-select-class.rb`, `for_playtest/shoes_manual/list_box.rb`, and `working/custom-list-box.rb:41`, which sits in `working/` although its handler can never fire.
- **Lacci today:** `super(**kwargs, &block)` ignores the block; `@callback` is only set by `#change` (`list_box.rb:15-29`, X2). A `change` dispatch reaches nobody.
- **Spec:** picking "b" in `list_box(items: %w[a b]) { |lb| $picked = lb.text }` sets `$picked == "b"`.
- **Native:** sends `change` with the item string (DESIGN 4.3).

### G3. List box initial selection, `text`, and `choose`

**Ruling: MANUAL.** **Needs fix 10.4** (`choose` echo); the default selection is a **Lacci change, unscheduled.**

- **Manual:** `text` is nil when nothing is selected (manual 3234-3237); `:choose` pre-selects (manual 1137-1142).
- **Lacci / WV today:** `@chosen = kwargs.delete(:choose) || @items&.first` (`list_box.rb:19`), so `text == "a"` with nothing chosen. Calzini selects by `props["choose"]` while Lacci sends `chosen` (`calzini/misc.rb:74-77` against `list_box.rb:10`). `#choose` sets `@chosen` without a `prop_change` (`list_box.rb:35-41`, X11).
- **Spec:** `list_box(items: %w[a b]).text` is nil; `choose: "b"` gives `"b"`; after `lb.choose("a")` the display shows "a" (layout text or snapshot).
- **Native:** reads `chosen`; shows an empty selection when it is null.

### G4. `:state` (nil, `"readonly"`, `"disabled"`)

**Ruling: MANUAL.** **Lacci change, unscheduled.** Button readonly is M33.

- **Manual:** for button, check, edit_box, edit_line, list_box, radio (manual 1410-1421).
- **Shoes 3:** `shoes_control_check_styles` applies `state` to every native control (`s3t_native.c:155-158`).
- **Lacci today:** no `:state` style; `button("dis", state: "disabled")` is accepted with a warning and ignored.
- **Spec:** clicking a disabled button does not call its block; typing into a readonly edit_line does not change its `text`.
- **Native:** draws disabled controls greyed and ignores their input; readonly inputs take focus and selection but no edits.

### G5. Does a programmatic `text=` fire `change`?

**Ruling: BOTH.** The spec asserts neither. Q7 asks whether to pin Scarpe's choice under `ext-scarpe`.

- **Manual:** silent (M32).
- **Shoes 3:** platform-dependent: GTK emits "changed" from `gtk_entry_set_text`, Cocoa does not.
- **Lacci today:** fires, on purpose: commit `eda8975` ("a deliberate deviation from Shoes3 behavior for better UX"), `edit_line.rb:30-40`, `edit_box.rb:30-40`.
- **Spec:** nothing either way.
- **Native:** sends `change` only for user edits; the programmatic path is Lacci's.

### G6. Radio grouping

**Ruling: MANUAL.**

- **Manual:** ungrouped radios group per slot; `radio :films` groups across slots (manual 2069-2074, 3293-3334).
- **Lacci / WV today:** Lacci groups by `@group || @parent&.linkable_id` (`radio.rb:55-57`), which is right. Calzini sets HTML `name: props["group"] || "no_group"` (`calzini/misc.rb:88-90`), so every ungrouped radio in the window is one browser group.
- **Spec:** two ungrouped radios in different stacks can both be marked; two radios sharing `:films` across stacks cannot.
- **Native:** does no grouping of its own. It sends `click` and shows Lacci's `checked` echo (DESIGN 4.3).

### G7. Button styling

**Ruling: EXT.** The Shoes 3.3 set (`font:`, `stroke:`, `icon:`, `icon_pos:`, `tooltip:`, from `for_playtest/shoes3-tests/button/button.rb`) is `ext-s33`. Scarpe-only `:color`, `:text_color`, `:font_size`, `:padding_*` (`button.rb:5`) are `ext-scarpe` behind `features: :scarpe`. The manual gives buttons no colour style. **Native:** honours the S3.3 set; Scarpe-only styles when the feature is on.

### G8. `check.checked`

**Ruling: MANUAL,** low. The manual documents `checked?` and `checked=` (manual 2979-2986). Lacci defines `checked(value)` with one required argument, which shadows the style getter (`check.rb:29-31`, same in `radio.rb:49-51`), so `check.checked` raises `ArgumentError`. **Spec:** `checked?` and `checked=` only. **Native:** nothing.

### G9. `focus` on buttons, and Enter clicks the focused button

**Ruling: MANUAL.** **Lacci change, unscheduled.** New row.

- **Manual:** button `focus`: "The button will be highlighted and, if the user hits Enter, the button will be clicked." (manual 2923-2926); radio `focus`, Enter toggles (manual 3356-3359).
- **Lacci today:** Button has no `focus` (report 03 probe); ListBox, EditBox and EditLine do.
- **Spec:** `button.focus`, then `press_key "\n"`, fires the click block once.
- **Native:** accepts `focus` for buttons, checks and radios; Enter or Space on a focused button sends `click`.

## H. Events

### H1. `keypress` key values

**Ruling: MANUAL (Q5),** with **S3**'s platform mapping for macOS: **Cmd is `alt_`**. Shoes 4's `super_` is **EXT**.

- **Manual:** characters arrive as Strings; special keys and combinations as Symbols. "The modifier keys are `control`, `shift` and `alt`. They appear in that order." (manual 2219-2221). Shift only shows on special keys; Return is `"\n"`, but with modifiers it becomes `:control_enter`, `:shift_alt_enter` and so on; `Shift-Alt-7` is `:alt_&` (manual 2207-2249).
- **Shoes 3, GTK:** Return is `rb_str_new2("\n")` (`s3_gtk.c:760-762`); Ctrl or Alt plus a character becomes a Symbol (`:765-778`); a modified Return becomes `:enter` (`:817-819`); modifiers are applied alt, then shift, then control, each as a prefix (`:821-830`), giving `control_shift_alt_...`.
- **Shoes 3, Cocoa:** **Cmd and Alt both become `alt_`** (`if ((modifier & NSCommandKeyMask) || (modifier & NSAlternateKeyMask)) KEY_STATE(alt);`, `s3_cocoa.m:287-288`, and for plain characters `:296-297`); Ctrl is `control_` (`:291-292`).
- **Shoes 4:** CR is `"\n"`; prefixes `control_`, `shift_` (special keys only), `alt_`, `super_` for Cmd (`s4swt_key_listener.rb:27, 85-91`); any modified key becomes a Symbol (`:143-145`).
- **Examples:** `for_playtest/shoes-contrib/simple/simple-editor.rb:19-23` and `philippe_checked/editor.rb:19-23` bind `:alt_q` (quit), `:alt_c` (copy), `:alt_v` (paste), which are Cmd-Q, Cmd-C and Cmd-V on a Mac under Shoes 3. `philippe/minimal_editor.rb:119` accepts `:control_a, :alt_a`. `needs_deps/expert-irb.rb:80` waits for `"\n"`.
- **Lacci / WV today:** WV maps Enter to `:return` (`wv/subscription_item.rb:127`); prefixes are `alt_`, then `control_`, then `shift_` (`:147-158`); Cmd (Meta) is ignored; a modified special key loses its `:` and arrives as the String `"alt_left"` (`:158`); a modified character arrives as the String `"alt_q"` because Lacci only symbolises values that start with `:` (`subscription_item.rb:67-77`). Plus the double fire (X1).
- **Spec:** `press_key "a"` gives `"a"`; Shift-a gives `"A"`; F1 gives `:f1`; Return gives `"\n"`; Control-Return gives `:control_enter`; Control-Shift-Alt-PageUp gives `:control_shift_alt_page_up`; Alt-q gives `:alt_q`. On macOS, Cmd-q gives `:alt_q`.
- **Native:** DESIGN 4.4, except for Cmd.
- **DESIGN conflict:** DESIGN 4.4 says "On macOS, Cmd maps to `control_` as well (Shoes 3 did this)". The Shoes 3 Cocoa source maps Cmd to `alt_`, and the examples' Cmd shortcuts are written as `:alt_q`/`:alt_c`/`:alt_v`. See Q5.

### H2. Mouse button numbers

**Ruling: S3** (Shoes 4 agrees): 1 left, 2 middle, 3 right.

- **Manual:** "the number of the mouse button" (manual 2189-2191).
- **Shoes 3:** platform button numbers, 1 = left (`s3_canvas.c:1061`).
- **Shoes 4:** `LEFT_MOUSE_BUTTON = 1`, `MIDDLE_MOUSE_BUTTON = 2`, `RIGHT_MOUSE_BUTTON = 3` (`dsl.rb:16-18`).
- **Examples:** `minesweeper.rb:259-261` (`button == 1/2/3`), `tankspank.rb:364`, `shoes-contrib/basic/scribble.rb:5` (`b == 1` through `self.mouse`).
- **Lacci / WV today:** WV passes the JS `event.button` (0 = left) to `click`/`release` (`wv/subscription_item.rb:87, 98`), while `App#mouse` reports 1 for the left button (`app.rb:462-467`).
- **Spec:** a left `click_at` delivers button 1; a right click delivers 3.
- **Native:** DESIGN 4.3. No conflict.

### H3. Coordinate frame of `click`, `release` and `motion`

**Ruling: S3 (Q4).** Window (app canvas) coordinates for every slot.

- **Manual:** silent. The motion example moves an oval by the reported coordinates in an app-level handler (manual 2264-2275), where every frame agrees.
- **Shoes 3:** the slot's click block gets the `x, y` it was called with (`s3_canvas.c:1056-1061`), and nested slots are called with the same coordinates unless the child canvas has its own origin (`:1045-1051, 1065-1068`). That flag is set only for a child slot drawn on its own native surface (`DC(c->slot) != DC(pc->slot)`, `:445-450, 586-590`), which Shoes 3 gives to scrolling slots; not traced further. Inside such a slot, coordinates are slot-relative. Motion is the same (`:1181-1193`). The app's top slot adds its scroll offset (`:1053-1054`).
- **Examples:** almost every coordinate reader binds at app level (`minesweeper.rb:256`, `tankspank.rb:362`, `othello.rb:304`, `curve-control-point.rb:33`, `mice-satellites.rb:24`). The one nested reader found, `examples/para_cursor_demo.rb:69-79`, passes x and y to `Para#hit`, which ignores them (`para.rb:232-234`).
- **Lacci / WV today:** WV computes coordinates relative to `e.currentTarget.getBoundingClientRect()`, that is slot-relative (`wv/subscription_item.rb:66-100`).
- **Spec:** app-level `click` reports window coordinates (every model agrees). The nested case (a click at window (150, 120) on a stack placed at (100, 100) reports (150, 120)) is written, tagged `ledger: H3`, and waits on Q4.
- **Native:** DESIGN 4.3 gives drawable clicks window coordinates, and SubscriptionItem `click`/`release`/`motion` "x/y relative to the item's parent slot".
- **DESIGN conflict:** the SubscriptionItem rule is WV's frame, not Shoes 3's.

### H4. The extra `mods` argument

**Ruling: MANUAL** arity. A trailing `mods` is **EXT** (procs tolerate it; lambdas would not).

- **Manual:** `click { |button, left, top| }`, `motion { |left, top| }` (manual 2187, 2259).
- **Shoes 3:** click and release get a fourth `mods`, motion a third (`s3_canvas.c:1061, 1193`); the strings are `"control"`, `"shift"`, `"control_shift"` (built for wheel at `s3_app.c:744-751`).
- **Lacci today:** motion calls `(x, y, mods)` with those same strings (`subscription_item.rb:47-54`); click and release pass three arguments.
- **Spec:** a `motion { |x, y| }` block gets two usable coordinates; `examples/motion_events.rb` (`|x, y, mods|`) runs under `ext-s33`.
- **Native:** sends `[x, y, ctrl, shift]`; Lacci builds `mods` (DESIGN 4.3).

### H5. `hover` and `leave` hand the block the slot

**Ruling: MANUAL.** **Lacci change, unscheduled.**

- **Manual:** the block "gets `self`, meaning the object which was hovered over" (manual 2200-2205, 2251-2257).
- **Shoes 3:** `CHECK_HOVER` calls the proc with `self`, the canvas (`s3_ruby.h:167-176`).
- **Examples:** `for_playtest/simple/menu1.rb:18` and `shoes-contrib/simple/simple-menu1.rb:18` (`hover do |box| if box.width < 170`).
- **Lacci today:** slot-level `hover { }` passes the SubscriptionItem, not the slot (`subscription_item.rb:37-46`), then a kwargs Hash on the double fire (X1); element-level `el.hover { }` passes nothing (`drawable.rb:416-422`).
- **Spec:** inside `stack { hover { |s| $s = s } }`, hovering sets `$s` to the stack.
- **Native:** sends `hover`/`leave` on transitions (DESIGN 4.3).

### H6. Registering a slot event twice: replace or add?

**Ruling: BOTH.** The spec does not register twice.

- **Shoes 3:** `EVENT_HANDLER` stores one proc per slot per event (`s3_canvas.c:934-955`), so the second replaces the first.
- **Shoes 4:** `motion` appends; change listeners accumulate (`s4_dsl_interaction.rb:23-26`, `s4_common_changeable.rb:13-16`).
- **Lacci today:** slot and app events make a new SubscriptionItem per call, so they accumulate (`app.rb:414-422`); element `click`/`change` replace `@block`.
- **Spec:** nothing. **Native:** nothing; each SubscriptionItem is its own node.

### H7. `wheel`

**Ruling: EXT.** The spec asserts only that the first argument is positive exactly when the wheel moves up.

- **Manual:** silent (Shoes 3.3 added it).
- **Shoes 3.3:** the slot's wheel block gets `(dir == up ? 1 : 0, x, y, mods)` (`s3_canvas.c:1250-1251`). The app's top slot scrolls 32 px per notch whenever it has a scrollbar, block or no block (`s3_app.c:743`). Cocoa sends one event per unit of delta (`s3_cocoa.m:235-236`).
- **Examples:** `for_playtest/shoes3-tests/wheel/wheel1.rb` (Shoes 3.3 style), `for_playtest/shoes_manual/wheel.rb` (Scarpe-authored, `delta.round(2)`).
- **Lacci / WV today:** `(delta_float, x, y)`, positive is up (`wv/subscription_item.rb:171-184`, `subscription_item.rb:78-84`).
- **Spec:** wheel up gives a first argument above 0, wheel down gives one at or below 0.
- **Native:** sends `[delta, x, y]`, delta > 0 up (DESIGN 4.3), and scrolls the root independently of any wheel block (C6).

### H8. `start` and `finish`

**Ruling: MANUAL** for `start` and `finish` on slots, each handed the slot. `keydown`, `keyup`, `keyrelease` and `resize` are **EXT**. **Lacci change, unscheduled.**

- **Manual:** `start { |self| }` fires "The first time the slot is drawn"; `finish { |self| }` fires on removal (manual 2195-2198, 2286-2289). See M26 for App `start` against `started?`.
- **Shoes 3:** `start` is a slot method (`s3_canvas.c:974-988`), sent after the first paint (`:180`, `:990-1016`); `finish` receives the slot (`:1030-1036`); `keydown`/`keyup` exist (`:950-952`).
- **Shoes 4:** adds `keyrelease` and `resize` (`s4_dsl_interaction.rb:32-35, 78-81`).
- **Lacci today:** `start` exists only on App and runs after the body with no argument (`app.rb:146-159`); `finish` on Slot fires on destroy with no argument (`slot.rb:209-219`, commit `1ce13b0`). No `keydown`, `keyup`, `keyrelease`, `resize`.
- **Spec:** `stack { start { |s| $started = s } }` sets `$started` to the stack after the first frame; `finish { |s| }` gets the slot on `clear`.
- **Native:** the pump dispatches the first `heartbeat` after the first frame; `start` should hang off that point (DESIGN 5.4).

## I. Timers

### I1. `animate`, `every` and `timer`: rate and counting

**Ruling: MANUAL** for `animate` (10 fps by default, the first frame is 0). **S3** for `every` (the count starts at 0) and `timer` (the spec does not assert its block's arity). **Needs fix 10.1** (the double fire).

- **Manual:** "If no number is given, the `fps` defaults to 10" (manual 1896-1897); "Starting with zero, the `frame` number tells the block how many frames of the animation have been shown" (manual 1883-1884); `every(seconds) { |count| }` without saying where `count` starts (manual 1989-1994, M31); `timer(seconds) { ... }` with no block argument (manual 2111-2114).
- **Shoes 3:** the default rate is 12 fps (`s3t_timerbase.c:83`); every timer kind calls its block with `frame`, reset to 0 on first draw and incremented after each call (`:34-36, 41-44`), so `every` counts 0, 1, 2 and `timer` gets 0.
- **Shoes 4:** `@framerate = @style[:framerate] || 10` and `@current_frame = 0` (`s4_animation.rb:17-20`); `every(n)` is `animate 1.0 / n` (`s4_dsl_animate.rb:32-34`).
- **Examples:** 23 files read `animate`'s frame. Two read `every`'s count (`examples/animate.rb:15`, `shoes3_only/switch/switch.rb:19`); neither depends on where it starts.
- **Lacci / WV today:** WV defaults to 10 fps (`wv/subscription_item.rb:24`) but pre-increments, so the first frame and the first count are **1** (`:25-39`); Lacci calls the `timer` block with nothing (`subscription_item.rb:33-36`); every callback fires twice (X1).
- **Spec:** the first `animate` frame is 0 and frames increase by 1; `animate` with no fps ticks about 10 times per `advance(1)`; the first `every` count is 0; `timer(0.1)` fires exactly once.
- **Native:** the Ruby pump owns timers (DESIGN 5.4).
- **DESIGN conflict:** DESIGN 5.4 says "every (count starts at 1)". Shoes 3 and Shoes 4 both start at 0, the manual is silent, and no example depends on it.

## J. Navigation

### J1. `url`, `visit` and pages

**Ruling: BOTH** for class-level and instance-level `url`. `page(:name)` is **EXT**. Add `location` (**MANUAL**, **Lacci change, unscheduled**).

- **Manual:** only `visit(url)` and `location()` (manual 980-982, 1012-1018); no `url` entry; "When you switch URLs, a new App object is created" (manual 848-849, see M29).
- **Shoes 3 / Shoes 4:** class-level `url` on `class Foo < Shoes`. Shoes 4 anchors the page string as `/^page$/`, passes one capture, and makes a fresh instance of the class per visit (`s4_url.rb:4-43`); `visit` clears the app and sets `location` (`s4_dsl_interaction.rb:97-107`).
- **Examples:** `examples/url_routing_example.rb` (instance-level), `examples/shoes_subclass_app.rb`, `examples/internal_link_navigation.rb` (pages plus `link(click: "/page2")`); 7 files use `url`, 9 use `visit`.
- **Lacci today:** both class-level (`lacci/lib/shoes.rb:98-114`, copied onto the app through `pending_app_class`, `:152-190`) and instance-level `url` inside `Shoes.app` (`app.rb:401-409`); strings containing `(` become regexes; all captures are passed; an unknown URL prints `Error: URL '...' not found` (`app.rb:364-399`); `"/"` renders on first boot when routed to `:index` (`app.rb:598-604`). Scarpe-only `page(:name) { }` with `visit(:name)` (`app.rb:355-362`, `docs/SCARPE_FEATURES.md:15-38`). No `location`.
- **Spec:** after `visit "/about"`, the `/about` handler's content is shown and `location == "/about"`. Nothing about App identity across visits.
- **Native:** nothing special: a visit is a `clear` plus new creates.

### J2. `link(..., click: "/path")` visits the path

**Ruling: MANUAL.** Concordant. Shoes 3 calls `shoes_app_goto` (`s3_canvas.c:1116-1119`); Shoes 4 calls `app.app.visit` (`s4_link.rb:25-35`); Lacci calls `app.visit(@click)` for strings starting with `/` (`link.rb:14-31`). **Spec:** clicking `link("go", click: "/two")` shows the `/two` content. **Native:** sends `click` on the link.

## K. Built-ins and dialogs

### K1. What `ask` returns on Cancel, and its options

**Ruling: S3 (Q6).** `nil` on Cancel in `core`; `""` stays as a documented Scarpe compatibility shim until Q6 is answered. Accept `secret:` and `title:`. **Needs fix 10.6.**

- **Manual:** `ask(message)` returns a string (manual 629-641); `:secret` is "For: ask, edit_line" (manual 1385-1391).
- **Shoes 3:** `ask(msg, opts)` reads `:title` and `:secret`; the answer starts as `Qnil` and is set only on `GTK_RESPONSE_OK` (`s3_gtk.c:1772-1826`).
- **Docs:** "Classic Shoes: ask() returned nil on cancel; Scarpe returns """ (`docs/scarpe_shoes_incompatibilities.md:104-107`). Commit `6ce3d28` says the opposite ("Shoes3 likely returned empty string") to stop Hackety Hack's guessing game crashing on `nil.to_i`.
- **Lacci today:** `ask(message_string)` takes one argument (`builtins.rb:20-22`); WV returns `""` on Cancel; a `nil` answer would trigger the `osascript` fallback (X8).
- **Spec:** with `stub_dialog(:ask, nil)`, `ask("x")` returns nil and no `osascript` runs; `ask("x", secret: true)` is accepted.
- **Native:** the dialog reply carries `value` null and `cancelled: true` (DESIGN 4.1); the shim passes nil through once fix 10.6 lands. Headless mode answers `""` today (DESIGN 5.2), which follows Scarpe, not the ruling.

### K2. Option hashes on dialogs

**Ruling: EXT.** Accept and ignore unknown keys. Shoes 3.3 has `alert(msg, title:)` and `ask_open_file(title:)` (examples `shoes3_only/menus/menu2.rb:5`, `shoes3_only/cardflip.rb:80`); Lacci's built-ins take one positional argument each (`builtins.rb:20-50`), so these raise `ArgumentError`. **Spec:** `ext-s33` only. **Native:** passes a `title` through to the dialog when present. **Lacci change, unscheduled.**

### K3. `debug`, `info`, `warn` and `error`

**Ruling: MANUAL.** Route all four to the Shoes log. **Lacci change, unscheduled.**

- **Manual:** loggers for the Shoes console; `error` accepts exceptions (manual 719-844).
- **Lacci today:** `debug`/`info` print `[DEBUG]`/`[INFO]` (`builtins.rb:54-60`), and App aliases both to `puts` (`app.rb:546-547`); `warn` is Ruby's `Kernel#warn`; `error` is undefined, so it raises `NoMethodError` inside an app.
- **Spec:** each call returns without raising, and the message reaches `Shoes::Log`.
- **Native:** nothing; the log is Ruby-side, and Rust `log` messages join it (DESIGN 4.2).

### K4. `font(path)` returns the family names

**Ruling: MANUAL.** **Lacci change, unscheduled.** New row.

- **Manual:** "If the font is properly loaded, you'll get back an array of font names found in the file. Otherwise, `nil` is returned if no fonts were found in the file." (manual 766-767).
- **Lacci today:** sends the `font` builtin, then returns `Shoes::FONTS << File.basename(path, ".*")` whatever happened (`builtins.rb:13-18`): `font("/nonexistent.ttf")` returns an array ending in `"nonexistent"`.
- **Spec:** `font("missing.ttf")` returns nil; loading a bundled Inter file returns an array that includes `"Inter"`.
- **Native:** registers the file (DESIGN 4.1 `font`) but sends no answer. To satisfy the ruling, the `font` builtin needs a reply with the family names the file contains.

### K5. `download` and its events

**Ruling: MANUAL.** Specced under a `network` tag that is off by default. **Lacci change, unscheduled.** New row.

- **Manual:** runs in the background and "fires `start`, `progress` and `finish` events" (manual 906-975); only `finish` is shown (M30).
- **Lacci today:** `Shoes::App#download` (`download.rb:31-125`) calls `handle_failure` with one argument though it takes two, so every non-2xx response logs an `ArgumentError` instead; it requires `nokogiri` unconditionally; it runs the user's block on a background `Thread` (report 04, C4).
- **Spec:** against a local HTTP server, `finish` fires once with the body and `start` fires before it.
- **Native:** display updates can arrive from that background thread; DESIGN 5.2 guards writes with a Mutex, which covers it.

## L. Loader and environment

### L1. Where app code runs

**Ruling: S3** (top level). The manual's "Raisins" rule runs each app in an anonymous class, but the same note says Policeman, the Shoes 3 release this manual describes, "uses TOPLEVEL_BINDING" (manual 487-533). Lacci's `Shoes.run_app` does `load path` at top level (`lacci/lib/shoes.rb:205-240`). **Spec:** nothing about the sandbox. **Native:** nothing.

### L2. Case-insensitive `require`

**Ruling: OOS.** Shoes 3 on JRuby and Windows tolerated `require 'CSV'`; Lacci installs a `Kernel#require` shim with a map and a downcase fallback (`compat_require.rb:11-40`, commit `36fc931`). Loader policy, kept in the runner, not specced.

### L3. Constants

**Ruling: MANUAL** for the names, values unspecified. The manual lists `Shoes::RELEASE_NAME`, `RELEASE_ID`, `REVISION` (a Subversion revision) and `FONTS` (manual 600-614). Lacci parses them from `CHANGELOG.md` (`changelog.rb:17-50`), sets `REVISION` to a git SHA, and adds `RELEASE_TYPE = "LOOSE_SHOES"`, `VERSION = "0.5.0"`, top-level `::VERSION`, `::ShoesGemJailBreak = true`, `DIR` and `LIB_DIR` (`constants.rb:6-76`). **Spec:** each manual constant is defined. **Native:** nothing.

### L4. Shoes 3 only widgets

**Ruling: OOS.** `plot`, `terminal`, `systray`, `spinner`, `switch`, `video` (VLC), `svghandle`, `menu`/`menubar`, `Shoes.settings`/`monitor`, `event`/`shoesevent`, `decoration`, `cache` (`docs/scarpe_shoes_incompatibilities.md:10-40`, `examples/legacy/shoes3_only/README.md`). Shoes 3 also ships `slider` (`shoes/types/slider.c`), which neither list mentions. The manual documents Video in full (manual 3435-3516) but ties it to VLC and optional builds, so it stays out of `core`. **Native:** DESIGN 7 reserves `Video` and `Slider` kinds; drawing a placeholder box is enough.

### L5. Scripts with no `Shoes.app`

**Ruling: MANUAL:** they must run. The spec smoke-tests them instead of asserting inside them. New row.

- **Manual:** the built-in examples run at the top level with no app (fences 581-584, 620-623, 634-637 and others; report 03).
- **Lacci today:** test code is hooked from `Shoes::App#initialize` (`app.rb:95-103`), so a script without `Shoes.app` can never run spec code, and the spec process writes no result (report 04, Surprise 3).
- **Spec:** the runner executes each such script with dialogs stubbed and asserts exit 0, no Ruby error, and no `osascript` spawn.
- **Native:** must answer built-ins with no App open (A5).

## X. Lacci and Webview defects

These are bugs, not disagreements about Shoes. A new display service inherits every Lacci one unchanged, so they decide the "Lacci today" field of many rows above. X1 to X6 keep the numbering of the seed's section 1. The last column names the DESIGN section 10 fix, or says the fix is unscheduled.

| Row | Defect | Where (at `fdcee7a`) | Consequence | Rows | Fix |
|---|---|---|---|---|---|
| X1 | Every SubscriptionItem callback fires twice: a typed handler per event, then a generic `bind_self_event(shoes_api_name) { \|*args\| @callback&.call(*args) }` for the same event. | `drawables/subscription_item.rb:24-87` and `:89-91` | `animate`/`every` blocks run at double speed; keypress editors type twice; the second call gets raw args plus a `{event_name:, event_target:}` Hash (probed: keypress `[:left, ":left"]`, motion `[5, 6, "shift"]` then `[5, 6, false, true, {...}]`). | H1, H4, H5, I1 | 10.1 |
| X2 | `ListBox` drops its creation block. | `drawables/list_box.rb:15-29` | `list_box(items: ...) { }` never fires. | G2 | 10.4 |
| X3 | `ins` is aliased to `inscription` on every Drawable. | `drawables/para.rb:314-315` | `ins("x")` is a 10 px Para; `Shoes::Ins` is unreachable. | F1 | 10.8 |
| X4 | Webview colour arrays mis-render: Calzini premultiplies alpha into black, and hands float arrays to CSS `rgba()` raw. | `calzini.rb:219-255`, `calzini/background.rb:33-35` | `red(0.2)` paints opaque dark red; `nofill` paints opaque black. Webview only; the native normaliser (DESIGN 5.3) avoids it. | D3, D7 | WV only |
| X5 | `Shoes.rgb` and a top-level `rgb` do not exist. | `lib/scarpe/wv/document_root.rb:151-155` calls `Shoes.rgb` and rescues the error | `ask_color` always returns nil in Webview. | D1, D4 | unscheduled |
| X6 | Webview does not declare `:multi_app`. | `lib/scarpe/wv.rb:80`; `app.rb:53-57` raises `TooManyInstancesError` without it | `window` and `dialog` fail under Webview. The native service declares it. | A3 | WV only |
| X7 | `Shape` sends `shape_commands: []` at create, then mutates the array in place with no `prop_change`. | `drawables/shape.rb:25-31`, `app.rb:509-568` | An out-of-process display never sees the path. | E7 | 10.2 |
| X8 | A `nil` builtin answer means "unhandled", so Lacci falls back to a real `osascript` dialog. | `builtins.rb:66-105` | A cancelled `ask` or file dialog pops a second, real macOS dialog; headless runs hang on it. | A5, K1, L5 | 10.6 |
| X9 | `Drawable#click`/`#release` on non-widgets store a block but bind no event. | `drawable.rb:784-802` | Clicks on shapes, text blocks and slots via the element method never fire. | E8 | 10.9 |
| X10 | `prepend` `unshift`s each child, reversing several, and the display is not told positions. | `drawables/slot.rb:50-51` | `prepend { a; b }` shows `b, a`. | B4 | 10.3 |
| X11 | `ListBox#choose` sets `@chosen` with no `prop_change`. | `drawables/list_box.rb:35-41` | The display keeps showing the old item. | G3 | 10.4 |
| X12 | `link(text, click: proc)` never calls the proc (`@block` is nil, `has_block` false). | `drawables/link.rb:11-31` | Only the block form of a link works. | F9 | 10.5 |
| X13 | `#rgb` expands each nibble times 16; `rgb()` picks int or float mode from `r` alone. | `colors.rb:229-234`, `:168-176` | `#DFA` is `[208, 240, 160]`; `rgb(0, 0.4, 0)` keeps a raw 0.4. | D2, D5 | 10.7 |
| X14 | Oval's third positional is stored as a radius and doubled. | `drawables/oval.rb:18-19, 33, 42` | Every three-argument oval is twice the size; four-argument ovals are 2w x h. | E1, M2 | 10.10 |
| X15 | `alias_method :remove, :destroy` on Drawable binds the base `destroy`, so `slot.remove` skips the cascade and `finish`. | `drawable.rb:615`, `drawables/slot.rb:231-235` | Removed slots leak their children in Lacci; `finish` never fires on `remove`. | B5 | unscheduled |
| X16 | `App#destroy` (and its alias `close`) sends a nil-target `destroy`, which every App obeys. | `app.rb:109-113, 280-287` | Closing one window closes all of them. | A8 | unscheduled |
| X17 | `all_drawables` seeds its queue with `[@document_root, @document_root.children]`, so the children Array itself lands in the result. | `app.rb:289-299` | Class-filtered finders hide it; `drawables()` with no filter returns an Array among the drawables. Matters to the spec finders. | spec API | unscheduled |
| X18 | `download`'s failure path calls `handle_failure(code)` against `def handle_failure(code, logger)`, requires `nokogiri` unconditionally, and runs blocks on a background Thread. | `download.rb:31-125` | Every non-2xx response logs an ArgumentError instead of failing cleanly. | K5 | unscheduled |
| X19 | Webview subscribes to `full_redraw_request`, `focus` and `scroll_top` with the wrong target (nil against id, or the reverse). | `drawables/slot.rb:243, 267` against `wv/slot.rb:14`; `edit_line.rb:45` against `wv/edit_line.rb:19`; `drawables/stack.rb:29` against `wv/stack.rb:8` | `slot.clear { }` never redraws in Webview; `focus` and `scroll_top` never arrive. The native shim subscribes by id and ignores `full_redraw_request` (DESIGN 5.2). | C5, G9 | WV only |

## M. Manual errata and vague spots

M1 to M37 carry the numbers of the contradictions in `native/research/03_manual_inventory.md`, so "contradiction 12" and "M12" are the same thing. M38 and M39 come from the seed's errata table. Where a behaviour row above already argues the point, the M row points at it.

### M1. `oval` radius: diameter or half?

**Ruling: ERRATA.** See E1. The manual contradicts itself: the `:radius` style is "half of the diameter" and doubling (manual 1352-1354), but `oval(styles)` calls `radius` "the width and height of the circle" (manual 1742), and two examples treat it as a diameter: White Circle puts `radius: 160` in a 200x200 window (manual 869-873), and the Art intro calls `radius: 100` "One-hundred pixels wide" (manual 1639-1645). Shoes 3 and Shoes 4 both double the style. **Spec:** `radius:` doubles; do not transcribe manual 1742, 869-873 or 1644-1645 as expectations. Inventory ids: `styles.radius`, `art.oval.positional`, `art.oval.styles`, `app.white_circle_example`, `art.stroke_fill_oval_example`.

### M2. `oval` with four arguments

**Ruling: MANUAL.** `oval(left, top, width, height)` (manual 1734), as the motion example uses it (`oval 0, 0, 100, 100`, manual 2269). Lacci draws that 200x100 (X14). See E1.

### M3. `rect` argument order

**Ruling: ERRATA.** See E3.

### M4. `border`'s first argument is a pattern

**Ruling: ERRATA.** The heading says `border(text, strokewidth: a number)` (manual 1925); the prose (manual 1927) and every example (manual 2826, 2839) pass a colour or pattern. **Spec:** `border red, strokewidth: 2` strokes 2 px of red inside the slot box. **Native:** DESIGN 6 strokes borders inside the box.

### M5. `EditBox#text` and `EditLine#text` return a String

**Ruling: ERRATA.** The headings say `text() » self` (manual 3049, 3097); the prose says "Return a string of characters" (manual 3051, 3099). **Spec:** `edit_line(text: "hi").text == "hi"`.

### M6. EditLine default height

**Ruling: ERRATA.** "200 pixels wide and 28 pixels wide" (manual 3063) means 28 high, as ListBox says (manual 3183). See C4.

### M7. `:shift_5` should read `:shift_7`

**Ruling: ERRATA.** The Shift-7 example says "rather than `:shift_5`" (manual 2224-2225). Irrelevant to the rule. See H1.

### M8. `motion` block parameter names

**Ruling: ERRATA.** Documented as `motion { |left, top| }` (manual 2259, 2262); the example names them `|top, left|` and calls `@circ.move top - 50, left - 50` (manual 2271-2272). The positions are right (the first argument goes to `move`'s left); the names are swapped. **Spec:** the first argument is the horizontal coordinate. See H3, H4.

### M9. `displace` wording

**Ruling: ERRATA.** "displace it 2 pixels left and 6 pixels on top ... (22, 46)" (manual 2596-2599): the element moves right and down, and `:displace_left` says positive means right (manual 1161-1167). **Spec:** `displace(2, 6)` on an element laid out at (20, 40) paints it at (22, 46), and `left`/`top` still read 20 and 40. **Native:** DESIGN 6 `displace_left/top`.

### M10. Width and height value types

**Ruling: MANUAL,** read broadly. The styles say "a number" (manual 1243-1245, 1543-1545), but the manual also uses `"100%"` (2482, 2738), negative widths (`-200`, 337), `"10px"` (2696) and a decimal margin `margin: 0.1` (3250). All of them are valid, with the meanings in C1 and C3.

### M11. `gray` takes a lightness, and defaults to 128

**Ruling: ERRATA.** "a level of darkness" (manual 792), yet `gray(0.0)` is black and `gray(1.0)` white (manual 796-797). Shoes 3 runs the argument through `NUM2RGBINT` and defaults it to 128 (`s3t_color.c:240-250`); Lacci also defaults to 128 (`colors.rb:162`). **Spec:** `gray(0.0)` is black, `gray(1.0)` is white, `gray()` has channels 128.

### M12. The Check section says "Button methods"

**Ruling: ERRATA.** A copy-paste slip (manual 2976). Nothing to spec.

### M13. "Both types of timers" when there are three

**Ruling: ERRATA.** Three classes (manual 3411-3413), then "Both types of timers automatically start themselves" (manual 3421). **Spec:** `start`, `stop` and `toggle` work on all three kinds; `timer` fires at most once.

### M14. Font sizes: pixels or points?

**Ruling: MANUAL:** pixels. `:size` is a "pixel size" (manual 1398) and the text blocks are "N pixels high" (manual 1923-2129, 3378-3384); the `:font` string's size is "in points" unless suffixed `px` (manual 1221-1223), which is Pango's convention leaking through. Shoes 3's own handling is not checked. **Spec:** relative sizes only (a `title` is taller than a `para`; `font: "Arial 20px"` and `size: 20` lay out the same height). **Native:** treats every size as logical pixels.

### M15. Style "For:" lists

**Ruling: OOS.** The lists name inline fragments where block alignment cannot apply, give `:leading` only to blocks, and mention `mask` and an element-level `gradient` that have no creation entry (manual 1144-1148 and the rest of the Styles Master List). The spec does not test style applicability from the For-lists.

### M16. The Styles Master List is not complete

**Ruling: ERRATA.** It claims to be "a complete list of every style" (manual 555) but omits the app styles `:title`, `:width`, `:height`, `:resizable` (manual 869-870), the download styles `:save`, `:method`, `:headers`, `:body` (manual 946, 958), and arc's `:angle1`/`:angle2` (manual 1669). The spec covers each where its own section documents it.

### M17. A Range of colours is a gradient

**Ruling: MANUAL,** as Shoes 3 reads it. `:fill`/`:stroke` accept "a range of either" (manual 1202, 1453) without explanation; Shoes 3 turns a Range into a linear gradient (`s3t_pattern.c:86-89`). See D6.

### M18. Is a String a colour or an image path?

**Ruling: S3.** A String that parses as a colour (hex, a named colour, `rgb(...)`) is a colour; anything else is an image path. The manual uses both (`fill "static/avatar.png"`, manual 1693; `"#DFA"`, 118; `"#333"`, 1793) with no rule. Shoes 3 tries `shoes_color_parse` first (`s3t_pattern.c:91-94`). **Native:** DESIGN 5.3 turns image paths and URLs into `{"image": path}` after colour parsing fails.

### M19. `background ... right: 50` is not "on the right-side"

**Ruling: ERRATA** for the description. `background black, width: 50, right: 50` (manual 2792) is described as "a fifty pixel column on the right-side of the window", but `:right` puts the right edge 50 px in from the slot's edge (manual 1356-1364). **Spec:** the column's right edge sits 50 px in from the window's right edge. See C10.

### M20. "Colors ... will tile across the background"

**Ruling: MANUAL** for images: image patterns tile, gradients stretch (manual 1901-1903, 1928). Tiling a flat colour is a no-op. **Spec:** an image background smaller than its slot repeats (the same pixel appears one image-width apart).

### M21. Is a combined `shape` filled?

**Ruling: S3.** The Rules chapter says 100 ovals combined into one `shape` "aren't filled in this time" (manual 403-405), while the `shape` entry says art inside a shape is "drawn as one" (manual 1820-1824). The Shoes 3 source fills the combined path once with cairo's default nonzero rule: art in a shape adds sub-paths (`s3t_shape.c:326-331`), the shape is drawn with `cairo_fill_preserve` (`:190`), and no `cairo_set_fill_rule` appears in the fetched source. The manual's "not filled" most likely describes the union being filled once at 10% instead of 100 stacked layers; nobody has run it in a real Shoes 3. **Spec:** the combined shape paints its region and strokes its outlines. Fill intensity is not asserted until someone runs the Rules example in a real Shoes 3.

### M22. `shape(left, top)` and `skew`

**Ruling: MANUAL** for `shape(left, top)` (manual 1799), which the only example calls with no arguments (manual 1810); Lacci accepts both (`shape.rb:17-23`). `skew` is named in `transform` (manual 1859) and documented nowhere: **EXT**.

### M23. The `image(w, h) { }` block

**Ruling: MANUAL.** Used in the Rules (manual 410-426), not documented under `image` (manual 2006). See E9.

### M24. Two `click` signatures

**Ruling: MANUAL,** by receiver. Slots and art get `click { |button, left, top| }` (manual 2187); Button, Check and Radio get `click { |self| }` (manual 2918, 2988, 3349). See G1 and H2 to H4.

### M25. Which elements get mouse events

**Ruling: MANUAL** for the `:click` For-list (manual 1146-1148, E8) and slot-level `hover`/`leave` (manual 2200-2257). Element-level `hover`/`leave`/`motion` on every Drawable is **EXT** (`ext-scarpe`, commit `c66f1d9`, `drawable.rb:18`).

### M26. The `start` event against `App#started?`

**Ruling: MANUAL.** Slot `start` fires the first time the slot is drawn (manual 2288); `App#started?` refers to "the start event which fires once the window is open" (manual 1008-1010). **Spec:** `started?` is false inside the app body and true inside a handler dispatched after the first frame. See H8.

### M27. Can a click unmark a radio?

**Ruling: S3** (Lacci agrees): a click marks and never unmarks. The manual says clicks are sent "for both marking and unmarking" (manual 3354) and that Enter "toggles" a focused radio (manual 3358-3359), which fights the one-marked-per-group rule. Shoes 3 uses native radio buttons; Lacci's click handler "always check[s] on click (never toggle)" (`radio.rb:27-35`). **Spec:** clicking a marked radio leaves it marked and calls its block once; marking a second radio in the group unmarks the first.

### M28. `prepend`, `before` and `after` inside handlers

**Ruling: MANUAL.** A bare `para` in a handler lands at the end of the app's top slot (B3); `prepend`, `before` and `after` need a target slot (manual 2910-2913). See B4.

### M29. Does switching URLs make a new App?

**Ruling: BOTH.** "When you switch URLs, a new App object is created" (manual 848-849), while `visit` "changes the location" (manual 1014). Shoes 4 makes a fresh instance per visit; Lacci keeps the App. The spec asserts nothing about App identity. See J1.

### M30. `download` events

**Ruling: MANUAL.** See K5.

### M31. Where `every`'s count starts

**Ruling: S3** (0). See I1.

### M32. Does a programmatic `text=` fire `change`?

**Ruling: BOTH.** See G5.

### M33. `:state` of `"readonly"` on buttons, checks and radios

**Ruling: BOTH.** The style lists button, check and radio (manual 1412), but "active but cannot be edited" (manual 1420) has no clear meaning for a control that is not edited. **Spec:** asserts only `"disabled"` on those three. **Native:** treats `"readonly"` on a button, check or radio like enabled.

### M34. What relative paths resolve against

**Ruling: S3:** the app script's directory. The manual never says (`image "static/shoes-manual-apps.gif"`, manual 3117; `fill "static/avatar.png"`, manual 1693). Lacci's `Shoes.run_app` `chdir`s into the app's directory (report 04, Surprise 11), so resolving against the current directory gives the same answer. **Native:** DESIGN 5.3 expands paths against `Dir.pwd` in the shim, which is the app directory after `run_app`.

### M35. Styling a whole class of elements

**Ruling: MANUAL.** "In some cases, you can even style an entire class of elements" (manual 1023-1024), with no API documented. Lacci's `style(Shoes::Para, ...)` (commit `83af65d`) is that API. See F2 and F7.

### M36. "Ruby itself isn't Unicode aware"

**Ruling: OOS.** A Ruby 1.8 statement (manual 434). The spec uses UTF-8 text freely.

### M37. Dead cross-references

**Ruling: OOS.** `[[Search]]` (manual 560), "the `ListBox` section under `Native` controls" (manual 2057-2058) and a bare `[[oval]]` (manual 1668) point nowhere.

### M38. Unexpanded placeholders

**Ruling: ERRATA.** `{INDEX}`, `{COLORS}` and `{SAMPLES}` (manual 1564, 1576, 3525) were never expanded. The colour list comes from Shoes 3's colour table and Lacci's `Shoes::COLORS`.

### M39. The Messenger fix

**Ruling: ERRATA.** See B2.

## Where DESIGN.md disagrees with this ledger

`native/DESIGN.md` says "If the code and this document disagree, fix one of them in the same change." These are the places where DESIGN and a ruling above disagree today. Items 1 to 3 are factual; the rest wait on Nick's answers below.

1. **Cmd on macOS (H1).** DESIGN 4.4: "On macOS, Cmd maps to `control_` as well (Shoes 3 did this)". Shoes 3's Cocoa backend maps Cmd to `alt_` (`s3_cocoa.m:287-288, 296-297`), and the examples' Cmd shortcuts are `:alt_q`, `:alt_c`, `:alt_v`.
2. **`every`'s first count (I1).** DESIGN 5.4: "every (count starts at 1)". Shoes 3 (`s3t_timerbase.c:35, 43-44`) and Shoes 4 (`s4_animation.rb:20`) start at 0.
3. **Control widths (C4).** DESIGN 6: `list_box 160x28`, `progress 160x14`. The manual: list_box "about 200 pixels wide" (manual 3183), progress "200 pixels wide" (manual 3245).
4. **Text in a flow (C7, Q2).** DESIGN 6 makes each text block a shrink-to-fit box; the manual and Shoes 3 continue it as one paragraph. The rule is also ambiguous about whether the width cap comes before or after the "does it fit on this row" test.
5. **Text-block margins (C9, Q3)** and **leading (F10).** DESIGN 6 gives text no default margin and adds `leading` only when given; Shoes 3 uses 4 px margins (12 px bottom) and the manual says leading defaults to 4 px.
6. **Nested-slot event coordinates (H3, Q4).** DESIGN 4.3 makes SubscriptionItem coordinates parent-relative; Shoes 3 uses window coordinates.
7. **Default window (A1, Q1).** DESIGN 6 names Lacci's 480x420 default; Shoes 3 and Shoes 4 use 600x500.
8. **Smaller points.** DESIGN 6's Float rule says "between 0 and 1 exclusive" and "1.0 = 100%" in the same breath; Shoes 3 treats every Float as a fraction (C1). DESIGN 6 does not mention `right`/`bottom` (C10). DESIGN 5.2's headless `ask` answers `""`, while K1 rules nil.

## Questions for Nick

The evidence is balanced on each of these, so the rows above carry a provisional ruling and the spec cases that depend on the answer are written but tagged with the row. One answer settles each.

- **Q1 (A1).** Should an app with no size open at **600x500 titled "Shoes"**, as Shoes 3 and Shoes 4 both do, or stay at Scarpe's **480x420 "Shoes!"**? The manual is silent. Changing it moves every snapshot of every example that does not pass a size (about 70% of them).
- **Q2 (C7).** Two `para`s side by side in a flow: should the second **continue the first as one paragraph**, its later lines wrapping back to the flow's left edge (manual 1610-1612 and Shoes 3), or be **its own box** beside or below the first (Webview today, DESIGN 6)? Single-line paras look the same either way. The paragraph model needs a first-line indent in the text layout.
- **Q3 (C9).** Should text blocks get Shoes 3's **default margins (4 px, 12 px below)**, or Webview's **zero**? Shoes 3 examples were written with the gap; Scarpe-authored examples were written without it.
- **Q4 (H3).** When a stack nested at (100, 100) has its own `click` handler, should a click at window (150, 120) report **(150, 120)** (Shoes 3) or **(50, 20)** (Webview, DESIGN 4.3)? No example found depends on either.
- **Q5 (H1).** On a Mac, should **Cmd-q arrive as `:alt_q`**, as in Shoes 3 and as the example editors expect, or as `:control_q`, as DESIGN 4.4 says? And should Cmd-Q still quit through the app menu before the app sees it?
- **Q6 (K1).** When the user cancels `ask`, should it return **nil** (Shoes 3's source) or **""** (your commit `6ce3d28`, which kept Hackety Hack's guessing game alive)?
- **Q7 (G5), lower priority.** Your commit `eda8975` makes `edit_line.text = "x"` fire `change`, on purpose. Should the spec pin that under `ext-scarpe`, or keep asserting neither?

## Citation check

Load-bearing citations re-read against the sources for this ledger (27 Sep 2026):

- **Shoes 3:** `s3t_timerbase.c:20-100`, `s3_cocoa.m:200-305`, `s3_gtk.c:750-835` and `:1768-1830`, `s3_canvas.c:170-185, 445-453, 545-600, 640-653, 710-745, 860-880, 930-1016, 1030-1070, 1105-1125, 1175-1200, 1228-1265`, `s3t_shape.c:94-182, 300-362`, `s3_ruby.c:20-40, 270-475`, `s3_ruby.h:125-180`, `s3t_color.c:8-40, 210-300, 440-465`, `s3t_pattern.c:45-95`, `s3t_native.c:155-200`, `s3t_list_box.c:95-112`, `s3_app.h:16-24`, `s3_app.c:55-70, 120-180, 738-763`, `s3t_textblock.c:108-240`.
- **Shoes 4:** `internal_app.rb:15-25`, `dsl.rb:12-20`, `s4_oval.rb:1-20`, `s4_dsl_art.rb:95-160`, `s4_animation.rb`, `s4_timer.rb`, `s4_dsl_animate.rb`, `s4_dsl_style.rb:66-86`, `s4_dsl_text.rb:45-58, 104-120`, `s4swt_key_listener.rb:20-30, 80-95, 138-150`.
- **Manual:** 196-199, 320-345, 382-414, 741-746, 760-770, 788-798, 864-876, 885-890, 901-912, 1071-1110, 1142-1152, 1239-1252, 1280-1310, 1346-1384, 1408-1422, 1578-1622, 1636-1646, 1670-1675, 1714-1753, 1799-1832, 1875-1905, 1923-1928, 1985-1996, 2023-2040, 2108-2116, 2180-2290, 2296-2360, 2394-2412, 2430-2434, 2592-2600, 2681-2684, 2788-2794, 2921-2926, 3000-3010, 3047-3066, 3095-3100, 3178-3186, 3240-3252, 3350-3360, 3376-3386, 3409-3422.
- **Lacci and Webview (at `fdcee7a`):** `drawables/subscription_item.rb:1-110`, `drawables/para.rb:232-234, 310-316`, `drawables/list_box.rb:5-45`, `colors.rb:150-238`, `drawables/button.rb:38-48`, `drawables/edit_line.rb:12-42`, `drawables/link.rb:1-45`, `drawables/radio.rb:1-59`, `drawables/shape.rb:1-44`, `drawables/slot.rb:48-55, 225-240, 280-353`, `drawable.rb:610-618`, `app.rb:38-50, 105-116, 276-290, 509-567`, `builtins.rb:1-125`, `wv/subscription_item.rb:20-40, 120-160`, `wv.rb:76-82`, `niente.rb:30-35`.

What the check changed against the seed and DESIGN:

1. **H7, wheel.** The seed said Shoes 3 scrolls a slot 32 px "without a block". That fallback (`s3_canvas.c:1252-1253`) can never run: it sits inside `if (!NIL_P(wheel))` and re-reads the same attribute. The scrolling happens at app level, whenever the top slot has a scrollbar, block or no block (`s3_app.c:743`).
2. **C3, short margin arrays.** The seed said missing entries default to 0. They default to the element's default margin, which is 4 for text blocks (`s3_ruby.h:152-155` with `s3t_textblock.c:108`).
3. **H1, Cmd.** DESIGN 4.4's "(Shoes 3 did this)" is wrong; the seed had it right (`s3_cocoa.m:287-297`).
4. **H3, coordinates.** The seed's "window coordinates" holds for slots drawn on the window's own surface; a scrolling slot with its own native surface reports slot-relative coordinates (`s3_canvas.c:445-450, 586-590, 1045-1051`).
5. **E4, star.** Added from the source: the first point points down (odd point counts give an upside-down star), and the reported size is `outer`, not `2 * outer` (`s3t_shape.c:162, 167-171`).
6. **H8, start.** `EVENT_HANDLER(start)` is commented out (`s3_canvas.c:954`), which looks like "no slot start"; a hand-written `shoes_canvas_start` exists at `:974-988` and fires after the first paint (`:180, 990-1016`).
7. **Small ones.** Shoes 4's `DEFAULT_OPTIONS` spans `internal_app.rb:19-25` (the seed said 19-23); `mfp_instance_eval` is at `s3_ruby.c:31-33`; the fresh regex count of three-argument ovals is 16 files, not 21 (a different regex, not a mistake); D8's default fill and stroke colours for Shoes 3 were not re-checked, only the stroke width.

Not re-read, taken from the research reports as written: the Webview and Calzini line numbers in C, D and E rows (report 02 measured them in a browser), the example counts from report 04, and the Shoes 3 layout of slots in flows (C8).

## Keeping this page honest

- The fetched Shoes 3 and Shoes 4 files live in a session scratchpad (`research/probe06/src/`), not in this repo. Until someone vendors them (for example under `native/research/sources/`), a reader re-checks a citation by fetching `shoes/shoes3@master` or `shoes/shoes4@main` and applying the file-name mapping in "How to read this".
- When a Lacci fix lands, update the row's "Lacci today" field and the X row, and leave the ruling alone. When Nick answers a question, replace "(Qn)" with the ruling, drop the `ledger:` hold on the spec cases, and move the answer into the row's ruling line with the date.
- New disagreements get the next free id in their area (C13, H9, ...). Ids are never reused or renumbered.

