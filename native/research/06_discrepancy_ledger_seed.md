# 06 — Discrepancy ledger seed (manual vs Shoes 3 vs Shoes 4 vs examples vs Lacci)

Lane: DSL discrepancies. Repo under study: `<repo>` (branch `master`). All paths below are relative to that repo unless prefixed.

## 0. How to read this

Sources and their tags:

| Tag | What | Where I read it |
|---|---|---|
| **M** | The manual, `docs/static/manual.md` (3,533 lines). It is the Shoes 3 "Policeman"-era `manual-en.txt` imported in commit `8e6218f` (2023-02-09, "shoes-deprecated formal docs") and restyled in `ac20151`. Note `M:489-491` literally says "This rule is for Raisins. Policeman uses TOPLEVEL_BINDING". It predates Shoes 3.3 additions (wheel, keydown/keyup, icons, menus...). | local file |
| **S3** | Shoes 3 C source, `github.com/shoes/shoes3@master` (3.3.x "Walkabout"). Fetched verbatim with curl. | `research/probe06/src/s3_*.c`, `s3t_*.c` (e.g. `s3_ruby.c` = `shoes/ruby.c`, `s3t_shape.c` = `shoes/types/shape.c`) |
| **S4** | Shoes 4 `shoes-core`, `github.com/shoes/shoes4@main`. | `research/probe06/src/s4_*.rb`, `shoes4_main_shoes-core_lib_shoes_*.rb`, `s4swt_key_listener.rb` |
| **EX** | Example corpus `examples/` (83 top-level entries) and `examples/legacy/{working (59 .rb), for_playtest (191 .rb), shoes3_only (49 files), needs_deps (3 .rb), path_issues (1 .rb)}`. `working/` means "boots in CI", not "behaves correctly" (see G2). | local |
| **L** | Current Lacci (`lacci/lib/shoes/**`). | local |
| **WV** | Current Webview display service (`lib/scarpe/wv/**`) + Calzini HTML renderer (`scarpe-components/lib/scarpe/components/calzini/**`). | local |
| **DOC** | Scarpe docs: `docs/scarpe_shoes_incompatibilities.md`, `docs/SCARPE_FEATURES.md`, repo `CLAUDE.md`. | local |
| **P1/P2/PC** | My probes, run with `bundle exec ruby -Ilacci/lib -Iscarpe-components/lib` against Niente. Outputs: `research/probe06/probe_out.json` (P1), `research/probe06/probe2_out.json` (P2); Calzini render probe `research/probe06/calzini_probe.rb` (PC, output quoted inline). | local |

Ruling vocabulary (default rule from the orchestrator: manual wins unless a large body of working examples depends on the other behaviour, then accept both):

- **MANUAL** — spec asserts the manual's behaviour.
- **S3** — manual silent or self-contradictory; spec follows Shoes 3 source.
- **BOTH** — spec must accept either behaviour (write assertions that both satisfy, noted per row).
- **EXT** — non-manual extension (Shoes 3.3 / Shoes 4 / Scarpe). Spec it under an extension tag, never in the core suite.
- **ERRATA** — the manual text itself is wrong; spec follows the verified behaviour and the manual snippet must not be transcribed verbatim.
- **OOS** — out of scope for the spec.

"L follows" = what current Lacci/WV actually does, verified by probe where marked.

---

## 1. Cross-cutting Lacci defects that poison many rows (fix before writing specs)

These are not DSL disagreements; they are bugs in the shared Lacci layer that a new (Rust) display service inherits unchanged, and they decide the "L follows" column for most event rows.

1. **Every SubscriptionItem callback fires twice.** `lacci/lib/shoes/drawables/subscription_item.rb:24-87` binds a per-event handler (`animate`, `every`, `timer`, `hover`, `leave`, `motion`, `click`, `release`, `keypress`, `wheel`), then `:89-91` unconditionally binds a *second* generic handler `bind_self_event(shoes_api_name) { |*args| @callback&.call(*args) }` for the same event name and target. `DisplayService.dispatch_event` (`lacci/lib/shoes/display_service.rb` handler list) calls both. Blame: line 89 dates from `05072013` (2023-07-05); the typed handlers were added later (`aa368db`, 2023-09-29) without removing it. P1: `animate` callback got `[7, 7]` for one dispatch; `keypress` got `[:left, ":left"]` (Symbol then raw String); `motion` got `[5, 6, "shift"]` then `[5, 6, false, true, {event_name:, event_target:}]`; `every` got `[3, 3]`. P2: two `click` handlers each fired twice (`[1, 1, 2, 2]`), `timer` block's last call received `[{event_name: "timer", event_target: 11}]`. Consequence: side-effecting `animate`/`every` blocks run at 2x speed; keypress editors double-type.
2. **`ListBox` drops its creation block.** `list_box.rb:15-29` passes `&block` to `super`, which ignores it; `@callback` is only set by `#change`. P1: `list_box(items: %w[a b c]) { ... }` then dispatch `change` → 0 calls.
3. **`ins` is shadowed.** `para.rb:314-315` does `alias_method :ins, :inscription` on `Shoes::Drawable`, so the real `Shoes::Ins` text fragment (`text_drawable.rb:127-131`) is unreachable via DSL. P1: `ins("hello").class == Shoes::Para`.
4. **Colour arrays mis-render.** `Shoes::Colors` returns bare `[r, g, b, a]` arrays with mixed int/float semantics (`colors.rb:152-176`); Calzini `rgb_to_hex` (`calzini.rb:219-255`) premultiplies alpha into black. PC: `fill: [255,0,0,0.2]` (i.e. `red(0.2)`) → `fill:#000000`; `nofill` (`[0,0,0,0]`) → `fill:#000000`.
5. **`Shoes.rgb` / top-level `rgb` do not exist.** Verified: `Shoes.respond_to?(:rgb) == false`, `rgb(1,2,3)` at top level → `NoMethodError`. `lib/scarpe/wv/document_root.rb:151` calls `Shoes.rgb(r, g, b)` inside `native_color_dialog`; the `rescue => e; nil` at `:154-155` swallows it, so **`ask_color` always returns `nil` in WV**.
6. **WV cannot open a second window.** `Shoes::App#initialize` (`app.rb:53-57`) raises `TooManyInstancesError` unless `Shoes::FEATURES.include?(:multi_app)`; WV pushes only `:html` (`lib/scarpe/wv.rb:80`); Niente pushes `:multi_app` (`lacci/lib/scarpe/niente.rb:33`). So `window`/`dialog` (`app.rb:577-585`) fail under WV.

---

## 2. The ledger

Column key per row: **Behaviour** / **M** / **S3** / **S4** / **EX** / **L follows** / **Ruling** (+ spec note).

### A. App and window

**A1. Default window size and title**
- M: silent (examples always pass sizes).
- S3: `SHOES_APP_WIDTH 600`, `SHOES_APP_HEIGHT 500` (`s3_app.h:20-21`, applied `s3_app.c:62-63,176`); title defaults to settings `app_name` ("Shoes") (`s3_app.c:145-153`).
- S4: `DEFAULT_OPTIONS = { width: 600, height: 500, title: "Shoes 4", resizable: true }` (`shoes4…internal_app.rb:19-23`).
- L follows: `title: 'Shoes!', width: 480, height: 420` (`lacci/lib/shoes.rb:138-145`, `app.rb:42-49`). P1 `app_default_wh: [480, 420]`.
- Ruling: **S3** (600x500; S3 and S4 agree). Title "Shoes".

**A2. When the `Shoes.app` block runs; multiple top-level `Shoes.app`**
- M: implies apps are listed in `Shoes.APPS`, "you can run many apps at once" (`M:885-889`).
- S3: `Shoes.app` stores the block as `@main_app` and returns (`s3_app.c:142`); every app is opened only after the script finishes loading (`shoes_app_start`, `s3_app.c:391-408`). So helpers defined *after* `Shoes.app` are visible, and N `Shoes.app` calls = N windows.
- L follows: `Shoes.app` runs `app.init; app.run` inline and does not return while the window lives (`shoes.rb:119-121,192-193`). DOC `scarpe_shoes_incompatibilities.md:64-90` documents "define helpers before Shoes.app" as the workaround.
- Ruling: **S3** as the target (a Rust host can collect app blocks and start them at end of load); spec asserts only "method defined after `Shoes.app` is callable from a button handler" under a compat tag.

**A3. `window`, `dialog`, `owner`**
- M: `window(styles){}` opens a new app whose `owner` is the launcher; normal `Shoes.app` has `owner == nil`; `dialog` is the same with dialog chrome (`M:1000-1004, 1958-1961, 2135-2154`); window/dialog blocks change `self` (`M:231-244`).
- S3: `shoes_app_window(argc, argv, self, owner)` (`s3_app.c:123-143`).
- EX: `examples/legacy/for_playtest/shoes_manual/window_owner.rb`, `trigger_window.rb`.
- L follows: `App#window`/`#dialog` → `Shoes.app(**opts.merge(owner: self))` (`app.rb:577-585`); `:owner` is a shoes_style (`app.rb:19`, commit `7f1cbba`); P1 `owner` of main app = `nil`. Fails under WV (§1.6). Top-level `Kernel#window` = `Shoes.app` without owner (`builtins.rb:114-122`).
- Ruling: **MANUAL**. New backend must declare `:multi_app`.

**A4. `app.width` / `app.height` / slot width at runtime**
- M: `width()` "returns an exact pixel size" (`M:2511-2513, 2723-2732`); `rect 10, 10, self.width - 20, self.height - 20` fills the box (`M:1757-1768`).
- S3: `shoes_app_get_width` returns live `app->width` (`s3_app.c:199-209`), updated on GTK `size-allocate` (`s3_gtk.c:736-750`).
- L follows: App `width`/`height` are static styles (`app.rb:19`); no resize is fed back (grep `resize|innerWidth` in `lib/scarpe/wv` finds nothing relevant). Slot width falls back to parent/App style (`drawable.rb:649-716`, commit `133b88b`); P1 `stack(width: -100).width == 380` (480 - 100), `stack(width: "50%").width == 240`.
- Ruling: **MANUAL** (live pixels after layout/resize).

**A5. Built-in dialogs with no app / at top level**
- M: `ask_color`, `ask_open_file`, `confirm` examples run *before* `Shoes.app` (`M:651-655, 665-669, 714-716`); built-ins are "usable anywhere" (`M:571-577`).
- DOC: says unsupported in Scarpe (`scarpe_shoes_incompatibilities.md:44-62, 109-118`) — partly stale.
- L follows: `Shoes::Builtins#shoes_builtin` falls back to `osascript` for `ask`, `confirm`, `ask_open_file`, `ask_save_file`, `ask_open_folder`, `ask_save_folder` (`builtins.rb:66-105`, macOS only); `alert` and `ask_color` have no fallback → `nil`.
- Ruling: **MANUAL**. The Rust host should own native dialogs independent of a window.

**A6. `Shoes.app("/start/url", styles)`**
- S3: first string arg is the start URL (`s3_app.c:128-138`).
- L follows: keyword-only signature (`shoes.rb:138-147`), unknown keywords swallowed by `**_extras`.
- Ruling: **EXT** (S3). Low priority.

**A7. App-level styles only in S3.3**: `fullscreen`, `decorated`, `hidden`, `menus`, `monitor` (`s3_app.c:155-168`). L: dropped by `**_extras`. DOC lists `decoration`, `Shoes.settings`, `Shoes.monitor` as unsupported. Ruling: **OOS** (shoes3_only).

### B. Blocks and `self`

**B1. Slot blocks (`stack`/`flow`/`append`/`prepend`/`before`/`after`/`clear`) keep the caller's `self`**
- M: "The stack block ... does NOT change self" (`M:198`); rule 2 at `M:322-324`.
- S3: slot blocks are invoked with plain `rb_funcall(block, s_call, 0)` inside `DRAW(...)` (`s3_canvas.c:650-653`, insert path `:715-731`); only `app {}` instance_evals (`:864-874`).
- L follows: `App#with_slot` does `instance_eval(&block)` on the App (`app.rb:200-207`), used by `Stack`/`Flow`/`Mask`/`Shape` (`stack.rb:18`, `flow.rb:19`, `mask.rb:25`, `shape.rb:31`). `append`/`prepend` special-case non-Drawable callers with `block.call` plus an "external self" fallback (`slot.rb:288-352`). `clear` is annotated `@incompatibility ... Scarpe uses the Shoes::App as self` (`slot.rb:255`). P2: inside a `Shoes::Widget#initialize`, `stack { self }` is `Shoes::App` and the widget's `@label` is `nil`.
- Identical inside a plain `Shoes.app` block (self is the App either way); diverges inside Widgets and user classes.
- Ruling: **MANUAL** (preserve caller `self`; redirect element creation through the app's current-slot stack).

**B2. `app { }` changes self; the manual's own fix snippet is broken**
- M: `@stack.app do @stack.append do para msg end end` (`M:300-313`).
- S3: `app {}` is `instance_eval` on the App (`s3_canvas.c:864-874` via `mfp_instance_eval`, `s3_ruby.c:27-33`), so `@stack` inside resolves on the App, not on `Messenger`.
- L follows: same (`drawable.rb:447-450`). P2: plain `@slot.append { para msg }` from a non-Shoes class → `NoMethodError` (matches `M:294`); the manual's fix → `NoMethodError: undefined method 'append' for nil` (same failure S3 would give). `s = @stack; @stack.app { s.append { para msg } }` works.
- Ruling: **ERRATA**. Spec the instance_eval semantics with a local-variable capture; do not transcribe `M:300-313`.

**B3. Where elements created inside event handlers land**
- M: button block appending with and without `append` "does the same thing" (`M:2894-2913`).
- S3: `shoes_safe_block` does not push a slot (`s3_ruby.c:273-286`); elements go to the top of `app->nesting`, i.e. the app's top slot after startup.
- L follows: after `init`, `@slots` holds only `document_root` (`app.rb:166-178`); new elements go there. Concordant.
- Ruling: **MANUAL** (spec: `para` in a button handler becomes the last child of the app root, not of the button's slot).

### C. Layout and dimensions

**C1. Float dimensions mean a fraction of the parent**
- M: decimal width/height = percentage, `1.0` = 100% (`M:1239-1245, 1539-1545`); `button "All of it", width: 1.0, height: 1.0` (`M:2702`).
- S3: `shoes_px` — Float → `pv * f`, `"N%"` → fraction, negative Integer → parent minus (`s3_ruby.c:298-312`).
- L follows: `compute_dimension` handles `"N%"` and negatives but returns Floats unchanged (`drawable.rb:681-700`); P1 `stack(width: 0.5).width == 0.5`. Calzini converts Float → `"50.0%"` for CSS (`calzini.rb:102-115`), so only the Ruby-side getter is wrong.
- Ruling: **MANUAL** (getter returns pixels).

**C2. `style[:width]` returns the original request**: M `M:2470-2487, 2691-2707`; L `shoes_style_values` returns an `IndifferentHash` of raw values (`drawable.rb:503-535`). Concordant. Ruling: **MANUAL**.

**C3. `:margin` forms**
- M: number or `[left, top, right, bottom]` (`M:1298-1309`).
- S3: `ATTR_MARGINS` reads array entries 0..3 with missing entries defaulting to 0; Floats are fractions (`s3_ruby.h:147-165`).
- L follows: `MarginHelper#margin_parse` (`margin_helper.rb:3-78`): number, Hash (`{left:, top:...}`), String `"1 2 3 4"`, 1- or 4-element arrays; **2- or 3-element arrays raise `InvalidAttributeValueError`** (`:45-51`). (Calzini's raw-array spacing order `[:left, :right, :top, :bottom]` at `calzini.rb:160,183` only affects `padding`, which is a Scarpe extension.)
- Ruling: **MANUAL**, plus accept 2-3 element arrays S3-style (missing = 0) instead of raising. Hash/String forms: **EXT**.

**C4. Native control default sizes**
- M: edit_box 200x108 (`M:3006`), edit_line 200 wide x ~28 (`M:3063`), list_box ~200x28 (`M:3183`), progress 200 wide (`M:3245`).
- L follows: no defaults in Lacci; Calzini emits no width (`calzini/misc.rb:15-37, 65-86, 113-128`) → browser defaults.
- Ruling: **MANUAL**.

**C5. Missing slot/element API**: `before(el){}`, `after(el){}` (`M:2315-2323`), `scroll_height`, `scroll_max` (`M:2440-2453`), `Image#path`/`path=`/`full_width`/`full_height` (`M:3143-3164`), `location` (`M:980-982`), `started?` (`M:1006-1010`), `imagesize` (`M:2017-2023`), `gutter` on slots (`M:2394-2410`).
- S3: `before`/`after` exist (`s3_canvas.c:731-743`).
- L follows: none of `before`, `after`, `scroll_max`, `scroll_height`, `location`, `started?`, `imagesize` exist (grep of `lacci/lib`, `lib/scarpe`); Image uses the `:url` style (`image.rb:5`; P2 `respond_to?(:path) == false`); `gutter` is App-only constant 28 (`app.rb:551-553`).
- EX usage: `before` 5 files, `after` 4, `scroll_max` 1, `location` 3.
- Ruling: **MANUAL** (alias `path` ↔ `url`).

### D. Colours and patterns

**D1. Colours are `Shoes::Color` objects**
- M: `ask_color` returns `Shoes::Color` (`M:643-655`); rgb/gray return `Shoes::Color` (`M:790, 815`).
- S3: `Shoes::Color` with `red`, `green`, `blue`, `alpha`, `black?`, `dark?`, `light?`, `white?`, `opaque?`, `transparent?`, `invert`, `to_s`, `inspect`, `to_pattern`, `<=>`, `==` (`s3t_color.c:16-33`).
- L follows: plain Arrays `[r, g, b, a]` (`colors.rb:152-176`).
- Ruling: **MANUAL**. Keep `to_a`/array-destructuring compatible so Lacci callers survive.

**D2. `rgb()` component typing is per component**
- M: `rgb(0, 0.4, 0)` is dark green (`M:827-832`); ints 0-255 or floats 0.0-1.0.
- S3: `NUM2RGBINT(x) = Float ? ROUND(x*255) : x` applied to each of r, g, b, a independently (`s3_ruby.h:130`, `s3t_color.c:216-224`).
- L follows: mode chosen from `r` only (`colors.rb:168-176`); P1 `rgb(0, 0.4, 0) == [0, 0.4, 0, 255]`.
- EX: `rgb(0, 0.6, 0.9)`, `rgb(0, 0.6, 0.9, 0.1)`; 10 calls of `rgb(int, int, int, 0.x)` (e.g. `for_playtest/expert/minesweeper.rb`, `tooltips.rb`, `curve-animation.rb`).
- Ruling: **MANUAL/S3**.

**D3. Alpha means opacity; named colours take an alpha**
- M: `fill black(0.1)` (`M:382`), `fill red(0.2)` (`M:1809`).
- S3: named colour alpha via `NUM2RGBINT` (`s3t_color.c:445-466`); patterns use `cairo_pattern_create_rgba` (`:252-258`).
- L follows: `define_method(color) { |alpha = 255| rgb + [alpha] }` stores floats verbatim (`colors.rb:152-158`; P1 `red(0.2) == [255, 0, 0, 0.2]`). Calzini shapes/text premultiply into black (PC: `fill:#000000`); backgrounds emit raw `rgba(...)` (`calzini/background.rb:33-35`), which is right for int arrays and wrong for float arrays (PC: `rgba(0.5, 0.5, 0.7, 1.0)`).
- EX: `green(0.2)` 4, `black(0.1)` 4, `red(0.2)` 3, `red(0.1)` 2, `red(0.05)` 2, `blue(0.1)`, `blue(0.4)`, `red(0.5)`, `red(0.9)`.
- Ruling: **MANUAL**.

**D4. `rgb`/`gray`/`gradient` are Kernel built-ins and `Shoes.rgb`**
- M: built-in, "may also be called as `Shoes.rgb`" (`M:785-834`).
- S3: defined on `rb_mKernel` and as `Shoes::Color` singletons (`s3t_color.c:11-15, 38-39`).
- L follows: only via `include Shoes::Colors` on Drawables (`drawable.rb:15`); see §1.5.
- Ruling: **MANUAL**.

**D5. Three-digit hex**
- S3: `#DFA` → each nibble ×17 → `DD FF AA` (`s3t_color.c:286-293`).
- L follows: `to_rgb` multiplies by 16 (`colors.rb:229-235`; P1 `to_rgb("#DFA") == [208, 240, 160, 255]`). Calzini passes hex strings straight to CSS, so rendering is right; only the Ruby value is off.
- EX: ~93 short-hex uses (`background "#DFA"` is the manual's first example, `M:118`).
- Ruling: **S3** (×17).

**D6. Gradient direction, `:angle`, ranges, radial**
- M: gradients run top→bottom by default; `angle: 90` rotates so they run left→right (`M:1073-1079`); `:fill`/`:stroke` accept "a range of either" (`M:1202, 1453`); `:angle`/`:radius` for background, border, gradient (`M:1073-1075, 1348-1350`).
- S3: `angle` default 0 → `dx = sin`, `dy = cos` → top→bottom; `:radius` → radial pattern (`s3t_pattern.c:53-76`); Ranges become gradients (`:86-89`).
- L follows: `Gradient` default angle **45** (`colors.rb:195-199`); Ranges render `linear-gradient(45deg, …)` (`calzini/background.rb:29`, `calzini/border.rb:24`, `calzini/slots.rb:125,149`); angle passed raw to CSS (CSS 0deg = bottom→top, so Shoes 0 ≠ CSS 0). `Background` has no `:angle` style (`background.rb:12`), so `background r..b, angle: 30` is dropped with a STDERR warning (`drawable.rb:385-388`); only `gradient(c1, c2, angle:)` carries it (commit `897582d`). No radial.
- EX: 15 files use `"#x".."#y"` ranges; `for_playtest/shoes-contrib/styles/gradient-angle.rb` uses `gradient purple, red, :angle => 45`.
- Ruling: **MANUAL/S3**. Mapping for a CSS-like renderer: `css_deg = 180 - shoes_deg`.

**D7. `nofill` / `nostroke`**
- M: no fill / no outline (`M:1701-1709`).
- S4: set to `nil` (`s4_dsl_style.rb:70-83`).
- L follows: sets `rgb(0, 0, 0, 0)` in the draw context (`slot.rb:131-133, 157-159`); PC renders `fill:#000000` (opaque black).
- Ruling: **MANUAL**. Represent as "none", not as an alpha-0 colour.

**D8. Default fill, stroke, strokewidth**
- S3: strokewidth default `1.0` (`s3t_shape.c:98`). S4: `STYLES = { fill: black }` for Oval and Star (`s4_oval.rb:6`, `shoes4…star.rb:6`).
- L follows: Oval defaults `fill: "black"`, `stroke: "black"` (`oval.rb:15-16`); Calzini default strokewidth `"2"` for ovals (`art_drawables.rb:97`), hard-coded `stroke-width:2` for stars (`:78, :83`) and `"stroke-width": "4"` for lines ignoring `strokewidth` (`:185`).
- Ruling: **S3** (black/black/1; honour `strokewidth` on every shape).

### E. Art

**E1. `oval(left, top, N)` — third positional is the diameter**
- M: "a width and height of `radius` pixels" (`M:1716-1722`); but `:radius` style "equivalent to setting both `:width` and `:height` to double this number" (`M:1348-1354`).
- S3: positional args map to `left, top, width, height` (`s3t_shape.c:347-352`, the radius variant is commented out); `shoes_place_exact` doubles only the `:radius` style and defaults height to width (`s3_ruby.c:393-395`).
- S4: `oval(left, top, diameter)` (`s4_dsl_art.rb:98-125`); `width ||= @style[:width] || @style[:diameter] || (@style[:radius] || 0) * 2` (`s4_oval.rb:8-15`).
- EX (21 files with 3-arg ovals): `for_playtest/expert/minesweeper.rb` draws `@app.oval(x*cell_size+3, y*cell_size+3, 13)` inside a cell; `for_playtest/shoes-contrib/animation/mice-satellites.rb` centres with `oval(hor - radius, vert-radius, radius*2.0)`; Scarpe's own `examples/oval.rb` assumes radius semantics.
- L follows: third positional is stored as `:radius` and `width = radius * 2` (`oval.rb:18-19, 33, 42`). P1 `oval(10, 10, 50)` → width/height 100. The `:radius` style is right (P1 `radius: 50` → 100).
- Ruling: **MANUAL+S3+S4** (diameter). `radius:` style stays a true radius. Scarpe's `examples/oval.rb` must change.

**E2. `:center` on oval/rect/arc/image/shape**
- M: `:center` means `(left, top)` is the centre (`M:1115-1121, 1745`).
- S3: shifts by `w/2`, `h/2` (`s3_ruby.c:401-404`).
- L follows: stored; Calzini inverts it: `cx: center ? radius : 0` (`art_drawables.rb:114, 123`). PC: `center:false` → `<ellipse cx="0" cy="0" …>` in a 50x50 svg (a clipped quarter circle), `center:true` → top-left placement.
- Ruling: **MANUAL**.

**E3. `rect` arguments**
- M: heading says `rect(top, left, width, height, corners = 0)` and "starting from coordinates (top, left)" (`M:1749-1753`); `rect(styles)` lists `top`, `left`, `curve` (`M:1770-1781`).
- S3: `left, top, width, height, curve` (`s3t_shape.c:342-345`). S4: same, plus `rect(left, top, side)` (`s4_dsl_art.rb:127-158`).
- L follows: `init_args :left, :top, :width, :height; opt_init_args :curve` (`rect.rb:8-9`); 3 args → square; **2 args → `(width, height)` at origin**; 1 arg → square side at origin; keywords-only defaults left/top to 0 (`rect.rb:17-30`). P1 `rect(10, 20, 30, 40, 5)` OK.
- Ruling: **ERRATA** for the heading (it is `left, top`). 2-arg form: **S4** (`left, top`, zero size); Scarpe's `(w, h)` is **EXT**.

**E4. `star` geometry**
- M: centre at `(left, top)`; `outer` is the full radius; defaults `points = 10, outer = 100.0, inner = 50.0` (`M:1826-1831`).
- S3: centred, radius `outer`/`inner` (`s3t_shape.c:154-173`). S4: `width = outer * 2`, centred (`shoes4…star.rb:9-38`).
- L follows: defaults match (P1 `[10, 100.0, 50.0]`); Calzini puts an `outer`-sized SVG at `left/top` and uses `outer/2` as the radius (`art_drawables.rb:59-90, 217-233`). PC: 100x100 box at (100,100) → half size, offset by +50,+50.
- Ruling: **MANUAL**.

**E5. `arrow(left, top, width)` geometry**
- M: "Draws an arrow at coordinates (left, top) with a pixel width" (`M:1672-1674`).
- S3: arrow body spans `left - w/2 .. left + w/2`, centred on `top` (`s3t_shape.c:134-152`). S4: "x-coordinate of the element center" (`s4_dsl_art.rb:12-15`).
- L follows: Calzini draws from `left` to `left + width` (`art_drawables.rb:238-289`).
- Ruling: **S3/S4** (centred).

**E6. `line(left, top, x2, y2)` endpoints**
- M: from `(left, top)` to `(x2, y2)` (`M:1711-1714`).
- S3: stores `right`/`bottom` = x2/y2 absolute (`s3t_shape.c:354-357`, `s3_ruby.c:396-399`).
- L follows: `init_args :left, :top, :x2, :y2` (`line.rb:8`); Calzini positions a div at `(left, top)` then draws `x1=left … x2=x2` inside an svg sized `x2 × y2` (`art_drawables.rb:50-58`), so the start is offset twice and a horizontal line gets an svg height of 0.
- Ruling: **MANUAL**.

**E7. `shape { move_to; line_to; curve_to; arc_to }`**
- M: one path; art calls inside join the path; only closed regions fill (`M:392-408, 1799-1824`).
- S3: builds a cairo path, measures extents into width/height (`s3t_shape.c:303-329`); art inside a shape adds sub-paths (`:331-345`).
- L follows: `Shape < Shoes::Slot` with `@incompatibility A Shoes3 Shape is *not* a slot; Scarpe does *not* do union shapes` (`shape.rb:11-13`); `move_to`/`line_to`/`curve_to`/`arc_to` are silently ignored outside a Shape (`app.rb:509-568`). EX: `for_playtest/expert/curve-control-point.rb:16` calls `move_to *xy[0]` outside any shape.
- Ruling: **MANUAL**.

**E8. click/release/hover/leave on shapes, text blocks, images**
- M: `:click` "For: arc, arrow, banner, button, caption, check, flow, image, inscription, line, link, mask, oval, para, radio, rect, shape, stack, star, subtitle, tagline, title" (`M:1144-1151`).
- S3: `Shape#click/release/hover/leave` (`s3t_shape.c:33-36`).
- L follows: `Drawable#click`/`#release` store `@block`/`@release` (`drawable.rb:784-802`) but only Button, Check, Radio, Link, Image and SubscriptionItem bind a `click` event; art classes declare no events (e.g. `rect.rb:6`), so the handler never fires.
- EX: `for_playtest/expert/curve-control-point.rb:22-30` (oval click/release drag), `colours.rb:70`.
- Ruling: **MANUAL**.

**E9. `image(w, h) { drawing }` canvas and effects**
- M: `image 300, 300 do … end` renders shapes into one image (`M:410-426`).
- S3: shapes inside an image draw into its surface (`s3t_shape.c:331-335`); `blur`, `glow`, `shadow` effects (`shoes/types/effect.c`).
- L follows: `image(w, h)` becomes a blank placeholder and the block is ignored (`image.rb:10-20`).
- EX: 3 files (`simple-sphere.rb`, `shoes_manual/ovals_image.rb` …); `blur` 1 file.
- Ruling: **MANUAL** for the image canvas; effects **EXT/S3** (low).

**E10. `transform`, `translate`, `cap`, `rotate`**
- M: `M:1676-1680, 1783-1797, 1857-1868`.
- L follows: `translate` and `cap` are no-ops (`app.rb:555-573`); `transform` exists only on Image (`image.rb:74-83`); `rotate`/`scale`/`skew` go into the draw context (`slot.rb:166-193`).
- Ruling: **MANUAL** (low priority).

### F. Text

**F1. `ins()` is an underline fragment, not an inscription**
- M: `ins(text) » Shoes::Ins`, single underline (`M:2025-2028`); `inscription` is the 10px block (`M:2030-2032`).
- S4: `ins: { underline: true }` span (`s4_dsl_text.rb:108-116`).
- EX: Scarpe's own `examples/span.rb:6` puts `ins("hard to read")` inside a `para`.
- L follows: alias to inscription (§1.3; commit `2212244` "Add ins alias for inscription (Shoes3 compatibility)"). `Shoes::Ins` with default `underline: "single"` exists but is unreachable (`text_drawable.rb:127-131`).
- Ruling: **MANUAL**. Revert the alias.

**F2. Text blocks are distinct classes**
- M: `banner` → `Shoes::Banner`, `title` → `Shoes::Title`, … (`M:1921-2129`); TextBlock sizes 48/34/26/18/14/12/10 (`M:3378-3384`).
- S4: `Shoes.const_get(method.capitalize)` per block type (`s4_dsl_text.rb:50-56`).
- L follows: all are `Para` with `size: :banner|:title|…` (`para.rb:258-316`); P1 `title("T").class == Shoes::Para`. Consequence: `style(Shoes::Para, stroke: red)` also restyles titles (P2 stores `[:size, :stroke]` on Para defaults), and `style(Shoes::Title, …)` cannot be expressed. Sizes match the manual (`calzini.rb:24-33`).
- Ruling: **MANUAL** (subclasses of Para; class-level `style()` targets one class).

**F3. `:size` accepts relative strings**
- M: `"xx-small"` 57% … `"xx-large"` 173% (`M:1393-1408`).
- L follows: Calzini `text_size` maps unknown strings via `SIZES[sz.to_sym] || sz.to_i` (`calzini.rb:88-99`), so `"large"` → 0. Symbols like `:title` are a Scarpe extension.
- Ruling: **MANUAL**; symbol sizes **EXT**.

**F4. `:weight`, `:variant`, `:font`**
- M: `:weight` names `ultralight` 200 … `heavy` 900 or a number (`M:1521-1537`); `:variant` `"normal"`/`"smallcaps"` (`M:1511-1519`); `:font` is a Pango description `"[FAMILY-LIST] [STYLE-OPTIONS] [SIZE]"` (`M:1212-1224`).
- L follows: Para declares `:weight` but Calzini renders only `font_weight` (`calzini/para.rb:47`), so `weight: "bold"` shows normal. `:font_weight` and `:font_variant` are Scarpe-invented. `variant:` is not a style (dropped with a warning). `FontHelper#parse_font` knows CSS names only (`font_helper.rb:15-18`).
- EX: `weight:` in 4 files (`"bold"`, `"ultrabold"`, `"strong"`).
- Ruling: **MANUAL**; `font_weight`/`font_variant` **EXT** aliases.

**F5. Manual text styles Lacci drops**
- M: `:leading` (`M:1282-1286`), `:justify` (`M:1268-1273`), `:rise` (`M:1366-1373`), `:stretch` (`M:1423-1434`), `:strikecolor` (`M:1436-1441`), `:undercolor` on Para (`M:1489-1494`).
- L follows: none are Para styles (`para.rb:6-36`); they fall to the "Unexpected non-style keyword" warning (`drawable.rb:385-388`). P1: `para("x", leading: 4, justify: true)` → no `leading` method. TextDrawable has `:undercolor` (`text_drawable.rb:15`); Calzini already renders `rise`, `strikecolor`, `undercolor` if present (`calzini/para.rb:43-50, 79-82`).
- Ruling: **MANUAL**.

**F6. `underline`/`strikethrough` value types**
- M: strings (`M:1443-1451, 1496-1509`).
- S4: booleans (`s4_dsl_text.rb:110, 112`).
- L follows: validators accept only `nil` or the manual strings; `true` raises `InvalidAttributeValueError` (`para.rb:15-29`, `text_drawable.rb:17-31`).
- Ruling: **BOTH** (map `true` → `"single"`, `false` → `"none"`).

**F7. Link defaults and `LinkHover`**
- M: link = single underline, stroke `#06E`; LinkHover = single underline, stroke `#039` (`M:2034-2039`).
- S4: `STYLES = { underline: true, stroke: blue, fill: nil }` (`s4_link.rb:13`).
- L follows: Link styles are `nil` in Lacci (P2); `LinkHover` class-level defaults are stored by `style()` but "the functionality isn't present in Lacci yet" (`link.rb:35-41`). Bare `Link`, `LinkHover`, `Window` constants exist for `style(Link, …)` (`lacci/lib/shoes.rb:48-52`).
- EX: `style(Shoes::Link, :underline => nil)` + `style(Shoes::LinkHover, …)` in `for_playtest/simple/menu.rb:25-26`, `menu1.rb:14-15`, `philippe_checked/accordion.rb:46-47`, `shoes-contrib/simple/simple-accordion.rb:39`. (Some of these were edited from `style(Link, …)` to `style(Shoes::Link, …)` despite the "we don't modify examples" rule in `examples/legacy/README.md`.)
- Ruling: **MANUAL**.

**F8. Link click block argument**
- M: silent (`link(text, click: proc or string)`, `M:2034`).
- S3 3.2-era: the link element (the commented line `s3_canvas.c:1114`). S3 master (3.3): `(button, x, y, mods)` (`s3_canvas.c:1115`).
- L follows: the Link (`link.rb:29-30`, commit `19ad0d0` for `shoes-notes.rb`'s `link('x') { |x| x.parent.remove }`).
- Ruling: **S3 (3.2) / current L** (pass the element). Spec only asserts `arg.is_a?(Shoes::Link)` under a compat tag.

### G. Native controls

**G1. Control callbacks receive the control (`self`)**
- M: button `click { |self| }` (`M:2918-2921`); check/radio `click { |self| }` (`M:2988-2993, 3349-3354`); edit_box/edit_line/list_box `change { |self| }` (`M:3038-3042, 3086-3090, 3211-3215`).
- S3: `shoes_safe_block(self_t->parent, click, rb_ary_new3(1, self))` for every control event (`s3t_native.c:160-195`). S4: `listener.call(self)` (`s4_common_changeable.rb:25-31`).
- L follows: Button calls with no args (`button.rb:42-45`; P1 `[]`); **EditLine passes the new String** (`edit_line.rb:15-20`; P1 `String`); EditBox, ListBox, Check, Radio pass self.
- EX: `for_playtest/shoes-contrib/elements/edit_line-character-count.rb:2-3` does `edit_line do |e| @counter.text = e.text.size end` (breaks on a String).
- Ruling: **MANUAL**.

**G2. `list_box(...) { }` block is the change handler** — M `M:3186-3206`; S3 `ATTRSET(args.a[0], change, args.a[1])` (`s3t_list_box.c:106-107`); S4 passes `blk` (`s4_dsl_element.rb:90-91`); L drops it (§1.2). EX: `for_playtest/shoes-contrib/basic/list_box-select-class.rb`, `for_playtest/shoes_manual/list_box.rb`, and `working/custom-list-box.rb:41` (sits in `working/` while its handler can never fire). Ruling: **MANUAL**.

**G3. ListBox initial selection and `text`**
- M: `text` is `nil` if nothing selected (`M:3234-3237`); `:choose` pre-selects (`M:1137-1142`).
- L follows: `@chosen = kwargs.delete(:choose) || @items&.first` (`list_box.rb:19`; P1 `list_box(items: %w[a b c]).text == "a"`); Calzini selects by `props["choose"]` but Lacci sends the style as `chosen` (`calzini/misc.rb:74-77` vs `list_box.rb:10`); `#choose` sets `@chosen` without a `prop_change` (`list_box.rb:35-41`).
- Ruling: **MANUAL**.

**G4. `:state` (`nil` / `"readonly"` / `"disabled"`)**
- M: for button, check, edit_box, edit_line, list_box, radio (`M:1410-1421`).
- S3: `state=`/`state` on every native control (`research/.../ref/shoes-spec/cases/drawables/NATIVE.md`, from `shoes/types/native.c`).
- L follows: no `:state` anywhere; P1 `button("dis", state: "disabled")` accepted with a STDERR warning and ignored.
- Ruling: **MANUAL**.

**G5. Does programmatic `text=` fire `change`?**
- M: silent.
- S3: platform-dependent (GTK emits "changed" on `gtk_entry_set_text`; Cocoa does not).
- L follows: fires, deliberately: commit `eda8975` ("This is a deliberate deviation from Shoes3 behavior for better UX"), `edit_line.rb:30-40`, `edit_box.rb:30-40`.
- Ruling: **BOTH** (spec must not assert either way).

**G6. Radio grouping**
- M: ungrouped radios group per slot; `radio :films` groups across slots (`M:2069-2074, 3293-3334`).
- L follows: Lacci groups by `@group || @parent&.linkable_id` (`radio.rb:55-57`, correct); Calzini sets HTML `name: props["group"] || "no_group"` (`calzini/misc.rb:88-90`), so every ungrouped radio in the window is one browser group.
- Ruling: **MANUAL** (a native backend should follow Lacci's grouping).

**G7. Button styling**
- M: no colour style on buttons.
- S3.3: `font:`, `stroke:`, `icon:`, `icon_pos:`, `tooltip:` (`examples/legacy/for_playtest/shoes3-tests/button/button.rb`).
- L follows: `:text, :width, :height, :top, :left, :color, :padding_top, :padding_bottom, :text_color, :size, :font_size, :tooltip, :icon, :icon_pos, :font, :stroke` (`button.rb:5`); `:color`, `:text_color`, `:font_size`, `:padding_*` are Scarpe-only.
- Ruling: S3.3 set **EXT**; Scarpe-only set **EXT** behind `features: :scarpe`.

**G8. `check.checked`** — L defines `checked(value)` (one required arg) which shadows the style getter (`check.rb:29-31`, same in `radio.rb:49-51`); P2 `check.checked` → `ArgumentError`. M only documents `checked?`/`checked=` (`M:2979-2986`). Ruling: **MANUAL** (low).

### H. Events

**H1. `keypress` key values**
- M: characters as Strings; special keys and combos as Symbols; modifier order `control_shift_alt_` (e.g. `:control_shift_alt_page_up`); shift only shows on special keys; Return is `"\n"`, but with modifiers `:control_enter`, `:shift_alt_enter`…; `Shift-Alt-7` → `:alt_&` (`M:2207-2249`).
- S3: Return → `rb_str_new2("\n")` (`s3_gtk.c:760-762`); Ctrl/Alt + character → `ID2SYM` (`:765-778`); modified Return → `:enter` (`:818-819`); modifiers applied alt, then shift, then control, each prefixing (`:821-830`) → `control_shift_alt_…`. Cocoa maps Cmd and Alt to `alt` (`s3_cocoa.m:285-298`).
- S4: CR → `"\n"`; order `control_`, `shift_` (special keys only), `alt_`, `super_` (Cmd); modified keys become Symbols (`s4swt_key_listener.rb:27, 84-91, 142-148`).
- L follows: WV maps `Enter` → `:return` (`lib/scarpe/wv/subscription_item.rb:127`); prefixes in order `alt_`, `control_`, `shift_` (`:147-158`); modified *regular* keys arrive as Strings like `"alt_q"` because Lacci only symbolises values starting with `:` (`lacci/…/subscription_item.rb:67-77`). Plus the double-fire (§1.1).
- EX: `for_playtest/shoes-contrib/simple/simple-editor.rb:11-27` (`when String` appends, `when :alt_q` quits) → in Scarpe Alt-Q types "alt_q"; `needs_deps/expert-irb.rb:80` waits for `"\n"`.
- Ruling: **MANUAL** (+ S4's `super_` as **EXT**).

**H2. Mouse button numbering**
- M: "number of the mouse button" (`M:2187-2193`).
- S3: platform button numbers, 1 = left (`s3_canvas.c:1061`). S4: `LEFT_MOUSE_BUTTON = 1`, `MIDDLE_MOUSE_BUTTON = 2`, `RIGHT_MOUSE_BUTTON = 3` (`shoes4…dsl.rb:16-18`).
- L follows: WV passes JS `event.button` (0 = left) to `click`/`release` (`lib/scarpe/wv/subscription_item.rb:87, 98`), while `App#mouse` reports 1 for left held (`app.rb:462-467`).
- EX: `minesweeper.rb:259-261` (`button == 1/2/3`), `tankspank.rb:364`, `shoes-contrib/basic/scribble.rb:5` (`b == 1` via `self.mouse`).
- Ruling: **S3/S4** (1/2/3).

**H3. Event coordinate frame**
- M: silent; the motion example moves an oval by the reported coordinates (`M:2264-2275`).
- S3: click and motion blocks get window/canvas `x, y` (the slot-local `ox, oy` are only used for hit-testing) (`s3_canvas.c:1040-1061, 1180-1193`).
- L follows: WV computes coordinates relative to `e.currentTarget.getBoundingClientRect()` (slot-relative) (`lib/scarpe/wv/subscription_item.rb:66-100`).
- Ruling: **S3** (window coordinates).

**H4. Extra `mods` argument**
- M: `click { |button, left, top| }`, `motion { |left, top| }` (`M:2187, 2259`).
- S3.3: click/release get a 4th `mods`, motion a 3rd (`s3_canvas.c:1061, 1193`).
- L follows: motion calls `(x, y, mods)` with `mods` in `"control"`, `"shift"`, `"control_shift"` (`lacci/…/subscription_item.rb:47-54`); click/release 3 args.
- Ruling: **MANUAL** arity; trailing `mods` **EXT** (procs tolerate it; lambdas would not).

**H5. `hover`/`leave` block argument**
- M: the slot/element (`M:2200-2205, 2251-2257`).
- S3: `CHECK_HOVER` passes `self` (`s3_ruby.h:167-176`).
- L follows: slot-level `hover {}` passes the SubscriptionItem (`subscription_item.rb:37-46`), then (double-fire) a kwargs Hash (P2 last call `[Hash]`); element-level `el.hover {}` passes nothing (`drawable.rb:416-422`).
- EX: `for_playtest/simple/menu1.rb:18` and `shoes-contrib/simple/simple-menu1.rb:18` (`hover do |box| if box.width < 170`).
- Ruling: **MANUAL**.

**H6. Re-registering a slot event replaces or adds?**
- S3: `EVENT_HANDLER` stores one proc per slot per event (`ATTRSET`, `s3_canvas.c:934-955`) → replace.
- S4: `motion` appends to `mouse_motion` (`s4_dsl_interaction.rb:23-26`); change listeners accumulate (`s4_common_changeable.rb:13-16`).
- L follows: slot/app events create a new SubscriptionItem per call → accumulate (`app.rb:414-422`); P2 two `click {}` both live. Element `click`/`change` replace (`@block`).
- Ruling: **BOTH** (do not spec double registration).

**H7. `wheel`** (not in M)
- S3.3: block gets `(dir == up ? 1 : 0, x, y, mods)`; without a block the slot scrolls 32px (`s3_canvas.c:1231-1263`); Cocoa emits one event per unit of delta (`s3_cocoa.m:213-237`).
- L follows: `(delta_float, x, y)`, positive = up (`lib/scarpe/wv/subscription_item.rb:171-184`, `lacci/…/subscription_item.rb:78-84`).
- EX: `for_playtest/shoes3-tests/wheel/wheel1.rb` (S3.3 style), `for_playtest/shoes_manual/wheel.rb` (Scarpe-authored, uses `delta.round(2)`).
- Ruling: **EXT/BOTH**: assert only `first_arg > 0` iff wheel-up (both shapes satisfy it).

**H8. Other event verbs**
- M: `start { |self| }` fires on first draw; `finish { |self| }` on removal (`M:2195-2198, 2286-2289`).
- S3.3: `keydown`, `keyup` (`s3_canvas.c:950-952`). S4: `keyrelease`, `resize` (`s4_dsl_interaction.rb:32-35, 78-81`).
- L follows: `start` exists only on App, runs after the body with no argument (`app.rb:146-159`); `finish` on Slot fires on destroy with no argument (`slot.rb:209-219`, commit `1ce13b0`); no `keydown`/`keyup`/`keyrelease`/`resize`.
- Ruling: **MANUAL** for start/finish (on slots, argument = slot); others **EXT**.

### I. Timers

**I1. `animate` default fps and frame numbering; `every`/`timer` arguments**
- M: default fps 10; frame starts at zero (`M:1877-1897`); `every(seconds) { |count| }` (`M:1989-1994`).
- S3: default 12 fps (`s3t_timerbase.c:83`); every timer kind passes `frame` starting at 0 (`:41-44`, reset to 0 at `:35`).
- S4: `@framerate = @style[:framerate] || 10` (`s4_animation.rb:17`).
- L follows: WV default 10 (`lib/scarpe/wv/subscription_item.rb:24`) but counters pre-increment so the first frame/count is **1** (`:27-29, 36-39`); `timer` passes nothing; plus double-fire (§1.1).
- Ruling: **MANUAL** (10 fps, first frame 0, `every` count from 0).

### J. Navigation

**J1. `url` / `visit` / pages**
- M: documents only `visit(url)` and `location()` (`M:980-982, 1012-1018`); no `url` entry.
- S3/S4: class-level `url` on `class Foo < Shoes` (S4: page string anchored as `/^page$/`, one capture passed, a fresh instance of the class per visit; `s4_url.rb:4-43`; `visit` clears and sets `location`, `s4_dsl_interaction.rb:97-107`).
- L follows: both class-level (`lacci/lib/shoes.rb:98-114`, copied onto the app through `pending_app_class`, `:152-190`) and instance-level `url` inside `Shoes.app` (`app.rb:401-409`); strings containing `(` become regexes; multiple captures passed; unknown URL prints `Error: URL '…' not found` (`app.rb:364-399`); `"/"` rendered on first boot if routed to `:index` (`app.rb:598-604`). Scarpe-only `page(:name) { }` + `visit(:name)` (`app.rb:355-362`, `docs/SCARPE_FEATURES.md:15-38`). No `location`.
- EX: `examples/url_routing_example.rb` (instance-level), `examples/shoes_subclass_app.rb`, `examples/internal_link_navigation.rb` (pages + `link(click: "/page2")`); 7 files use `url`, 9 use `visit`.
- Ruling: **BOTH** for class vs instance `url`; `page` **EXT**; add `location` (**MANUAL**).

**J2. `link(..., click: "/path")` visits** — S3 `shoes_app_goto` (`s3_canvas.c:1116-1119`), S4 `app.app.visit` (`s4_link.rb:25-35`), L `app.visit(@click)` for strings starting with `/` (`link.rb:14-31`). Concordant. Ruling: **MANUAL**.

### K. Built-ins and dialogs

**K1. `ask` cancel value and options**
- M: `ask(message)` returns a string (`M:629-641`); `:secret` is listed "For: ask, edit_line" (`M:1385-1391`).
- S3: `ask(msg, opts)` with `:title` and `:secret`; returns `nil` on Cancel (`s3_gtk.c:1772-1826`: `VALUE answer = Qnil`, set only on `GTK_RESPONSE_OK`).
- DOC: "Classic Shoes: ask() returned nil on cancel; Scarpe returns """ (`scarpe_shoes_incompatibilities.md:104-107`). Commit `6ce3d28` says the opposite ("Shoes3 likely returned empty string") to keep Hackety Hack's guessing game from crashing.
- L follows: `ask(message_string)` single argument (`builtins.rb:20-22`); WV returns `""` on cancel.
- Ruling: **S3** (`nil`) for the core spec; `""` as a documented Scarpe compat shim; accept `secret:`/`title:`.

**K2. Dialog option hashes** — S3.3 `alert(msg, title:)`, `ask_open_file(title:)` (EX: `shoes3_only/menus/menu2.rb:5`, `shoes3_only/cardflip.rb:80`). L: one positional arg each (`builtins.rb:20-50`) → `ArgumentError`. Ruling: **EXT** (accept and ignore unknown keys).

**K3. `debug`, `info`, `warn`, `error`** — M: Shoes console loggers; `error` accepts exceptions (`M:719-844`). L: `debug`/`info` print `[DEBUG]`/`[INFO]` (`builtins.rb:54-60`) and App aliases both to `puts` (`app.rb:546-547`); `warn` is Ruby's `Kernel#warn`; `error` is undefined. Ruling: **MANUAL** (route all four to the log).

### L. Loader and environment

**L1. App code isolation** — M's "Raisins" rule: each app runs in an anonymous class so app-local classes vanish (`M:487-533`), but the same note says Policeman (S3.1+) uses `TOPLEVEL_BINDING`. L: `Shoes.run_app` does `load path` at top level (`lacci/lib/shoes.rb:205-240`). Ruling: **S3** (top level). Spec nothing about the sandbox.

**L2. Case-insensitive `require`** — Shoes 3 on JRuby/Windows tolerated `require 'CSV'`; L installs a `Kernel#require` shim with a map and a downcase fallback (`compat_require.rb:11-40`, commit `36fc931`). Ruling: **OOS** for the spec (loader policy); keep it in the runner.

**L3. Constants** — M: `Shoes::RELEASE_NAME`, `RELEASE_ID`, `REVISION` (a Subversion revision), `FONTS` (`M:600-614`). L: parsed from `CHANGELOG.md` (`changelog.rb:17-50`), `REVISION` = git SHA, plus `RELEASE_TYPE = "LOOSE_SHOES"`, `VERSION = "0.5.0"`, top-level `::VERSION`, `::ShoesGemJailBreak = true`, `DIR` = Scarpe install dir, `LIB_DIR` ≈ `~/.shoes` (`constants.rb:6-76`). Ruling: **MANUAL** names; values unspecified.

**L4. Shoes3-only widgets** — `plot`, `terminal`, `systray`, `spinner`, `switch`, `video` (VLC), `svghandle`, `menu`/`menubar`, `Shoes.settings`/`monitor`, `event`/`shoesevent`, `decoration`, `cache` (`docs/scarpe_shoes_incompatibilities.md:10-40`, `examples/legacy/shoes3_only/README.md`). S3 also ships `slider` (`shoes/types/slider.c`), which neither list mentions. Ruling: **OOS**.

---

## 3. Manual errata (internal contradictions a spec must adjudicate)

| Where | Problem | Verified behaviour |
|---|---|---|
| `M:1749-1753` | `rect(top, left, …)` and "from coordinates (top, left)" | `left, top, width, height, curve` (S3 `s3t_shape.c:342-345`, S4) |
| `M:1639-1645`, `M:869-874` | "radius: 100 … One-hundred pixels wide"; `radius: 160` circle fitting a 200x200 window | `:radius` is a true radius: width = 2 × radius (`s3_ruby.c:393-394`, `M:1348-1354`) |
| `M:1716-1722` vs `M:1348-1354` | 3rd positional "radius" is really the diameter; `:radius` style doubles | both true: positional = width, style = radius (E1) |
| `M:2271-2273` | `motion do |top, left| @circ.move top - 50, left - 50` | positional order is `(left, top)`; the names are swapped, the maths works |
| `M:2225` | "rather than `:shift_5`" | should read `:shift_7`; irrelevant to the rule |
| `M:3049, 3097` | `text() » self` for EditBox/EditLine | returns the String |
| `M:1925` | `border(text, strokewidth:)` | first arg is a pattern |
| `M:300-313` | Messenger fix with `@stack.app { @stack.append … }` | fails in S3 and Scarpe (B2) |
| `M:1564, 1576, 3525` | `{INDEX}`, `{COLORS}`, `{SAMPLES}` placeholders never expanded | colour list must come from S3 / `colors.rb` `COLORS` |

## 4. Decisions already taken in Scarpe history (harvested from `git log`)

| Commit | Date | Decision |
|---|---|---|
| `8e6218f` | 2023-02-09 | Manual imported from shoes-deprecated (Shoes 3) as markdown |
| `6182c74` | 2023-02-07 | Para options: `stroke` acts as text colour |
| `bacec91`, `f29d773` | 2023-02 | Button width/height; EditLine width default (later removed from Calzini defaults) |
| `83af65d` | 2023-10-05 | Per-class default styles + `style()` |
| `a687c58` | 2023-12-08 | `Shoes::FEATURES` / `Shoes::EXTENSIONS` negotiation (`features: :html`, `:scarpe`) |
| `ebb092e`, `a9e3c0a` | 2023-12 | margin/padding and width/height/left/top on all drawables |
| `c66f1d9` | 2024-01-23 | hover/leave/motion moved from Button to every Drawable |
| `b6b4b1f` | 2024-07-09 | Multiple apps only when a display service declares `:multi_app` |
| `8cec81a`, `5fe7203` | 2024-10 | `url`/`visit`; render index on first boot |
| `e3d0895` | 2025-12-23 | `class Foo < Shoes` app composition |
| `2d943d8` | 2026-02-05 | `Shoes.p` |
| `1ce13b0` | 2026-02-05 | `slot.finish` fires on removal |
| `7f1cbba` | 2026-02-05 | `:owner` style for window/dialog |
| `271eaf9`, `56525cb` | 2026-02 | `app.slot`, `close`/`quit`/`exit`, `refresh_slot` |
| `2455149` | 2026-02-09 | Button `:font`/`:stroke`, text optional |
| `02d4e19` | 2026-02-09 | `Para#contents`, `TextDrawable#contents` |
| `8e02306` | 2026-02-10 | `:attach` style on slots |
| `897582d` | 2026-02-10 | `gradient(..., angle:)` (default stays 45) |
| `133b88b` | 2026-02-06 | `slot.width/height` computed pixels (no Float support) |
| `6ce3d28` | 2026-02-13 | `ask` cancel returns `""` |
| `19ad0d0` | 2026-02-16 | Link click passes the Link |
| `2212244` | 2026-02-18 | `ins` aliased to `inscription` (conflicts with M, see F1) |
| `eda8975` | 2026-02-19 | programmatic `text=` fires `change` (deliberate deviation) |
| `0a82077` | 2026-02-21 | radio group switching fix |
| `36fc931` | 2026-04-07 | case-insensitive `require` shim; `observer`/`csv`/`bigdecimal` deps; Slot Hash→kwargs |
| in code | — | `@incompatibility` notes: `shoes.rb:119-123`, `drawable.rb:440-443`, `shape.rb:11`, `slot.rb:4`, `slot.rb:255` |

## 5. Stale or empty docs (do not cite as authority)

- `docs/web_archaeology.md` and `docs/shoes_implementations.md`: outline placeholders with no facts.
- `docs/scarpe_shoes_incompatibilities.md`: says pre-app dialogs don't work (partly false, §A5); records classic `ask` cancel = `nil` while commit `6ce3d28` claims the opposite.
- Repo `CLAUDE.md:26, 198` points at `examples/legacy/not_checked/`, which no longer exists (now `working/` + `for_playtest/` + `shoes3_only/` + `needs_deps/` + `path_issues/`).
- `examples/legacy/README.md` still explains a "not_checked" directory.

## 6. Implications for the spec suite builders

1. Fix §1 items 1-5 in Lacci first; otherwise any spec that counts callbacks, checks colour output, uses `ins`, list boxes, or `ask_color` fails for reasons unrelated to the Rust backend.
2. Tag every spec: `core` (MANUAL/S3/ERRATA rows), `compat-both` (BOTH rows, assertions both behaviours satisfy), `ext-s33`, `ext-s4`, `ext-scarpe`.
3. `examples/legacy/working/` is not an oracle for behaviour; it only proves boot (e.g. G2's `custom-list-box.rb`). Use it for "loads without error", not for semantics.
4. Geometry rows (E1-E6) change what pixels appear. The Rust renderer should implement S3 geometry from `s3t_shape.c:96-181` and `s3_ruby.c:385-405` directly; they are short and exact.
5. Keypress (H1) and mouse buttons (H2) need a mapping table in the native backend, not in Lacci; write it from `s3_gtk.c:752-833`.

## 7. Artefacts

- Probe scripts: `research/probe06/probe.rb`, `research/probe06/probe2.rb`, `research/probe06/calzini_probe.rb`.
- Probe outputs: `research/probe06/probe_out.json`, `research/probe06/probe2_out.json`.
- Fetched upstream sources (verbatim): `research/probe06/src/` — Shoes 3 (`s3_app.c`, `s3_app.h`, `s3_canvas.c`, `s3_ruby.c`, `s3_ruby.h`, `s3_gtk.c`, `s3_cocoa.m`, `s3t_shape.c`, `s3t_color.c`, `s3t_pattern.c`, `s3t_native.c`, `s3t_list_box.c`, `s3t_timerbase.c`, …) and Shoes 4 (`s4_dsl_*.rb`, `s4_oval.rb`, `shoes4…star.rb`, `s4_url.rb`, `s4_link.rb`, `s4_animation.rb`, `s4_common_changeable.rb`, `s4swt_key_listener.rb`, …).
