# The Shoes ledger

Shoes-Spec was Noah Gibbs' idea: write down what Shoes *is* as tests that any display service can run. Wherever the sources disagree about what Shoes is, the argument happens on this page. Each row records one disagreement, the evidence on every side, the ruling, what `spec/` asserts, and what the native Rust backend does.

Status: v1.7, 28 Sep 2026. Nick ruled Q10: a negative `left` or `top` is a plain coordinate on every element, as Shoes 3 reads it, and the w10 scarpe lane made native do so (new row C18, with C10 and C15 brought in line). The same lane, on Nick's two other decisions that day, added K8 (the Shoes console, which Alt-/ opens: H10 now rules that key MANUAL), K9 (`Shoes.on_error`) and K10 (`Shoes.run_program`), and routed the log built-ins to the console (K3). The w10 integrate lane then made `run_program` start a packaged app's programs when the app's path has a space in it, as "Hackety Hack.app" does (K10), and let a startup error find the program's own frame through a linked path (K9). The w10 land lane made the log say an error a timer raises again and again once, then how often (K9), and wrote down how Q10 moved Hackety Hack's lesson tips, which added two frames together (C18, A4). v1.6, 28 Sep 2026. The Hackety Hack polish lane (w9) ruled M19 MANUAL, so a background or border with a size of its own is placed from the far edge by its pattern's size, as Shoes 3 places a tile; added C16 (a slot with no height reaches down to its row's bottom in a flow), C17 with Q13 (placement on one axis), and Q12 with an opt-in for Shoes 3's text (M14, `Shoes.text_mode = :shoes3`); and extended C10 (a bottom-placed slot with no height), F14 (`cursor = :marker`), I1 (`timer(0)` after layout), K7 and M38 (the manual's pictures and lists). v1.5, 28 Sep 2026. The Hackety Hack integrate lane (w9) ruled H6 S3, so a slot's second handler for an event replaces its first; made a closing window send its slots' `finish` (H8); let a sized or trimmed line sit beside what came before when its text fits (C7); kept the colon key a String (H1); and packaged apps carry the manual (K7). v1.4, 28 Sep 2026. The Hackety Hack lane (w9) moved B1 into Lacci, so slot blocks keep their caller's `self`; extended C5, C10, E8, E10 and F5 with what Hackety Hack met; added A10, F13, F14 and K7; and asked Q10 and Q11 under "Open questions". v1.3, 28 Sep 2026. The sixth build wave (the legendary apps) extended C15 to every number on art and added E12 and G16; its finishing lane fixed what the app builders met, each row saying so. v1.2, 27 Sep 2026: The orchestrator ruled the seven open questions (Q1 to Q7) that day, then Q8 and Q9 as the later build waves raised them, with two new rows (C15, G15) from the fifth wave's rulings; and the rows the first build wave asked for joined it (A9, B6, C13, D9, E11, F12, G10 to G14, H9, H10, I2, K6, X20). v1 was seeded from `native/research/06_discrepancy_ledger_seed.md` (rows A1 to L4, ids kept), the 37 contradictions in `native/research/03_manual_inventory.md` (rows M1 to M37, same numbers), and the Lacci divergences in reports 01, 03 and 04 (rows X1 to X19 plus new rows in each area). Contract: `native/DESIGN.md`. When the build lanes merged the same day, every row whose Lacci behaviour changed gained a "Since 27 Sep" sentence naming the Lacci lane commit, and rows whose Lacci change landed say so in their ruling line.

## How to read this

### The sources

| Tag | Source | Where |
|---|---|---|
| Manual | The Shoes manual, `docs/static/manual.md` (3,533 lines). A Markdown copy of Shoes 3's built-in "Policeman"-era manual. Cited as `manual 1716-1722`. | this repo |
| Shoes 3 | `shoes/shoes3@master` C source (3.3.x). Files are named as fetched: `s3_ruby.c` is `shoes/ruby.c`, `s3t_shape.c` is `shoes/types/shape.c`, `s3_gtk.c` and `s3_cocoa.m` are the GTK and Cocoa backends. | fetched copies in `native/research/sources/` (see the end of this page) |
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

A ruling marked **ruled 27 Sep 2026 (Q3)** settled question 3 at the bottom of this page, where the evidence was balanced. The orchestrator ruled all seven on 27 Sep 2026. Nick may overrule any of them; his answer then replaces the ruling line, with its date. Question 8, raised after those rulings, was ruled the same day.

### The fields in each row

- **Behaviour**: the row's heading, stated as the behaviour the ruling settles.
- **Manual / Shoes 3 / Shoes 4 / Examples / Lacci today**: the evidence. "Silent" means the source says nothing. "Not checked" means nobody has read it yet.
- **Ruling**: one tag from the table above, with the reason.
- **Spec**: what `spec/` asserts. Cases cite the row with `ledger: E1` in their front matter (DESIGN section 9).
- **Native**: what the Rust backend and its Ruby shim do. Where DESIGN.md says something different from the ruling, the row says so under **DESIGN conflict**.
- **Lacci fix**: the fix from DESIGN section 10 this row waits on (**fix 10.N**), or **Lacci change, unscheduled** when the ruling needs a Lacci change that section 10 does not list yet.

Rows X1 to X20 are Lacci and Webview defects rather than disagreements about Shoes. Each points at the behaviour rows it poisons. Rows M1 to M40 are the manual's own errata and vague spots; where a behaviour row already argues the point, the M row is one line pointing at it.

## Contents: every row and its ruling

"Fix" names the DESIGN section 10 fix the row waits on; "unsched." means the ruling needs a Lacci change that section 10 does not list. "DESIGN" marks a row where `native/DESIGN.md` currently says something else (listed again under "Where DESIGN.md disagrees").

### A. App and window

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| A1 | Default window size and title | S3, ruled (Q1) | | |
| A2 | When the `Shoes.app` block runs | S3 | | |
| A3 | `window`, `dialog`, `owner` | MANUAL | | |
| A4 | Live positions and sizes of apps, slots and elements; margins count | MANUAL; S3 for margins | | |
| A5 | Built-in dialogs with no app open | MANUAL | 10.6 | |
| A6 | `Shoes.app("/start/url")` | EXT | | |
| A7 | Shoes 3.3 app styles | OOS | | |
| A8 | `close` closes one window | MANUAL | | |
| A9 | `Shoes.app`, `window` and `dialog` return the App | MANUAL | | |
| A10 | `Shoes.app`, `window` and `dialog` take their styles as a Hash | S3 | | new 28 Sep |

### B. Blocks, `self` and slot manipulation

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| B1 | Slot blocks keep the caller's `self` | MANUAL | | done 28 Sep |
| B2 | `app { }` changes `self`; the manual's fix fails | ERRATA | | |
| B3 | Elements created in handlers land in the app's top slot | MANUAL | | |
| B4 | `prepend`/`before`/`after` keep the written order | MANUAL | 10.3 | |
| B5 | `slot.remove` removes children and fires `finish` | MANUAL | | |
| B6 | Methods headed `» self` return `self` | MANUAL | | |
| B7 | `clear` and the timers a slot started | S3, ruled (Q8) | | |

### C. Layout and dimensions

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| C1 | A Float dimension is a fraction of the parent | MANUAL | | |
| C2 | `style[:width]` returns what was asked for | MANUAL | | |
| C3 | Forms of `:margin` | MANUAL | unsched. | |
| C4 | Default sizes of native controls | MANUAL | | |
| C5 | Missing slot and element methods | MANUAL | | |
| C6 | The window scrolls; `gutter` | MANUAL | | |
| C7 | Text side by side in a flow reads as one paragraph | MANUAL, ruled (Q2) | | |
| C8 | Default width of a slot | S3 | | |
| C9 | Default margins of text blocks | S3, ruled (Q3) | | |
| C10 | `:right` and `:bottom` | MANUAL | | |
| C11 | `attach: Window` | MANUAL | | |
| C12 | Paint order: backgrounds are layered elements | MANUAL | | |
| C13 | A fixed height clips the slot | MANUAL | | |
| C14 | An explicit width or height includes the margins | S3, ruled (Q9) | | |
| C15 | A number on art is a plain coordinate, negative or under 1 | S3; MANUAL for Floats | | |
| C16 | A slot with no height reaches down to its row's bottom in a flow | S3 | | new 28 Sep |
| C17 | An element placed on one axis keeps the flow's place on the other | open (Q13) | | new 28 Sep |
| C18 | A negative `left` or `top` is a plain coordinate on every element | S3, ruled (Q10, Nick) | | new 28 Sep |

#### C18. A negative `left` or `top` is a plain coordinate on every element

**Ruling: S3, ruled by Nick 28 Sep 2026 (Q10):** "sounds good do it". Every position is a plain number: a negative `left` or `top` on a slot, a control, text, an image, a background or a border lies past its slot's left or top edge, as on art (C15), and as a negative `right` or `bottom` lies past the far edge (C10). Only a size (`width`, `height`, a margin) counts back from the parent. **Native change, done 28 Sep 2026** (the w10 scarpe lane). New row, from Hackety Hack's intro.

- **Manual:** silent on negative positions. `:left` "places the object's left edge ten pixels away from the left edge of the slot" (manual 1288-1294), and `:top` likewise (manual 1477-1485).
- **Shoes 3:** `shoes_px2` reads `left` (or `top`) with `shoes_px(obj, dv, pv, 0)`, and with `nv` 0 a negative Integer stays as it is. Only `nv` 1 adds the parent's size to a negative number, and the `PX` macro passes that for sizes and margins alone (`s3_ruby.c:298-337`, `s3_ruby.h:142-144`). `shoes_place_decide` places slots, controls, images and tiles with it: `place->x = PX2(attr, left, right, cx, tw, canvas->place.iw) + ox` and `place->y` likewise (`s3_ruby.c:518-520`). Text blocks read `left` and `top` as plain integers (`ATTR2(int, ...)`, `s3t_textblock.c:114-115`). A Float or a `"N%"` String is `pv * f` either way, so a negative share lies past the edge too.
- **When it changed:** _why removed the far-edge reading on 20 Mar 2008, in a commit titled "negative values for coordinates should be negative" (`whymirror/shoes@5777c978`, which deletes `if (px < 0) px += pv;` from `shoes_px`), and the next day gave sizes their own switch, "allow negative widths, they're in NKS" (`@64e401a3`, the `nv` argument). Every Shoes since, Raisins (Shoes 2) and Policeman (Shoes 3) among them, reads positions this way. Both commits were read on GitHub for this row; they are not vendored.
- **Examples:** Hackety Hack's intro (`app/ui/widgets.rb`, `splash`) starts its hand at `stack :top => -400`, above the window, and animates `@s.top` down to 198 while the title fades in; its Ready button sweeps the intro off to the left with `@s.parent.move(-(i*40), 0)`. `shoes-contrib/simple/simple-slide.rb` slides a slot up with `top = -i * 3`. The three copies of Othello (`for_playtest/expert/othello.rb`, `for_playtest/shoes-contrib/expert/expert-othello.rb` and Shoes 3's own sample, `working/shoes-dep-samples/expert-othello.rb`) put their Undo button at `:left => -150`. The file is dated 13 Jan 2008, two months before the change, when a negative number still counted in from the far edge.
- **Lacci today:** passes the numbers through, and `left` and `top` of an element the app placed answer what it was given (A4), so Hackety Hack's `@s.top < 198` reads -400.
- **Native:** since 28 Sep 2026 `left` and `top` read through `style::dim::position` (`layout::place_positioned`, `decor_box`), as `right` and `bottom` have since the w9 lane. `stack top: -400` lays out 400 px above its slot, where it read as the slot less 400, clamped at 0, so Hackety Hack's hand rose from the window's foot and jumped, and Ready swept the intro back across Home from the right. Played headless, the hand's top is now -340, -210, -70, 120 and 198 at 0.2, 0.6, 1.0, 1.6 and 2.4 s (it was at 210, 350, 480, 120 and 198), and after Ready the intro's left is -80, -400 and -840 at 0.1, 0.3 and 0.6 s, then it is removed (it was at 710, 390 and 0). `shoes-contrib/simple/simple-slide.rb`, MooTools' Fx.Slide, now slides its text up out of its shrinking box (0.4 s in, at y = 7.4 in a box at 40.4), where it fell to the box's foot (124.4). A negative size keeps the dimension rule: `stack width: -400` is its parent less 400.
- **Typewriter:** the legendary Typewriter (`examples/native/legendary/typewriter`, Scarpe's own) slides its paper and carriage left as it types, `@carriage.move(x - 70, 244)`, and rolls the paper up a line at a time, `@paper.move(x, 244 - line * 22)`. Under the old reading the carriage leapt to the window's right side from the 32nd letter of a line, and the paper to its foot from the 12th line; now both ride on past the left and top edges, as a typewriter's do. At the margin the carriage's lever has slid off the window with it, so its check clicks the lever while it is in reach and sends the carriage home from the margin with Return, as the app itself asks ("The carriage is at the margin. Press Return."); the check had clicked the lever where the far-edge reading threw it.
- **Hackety Hack's lesson tips:** hovering the lesson pane's Previous, Index or Next arrow puts a red tip over it, at the arrow's `left` less the pane's. Those answer in the two frames of A4: the arrow's `:left => 100` as given, from its row, and the pane's as its place in the window, 390, so the tip was placed at `left: -290`. The far-edge reading put that near the arrow by luck; this one put it 290 px past the pane's left edge, over the lessons list (found by the w10 adversarial lane). Hackety Hack now adds a placed `left` to its parent's place, as 1.0 added up its parents' lefts in Shoes 3, where every `left` counts from the parent, and the tip is a small positive offset, the same under either reading (its commit `6f292b9`).
- **Othello:** its Undo button now lays out at x = -140, off the window, where Shoes 3 put it too: in Shoes 3 its 144 px button (`SETUP_CONTROL`'s `len * 8 + 32`, `s3_ruby.h:242`) showed only its last 4 px at the window's left edge, and native's is 117 px wide and shows none. Shoes 3 broke the sample, and every Shoes since March 2008 did; the files are Shoes 3's samples and are left as written. `spec/examples.yml` loads them without playing a move, so no smoke run needs the button.
- **Spec:** `styles.top__negative` (native): a stack at `top: -40` sits 40 px above its slot's top edge, and its `top` reads -40. `styles.left__negative` (native): a window-wide stack moved to `(-40, 0)` lays out at x = -40 and leaves the window's last 40 px white. **Test:** `layout::tests::negative_left_and_top_place_past_the_near_edges`.

## D. Colours and patterns

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| D1 | Colours are `Shoes::Color` objects | MANUAL | | |
| D2 | `rgb()` types each component | MANUAL | 10.7 | |
| D3 | Alpha is opacity; named colours take one | MANUAL | | |
| D4 | `rgb`/`gray`/`gradient` are built-ins; `Shoes.rgb` | MANUAL | | |
| D5 | Three-digit hex times 17 | S3 | 10.7 | |
| D6 | Gradient direction, `:angle`, Ranges | MANUAL | | |
| D7 | `nofill`/`nostroke` mean none | MANUAL | | |
| D8 | Default fill, stroke and stroke width | S3 | | |
| D9 | `Shoes::Pattern`: `gradient`, backgrounds, borders, `to_pattern` | MANUAL | | |

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
| E9 | `image(w, h) { }` is a canvas | MANUAL | | |
| E10 | Transforms; turns add up | MANUAL; S3 for turns | | |
| E11 | Art methods return `Shoes::Shape` | MANUAL | | |
| E12 | `arc(..., wedge: true)` fills a pie slice | EXT | | |

### F. Text

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| F1 | `ins()` is an underline fragment | MANUAL | 10.8 | |
| F2 | Text blocks are distinct classes | MANUAL | | |
| F3 | Relative `:size` strings | MANUAL | | |
| F4 | `:weight`, `:variant`, `:font` | MANUAL | | |
| F5 | Text styles Lacci drops | MANUAL | | |
| F6 | `underline: true` | BOTH | | |
| F7 | Link and LinkHover defaults | MANUAL | | |
| F8 | Argument of a link's click block | S3 | | |
| F9 | `link(click: proc)` fires | MANUAL | 10.5 | |
| F10 | `:leading` defaults to 4 px | MANUAL | | |
| F11 | `para` with non-String arguments | BOTH | | |
| F12 | Text with invalid UTF-8 is reported | MANUAL | | |
| F13 | A text fragment's parent is what holds it | S3 | | new 28 Sep |
| F14 | A text block's `hit`, `cursor_top` and `cursor_left` | EXT | | new 28 Sep |

### G. Native controls

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| G1 | Control callbacks receive the control | MANUAL | | |
| G2 | The `list_box { }` block is the change handler | MANUAL | 10.4 | |
| G3 | List box selection, `text`, `choose` | MANUAL | 10.4 | |
| G4 | `:state` | MANUAL | | |
| G5 | Programmatic `text=` and `change` | BOTH; EXT pin, ruled (Q7) | | |
| G6 | Radio grouping | MANUAL | | |
| G7 | Button styling | EXT | | |
| G8 | `check.checked` | MANUAL | | |
| G9 | `focus` on buttons; Enter clicks | MANUAL | | |
| G10 | `click:` and `change:` styles are the handlers | MANUAL | | |
| G11 | Fonts on edit lines and edit boxes | EXT | | |
| G12 | New inputs read `""`, new progress bars `0.0` | MANUAL | | |
| G13 | Up and Down on a focused list box select | MANUAL | | |
| G14 | A radio unmarked by its sibling: does its block run? | BOTH | | |
| G15 | Scarpe draws its own controls | EXT | | |
| G16 | `edit_line.finish = proc` runs on Return | EXT | | |
| G17 | Colours on edit lines and edit boxes | EXT | | |

### H. Events

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| H1 | `keypress` values; Cmd on macOS | MANUAL, ruled (Q5) | | |
| H2 | Mouse button numbers | S3 | | |
| H3 | Coordinate frame of mouse events | S3, ruled (Q4) | | |
| H4 | The extra `mods` argument | MANUAL | | |
| H5 | `hover`/`leave` get the slot | MANUAL | | |
| H6 | Registering an event twice | S3 | | done 28 Sep |
| H7 | `wheel` | EXT | | |
| H8 | `start` and `finish` | MANUAL | | |
| H9 | Slot event handlers survive `clear` | MANUAL | | |
| H10 | Hotkeys the manual reserves for the console | MANUAL for Alt-/; OOS for the rest | | 28 Sep |

### I to L. Timers, navigation, built-ins, loader

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| I1 | Timer rate and counting | MANUAL | 10.1 | |
| I2 | `Shoes::Animation`, `Shoes::Every` and `Shoes::Timer` | MANUAL | | |
| J1 | `url`, `visit`, pages, `location` | BOTH | | |
| J2 | `link(click: "/path")` visits | MANUAL | | |
| K1 | `ask` on Cancel; its options | MANUAL, ruled (Q6) | 10.6 | |
| K2 | Option hashes on dialogs | EXT | unsched. | |
| K3 | `debug`, `info`, `warn`, `error` | MANUAL | | 28 Sep |
| K4 | `font(path)` returns family names | MANUAL | | |
| K5 | `download` and its events | MANUAL | | |
| K6 | `exit` stops the program at once | MANUAL | unsched. | |
| K7 | `Shoes.show_manual` opens the manual in a window | S3 | | new 28 Sep |
| K8 | The Shoes console | MANUAL; S3 for what it lists | | new 28 Sep |
| K9 | `Shoes.on_error` | EXT | | new 28 Sep |
| K10 | `Shoes.run_program` runs a program in a process of its own | EXT | | new 28 Sep |
| L1 | App code runs at top level | S3 | | |
| L2 | Case-insensitive `require` | OOS | | |
| L3 | Constants | MANUAL | | |
| L4 | Shoes 3 only widgets | OOS | | |
| L5 | Scripts with no `Shoes.app` | MANUAL | | |

### N. Screen readers

| Row | Behaviour | Ruling | Fix | Note |
|---|---|---|---|---|
| N1 | A screen reader reads and works what Scarpe draws | EXT | | |

### X and M

X1 to X20 (Lacci and Webview defects) are one table. M1 to M40 (manual errata): M1 ERRATA, M2 MANUAL, M3 ERRATA, M4 ERRATA, M5 ERRATA, M6 ERRATA, M7 ERRATA, M8 ERRATA, M9 ERRATA, M10 MANUAL, M11 ERRATA, M12 ERRATA, M13 ERRATA, M14 MANUAL, M15 OOS, M16 ERRATA, M17 MANUAL, M18 S3, M19 ERRATA, M20 MANUAL, M21 S3, M22 MANUAL, M23 MANUAL, M24 MANUAL, M25 MANUAL, M26 MANUAL, M27 S3, M28 MANUAL, M29 BOTH, M30 MANUAL, M31 S3, M32 BOTH, M33 BOTH, M34 S3, M35 MANUAL, M36 OOS, M37 OOS, M38 ERRATA, M39 ERRATA, M40 ERRATA.

## A. App and window

### A1. Default window size and title

**Ruling: S3, ruled 27 Sep 2026 (Q1)** by the orchestrator; Nick may overrule. 600x500 and the title "Shoes". Shoes 3 and Shoes 4 agree; the manual is silent. **Lacci change, done 27 Sep 2026.**

- **Manual:** silent. Examples that care pass `width:`/`height:`.
- **Shoes 3:** `#define SHOES_APP_WIDTH 600`, `SHOES_APP_HEIGHT 500` (`s3_app.h:20-21`), applied at `s3_app.c:62-63, 176`. Title comes from `ATTR(attr, title)`, or the settings app name when built with `MTITLE` (`s3_app.c:144-154`).
- **Shoes 4:** `DEFAULT_OPTIONS = { width: 600, height: 500, title: "Shoes 4", resizable: true, border: true }` (`internal_app.rb:19-25`).
- **Examples:** 95 of the 350 examples in the target set pass a size (report 04, B3). The rest take the default; Scarpe's own examples were tuned at 480x420.
- **Lacci today:** `title: 'Shoes!', width: 480, height: 420` (`app.rb:42-49`). Since 27 Sep (`44dfc51`) the default lives once, on `Shoes::App`: 600x500, titled "Shoes".
- **Spec:** `app.style.width_height__default` asserts that an app with no size reports 600x500, and `app.style.title__default` that its title is "Shoes". Both pass since the Lacci lane moved its default (27 Sep). Cases about something else pin their own window size so they hold on either side of that change (`rules.negative_width` now opens at an explicit 600x500).
- **Native:** takes the App's `width`/`height` props, so it follows whatever Lacci defaults to; an App that sends none opens at 600x500 titled "Shoes" (`runtime.rs` `DEFAULT_SIZE`, DESIGN 6, 27 Sep).

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
- **Lacci today:** `App#window`/`#dialog` call `Shoes.app(**opts.merge(owner: self))` (`app.rb:577-585`). Top-level `Kernel#window` is `Shoes.app` without an owner (`builtins.rb:114-122`). Webview cannot open a second window at all (X6). Since 27 Sep `Shoes.app` returns the new App, so `window` and `dialog` return it too (`41a9811`, A9).
- **Spec:** `window { }` from a handler creates a second app; `Shoes.APPS.size == 2`; its `owner` is the first app; the first app's `owner` is nil.
- **Native:** declares `:multi_app` (DESIGN 5.1) and opens one OS window (or headless canvas) per App.

### A4. Live positions and sizes of apps, slots and elements

**Ruling: MANUAL.** Live pixels after layout and after the user resizes: `width` and `height` of apps, slots and elements, and `left` and `top` of slots and elements (extended to `left`/`top` on 27 Sep 2026, at the events and elements writers' request). **Lacci change, done 27 Sep 2026** (the getters), fed by wire contract (a) below.

- **Manual:** `width()` "returns an exact pixel size" (manual 2511-2513, 2723-2732); `left()` is "The left pixel location of the slot" and `top()` likewise (manual 2421-2423, 2507-2509; for elements 2644-2646, 2719-2721); `rect 10, 10, self.width - 20, self.height - 20` fills the box (manual 1757-1768).
- **Shoes 3:** `shoes_app_get_width` returns the live `app->width` (`s3_app.c:199-209`), updated on GTK `size-allocate` (`s3_gtk.c:736-750`).
- **Shoes 3, positions:** slots answer `left`/`top` from their placed canvas (`s3_ruby.c:748-749`).
- **Lacci today:** App `width`/`height` are static styles (`app.rb:19`); nothing feeds a resize back. Slot `width` falls back to the parent's style (`drawable.rb:649-716`): `stack(width: -100).width == 380` in a 480 app, `stack(width: "50%").width == 240`. `left` and `top` return the `left`/`top` styles: nil for an element its slot placed, 0 for a slot. Since 27 Sep (`32ebbf3`) the four getters read the rect the display pushed (contract a), rounded to whole pixels, unless the app gave a pixel number, which stays the answer so `el.left += 5` cannot drift through a stale layout; with no layout (Niente, Webview) sizes resolve the way `dim.rs` reads them. Since the wave-4 Lacci lane they widen that rect by the element's margins (its own, else a text block's 4 px and 12 below) and take any displacement back off `left` and `top`; `scroll_max` still measures against the rect inside the margins, where the slot scrolls.
- **Margins, ruled 27 Sep 2026: S3** (Nick may overrule). The getters report the element's box with its margins, as Shoes 3 reports its `place` (`place.x`, `place.y`, `place.w`, `place.h` in `PLACE_COMMON`, `s3_ruby.h:376-413`; a text block's `place.w` is its text plus both margins and `place.h` its lines plus 4 above and 12 below, `s3t_textblock.c:108-110, 207-212`). The manual is silent on margins, though its "full size of the element" (manual 2725) and its 100%-of-120 example (manual 2730-2732, which holds for a para only with its margins counted) read the same way. Since Q3 gave text blocks 4 px margins this moves a para's `left` and `top` 4 px out and adds 8 to its `width` and 16 to its `height`; controls and shapes have no margins unless given, so theirs do not move. A pixel size the app gave still comes back as given, which is also Shoes 3's number, since Shoes 3 fits the margins inside a pixel size. `left` and `top` also read as if the element and its slots were not displaced (manual 2623-2626, M9), though the display pushes where it painted.
- **Spec:** after `resize` to 300x200, `app.width == 300` and `app.height == 200`. A laid-out `stack(width: 0.5)` reports half its parent's inner width in pixels (see C1). `common.left` and `common.top` read the laid-out position of an element its slot placed; `slot.left`, `slot.top` and `slot.height__content` do the same for slots. `common.width__margins_included`: a para's getters are `layout_of` widened by its margins. `common.displace.coords_unchanged__in_flow`: a displaced button still reads its laid-out place.
- **Two frames, written down 28 Sep 2026 (wave 8).** `left` and `top` answer in two frames: a drawable the app placed answers the numbers it was given, from its slot's corner (Shoes 3's answer, `s3_ruby.h:376-399`, and what keeps `left += 5` from drifting), and one its slot flowed answers the laid-out rect, in window coordinates (Shoes 3 answers that from the slot's corner too). `docs/native.md` said only "window coordinates", so the Peekaboo Moles builder hit-tested a card's button by its `left` and `top` and missed, and Hackety Hack placed its lesson tips from a placed `left` less a flowed one (C18). The code is unchanged: `common.move__returns_self` pins the first half, `common.displace.coords_unchanged__in_flow` the second, and `slot.left__placed_in_a_placed_slot` both in one slot. Moving flowed drawables to the slot's corner, as Shoes 3 does, would close the gap, but Kanban's drag reads its cards' `left` and `top` against window coordinates, so that waits for a ruling.
- **Native:** reports resizes with the `resize` message; the shim sets `@width`/`@height` without a `prop_change` echo (DESIGN 4.2). **Wire contract (a), 27 Sep 2026:** after every layout pass, and before presenting, Rust sends `{"t":"layout","app":N,"rects":[[id,x,y,w,h,scroll_h],...]}` for the nodes whose rect changed (every node on an app's first layout), in window logical px as Floats; `scroll_h` is a slot's content height, else `h`. Destroyed ids are not sent again. The shim keeps `Shoes::DisplayService.layout_cache[id] = [x, y, w, h, scroll_h]` (Integer keys, a class-level Hash like `para_hit_cache`) and deletes ids on destroy. Lacci's `left`/`top`/`width`/`height` return the laid-out values when present and fall back to today's behaviour otherwise. App size still comes from `resize`. Built 27 Sep by the layout lane (Rust's push, rounded to 1/100 px, and the shim's `layout_cache`; DESIGN 4.2) and the Lacci lane (the getters).

### A5. Built-in dialogs with no app open

**Ruling: MANUAL.** Built-ins work anywhere, including before `Shoes.app`. **Needs fix 10.6.**

- **Manual:** `ask_color`, `ask_open_file` and `confirm` examples run before any `Shoes.app` (manual 651-655, 665-669, 714-716); built-ins are "usable anywhere" (manual 571-577).
- **Lacci today:** `Shoes::Builtins#shoes_builtin` treats a `nil` answer as "nobody handled it" and falls back to `osascript` for `ask`, `confirm` and the four file/folder dialogs (`builtins.rb:66-105`, macOS only). `alert` and `ask_color` have no fallback and return nil (X8).
- **Docs:** `docs/scarpe_shoes_incompatibilities.md:44-62, 109-118` says pre-app dialogs are unsupported. Partly stale.
- **Spec:** a script that calls `confirm` before `Shoes.app`, with the dialog stubbed, receives the stubbed value and never spawns `osascript`.
- **Native:** the shim must answer a `builtin` even when no App exists yet. DESIGN 5.2 spawns the child lazily on the first DocumentRoot, so a pre-app builtin has no child to ask. The shim should spawn the child on the first `builtin` too (or answer headless stubs), or Lacci pops a real macOS dialog. Since 27 Sep it does: `lib/scarpe/native.rb` subscribes to `builtin` at require time and switches Lacci's osascript fallback off, headless runs answer quietly, and a windowed dialog spawns the child when it asks (DESIGN 5.1, 5.2).

### A6. `Shoes.app("/start/url", styles)`

**Ruling: EXT** (Shoes 3). Low priority.

- **Shoes 3:** a leading String argument is the start URL (`s3_app.c:128-138`).
- **Lacci today:** keyword-only signature (`shoes.rb:138-147`); unknown keywords vanish into `**_extras`.
- **Spec:** nothing in `core`. **Native:** nothing; routing is Ruby-side.

### A7. App styles added in Shoes 3.3

**Ruling: OOS.** `fullscreen`, `decorated`, `hidden`, `menus`, `monitor` (`s3_app.c:155-168`). Lacci drops them through `**_extras`; `docs/scarpe_shoes_incompatibilities.md` lists `decoration`, `Shoes.settings` and `Shoes.monitor` as unsupported. The spec does not touch them.

### A8. `close` closes one window

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.** New row.

- **Manual:** "Closes the app window. If multiple windows are open and you want to close the entire application, use the built-in method `exit`." (manual 901-904).
- **Shoes 3:** not checked.
- **Lacci today:** `App#destroy` sends `destroy` with a **nil** target (`app.rb:280-283`), every App listens for nil-target `destroy` (`app.rb:109-113`), and `close` is an alias of `destroy` (`app.rb:287`). So `close` on any window closes every app. Since the wave-5 shim lane `close` is its own method: while another started app is open it leaves `Shoes.APPS` and sends `destroy` aimed at its own id; the last window's `close` is still `destroy`. Niente's App ends its loop on that aimed destroy.
- **Spec:** with two windows open, `close` on the second leaves the first open and `Shoes.APPS.size == 1` (`app.close`, `app.Shoes.APPS__closed_removed`, both passing on both displays; `app.close` watches destroys aimed at each app, and a nil-target one, which would mean every app quit).
- **Native:** the shim takes a `destroy` aimed at an App as that window closing: it sends `quit {app}`, so Rust frees the view and its document, and forgets the app's timers and drawables. A window the user closes while another is open goes the same way, and leaves `Shoes.APPS` too.

### A9. `Shoes.app`, `window` and `dialog` return the App

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.** New row, requested by the elements and app writers.

- **Manual:** `Shoes.app(styles) { ... } » Shoes::App` (manual 859); `window` and `dialog` return a `Shoes::App` too (manual 1958, 2135).
- **Shoes 3:** `shoes_app_window` ends `return app;` (`s3_app.c:186`); `Shoes.app` returns it (`:189-191`), and so do `window` and `dialog` (`s3_canvas.c:1387-1394`).
- **Lacci today:** `Shoes.app` ends `app.init; app.run; nil` (`lacci/lib/shoes.rb:192-194`), and `App#window`/`#dialog` return what `Shoes.app` returns (`app.rb:585-593`), so all three give nil. Since 27 Sep (`41a9811`) `Shoes.app` returns the App it made, and `window` and `dialog` with it.
- **Spec:** `app.shoes_app`, `element.window__returns_app`, `element.dialog__returns_app`: each returns a `Shoes::App`, the very one in `Shoes.APPS`.
- **Native:** nothing; the return value is Ruby-side.

### A10. `Shoes.app`, `window` and `dialog` take their styles as a Hash

**Ruling: S3.** **Lacci change, done 28 Sep 2026.** New row, from the Hackety Hack lane (w9).

- **Manual:** `Shoes.app(styles) { ... }` (manual 859-865), written for Ruby 1.8, where a Hash and keywords were one thing.
- **Shoes 3:** `Shoes.app` reads its argument as a Hash of styles.
- **Examples:** Ruby 1.9 programs build the styles first and pass them on: Hackety Hack's `lib/art/turtle.rb` calls `Shoes.app opts`, so its Fractal and both Turtle samples stopped at once.
- **Lacci until 28 Sep:** keywords only, so a Hash, which Ruby 3 hands over as a positional argument, raised `ArgumentError: wrong number of arguments (given 1, expected 0)`. Since 28 Sep `Shoes.app`, `window` and `dialog` take a Hash as well, and keywords given beside it win. Anything else still raises.
- **Spec:** `app.shoes_app__styles_hash`: styles built as a Hash open that window and run its block.
- **Native:** nothing.

## B. Blocks, `self` and slot manipulation

### B1. Slot blocks keep the caller's `self`

**Ruling: MANUAL.** **Lacci change, done 28 Sep 2026** (the w9 Hackety Hack lane), with one reading of our own for widgets, below.

- **Manual:** "The stack block ... does NOT change self" (manual 198); rule 2: blocks attached to stacks, flows or manipulation methods "do not change self. Instead, they pop the slot on to the app's editing stack" (manual 322-324).
- **Shoes 3:** slot blocks run with a plain `rb_funcall(block, s_call, 0)` inside `DRAW(...)` (`s3_canvas.c:650-653`, insert path `:713-729`); only `app { }` does an `instance_eval` (`:864-874`). Every canvas method is a `FUNC_M` redirect (`s3_ruby.h:195-229`): the App's always act on the top of the app's nesting stack, and a widget's do too whenever that stack is not empty (a widget is pushed while its `initialize` runs, `s3_canvas.c:835-846`). So a widget's `para` inside its own `stack do ... end` lands in the stack, and so does one inside another slot's `append`: Hackety Hack's turtle draws its pen swatch that way (`lib/art/turtle.rb`, `update_pen_info`).
- **Shoes 4:** slot blocks are called with `eval_block`, `self` unchanged (`s4_slot.rb`), and a widget sends what it lacks to its app (`s4_widget.rb`).
- **Lacci until 28 Sep:** `App#with_slot` did `instance_eval(&block)` on the App, used by Stack, Flow, Mask, Shape and image canvases. `append`/`prepend` special-cased non-Drawable callers with `block.call` plus an "external self" fallback on the App. Inside a `Shoes::Widget#initialize`, `stack { self }` was the App and the widget's `@label` was nil. Hackety Hack's editor failed at `editor.rb:90` (`undefined method 'name' for nil`): its `stack do @code_editor.name ... end` read the App's ivar.
- **Lacci since 28 Sep:** `with_slot` pushes the slot and calls the block, which keeps its self. Only the app block (`init`), `window`, `dialog` and `app { }` are `instance_eval`'d on the App, the blocks the manual says change self (manual 318-321). The external-self fallback is gone: a plain object's own methods are in reach because self is the object. `start` and `finish` blocks keep their self too, where they ran on the App (H8). A widget sends its DSL calls (drawables, `background`, events, timers, pens, `start`, `finish`) to the slot being built while a slot block runs (`Widget#dsl_target`), unless that slot holds the widget: a call made from the slot around the widget, or between events, lands in the widget itself. Shoes 3 would send a call made during the app block to the app's top slot instead; nothing found depends on that. What a widget lacks and the App has (`move_to`, `line_to`, `mouse`, `window`, `visit`) goes to the App, as in Shoes 4. Slot manipulation (`clear`, `append`, `contents`) is never redirected.
- **Examples:** identical inside a plain `Shoes.app` block, where `self` is the App either way. Lacci's own turtle leaned on the old behaviour in `update_pen_info` and now calls the slot's own `background` by its other name, as Hackety Hack's turtle does. `skip_ci/guitar_fretboard.rb` (skipped, it needs the bloops gem) calls `app.flow do flow ... end` from a plain class, and now raises `NoMethodError` as it would in Shoes 3 and 4. `expert/tooltips.rb`'s `start { @menu.show }` inside a widget method now reads the widget's `@menu`. On 28 Sep every example that loaded before still loads on both displays (453 examples: niente 356, native 340).
- **Spec:** `rules.blocks.stack_block_keeps_self__in_widget` (no longer `expect: fail`): inside a widget's stack block `self` is the widget, `@tag` is the widget's, and the para is a child of the stack. `rules.blocks.stack_block_keeps_self__plain_object`: a class shaped like Hackety Hack's side tabs keeps its self and ivars through `append`, `flow` and `stack` blocks. `lacci/test/test_block_self.rb` checks the redirects, a widget reaching App methods, a widget method drawing into another slot, and that `app { }` still changes self.
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

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.** New row.

- **Manual:** slot `remove`: "It will no longer be displayed and will not be listed in its parent's contents. It's gone." (manual 2430-2433); `finish` fires "When a slot is removed" and is handed `self` (manual 2195-2198).
- **Shoes 3:** `finish` receives the slot (`s3_canvas.c:1030-1036`).
- **Lacci today:** `alias_method :remove, :destroy` sits on `Drawable` (`drawable.rb:615`), so `slot.remove` binds `Drawable#destroy` and skips `Slot#destroy` (`slot.rb:231-235`), which is the method that cascades to children and fires `finish`. Only the slot's own `destroy` is sent (report 01, 2b, probed). Since 27 Sep (`64e1ca6`) `remove` calls `destroy` by name, so a removed slot clears its children, fires `finish` and returns self (X15).
- **Spec:** `slot.remove` fires the slot's `finish` block with the slot, and none of its children can be found afterwards.
- **Native:** `destroy` removes the whole subtree already (DESIGN 4.1), so the pixels were right before Lacci's fix; until 27 Sep the Lacci-side children leaked and `finish` was lost.

### B6. Methods headed `» self` return `self`

**Ruling: MANUAL** (Shoes 3 agrees). **Lacci change, done 27 Sep 2026.** New row, requested by the events, elements and art writers; it covers the `hide`/`show`/`toggle` request too.

- **Manual:** every heading below ends `» self` (manual 1676-1862, 2187-2360, 2417-2503, 2639-2715, 3419-3430).
- **Shoes 3:** `append`, `prepend`, `before`, `after` (`s3_canvas.c:731-757`), `toggle` (`:924-932`) and every slot event method (`EVENT_HANDLER`, `:934-944`) end `return self`; so do `hide`/`show` (`s3t_native.c:232-248`) and the timers' `start`/`stop`/`toggle` (`s3t_timerbase.c:93-121`). The draw-context methods are generated by a macro whose bodies are not in the fetched files.
- **Shoes 4:** `nofill`, `nostroke` and `translate` return the App (`s4_dsl_style.rb:57-80`); the timers' `start`/`stop`/`toggle` return the new flag (`s4_animation.rb:27-41`).
- **Lacci today:**

  | Method | Returns | Where |
  |---|---|---|
  | slot `append`, `prepend` | the block's last value | `drawables/slot.rb:292-312` |
  | slot `clear`, `clear { }` | nil | `drawables/slot.rb:263-274` |
  | `hide`, `show`, `toggle` (slots and elements) | the new `hidden` value | `drawable.rb:739-751` |
  | slot `click`, `hover`, `leave`, `motion`, `release`, `keypress` | the new SubscriptionItem | `app.rb:414-422` |
  | slot `finish` | its Array of callbacks | `drawables/slot.rb:213-216` |
  | timer `start`, `stop`, `toggle` | the new `stopped` value | `drawables/subscription_item.rb:97-109` |
  | `nofill`, `nostroke`, `strokewidth`, `rotate` | the value stored in the draw context | `drawables/slot.rb:135-172` |
  | `cap`, `translate` | nil (no-op stubs) | `app.rb:565-582` |
  | `move`, `displace`, `remove`, `before`, `after` | self (already right) | |

  Since 27 Sep (`bedd0e6`, `5cd2ed1`) every method in the table returns self, `cap` and `translate` included; `animate`, `every` and `timer` still return the timer, so it can be stopped.

- **Spec:** one `__returns_self` case per method: `events.{click,hover,leave,motion,release,keypress,finish}__returns_self`, `manip.{append,prepend,clear,clear_with_block}__returns_self`, `slot.{hide,show,toggle}__returns_self`, `common.{hide,show,toggle}__returns_self`, `timers.{start,stop,toggle}__returns_self`, `art.{nofill,nostroke,rotate}__returns_self` (rotate also sits under E10). Each checks the result with `assert_same` against the receiver.
- **Native:** nothing; the return values are Ruby-side.

### B7. `clear` and the timers a slot started

**Ruling: S3, ruled 27 Sep 2026 (Q8)** by the orchestrator; Nick may overrule. `clear` empties the slot's contents and keeps the timers the slot started, as Shoes 3 does and ten examples need. The manual's "any elements, timers and nested slots" (manual 2327-2329) is **ERRATA** (M40). `visit` still starts the new page from nothing, timers included. New row, found at the 27 Sep 2026 merge of the build lanes.

- **Manual:** `clear()` "Empties the slot of any elements, timers and nested slots. This is effectively identical to looping through the contents of the slot and calling each element's `remove` method." (manual 2327-2329).
- **Shoes 3:** `animate`, `every` and `timer` push their timer onto `app->extras`, not onto the slot's contents (`s3t_timerbase.c:132, 143, 154`). The `clear` method empties with `shoes_canvas_empty(canvas, FALSE)` (`s3_canvas.c:759-781`), which removes the contents and leaves the extras alone (`:273-279`). Only the full canvas reset passes TRUE, which removes the timers whose parent is that canvas (`s3_canvas.c:282-295`, `s3_ruby.c:581-593`). So a timer survives `clear`.
- **Examples:** ten clear the app from inside its own `animate` and need the timer to keep ticking: `for_playtest/simple/arc.rb` and `follow.rb`, `working/simple/clock.rb`, `shoes-contrib/animation/rotating-star.rb`, `flowers.rb`, `happy-trails.rb`, `pink-bubbles.rb` and `mice-satellites.rb`, `shoes-contrib/good/good-arc.rb`, and `shoes-dep-samples/expert-game-of-life.rb`.
- **Lacci today:** since 27 Sep (the Lacci lane, for H9) `clear` keeps the slot's SubscriptionItems, handlers and timers alike; `visit` still removes everything. Before that `clear` destroyed them, and `mice-satellites.rb` stopped after one frame.
- **Shoes 3, visit:** `shoes_app_visit` calls `shoes_app_clear`, which removes the app's extras and resets the whole canvas (`s3_app.c:93-101, 524-533`), so a page's timers stop when the app visits another.
- **Spec:** `manip.clear.stops_timers` (the inventory id; the case asserts the ruling): a timer started inside a stack keeps ticking after the stack is cleared. `app.visit__stops_timers`: the first page's timer stops once the app visits another page. Both run on native, where the pump fires timers.
- **Native:** the Ruby pump owns timers (DESIGN 5.4) and follows Lacci.
- **Before the ruling:** the case asserted the manual and was `expect: fail` from the merge until Q8 was ruled. MANUAL would have needed Lacci to stop the timers a slot started when it is cleared, which stops every one of the ten examples above after its first frame.

## C. Layout and dimensions

### C1. A Float dimension is a fraction of the parent

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026** (getter only).

- **Manual:** a decimal width or height is a percentage, "0.0 being 0% and 1.0 being 100%" (manual 1239-1245, 1539-1545); `button "All of it", width: 1.0, height: 1.0` (manual 2702).
- **Shoes 3:** `shoes_px`: any Float is `parent * f`, a String ending in `%` is a fraction, other Strings go through `to_i` (so `"10px"` is 10), a negative Integer is `parent - |n|` (`s3_ruby.c:298-319`). Floats of 1.0 and above are fractions too.
- **Lacci today:** `compute_dimension` handles `"N%"` and negatives but returns Floats unchanged (`drawable.rb:681-700`): `stack(width: 0.5).width == 0.5`. Calzini turns a Float into `"50.0%"` (`calzini.rb:102-115`), so only the Ruby getter is wrong. Since 27 Sep (`32ebbf3`) the getter reads the laid-out size when the display pushes one, and otherwise treats a Float in (0, 1] as a fraction of the parent, as `dim.rs` does.
- **Spec:** a laid-out `stack(width: 0.5)` reports half its parent's inner width in pixels; `button width: 1.0` spans its slot.
- **Native:** DESIGN 6.
- **DESIGN conflict (small), resolved 27 Sep:** DESIGN 6 said "Float between 0 and 1 exclusive = fraction ... (1.0 = 100%)", which contradicted itself. It now states what `dim.rs` does: a Float in (0, 1] is a fraction and a Float above 1 is px, where Shoes 3 treats every Float as a fraction, including 1.5. The manual's claims (0.5, 1.0) hold either way.

### C2. `style[:width]` returns what was asked for

**Ruling: MANUAL.** Concordant. Manual 2470-2487, 2691-2707; Lacci `shoes_style_values` returns the raw values (`drawable.rb:503-535`). **Spec:** `stack(width: 0.5).style[:width] == 0.5`, `style[:width] == "100%"` when given `"100%"`. **Native:** nothing.

### C3. Forms of `:margin`

**Ruling: MANUAL,** plus Shoes 3's tolerance of short arrays. Hash and String forms are **EXT**. **Lacci change, unscheduled.**

- **Manual:** a number, or "an array of four numbers in the form `[left, top, right, bottom]`" (manual 1298-1309). `margin: 0.1` is used as a fraction (manual 3250; see M10).
- **Shoes 3:** `ATTR_MARGINS` reads array entries 0 to 3; a missing entry falls back to the element's default margin (0 for slots, 4 for text blocks), and every entry goes through `shoes_px`, so Floats are fractions (`s3_ruby.h:147-165`).
- **Lacci today:** `MarginHelper#margin_parse` accepts a number, a Hash, a String `"1 2 3 4"`, and 1- or 4-element arrays; **2- and 3-element arrays raise `InvalidAttributeValueError`** (`margin_helper.rb:45-51`).
- **Also today:** `margin_parse` expands `margin` into the four sides and then clears it, so `stack(margin: 10).margin` reads nil (`slot.style_getter_methods__margin`, from the events writer). Since the wave-4 Lacci lane it keeps `margin` as given beside the four sides, so the getter reads 10 and the wire carries both; displays read the sides over it, so nothing moves, except that a text block given a partial Hash margin now gets 4 px below instead of 12, as Shoes 3's "margin or margin_bottom given" rule says (C9).
- **Spec:** `margin: [10, 20]` is accepted: left 10, top 20, right and bottom default. `margin: 0.1` in a 400-wide parent gives 40 px left and right.
- **Native:** DESIGN 6 reads arrays as `[left, top, right, bottom]`; missing entries use the default margin.

### C4. Default sizes of native controls

**Ruling: MANUAL.**

- **Manual:** edit_box "200 pixels by 108 pixels" (manual 3006); edit_line "200 pixels wide and 28 pixels wide. Roughly." (manual 3063, see M6); list_box "about 200 pixels wide and 28 pixels high" (manual 3183); progress "200 pixels wide" (manual 3245).
- **Lacci today:** no defaults; Calzini emits no width (`calzini/misc.rb:15-37, 65-86, 113-128`), so browser defaults apply.
- **Spec:** unstyled edit_box 200x108, edit_line 200 wide, list_box 200 wide, progress 200 wide (±2 px). Heights other than edit_box: 28 ±6.
- **Native:** edit_line 200x28, edit_box 200x108, list_box 200x28, progress 200x14 (DESIGN 6). DESIGN 6 and the Rust sizes said 160 for list_box and progress until 27 Sep.

### C5. Slot and element methods Lacci is missing

**Ruling: MANUAL.** Alias Image `path` to `url`. **Lacci change, done 27 Sep 2026.**

- **Manual:** `before(el) { }`, `after(el) { }` (manual 2315-2323); `scroll_height`, `scroll_max` (manual 2440-2453); `Image#path`, `path=`, `full_width`, `full_height` (manual 3143-3164); `location` (manual 980-982); `started?` (manual 1006-1010); `imagesize` (manual 2017-2023); `gutter` on slots (manual 2394-2410).
- **Shoes 3:** `before`/`after` exist (`s3_canvas.c:731-743`); `started?` is `shoes_app_is_started` (`s3_ruby.c:791`).
- **Examples:** `before` in 5 files, `after` 4, `scroll_max` 1, `location` 3.
- **Lacci today:** none of `before`, `after`, `scroll_max`, `scroll_height`, `location`, `started?`, `imagesize` exist; Image uses a `url` style (`image.rb:5`); `gutter` is App-only and a constant 28 (`app.rb:551-553`). Since 27 Sep slots have `scroll_height`, `scroll_max` and a `gutter` of their own (`32ebbf3`), and apps `location` and `started?` (`8e5a4cf`); `before` and `after` came with fix 10.3 (`e75b5a0`). Since the wave-4 Lacci lane Image has `path` (its `url`), `path=` (swaps the picture), `full_width` and `full_height` (read from the file with FastImage, as `Image#size` already was), and `imagesize(path)` is a built-in. FastImage is a gem, and `scarpe package --native` ships none, so those four raise `LoadError` in a packaged app.
- **Spec:** each method exists and returns a plausible value (for example `scroll_max == scroll_height - height` on a scrolling stack with overflowing content).
- **Native:** `scroll_height` and `scroll_max` need the content height from Rust. Wire contract (a) (see A4) carries it as each slot's `scroll_h`, which Rust pushes after every layout pass since 27 Sep (DESIGN 4.2) and the shim keeps in `Shoes::DisplayService.layout_cache`: Lacci reads `scroll_height = scroll_h` and `scroll_max = max(0, scroll_h - h)` from it.
- **Flows, 28 Sep 2026 (w9):** only Stack had `scroll_top` and `scroll_top=`; a flow's `scroll_top` was its raw style, nil until set, so Hackety Hack's editor, which scrolls a flow, compared a number with nil on its first key. Both now live on every slot. **Spec:** `slot.scroll_top__flow` (native).

### C6. The window scrolls, and `gutter` says by how much

**Ruling: MANUAL.** New row.

- **Manual:** "vertical scrolling has really become the only overflow that matters ... width is generally fixed. While height goes on and on" (manual 1584-1587); "The Shoes window itself is a flow" (manual 1621); `gutter` is "The size of the scrollbar area" (manual 2394-2399).
- **Shoes 3:** the app's top slot scrolls 32 px per wheel notch whenever it has a vertical scrollbar (`s3_app.c:743`, `s3_canvas.c:1231-1236`).
- **Lacci / WV today:** WV sets `body { overflow: hidden }`, so content past the window is clipped unless it sits in a `scroll: true` slot (report 02, section 2). `gutter` is 28 (`app.rb:551-553`).
- **Spec:** an app with content taller than its window scrolls on `wheel`, and the bottom element becomes visible. `gutter` returns an Integer of at least 0.
- **Native:** DESIGN 6: the root scrolls vertically with a thin overlay scrollbar. The overlay should be no wider than `gutter`, so the manual's `margin_right: 20 + gutter` idiom keeps text clear of it.

### C7. Text blocks side by side in a flow read as one paragraph

**Ruling: MANUAL, ruled 27 Sep 2026 (Q2)** by the orchestrator; Nick may overrule. Text blocks side by side in a flow continue as one paragraph: a text block placed after other inline content starts at the current x (a first-line indent), and its later lines wrap back to the flow's left edge (manual 1610-1612, Shoes 3). **Native change**, landed 27 Sep by the layout lane. New row.

- **Manual:** "Text elements placed next to each other will appear as a single paragraph. Images and widgets will run together as a series." (manual 1610-1612). The window is a flow (manual 1621).
- **Shoes 3:** a text block with no width takes the remaining width of the current line (`s3t_textblock.c:125`). If it starts mid-line, it moves to the flow's left edge with a first-line indent equal to the space already used (`:134-145`), so its first line continues where the previous text ended and later lines wrap back to the left edge. Afterwards the cursor sits at the end of its last line (`:217-228`), so the next element continues from there. In a stack the cursor returns to the left edge (`:235-237`).
- **Examples:** every app that puts two `para`s at the top level relies on this, since the top slot is a flow. Single-line paras look the same under every model. Multi-line paras differ.
- **Lacci / WV today:** each para is its own flex item: shrink-to-fit, packed side by side, and a long para wraps onto a new row as its own box (report 02, 4.1).
- **Spec:** two single-line paras in a flow share a row (`slots.flow.adjacent_text_one_paragraph`, all models agree). The multi-line case is `slots.flow.adjacent_text_one_paragraph__wraps_to_left_edge`: the second para carries on from the end of the first, on the same line, and its later lines wrap back to the flow's left edge, 4 px in for the para's margin (C9). It passes on native since the layout lane landed the paragraph model. Many style cases put one para alone in a flow and read `layout_of(para).w` as the text's width. That matches Shoes 3, where a one-line text block shrinks to its line (`s3t_textblock.c:207-210`), so a single-line para's box stays as wide as its text under the paragraph model.
- **Native:** since 27 Sep, as Shoes 3 (DESIGN 6): text that fits on the rest of the line sits there; longer text indents its first line to where the line stands and wraps the rest to the left edge, and the next element carries on from its last line. Two paras sit one margin apart. Where Shoes 3 would wrap lines under something taller earlier on the line (a picture, a title), or not even the first word fits, the text starts a new row instead. Centred, right-aligned, justified, trimmed and sized text stays a box. Since wave 4 a text that ends in a newline ends its line: Pango keeps an empty last line under it ("newlines have an empty size", `s3t_textblock.c:217-228`), so the next element starts the following line at the flow's left edge. The manual's radio example relies on it (manual 3285-3289, `radio; para strong(...), "...\n"`), as do 11 example files in all; before, the radios ran on after the text. Since 28 Sep (the w9 integrate lane) a text with a width of its own, or trimmed, that is too wide as a box for the rest of the line but whose text fits there on one line, inside its own width after what came before, sits on that line as wide as its text, and what follows carries on after it: Shoes 3 starts a sized text block at the left edge with its first line indented past what came before (`s3t_textblock.c:125-145`) and shrinks one line to its text (`:207-210`). Hackety Hack's program and lesson lists put each name (280 px, trimmed) beside its 16 px icon this way; as a box it took a row under the icon. A sized box that fits beside keeps its own width, and sized text that wraps is still a box. **Test:** `layout::tests::a_sized_line_too_wide_as_a_box_still_sits_beside_what_came_before`.

### C8. Default width of a slot

**Ruling: S3.** New row. Corrected 27 Sep 2026 by the layout lane: the Shoes 3 source gives an unsized slot its parent's whole width, not the rest of the line.

- **Manual:** "A stack is also shaped like a box. So if a stack is given a width of 250, that stack is itself an element which is 250 pixels wide." (manual 1602-1603). Silent on the default.
- **Shoes 3:** a slot reflows with `shoes_place_decide(..., dw = parent->place.iw, ...)` (`s3_canvas.c:468`), so its default width is the parent's whole inner width; a slot that no longer fits at the cursor moves to a new line (`s3_ruby.c:505-532`). So in a flow an unsized slot after anything else starts a row. (Report 02, 4.1 said "the remaining width of the current line"; the source says otherwise.)
- **Shoes 4:** `self.width ||= 1.0` (`s4_slot.rb:48`), then a flow moves what does not fit to the next line (`s4_slot.rb:322-326, 375-381`).
- **Lacci / WV today:** Lacci's getter says "Slots without explicit width should fill their parent (Shoes3 behavior)" (`drawable.rb:649-655`); WV makes a stack in a flow shrink-to-fit (measured 65 px for "stack in flow") and a stack in a stack full width; Flow defaults to `"100%"` (`flow.rb:9`).
- **Spec:** in a flow, an unsized stack after a 100 px one is as wide as the flow and starts a new row (`slot.width__in_flow`).
- **Native:** since 27 Sep stacks, flows and widgets default to the parent's width (DESIGN 6); before, stacks and widgets took the rest of the line.

### C9. Default margins of text blocks

**Ruling: S3, ruled 27 Sep 2026 (Q3)** by the orchestrator; Nick may overrule. Text blocks get Shoes 3's default margins: 4 px on every side, and 12 px below when neither `margin` nor `margin_bottom` is given. An explicit `margin: 0` gives none. New row.

- **Manual:** silent.
- **Shoes 3:** text blocks default to a 4 px margin on every side (`ATTR_MARGINS(self_t->attr, 4, canvas)`), and the bottom margin becomes 12 px when neither `margin` nor `margin_bottom` is given (`s3t_textblock.c:108-110`). A second adjustment at `:239-240` sets the bottom margin to the last line's height after placement (not traced further).
- **Examples:** Shoes 3 examples were written against the spacing; Scarpe-authored examples were written against WV's zero margins.
- **Lacci / WV today:** `p { margin: 0 }` (`calzini.rb:56-87`). Paras stack with no gap.
- **Spec:** `styles.margin__text_default` (native): a para in a stack sits 4 px in and 4 px down from the stack's corner, and the next para starts 12 + 4 px below it. `core` also asserts that an explicit `margin: 0` gives no gap. Cases that measure a text block against a slot edge for another reason allow for the 4 px margins in their assertions (`styles.align.left`, `.center`, `.right`, `styles.attach.nil_resets`, and the C7 wraps case), and `rules.fixed_height_scrollbar__needs_height` opens a window tall enough for its ten margined paras.
- **Native:** since 27 Sep text blocks default to 4 px margins, 12 px below unless `margin` or `margin_bottom` is given, and a short `margin` array keeps the default for the sides it leaves out (DESIGN 6, C3). Lacci sends `margin: 0` as four explicit `margin_*: 0` props, so "given" and "not given" differ on the wire.

### C10. `:right` and `:bottom`

**Ruling: MANUAL.** New row.

- **Manual:** `right: 0` aligns the element's right edge with its slot's right edge; `right: 20` puts it 20 px in (manual 1356-1364). `bottom` is the same for the lower edge (manual 1100-1106).
- **Shoes 3:** `shoes_px2` computes `(parent - dr) - px` when the right/bottom key is present (`s3_ruby.c:327-337`); art shapes read `right`/`bottom` as absolute coordinates instead (`s3_ruby.c:396-399`, see E6).
- **Lacci / WV today:** declared as styles (`drawable.rb:264`) and never rendered (report 02, 4.2).
- **Spec:** `background black, width: 50, right: 50` paints the manual's "fifty pixel column on the right-side", its left edge 51 px in from the window's right edge: a background or border with a size of its own is measured from the far edge by its pattern's size, 1 px for a colour or gradient, as Shoes 3 places it (M19, since 28 Sep 2026).
- **Native:** an element with `right` or `bottom` is out of flow and placed from the slot's right or bottom edge; backgrounds and borders too (DESIGN 6 and 12, 27 Sep). Art follows the same ruling since wave 4 (DESIGN 12): its far edge sits `right` px in from the slot's right edge, art that names both edges and no size runs between them, and `left`/`top` win when given; Shoes 3 instead read them on art as absolute far-edge coordinates that size the shape (`s3_ruby.c:396-399`), and no example uses either. **Lacci** gave art no way to reach this until wave 5: `rect` defaulted `left` and `top` to 0 and every art class required `left`, `top` and a size (`rect.rb:18-21`, `oval.rb`, `drawable.rb:343-349`), so `right`/`bottom` arrived only beside a `left` that won. Now `right` stands in for `left` and `bottom` for `top` on art, and naming both edges of an axis stands in for the size along it (`Shoes::Art.placed_by_edges`); an oval still defaults to a circle unless it spans both edges of an axis. **Lacci change, done 27 Sep 2026.** **Spec:** `styles.right__art` (native) places a rect, an oval and a star by their far edges and stretches a rect between both edges.
- **Negative `right` and `bottom`, 28 Sep 2026 (w9):** Shoes 3 reads a position as a plain number, negative ones too: `shoes_px2` passes `nv` 0 to `shoes_px` (`s3_ruby.c:298-337`), so `bottom: -3` hangs an element 3 px below its slot's lower edge. Native read a negative `right` or `bottom` by the dimension rule, as the slot less that much, so Hackety Hack's editor button bar (`stack height: 40, width: 182, bottom: -3, right: 0`) landed at y = -37, above the window. Now a negative `right` or `bottom` on an element, a background or a border lies past the slot's edge, and a Float up to 1 or a percentage is still a share of the slot, a negative share past the edge too (`style::dim::position`). Since the w10 lane `left` and `top` follow the same rule on every element (C18, Nick's ruling of Q10). **Spec:** `styles.bottom__negative` (native).
- **A slot with no height, 28 Sep 2026 (w9 polish):** Shoes 3 places a canvas it has not drawn yet with the margins as its height (`dh += tmargin + bmargin` when `dh` is 0, then `th = place->h`, `s3_ruby.c:434-436, 511-525`), so `stack :bottom => 26, :margin => 4` has its top 26 px plus its margins above the slot's foot and its contents below that. Hackety Hack's bottom side tabs (Prefs and Quit, `stack pos => pixelpos, :margin => 4`, `app/ui/tabs/sidetabs.rb`) sat 24 px higher on native than in the Mac 1.0 and Ubuntu 1.0.1 screenshots (icons at 473 and 499 against 497 and 523), and so did their tips. Now a slot with no `height` placed by `bottom` is measured by its margins alone; one with a height, and every other element, stands on the line as before. No example places a slot with no height by `bottom`. **Test:** `layout::tests::a_slot_with_no_height_placed_by_bottom_is_measured_by_its_margins`.

### C11. `attach: Window`

**Ruling: MANUAL.** Attaching to the mouse is **EXT**. New row.

- **Manual:** `attach: Window` positions the slot in the window's coordinates; attaching to an element makes the slot follow it; `nil` returns it to the flow (manual 1081-1091).
- **Shoes 3:** `attach` of `Window` is window-relative, `Mouse` is cursor-relative, anything else is sticky to that element (`s3_ruby.c:440-447, 459-465`).
- **Lacci / WV today:** Lacci defines `Window = Shoes::App` (`lacci/lib/shoes.rb:52`), which stringifies to `"Shoes::App"`, and WV matches only `/window/i`, so `attach: Window` does nothing (report 02, 4.3).
- **Spec:** `stack top: 10, left: 10, attach: Window` inside a nested, scrolled slot lands at window point (10, 10).
- **Native:** DESIGN 5.3 turns `attach: Shoes::App` into `"window"` and DESIGN 6 places it in window coordinates. Attaching to a drawable id is in the wire format; since 27 Sep DESIGN 6 writes down what the layout does with it: the element is placed from that drawable's top-left corner, with the window's size as its frame.

### C12. Paint order: backgrounds are layered elements

**Ruling: MANUAL.** New row.

- **Manual:** "Backgrounds are actual elements, not styles" (manual 1905); "Shoes layers background elements" (manual 1907); borders likewise (manual 1933).
- **Lacci / WV today:** backgrounds and borders are `position:absolute` divs, and CSS paints positioned boxes after in-flow ones, so a background covers every para and button in its slot regardless of order (report 02, 4.4, screenshots p1 and p3).
- **Spec:** a para declared after a background shows its text colour at a pixel inside a glyph. Nothing about a background declared after the text; Shoes 3's order in that case is not checked.
- **Native:** DESIGN 6 paints in tree order. No conflict.

### C13. A fixed height clips the slot

**Ruling: MANUAL.** New row, requested by the app writer and the integration lane.

- **Manual:** "fixed heights actually force slots to behave differently. To be sure that the end of the slot is chopped off perfectly, the slot becomes a 'nested window'" (manual 345-352); only nested-window slots can have scrollbars (manual 354-355).
- **Shoes 3:** a slot with a `height` (or `scroll: true`) gets its own native surface when it is created (`s3_canvas.c:1316-1324`), which clips its drawing.
- **Examples:** the accordions (`philippe_checked/accordion.rb`, `shoes-contrib/simple/simple-accordion.rb`) animate a fixed height to fold pages away; without clipping, the folded pages' text spills over the open one and still takes clicks.
- **Lacci / WV today:** WV does not clip a fixed-height slot unless it scrolls.
- **Spec:** `rules.fixed_height_clips`: a stack 100 px high holding a 300 px red stack shows red inside its height and not below it.
- **Native:** since 27 Sep every slot with a fixed `height` clips what it holds, with or without `scroll: true`, and hit-testing respects the clip (DESIGN 6); `rules.fixed_height_clips` passes on native. Before, DESIGN 6 clipped only with `scroll: true`.

### C14. An explicit width or height includes the margins

**Ruling: S3, ruled 27 Sep 2026 (Q9)** by the orchestrator; Nick may overrule. A px `width` or `height` is the margin box, margins inside it, as relative sizes already are. New row, found by the wave 4 native lane looking at example snapshots.

- **Manual:** silent. `:margin` "space[s] an element out from its surroundings" (manual 1298-1309); `:width` says nothing of margins.
- **Shoes 3:** a given `width` is the margin box: `place->w = PX(attr, width, ...)`, then the content is `place->iw = place->w - (lmargin + rmargin)` and likewise `ih` for `height` (`s3_ruby.c:506, 537, 540`). Slots are placed that way (`s3_canvas.c:468`), and text blocks too (`s3t_textblock.c:125-126`): `para "x", width: 200` wraps its text at 192, inside Shoes 3's 4 px text margins (C9).
- **Examples:** `legacy/for_playtest/simple/menu1.rb` sets four panels of 170, 140, 140 and 140 px with `margin: 4` in a 600 px window; they fit on one row only if the margins are inside the widths (590 px against 622). `shoes-contrib/simple/simple-control-sizes.rb` is Shoes 3's own check that controls "size appropriately despite the platform": it stacks controls such as `button ..., margin: 2, height: 30` against a 30 px grid, and they keep to the grid only if each height holds its margins (here that button takes 34 px). 39 lines under `examples/` give an element both a px width and a margin; 17 manual cases do.
- **Lacci / WV today:** Webview writes CSS `margin`, which always sits outside a CSS `width` (`calzini.rb:148-151`).
- **Native:** since wave 5 (27 Sep 2026), every width or height the app gives, px or relative, sizes the margin box (`layout::sized`, DESIGN 12), so menu1's four panels share its 600 px row. Before, a px size was the border box with margins outside it, and menu1's fourth panel wrapped below the window.
- **Spec:** `styles.margin__inside_width`: `stack width: 100, margin: 10` takes 100 px of its flow's row, with an 80 px box inside its margins, and its `width` reads 100. `styles.height.pixels__margin_box`: `button "OK", height: 30, margin: 2` is 26 px tall and what follows starts 30 px down, the grid `simple-control-sizes.rb` checks. `border.box_size_constant` checks the margins sit inside the fifty pixels.
- **Lacci:** nothing to change: the getters already report a px size as given (A4), which is the margin box under this ruling.

### C15. A negative `left` or `top` on art is a plain coordinate

**Ruling: S3, ruled 27 Sep 2026** by the orchestrator; Nick may overrule. `oval -30, 50, 100` sits 30 px left of its slot, so art can be drawn, or animated, off the left or top edge. Negative sizes keep the dimension rule (DESIGN 6). A negative `left` or `top` on anything that is not art kept it too until 28 Sep 2026, when Nick ruled Q10 and every element read it this way (C18). New row, found by the wave 4 showcase lane.

- **Manual:** silent on negative coordinates. `:left` "places the object's left edge ten pixels away from the left edge of the slot" (manual 1288-1294).
- **Shoes 3:** `shoes_place_exact` reads art's `left` and `top` as they are: `place->x = ATTR2(int, attr, left, 0) + ox` (`s3_ruby.c:385-392`), with no far-edge reading for negatives.
- **Examples:** the showcase's starfield wraps its stars with `%` to avoid the far-edge jump; any shape animated off the left or top edge jumped to the far side.
- **Lacci today:** passes the number through. Oval, arc and arrow declare clamping validators for `left`, `top`, `width` and `height`, but none of them runs: `validate_as` takes the base Drawable's declaration of those names first, so `Shoes::Oval.validate_as(:left, -30)` is -30.
- **Spec:** `styles.left__art_negative` (both displays): an oval, arc, arrow and rect keep a negative `left` and `top` as given. `styles.left__art_negative__drawn` (native): `oval -30, 50, 100` has its box at x = -30 and shows its right half at the window's left edge.
- **Native:** since wave 5 (`b52957b`, `shapes::coordinate`) art's `left` and `top`, a line's ends and a shape block's origin read a negative number as a plain coordinate: the example above lays out at `#3 Oval -30,50`. Before, it read as that far in from the slot's far edge (`#3 Oval 270,50`), the dimension rule every other element keeps. Fractions and percentages stay relative to the slot.
- **Extended 28 Sep 2026 (wave 6), ruling MANUAL for Floats:** every number on art is pixels, Floats between 0 and 1 included, and a size too (`width`, `height`); only a percentage String is of the slot, and a negative size keeps the dimension rule. The manual draws an oval "at pixel coordinates (left, top)" with a width "of `radius` pixels" (manual 1716-1722), and Shoes 3 reads every art number as whole pixels (`shoes_place_exact`, `ATTR2(int, ...)`, `s3_ruby.c:385-392`). Two of the four wave-6 app lanes met the fraction reading on their own: Weather Window's rain streaks stretched across the glass whenever a drop passed x = 0.5, Aquarium's kelp drew a chevron into the castle, and a star of diameter 0.8 filled 80% of the slot; both apps carried a `px` helper to keep art off (0, 1]. C1 still rules every other element: `stack(width: 0.5)` is half its parent. **Spec:** `art.oval.positional__float_pixels` (native). **Native:** `shapes::coordinate` and `shapes::size`; `oval 0.5, 0.5, 12, center: true` lays out at (-5.5, -5.5), where it read (144, 94).

### C16. A slot with no height reaches down to its row's bottom in a flow

**Ruling: S3.** **Native change, done 28 Sep 2026** (the w9 polish lane). New row, from Hackety Hack.

- **Manual:** silent on how tall a slot with no height is beyond "height goes on and on" (manual 1584-1587).
- **Shoes 3:** a slot drawn on its parent's surface ends its draw with `self_t->fully = canvas->endy = max(canvas->endy, self_t->endy + bmargin)` and `place.h = canvas->endy - place.y` (`shoes_canvas_draw`, `s3_canvas.c:639-642`): its height runs to the parent's end so far, and in a flow that is the bottom of whatever came before it on its row. Its backgrounds fill that (a tile's height is `max(canvas->height, CPH(canvas))`, `s3_ruby.c:481-487`), and a child placed by `bottom:` sits against it (`PX2(..., canvas->fully)`, `s3_ruby.c:524-525`). In a stack each slot starts its own row, so nothing changes there.
- **Examples:** Hackety Hack's window is a flow of its 549 px content flow and its lesson pane, `stack :width => 400` with no height, whose page is `background gray(0.1)`, a scrolling stack `:height => -32` and a nav bar `flow :height => 32, :bottom => 0` (`app/ui/lessons.rb:229-261`). The Mac 1.0 screenshot has the pane dark to y 549 with its arrows at rows 530 to 536; native stopped it at 518, its content, left a white strip under it and put the arrows at 498 to 505.
- **Native:** since 28 Sep a slot with no `height` placed in a flow after something on its row is at least as tall as the row so far, margins aside (`layout::place_in_flow`, `Engine::row_floor`); the first on a row, and every slot in a stack, is as tall as its content, as before. **Test:** `layout::tests::a_slot_beside_a_taller_one_in_a_flow_reaches_down_to_its_bottom`.

### C17. An element placed on one axis keeps the flow's place on the other

**Ruling: open, Q13 (28 Sep 2026).** New row, from Hackety Hack's turtle (the w9 learner lane).

- **Manual:** `:left` "places the object's left edge ten pixels away from the left edge of the slot" (manual 1288-1294), and `:top` likewise; silent on the axis not given.
- **Shoes 3:** `shoes_place_decide` takes `x = PX2(left, right, cx, ...) + ox` and `y = PX2(top, bottom, cy, ...) + oy`, where `ox` and `oy` are the canvas's cursor (`s3_ruby.c:463-470, 521-525`), so an element given only `top` or `bottom` keeps the x the flow stood at, and one given only `left` or `right` keeps its y. Only the vertical keys make it absolute for the flow: `FINISH` moves the cursor on for anything not `ABSY` (`s3_ruby.h:246-255`), so a `left`-only element still takes its place in the line.
- **Examples:** Hackety Hack's turtle, and Lacci's port of it, put the pen swatch after its label with `para "pen: "; stack :top => 5, :width => 40, :height => 20` (`lib/art/turtle.rb` on Hackety Hack's master).
- **Native:** any of `left`, `top`, `right`, `bottom` takes an element out of the flow, placed from the slot's corner on an axis it was not given (`layout::place_positioned`). So the swatch covered the label. Since 28 Sep Lacci's turtle places the swatch in the flow, 5 px down (`lacci/test/test_turtle.rb`); the rule itself waits on Q13.

## D. Colours and patterns

### D1. Colours are `Shoes::Color` objects

**Ruling: MANUAL.** Keep `to_a` and array destructuring working so Lacci callers survive. **Lacci change, done 27 Sep 2026.**

- **Manual:** `ask_color` returns a `Shoes::Color` (manual 643-655); `rgb` and `gray` return `Shoes::Color` (manual 790, 815).
- **Shoes 3:** `Shoes::Color` with `red green blue alpha black? dark? light? white? opaque? transparent? invert to_s inspect to_pattern <=> ==` (`s3t_color.c:16-33`).
- **Lacci today:** plain Arrays `[r, g, b, a]` (`colors.rb:152-176`). `black(0.1)` gives `[0, 0, 0, 0.1]`, integer channels with a float alpha. Since the wave-4 Lacci lane `rgb`, and so `gray` and every named colour, return a `Shoes::Color` (`color.rb`) with `red`, `green`, `blue` and `alpha`, and `ask_color` turns its answer into one. `Shoes::Color` subclasses Array, so destructuring, `==` against an Array, `to_a` and the displays' normalisers work unchanged; Shoes 3's `dark?`, `light?`, `invert` and friends are not there yet. The cost: `Array#flatten` still dissolves a colour into its numbers, so `expert/colours.rb` (`[n.first, n[1..-2].shuffle, n.last].flatten`) paints every square black. A Color that is not an Array would stop that, and would need every display's colour handling (Calzini's and the native normaliser's `when Array`) to learn the class; `examples.yml` holds colours.rb as failing on native, checked by two of its squares' `pixels:`.
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

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.**

- **Manual:** built-ins that "may also be called as `Shoes.rgb`" (manual 785-834).
- **Shoes 3:** defined on `rb_mKernel` and as `Shoes::Color` singletons (`s3t_color.c:11-15, 38-40`).
- **Lacci today:** only through `include Shoes::Colors` on Drawables (`drawable.rb:15`). `Shoes.respond_to?(:rgb) == false`, and top-level `rgb(1, 2, 3)` raises `NoMethodError` (X5). Since 27 Sep (`95b1970`) `rgb`, `gray` and `gradient` are built-ins callable from any object, so a top-level `rgb(1, 2, 3)` and `Shoes.rgb(1, 2, 3)` both return a colour; the named colours stay on drawables.
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

**Ruling: MANUAL** (Shoes 3 agrees). Radial is **EXT**. **Lacci change, done 27 Sep 2026** (default angle, `Background` angle, alpha).

- **Manual:** "Normally, gradient colors range from top to bottom. If the `:angle` is set to 90, the gradient will rotate 90 degrees counter-clockwise and the gradient will go from left to right." (manual 1073-1079). `:fill`/`:stroke` accept "a range of either" (manual 1202, 1453).
- **Shoes 3:** angle defaults to 0; the direction vector is `(sin a, cos a)`, so 0 runs top to bottom and 90 runs left to right (`s3t_pattern.c:53-72`); a Range becomes a gradient (`:86-89`); `:radius` makes it radial (`:65-69`), though the radius parse checks the wrong variable and always uses 0.001.
- **Examples:** 15 files use `"#x".."#y"` Ranges; `for_playtest/shoes-contrib/styles/gradient-angle.rb` uses `gradient purple, red, :angle => 45`.
- **Lacci / WV today:** `Gradient` defaults to 45 (`colors.rb:198`); Ranges render as `linear-gradient(45deg, ...)`; the Shoes angle goes to CSS unchanged although CSS 0 runs bottom to top. `Background` has no `:angle` style, so `background r..b, angle: 30` is dropped with a warning (`background.rb:12`, `drawable.rb:385-388`). `gradient()` throws away each colour's alpha (`colors.rb:185-186`). No radial. Since 27 Sep (`95b1970`) `Gradient` defaults to angle 0 and keeps each end's alpha, `background` takes `angle:` and folds it into its gradient, and Calzini writes `180 - angle` for CSS.
- **Spec:** `background red..blue` is red at the top row and blue at the bottom row; with `angle: 90` it is red on the left and blue on the right.
- **Native:** DESIGN 5.3 sends `{"gradient":[c1,c2],"angle":deg}`; angle 0 is top to bottom. A CSS-style renderer maps `css_deg = 180 - shoes_deg`. Since Lacci's default moved to 0 on 27 Sep, a plain `gradient(a, b)` reaches the native backend as 0, top to bottom.

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
- **Lacci / WV today:** Rect and Line declare no `strokewidth` style (`drawables/rect.rb:5`, `drawables/line.rb:5`), so `rect(..., strokewidth: 4)` is dropped with a warning; only the draw context's `strokewidth` reaches them. Since the wave-4 Lacci lane rect, line, arc, arrow and star declare `strokewidth` as oval did, and the native display draws it (`styles.strokewidth`). Since wave 5 line, arc, arrow, star and `shape` also declare `stroke` and `fill`, and `shape` declares `strokewidth`, as the manual's lists name them (manual 1202-1210, 1453-1468; `styles.stroke__every_shape`). A shape keeps only the pens it is given as styles; the rest still come from the draw context sent after its block (E7). Oval defaults `fill: "black"`, `stroke: "black"` (`oval.rb:15-16`); Calzini uses stroke width 2 for ovals, a hard-coded 2 for stars and 4 for lines, ignoring `strokewidth` (`art_drawables.rb:78, 83, 97, 185`).
- **Spec:** a default `rect` over white has a black interior and a 1 px outline; `strokewidth 5; line ...` draws a line about 5 px thick.
- **Native:** draws every shape with the draw context's fill, stroke and width, defaulting to black, black, 1.

### D9. `Shoes::Pattern`: `gradient`, backgrounds, borders and `to_pattern`

**Ruling: MANUAL** (Shoes 3 agrees). **Lacci change, done 27 Sep 2026.** New row, requested by the art and app writers.

- **Manual:** `gradient(color1, color2) » Shoes::Pattern` (manual 785); "Both backgrounds and borders are a type of Shoes::Pattern" (manual 2754-2755, 2807-2809); `to_pattern() » a Shoes::Pattern` on both, reusable in other backgrounds and borders (manual 2799-2803, 2854-2858).
- **Shoes 3:** `Shoes::Pattern` has `to_pattern` (returning itself), and `Background` and `Border` subclass it (`s3t_pattern.c:13-31, 117-119`); `gradient` builds a `Pattern` (`s3t_color.c:226-238`).
- **Lacci today:** no `Shoes::Pattern`. `Background` and `Border` inherit from `Shoes::Drawable` (`drawables/background.rb:11`, `drawables/border.rb:4`) and have no `to_pattern`; `gradient` returns a `Shoes::Colors::Gradient` (`colors.rb:176-198`). Since the wave-4 Lacci lane `Shoes::Pattern` is a module (`pattern.rb`) that `Background`, `Border` and `Gradient` include, since the first two stay Drawables. `to_pattern` returns the pattern itself, and a background's `fill`, a border's `stroke` and the draw context's `fill` and `stroke` take a pattern and keep its paint (the background's fill, the border's stroke, or the gradient), so the wire carries the same colour, gradient or image as before.
- **Spec:** `background.is_pattern`, `border.is_pattern`, `background.to_pattern` (and `__reused`), `border.to_pattern` (and `__reused`), `builtins.gradient__pattern`.
- **Native:** nothing new: a reused pattern arrives as the same colour, gradient or image wire value (DESIGN 5.3).

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
- **Lacci / WV today:** Oval stores it, but Calzini inverts it: `cx: center ? radius : 0` (`art_drawables.rb:114, 123`). Without `center`, WV shows a clipped quarter circle; with it, the oval sits where the manual's default would put it. Rect declares no `:center` style (`drawables/rect.rb:5`), so `rect(..., center: true)` is dropped with a warning (`styles.center__accepted`). Since the wave-4 Lacci lane rect and arc declare `:center` too (the manual's For-list is arc, image, oval, rect, shape; image and shape still do not), and the native display centres them (`styles.center__rect`, `art.rect.styles__center`).
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
- **`move`, 28 Sep 2026 (wave 6):** Shoes 3 draws a line across its place box (`s3t_shape.c:127-132`) and `move` shifts the box, so the whole line moves. Lacci's `move` set only `left` and `top`, and Ledger's vertical hover guide became a diagonal from its new start back to its old end. `Line#move` now shifts `x2` and `y2` by as much, in one `prop_change`. **Spec:** `common.move__line` (native).

### E7. `shape { move_to; line_to; curve_to; arc_to }` is one path

**Ruling: MANUAL.** **Needs fix 10.2.**

- **Manual:** one path starting at (left, top) (manual 1799-1804); art inside a shape joins as a group "drawn as one" (manual 1820-1824); the Rules chapter's version is M21.
- **Shoes 3:** builds a cairo path and measures its extents into width/height (`s3t_shape.c:300-316`); art calls inside a shape add sub-paths to it (`:326-331`).
- **Examples:** `for_playtest/expert/curve-control-point.rb:16` calls `move_to *xy[0]` outside any shape.
- **Lacci today:** `Shape < Shoes::Slot` with `@incompatibility A Shoes3 Shape is *not* a slot; Scarpe does *not* do union shapes` (`shape.rb:11-12`). `shape_commands` is sent empty at create and mutated afterwards without a `prop_change` (`shape.rb:25-31`, X7). `move_to` and friends are ignored outside a Shape (`app.rb:509-568`).
- **Shoes 3, pens:** the shape is made after its block runs and copies the canvas's pens then (`s3t_shape.c:290-315`, `COPY_PENS` at `:206`), so `stroke red` inside the block strokes that shape; since the block draws on the enclosing canvas, the pen also stays set for later shapes there.
- **Lacci, pens:** since 27 Sep (wave-4 Lacci lane) the prop_change that carries the finished `shape_commands` carries the shape's final `draw_context` too, so pens set inside the block style the shape (`expert/curve-animation.rb` drew all three waves black before). A Lacci Shape is a slot, so those pens stay inside it and do not reach the shapes drawn after it, where Shoes 3 would carry them on.
- **Spec:** a closed `shape` fills its interior with the current fill; an oval created inside a shape paints (is not dropped). `art.shape__pens_in_block`: a stroke set inside the block colours the line.
- **Native:** builds one path from the complete `shape_commands`, offset by (left, top). Art children of the shape join the same path, measured from the shape's (left, top), and the whole group is filled once (nonzero) and stroked once with the shape's own draw context (DESIGN 12). The group turns about its own corner by the shape's transform, members' own transforms ignored, and since wave 4 the layout boxes of the shape and its members follow that turn (before, each member's box turned about its own corner, so clicks missed what was drawn).

### E8. `click`, `release`, `hover` and `leave` on shapes, text blocks and images

**Ruling: MANUAL.** **Needs fix 10.9.**

- **Manual:** the `:click` style is "For: arc, arrow, banner, button, caption, check, flow, image, inscription, line, link, mask, oval, para, radio, rect, shape, stack, star, subtitle, tagline, title" (manual 1144-1151).
- **Shoes 3:** `Shape#click`, `release`, `hover`, `leave` (`s3t_shape.c:33-36`).
- **Examples:** `for_playtest/expert/curve-control-point.rb:22-30` (drag with oval `click`/`release`), `expert/colours.rb:70`.
- **Lacci today:** `Drawable#click`/`#release` store `@block`/`@release` (`drawable.rb:784-802`), but only Button, Check, Radio, Link, Image and SubscriptionItem bind a `click` event; art classes declare no events, so the handler never fires (X9). Fix 10.9 bound the `click` and `release` methods; since the wave-4 Lacci lane a `click:` proc given as a style binds the same way (G10), so `styles.click__para` passes.
- **Spec:** `oval(...).click { }` fires on `click_at` the oval's centre and not on a click outside it.
- **Native:** routes a press to the topmost drawable with `has_click` (DESIGN 4.3). Until 28 Sep 2026 it looked only at the topmost drawable and its slots, so a label or icon drawn over a clickable shape swallowed the press; Shoes 3's `shoes_canvas_send_click2` skips elements with no click block and asks the next one down. Now a press no control takes goes to the topmost drawable under the pointer with `has_click` (`input::pointer_owner`), and a release likewise. A control on top still keeps its press. **Spec:** `events.click__through_a_label` (native). Since 28 Sep (wave 8) the slots' `click` blocks run first and that drawable's after, as Shoes 3's walk runs each canvas's block on the way down and the shape's once the walk stops on it (`s3_canvas.c:1038-1102`; a canvas's own send_click answers nil, so the walk goes on past it): a card over a clickable backdrop that took the card away had lost its own click (`events.click__slot_before_shape`). Where Shoes 3 stops the walk at a shape drawn over a slot, and that slot's block never runs, native still runs it. Automation's `click` and `click_on` go where a real press goes, through an empty slot on top (`events.click__through_an_empty_slot`).
- **Images, 28 Sep 2026 (w9):** Lacci's `Image#click` kept its block without telling the display, and native clicked an image only when the image itself was topmost, on the release, like a button (DESIGN 4.3). Hackety Hack leaves an empty, window-sized stack over its side-tab icons once its intro is skipped, so no tab opened. An image's click block is now heard like a shape's: Lacci sends `has_click` (`Drawable#click`), and a press reaches the picture through an empty slot over it, once, on the press, with `[button, x, y]` in window coordinates. **Spec:** `events.click__image_under_an_empty_slot` and `events.click__image_once` (native).

### E9. `image(w, h) { drawing }` is a canvas

**Ruling: MANUAL** for the canvas; effects (`blur`, `glow`, `shadow`) are **EXT**. **Lacci change, done 27 Sep 2026.**

- **Manual:** `image 300, 300 do ... end` renders the shapes into one image (manual 410-426); the block form is not documented under `image` itself (M23).
- **Shoes 3:** shapes inside an image draw into its surface (`s3t_shape.c:318-323`); effects live in `shoes/types/effect.c` (not fetched).
- **Examples:** 3 files (`simple-sphere.rb`, `shoes_manual/ovals_image.rb`, ...); `blur` in 1.
- **Lacci today:** `image(w, h)` becomes a blank placeholder and the block is ignored (`image.rb:10-20`). Since 27 Sep (`64e1ca6`) the block runs with the Image as the current slot (contract c), so its shapes and text are the Image's children, and `image(styles) { }` is a canvas too; `blur`, `glow` and `shadow` are accepted and ignored. A file image's block is its click handler, as in Shoes 3.
- **Spec:** `image(100, 100) { oval 0, 0, 50 }` paints the oval inside the image's box.
- **Native:** **wire contract (c), 27 Sep 2026:** the `image(w, h) { }` block runs with the Image as the current slot, so the art and text inside arrive as children of the Image node, and Rust paints them clipped to the image's box in image-local coordinates. Built 27 Sep: an Image with children lays them out inside its box like a flow, clipped to it (DESIGN 12). Effects stay undrawn: the manual names blurred ovals and shadows in its introduction (manual 51-52) but documents no API for them.

### E10. `transform`, `translate`, `cap`, `rotate`, `scale`, `skew`

**Ruling: MANUAL,** low priority. **Turns add up: S3, ruled 27 Sep 2026** by the orchestrator (Nick may overrule): the manual is silent on whether a second `rotate` adds to the first, and Shoes 3 adds, so `rotate 45; rotate 45` turns later shapes 90 degrees and a slot's turn survives `clear`.

- **Manual:** manual 1676-1680, 1783-1797, 1857-1868. `transform`: "Shoes defaults to `:corner`", the corner of the shape (1857-1860).
- **Shoes 3:** `shoes_transform_new` starts every transform in `s_center` mode, and outside centre mode the matrix is applied about the canvas origin, not the shape's corner (`s3_canvas.c:31-41, 192-205`). The ruling keeps the manual's shape corner; nobody has checked what a real Shoes 3 draws.
- **Shoes 3, turns add up:** the canvas's `rotate`, `scale` and `skew` multiply into the canvas matrix (`TRANS_COMMON(canvas, 0)` at `s3_ruby.c:645` expands to `cairo_matrix_rotate(&self_t->st->tf, -rad)` and friends, `s3_ruby.h:444-510`), and `clear` leaves that matrix alone (`s3_canvas.c:759-781`; only the full reset in `:282-303` clears it). So `rotate 1` inside `animate { clear { ... } }` spins what it draws.
- **Shoes 4, turns:** `rotate` sets the app style outright (`s4_dsl_style.rb:42-55`), so turns do not add up.
- **Manual, turns:** "Rotates the pen used for drawing by a certain number of degrees" (manual 1783-1786); silent on a second call.
- **Examples, turns:** `shoes-contrib/animation/rotating-star.rb` (`rotate 1` every frame) and `for_playtest/simple/path-animation.rb` (`rotate -5` every frame) only move when turns add up. Scarpe's own `examples/rotate_shapes.rb` was written against Webview's set-outright turn, so its later shapes now land at the running total (90, 270, 330, 450...).
- **Lacci today:** `translate` and `cap` are no-ops (`app.rb:555-573`); `transform` exists only on Image (`image.rb:74-83`); `rotate`/`scale`/`skew` go into the draw context (`slot.rb:166-193`), and WV applies them to some shapes only (report 02, 6.8). Wire contract (b) of 27 Sep 2026 has Lacci send `translate: [x, y]` (running total), `transform: "center"|"corner"` and `cap: "curve"|"rect"|"project"` in the draw context. Since 27 Sep (`5cd2ed1`) `translate` (a running total), `transform` and `cap` go into the draw context as contract (b) reads them, and shapes take a `cap:` style of their own; inside an `image(w, h) { }` block `rotate` and `transform` still turn the whole image.
- **Spec:** `rotate 45; rect 100, 100, 50, 10` paints a pixel off the unrotated rect's box. `art.rotate__adds_up`: `rotate 45; rotate 45` stands a bar on end, as `rotate 90` does.
- **Lacci, turns:** since 27 Sep (this ledger's wave-4 Lacci lane) `rotate` adds to the slot's running total, which a child slot inherits and `clear` keeps; `rotate nil` drops the slot's own. `scale` and `skew` still set their value outright, where Shoes 3 multiplies them in too; no example found depends on either (under Shoes 3 `rotating-star.rb`'s random `scale` would wander rather than pulse). Since 28 Sep (wave 8) `style` sends every draw-context setting to the display, `scale`, `skew`, `translate` and `transform` as well as `fill`, `stroke`, `strokewidth` and `rotate`: `shape.style(scale: [2, 2])` had only set an instance variable. A bare number scales both ways and skews along x, as the `scale` and `skew` methods read one. **Spec:** `styles.style_method__scale`.
- **Native:** applies the draw context's transforms to every shape, rotating about the shape's top-left corner unless `transform: "center"` (or `center: true`); `translate` moves the shape and its layout box; caps are round, flat or square (DESIGN 12). **Wire contract (b), 27 Sep 2026:** Lacci sends `"translate": [x, y]` (cumulative), `"transform": "center" | "corner"` (the rotate and scale pivot, default corner) and `"cap": "curve" | "rect" | "project"` (round, butt, square) in the draw context, and Rust renders them.
- **Stars and arrows, 28 Sep 2026 (w9):** a star's and an arrow's `left` and `top` are their centre (E4, E5), and native turned them about their box's top-left corner, so Hackety Hack's splash, which turns `rotate 1; star 210, 210, 130, 500, 90` inside a mask every frame, swung its star window off the hand. Now the point a turn keeps still is the one the shape's `left` and `top` name: the corner of a rect, an oval, an arc or a shape block, the centre of a star or an arrow, as `center: true` makes it for anything (manual 1115-1121). Shoes 3.3 goes further and turns every shape about its centre unless `transform :corner` was called (`shoes_transform_new` starts in `s_center`, `s3_canvas.c:31-41, 192-205`), against the manual's "Shoes defaults to `:corner`"; that is Q11. Whether `rotate` adds up across `clear`, the splash's other question, was settled by the turns ruling above. **Spec:** `art.rotate__star_in_place` (native).

### E11. Art methods return `Shoes::Shape`

**Ruling: MANUAL** (Shoes 3 agrees). Subclasses (`Shoes::Oval < Shoes::Shape`) satisfy it. **Lacci change, done 27 Sep 2026** (without subclasses, see below). New row, requested by the art writer.

- **Manual:** `arc`, `arrow`, `line`, `oval`, `rect`, `shape` and `star` are each headed `» Shoes::Shape` (manual 1665-1826), and "A shape is a path outline usually created by drawing methods like `oval` and `rect`" (manual 3363-3366).
- **Shoes 3:** every art call makes a `cShape` (`s3t_shape.c:16, 195-198, 334`).
- **Lacci today:** `Shoes::Oval`, `Shoes::Rect` and the rest inherit from `Shoes::Drawable`; `Shoes::Shape` exists only as the `shape { }` slot (`drawables/shape.rb`). Since the wave-4 Lacci lane the six art classes include `Shoes::Art` (`art.rb`) and answer `is_a?(Shoes::Shape)` and `kind_of?(Shoes::Shape)` with true, as `ActiveSupport::Duration` answers `is_a?`. They keep their classes, so the display is still told `Oval` or `Rect`, and `Shoes::Shape` stays the `shape { }` slot, so shape blocks work as before. `Shoes::Shape === oval` is still false, on purpose: the spec finders match with `===`, and the `shape` finder should keep meaning shape blocks. Making the art real subclasses would need `Shoes::Shape` to stop being a slot.
- **Spec:** `shape.element`: every art method's result `is_a?(Shoes::Shape)` and answers the Common methods.
- **Native:** nothing; the `kind` on the wire stays the concrete class name (DESIGN 4.1).

### E12. `arc(..., wedge: true)` fills a pie slice

**Ruling: EXT** (Shoes 4). New row, 28 Sep 2026, from the wave-6 toys lane.

- **Manual:** silent; `arc` draws "a section of an oval" (manual 1665-1670).
- **Shoes 3:** no `wedge`: an arc is its curve alone (`shoes_cairo_arc`, `s3_ruby.c:613-617`), filled as a chord.
- **Shoes 4:** `style_with ... :wedge`, default `false` (`s4_arc.rb:14-15`, `s4_dsl_art.rb:47`).
- **Lacci today:** until 28 Sep Arc declared no `wedge`, so `arc ..., wedge: true` logged "Unexpected non-style keyword(s)" and dropped it, though DESIGN 12 and the renderer already drew a pie for it. Marble Machine drew its rainbow swatch from `shape` slices instead. Arc now declares it.
- **Spec:** `art.arc__wedge` (native): the pie is filled to its centre and the chord is not.
- **Native:** `wedge: true` closes the arc through its centre (`shapes.rs`, DESIGN 12).

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

**Ruling: MANUAL.** Subclasses, so a class-level `style()` targets one kind. **Lacci change, done 27 Sep 2026.**

- **Manual:** `banner » Shoes::Banner`, `title » Shoes::Title`, and so on (manual 1921-2129); sizes 48, 34, 26, 18, 14, 12, 10 (manual 3378-3384).
- **Shoes 4:** `Shoes.const_get(method.capitalize)` per block type (`s4_dsl_text.rb:50-56`).
- **Lacci today:** all are `Para` with `size: :banner|:title|...` (`para.rb:258-316`): `title("T").class == Shoes::Para`. So `style(Shoes::Para, stroke: red)` restyles titles too, and `style(Shoes::Title, ...)` cannot be expressed. Sizes match the manual (`calzini.rb:24-33`). Since the wave-4 Lacci lane `Shoes::Banner`, `Title`, `Subtitle`, `Tagline`, `Caption` and `Inscription` are subclasses of `Para`, each defaulting to its own size, and `banner`, `title` and the rest make them. `style(Shoes::Title, ...)` styles titles alone and `style(Shoes::Para, ...)` no longer reaches them. Every kind tells the display `Para`, so nothing changes on the wire. They are still Paras, so the `paras` finder still includes them and the imported cases that expect otherwise stay `expect: fail`; Shoes 3 makes them siblings under a TextBlock class instead.
- **Spec:** `title("T").class == Shoes::Title`; after `style(Shoes::Title, stroke: red)`, a new `para` keeps the default stroke.
- **Native:** nothing: `Para.display_class_name` is `"Para"` for every kind, so `create` still carries `kind: "Para"` with the size.

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
- **Lacci / WV today:** Para declares `:weight`, but Calzini only renders `font_weight` (`calzini/para.rb:47`), so `weight: "bold"` shows normal. `variant:` is not a style and is dropped with a warning. `FontHelper#parse_font` knows CSS names only (`font_helper.rb:15-18`). Since the wave-4 Lacci lane text blocks and text fragments keep `variant:` as a style and send it.
- **Spec:** `para "x", weight: "bold"` lays out wider than `para "x"`.
- **Native:** maps weight names to numeric weights and parses the Pango-style font string (family list, style words, size). Since wave 5 (27 Sep 2026) `variant: "smallcaps"` draws small capitals: the face's own (OpenType `smcp`) when it has them, else lower-case letters as capitals at 0.78 of the size (the bundled Inter has none), so `styles.variant.normal` and `.smallcaps` pass on native.

### F5. Text styles Lacci drops

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.**

- **Manual:** `:leading` (manual 1282-1286, see F10), `:justify` (1268-1273), `:rise` (1366-1373), `:stretch` (1423-1434), `:strikecolor` (1436-1441), `:undercolor` on Para (1489-1494).
- **Lacci / WV today:** none are Para styles (`para.rb:6-36`); they hit the "Unexpected non-style keyword" warning (`drawable.rb:385-388`). TextDrawable has `:undercolor` (`text_drawable.rb:15`). Calzini already renders `rise`, `strikecolor` and `undercolor` when present (`calzini/para.rb:43-50, 79-82`). Since the wave-4 Lacci lane Para declares all six (colours through `to_rgb`, as its stroke), and text fragments `justify`, `rise`, `stretch` and `strikecolor` besides their `undercolor`. The native display draws all but `stretch`, so the four `styles.stretch` visual cases stay `expect: fail` on native: cosmic-text varies only a font's weight axis, not its width, and the bundled fonts have no condensed or expanded faces (checked in wave 5).
- **Spec:** each style is accepted without a warning and reads back through `style`; `leading` and `rise` change layout.
- **Native:** honours them once Lacci sends them.
- **Fragments, 28 Sep 2026 (w9):** the manual lists span and the other fragments for `weight`, `family`, `emphasis` and `kerning` too (manual 1181-1283, 1521-1537), and native already drew them on spans, but Lacci dropped them with a warning. Hackety Hack colours its method names with bold spans. Fragments now keep all four. **Spec:** `styles.weight__span` (native).

### F6. `underline` and `strikethrough` value types

**Ruling: BOTH.** Map `true` to `"single"` and `false` to `"none"`.

- **Manual:** strings (manual 1443-1451, 1496-1509).
- **Shoes 4:** booleans (`s4_dsl_text.rb:110-112`).
- **Lacci today:** the validators accept only nil or the manual's strings; `true` raises `InvalidAttributeValueError` (`para.rb:15-29`, `text_drawable.rb:17-31`). Since 27 Sep (`a24066f`) `true` becomes `"single"`, and `false` or nil set by a style becomes `"none"`, for Para and the text fragments alike.
- **Spec:** `underline: "single"` and `underline: true` both underline.
- **Native:** receives the string form.

### F7. Link and LinkHover defaults

**Ruling: MANUAL.**

- **Manual:** a link has a single underline and a `#06E` stroke; LinkHover has a single underline and a `#039` stroke (manual 2034-2039).
- **Shoes 4:** `STYLES = { underline: true, stroke: blue, fill: nil }` (`s4_link.rb:13`).
- **Examples:** `style(Shoes::Link, :underline => nil)` plus `style(Shoes::LinkHover, ...)` in `for_playtest/simple/menu.rb:25-26`, `menu1.rb:14-15`, `philippe_checked/accordion.rb:46-47`, `shoes-contrib/simple/simple-accordion.rb:39`.
- **Lacci today:** Link styles are nil; LinkHover class defaults are stored by `style()` but "The functionality isn't present in Lacci yet" (`link.rb:35-41`). Since 27 Sep (`a24066f`) a style that sets `underline` or `strikethrough` to nil or false sends `"none"` (contract d), so `style(Shoes::Link, underline: nil)` takes the underline off; LinkHover defaults still do nothing.
- **Spec:** an unstyled link's glyph pixels read close to `#0066EE` and it is underlined; after `style(Shoes::Link, underline: nil)` it is not.
- **Native:** DESIGN 7 uses `#0066ee` with an underline, which is `#06E`. On hover it should switch to `#039` (`#003399`) unless the app styled LinkHover; DESIGN only says "darker on hover". **Wire contract (d), 27 Sep 2026:** when a style sets `underline` (or `strikethrough`) to nil or false, Lacci sends `"none"`, and Rust draws no decoration for `"none"`. That is how `style(Shoes::Link, underline: nil)` reaches the display, since create props drop nils.

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
- **Native:** since 27 Sep leading defaults to 4 px and goes between lines only, as Pango's spacing does: one line is 1.2 x size, two are 2.4 x size + 4 (DESIGN 6). Lacci sends `:leading` since the wave-4 Lacci lane (F5), and `styles.leading` and `styles.leading__default` pass.

### F11. `para` with non-String arguments

**Ruling: BOTH.** New row.

- **Manual:** silent. Its examples assign Integers to `text=` (`@counter.text = e.text.size`, manual 3025).
- **Lacci today:** Arrays are joined (`para(["a", "b"]).text == "ab"`), other objects go through `to_s`/`inspect`; `strong("0").text = 5` reads back `"5"` (report 03 probes).
- **Spec:** only `para(5).text == "5"` and `text = 5` reading back `"5"`.
- **Native:** receives Strings.

### F12. Text with invalid UTF-8 is reported

**Ruling: MANUAL.** **Lacci change, unscheduled.** New row, requested by the app writer.

- **Manual:** "Edit boxes, edit lines, list boxes, window titles and text blocks all take UTF-8. If you give a string with bad characters in it, an error will show up in the console." (manual 482-485).
- **Shoes 3:** not checked.
- **Lacci today:** passes the bytes through without a word; neither display reports them. Since the wave-4 Lacci lane text blocks and text fragments print `[ERROR] para text is not valid UTF-8: ...` on stderr and replace the bad bytes with U+FFFD, so every display gets valid text and the app carries on. Edit lines, edit boxes, list boxes and window titles are not checked yet.
- **Spec:** `rules.utf8_bad_chars_error`: a para made from a string with a stray Latin-1 byte puts a UTF-8 or encoding message on stdout or stderr, and the app carries on. Since 28 Sep (the w10 scarpe lane) the message reaches the Shoes console as well (K8), which the manual means (`lacci/test/test_console.rb`).
- **Native:** the shim must not crash on such a string: JSON generation of invalid UTF-8 raises, so it should report and replace the bad bytes before the text crosses the wire.

### F13. A text fragment's parent is what holds it

**Ruling: S3.** **Lacci change, done 28 Sep 2026.** New row, from the Hackety Hack lane (w9).

- **Manual:** `parent` "Gets the object for this element's container" (manual 2676-2679), among the common methods; silent on text fragments.
- **Shoes 3:** a text block or fragment sets the parent of each fragment it takes as text to itself (`shoes_text_check`, `s3t_text.c:72-83`), so a link in a para answers the para, and a fragment inside a `strong` answers the `strong`.
- **Examples:** Hackety Hack's `britelink` recolours a whole line on hover through `p1.parent.stroke = white` (`app/ui/widgets.rb:274-283`).
- **Lacci until 28 Sep:** a fragment has no slot parent, and `parent` answered nil. Since 28 Sep a para or a fragment that takes a fragment as text sets its `parent`; a fragment nothing has taken still answers nil. The slot bookkeeping (`remove_child`, margins) keeps to the slot parent.
- **Spec:** `common.parent__text_fragment`.
- **Native:** nothing.

### F14. A text block's `hit`, `cursor_top` and `cursor_left`

**Ruling: EXT** (Shoes 3.1). **Lacci and native change, done 28 Sep 2026.** New row, from the Hackety Hack lane (w9).

- **Manual:** silent; the text cursor (`cursor`, `marker`, `highlight`, `hit`, `cursor_left`, `cursor_top`) came with Shoes 3.1, for editors, after the manual.
- **Shoes 3:** `hit(x, y)` measures from the block's inner corner and asks Pango's `xy_to_index` for the character under the point, nil off the block (`s3t_textblock.c:713-722`); `cursor_left` and `cursor_top` are where the caret was drawn, in the block's own surface (`:173-181`, `:629-638`).
- **Examples:** Hackety Hack's editor puts its caret where the pointer is with `hit_sloppy`, one right of `hit`, or `hit(48, y)` from the gutter, and scrolls the caret into view by comparing `cursor_top` with its flow's `scroll_top` (`app/ui/editor/editor.rb:101-112, 334-340`). `examples/para_cursor_demo.rb` uses `hit` too.
- **Lacci until 28 Sep:** `hit` ignored its arguments and gave back the index the pointer last hovered (H3), and on native `cursor_top` was always 0: nothing filled its cache. Since 28 Sep both ask the display when it can answer, as native does through `para_hit` and `para_caret` requests (DESIGN 4.1). `hit` takes window coordinates, as every click hands them out (H3). `cursor_top` and the new `cursor_left` are measured from the content origin of the slot that scrolls the para, or the window's, so they compare with that slot's `scroll_top` however far it is scrolled. Other displays keep the old caches.
- **Spec:** `textblock.types__hit` and `textblock.types__cursor_top` (native).
- **Native:** `input::char_under` and `Runtime::para_caret`; the caret is drawn from the same position (`paint::text::para_caret`).
- **`cursor = :marker`, 28 Sep 2026 (w9 polish):** Shoes 3.1 reads it as "drop the selection": with a marker set, the caret goes to the start of the selection and the marker is cleared, and with none nothing changes; `cursor = nil` clears both (`shoes_textblock_set_cursor`, `s3t_textblock.c:602-616`). Lacci jumped the caret to the marker and kept the marker. Hackety Hack's editor says `cursor = :marker` after every edit (`app/ui/editor/editor.rb:291-301`), and its Backspace sets the marker, so after one Backspace the next did nothing and typed letters came out backwards at a stuck caret, and after select-all a whole line came out reversed (the learner lane's `alert "hello"` with two Backspaces and `p!"` read `alert "hello"!p`). **Test:** `lacci/test/test_lacci.rb` (`test_para_cursor_marker_drops_the_selection`, `test_para_typing_after_a_backspace_goes_forward`), failing before and passing after.

## G. Native controls

### G1. Control callbacks receive the control

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.**

- **Manual:** button `click { |self| }` (manual 2918-2921); check and radio `click { |self| }` (manual 2988-2993, 3349-3354); edit_box, edit_line and list_box `change { |self| }` (manual 3038-3042, 3086-3090, 3211-3215).
- **Shoes 3:** every control event calls its block with `rb_ary_new3(1, self)` (`s3t_native.c:189-193`).
- **Shoes 4:** `listener.call(self)` (`s4_common_changeable.rb:25-31`).
- **Examples:** `for_playtest/shoes-contrib/elements/edit_line-character-count.rb:2-3` does `edit_line do |e| @counter.text = e.text.size end`, which breaks on a String.
- **Lacci today:** Button calls its block with no arguments (`button.rb:42-45`); **EditLine passes the new String** (`edit_line.rb:15-20`); EditBox, ListBox, Check and Radio pass `self`. Since 27 Sep (`c91ffd6`) every control calls its block with itself, Button and EditLine included, and handler setters return the control.
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

**Ruling: MANUAL.** **Needs fix 10.4** (`choose` echo); the default selection was a **Lacci change, done 27 Sep 2026.**

- **Manual:** `text` is nil when nothing is selected (manual 3234-3237); `:choose` pre-selects (manual 1137-1142).
- **Lacci / WV today:** `@chosen = kwargs.delete(:choose) || @items&.first` (`list_box.rb:19`), so `text == "a"` with nothing chosen. Calzini selects by `props["choose"]` while Lacci sends `chosen` (`calzini/misc.rb:74-77` against `list_box.rb:10`). `#choose` sets `@chosen` without a `prop_change` (`list_box.rb:35-41`, X11). Since 27 Sep (`c91ffd6`) a list box with no `choose:` selects nothing, so `text` is nil; the `choose` echo (fix 10.4) is unchanged.
- **Spec:** `list_box(items: %w[a b]).text` is nil; `choose: "b"` gives `"b"`; after `lb.choose("a")` the display shows "a" (layout text or snapshot).
- **Native:** reads `chosen`; shows an empty selection when it is null.

### G4. `:state` (nil, `"readonly"`, `"disabled"`)

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.** Button readonly is M33.

- **Manual:** for button, check, edit_box, edit_line, list_box, radio (manual 1410-1421).
- **Shoes 3:** `shoes_control_check_styles` applies `state` to every native control (`s3t_native.c:155-158`).
- **Lacci today:** no `:state` style; `button("dis", state: "disabled")` is accepted with a warning and ignored. Since the wave-4 Lacci lane the six controls declare `:state` and send it; the native display already greys disabled controls and ignores their input, so the four `styles.state` cases pass there.
- **Spec:** clicking a disabled button does not call its block; typing into a readonly edit_line does not change its `text`.
- **Native:** draws disabled controls greyed and ignores their input; readonly inputs take focus and selection but no edits.

### G5. Does a programmatic `text=` fire `change`?

**Ruling: BOTH** in `core`, which asserts neither. **EXT pin, ruled 27 Sep 2026 (Q7)** by the orchestrator (Nick may overrule): Scarpe's choice to fire `change` is pinned under `ext-scarpe`.

- **Manual:** silent (M32).
- **Shoes 3:** platform-dependent: GTK emits "changed" from `gtk_entry_set_text`, Cocoa does not.
- **Lacci today:** fires, on purpose: commit `eda8975` ("a deliberate deviation from Shoes3 behavior for better UX"), `edit_line.rb:30-40`, `edit_box.rb:30-40`. Since 27 Sep (`c91ffd6`) it still fires, and hands the control to the block, as G1 has every control do.
- **Spec:** `core` nothing either way; `edit_line.text=__fires_change` pins the extension: setting `text` from code calls the change block once.
- **Native:** sends `change` only for user edits; the programmatic path is Lacci's, so the pin holds on every display.

### G6. Radio grouping

**Ruling: MANUAL.**

- **Manual:** ungrouped radios group per slot; `radio :films` groups across slots (manual 2069-2074, 3293-3334).
- **Lacci / WV today:** Lacci groups by `@group || @parent&.linkable_id` (`radio.rb:55-57`), which is right. Calzini sets HTML `name: props["group"] || "no_group"` (`calzini/misc.rb:88-90`), so every ungrouped radio in the window is one browser group.
- **Spec:** two ungrouped radios in different stacks can both be marked; two radios sharing `:films` across stacks cannot.
- **Native:** does no grouping of its own. It sends `click` and shows Lacci's `checked` echo (DESIGN 4.3).

### G7. Button styling

**Ruling: EXT.** The Shoes 3.3 set (`font:`, `stroke:`, `icon:`, `icon_pos:`, `tooltip:`, from `for_playtest/shoes3-tests/button/button.rb`) is `ext-s33`. Scarpe-only `:color`, `:text_color`, `:font_size`, `:padding_*` (`button.rb:5`) are `ext-scarpe` behind `features: :scarpe`. The manual gives buttons no colour style. **Native:** honours the S3.3 set (since 27 Sep that includes `icon:` with `icon_pos:` and `tooltip:`, DESIGN 12); Scarpe-only styles when the feature is on. Nobody has checked Shoes 3.3's default `icon_pos`; native puts the icon on the left, as GTK and AppKit do by default.

### G8. `check.checked`

**Ruling: MANUAL,** low. The manual documents `checked?` and `checked=` (manual 2979-2986). Lacci defines `checked(value)` with one required argument, which shadows the style getter (`check.rb:29-31`, same in `radio.rb:49-51`), so `check.checked` raises `ArgumentError`. **Spec:** `checked?` and `checked=` only. **Native:** nothing.

### G9. `focus` on buttons, and Enter clicks the focused button

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.** New row.

- **Manual:** button `focus`: "The button will be highlighted and, if the user hits Enter, the button will be clicked." (manual 2923-2926); radio `focus`, Enter toggles (manual 3356-3359).
- **Lacci today:** Button has no `focus` (report 03 probe); ListBox, EditBox and EditLine do. Since 27 Sep (`c91ffd6`) Button, Check and Radio have `focus` too, shared with the other controls through `Shoes::Focusable`.
- **Spec:** `button.focus`, then `press_key "\n"`, fires the click block once.
- **Native:** accepts `focus` for buttons, checks and radios; Enter or Space on a focused button, check or radio sends `click` (since wave 5, 27 Sep 2026; the manual's Enter toggles them, manual 3356-3359), so `check.focus` and `radio.focus` pass on native. Since 28 Sep 2026 only focus that shows its ring takes those keys: focus from `focus` or the Tab key. A control the mouse pressed has focus without a ring and leaves Space, Return and the arrows to the app's `keypress`, as a Mac's push buttons and pop-up buttons do; Bloop Sequencer lost its Space-to-play to a list box it had just used.

### G10. `click:` and `change:` styles are the handlers

**Ruling: MANUAL** (Shoes 3 agrees). **Lacci change, done 27 Sep 2026.** New row, requested by the styles writer and the lacci lane.

- **Manual:** "The `click` event handler is stored in this style" for everything in the `:click` For-list (manual 1144-1151); "The `change` event handler is stored in this style" for edit_box, edit_line and list_box (manual 1123-1128).
- **Shoes 3:** handlers live in the element's style hash: `ATTRSET(attr, change, ...)` for edit lines, edit boxes and list boxes (`s3t_edit_line.c:100`, `s3t_edit_box.c:102`, `s3t_list_box.c:107`), and slot events the same way (`s3_canvas.c:934-944`).
- **Lacci today:** Button and EditLine declare no `:click`/`:change` style (`drawables/button.rb:5-6`, `drawables/edit_line.rb:5-6`), so `button "Go", click: proc { }` and `edit_line change: proc { }` are dropped with an "Unexpected non-style keyword" warning; blocks live in `@block`, so `style[:click]` is nil. Links accept `click:` (F9); art and paras drop it (E8). Since the wave-4 Lacci lane every drawable has a `:click` style and edit lines, edit boxes and list boxes a `:change` style, and each is the handler itself: a proc given as the style runs on the event, and a block given to `click` or `change` (or when the drawable is made) reads back through `style`. On art, text and slots a `click:` proc binds the same way the `click` method does (a slot gets its `click` subscription). Links keep their own `click:` (a route, a URL or a proc, F9).
- **Spec:** `styles.click` and `styles.change` fire a proc passed as the style; `styles.click__readback` and `styles.change__readback` read the handler back from `style`.
- **Native:** nothing; handlers stay in Ruby. A `click:` style on art or text must still turn on `has_click` (DESIGN section 10, fix 9).

### G11. Fonts on edit lines and edit boxes

**Ruling: EXT** (`ext-scarpe`). New row, requested by the widgets writer.

- **Manual:** "in current versions of Shoes, the font for edit lines and edit boxes cannot be altered anyway" (manual 3078-3079): a limitation of that release, not a promise.
- **Lacci today:** EditLine and EditBox declare `:font` (`drawables/edit_line.rb:5`, `drawables/edit_box.rb:5`), and the native backend honours it.
- **Spec:** `core` asserts nothing; `edit_line.font_fixed` stays in `UNTESTABLE.md`. A case under `ext-scarpe` may assert that `font:` changes an input's text.
- **Native:** honours `font:` on inputs: family and size, and since 28 Sep 2026 weight and slant too (`"bold 16px"`, `"Georgia italic"`), which the fields dropped while a para with the same string drew them.

### G12. New inputs read `""`, new progress bars `0.0`

**Ruling: MANUAL** (Shoes 3 agrees). **Lacci change, done 27 Sep 2026.** New row, requested by the widgets and elements writers; see M5.

- **Manual:** `text` on an edit line or edit box returns "a string of characters" (manual 3051, 3099); `fraction` returns "a decimal number from 0.0 to 1.0" (manual 3264-3266).
- **Shoes 3:** `text` reads the native widget (`s3t_edit_line.c:23-27`), which is a String even when empty. The progress getter is not in the fetched files.
- **Lacci today:** `edit_line.text`, `edit_box.text` and `progress.fraction` are nil until something sets them (`drawables/edit_line.rb:5-9`, `drawables/progress.rb:5`). Since 27 Sep (`c91ffd6`) `text` starts as `""` and `fraction` as 0.0, as in Shoes 3.
- **Spec:** `element.edit_line__no_text` and `element.edit_box__no_text` read `""`; `progress.fraction__untouched` reads `0.0`.
- **Native:** shows an empty field and an empty bar either way.

### G13. Up and Down on a focused list box select

**Ruling: MANUAL.** New row, requested by the widgets writer.

- **Manual:** focus on a list box: "if the user hits the up and down arrow keys, other options in the list will be selected" (manual 3221-3224).
- **Shoes 3:** a native combo box; not traced.
- **Spec:** `list_box.focus`: after `focus`, Down selects the next item and sends `change`, with no popup opened.
- **Native:** after `focus`, Up and Down choose in place and Return and Space open the popup (DESIGN 12, "Focus"). A list box the mouse opened keeps focus without a ring and, since 28 Sep 2026, leaves those keys to the app (G9). **Spec:** `list_box.focus__mouse_leaves_keys` (native).

### G14. A radio unmarked by its sibling: does its click block run?

**Ruling: BOTH.** The spec asserts neither. New row, the M27 follow-up the widgets writer asked for.

- **Manual:** "Clicks are sent for both marking and unmarking the radio" (manual 3349-3354).
- **Shoes 3:** radios are native GTK or Cocoa buttons; the widgets writer reports GTK emits `clicked` on the button that loses its mark too. The fetched files hold only the grouping code (`s3t_radio.c:20-60`), so this is not checked.
- **Lacci today:** only the clicked radio's block runs; a sibling it unmarks gets a `checked` echo and no call.
- **Spec:** nothing. M27 covers what a click does to the clicked radio.
- **Native:** nothing; Lacci owns the grouping (G6).

### G15. Scarpe draws its own controls

**Ruling: EXT** (`ext-scarpe`), Nick, 27 Sep 2026: "our buttons are OUR buttons". The manual's seven native controls are "drawn by the operating system" and "will match the look of the window theme" (manual 73-79, 2540-2544); Scarpe's native display draws all seven itself, the same on every platform. `alert`, `confirm` and the file and folder choosers stay the operating system's own dialogs. New row.

- **Manual:** "each of these seven elements is drawn by the operating system. So, a Progress bar will look one way on Windows and another way on OS X" (manual 2540-2544); "Shoes will try to keep native controls all within the size you give them, only the look will vary" (manual 76-79).
- **Shoes 3:** GTK and Cocoa widgets (`s3_gtk.c`, `s3_cocoa.m`).
- **Lacci / WV today:** Webview uses HTML form controls, which the browser engine draws.
- **Spec:** `elements.native_controls__drawn_by_scarpe` (native): in a headless run, where no OS widget exists, a button, edit line, edit box, list box, progress bar, check and radio each paint their own pixels. The manual's claim is not transcribed as an expectation. Sizes still follow C4.
- **Native:** every control is drawn by the renderer (DESIGN 7, "Look and feel"). `alert`, `confirm` and the file and folder choosers are the platform's (rfd); `ask` and `ask_color` are drawn in the window (DESIGN 12, "Windowed dialogs").

### G16. `edit_line.finish = proc` runs on Return

**Ruling: EXT** (Shoes 3.2.15). New row, 28 Sep 2026, from the wave-6 business lane.

- **Manual:** silent; an edit line has `change`, `focus`, `text` and `text=` (manual 3057-3104).
- **Shoes 3:** `rb_define_method(cEditLine, "finish=", ..., 1)` stores the proc as the field's `donekey` attribute, run when Return is pressed (`s3t_edit_line.c:15, 42-49`, "added in Shoes 3.2.15").
- **Lacci today:** until 28 Sep EditLine had no `finish=`, and Return in a focused line reached no Shoes code at all, since `keypress` skips unmodified keys while a field has focus (DESIGN 4.3). Kanban typed new cards into an edit box to hear the newline, and Ledger took Cmd-Return. Now `finish=` stores a proc, called with the line.
- **Spec:** `element.edit_line__finish` (native): typing does not run it, Return does, with the line holding its text.
- **Native:** Return, with no Control, Option, Command or Shift, in a focused edit line sends `finish` (DESIGN 4.3). An edit box takes Return as a new line. Webview sends nothing yet.

### G17. Colours on edit lines and edit boxes

**Ruling: EXT** (`ext-scarpe`). New row, 28 Sep 2026, from the wave-7 ZARKING lane: an app drawn on warm paper had one white box with a blue ring in it, whatever its palette.

- **Manual:** silent on a field's colours; its look is the platform's (manual 73-79, see G15).
- **Shoes 3:** GTK and Cocoa draw the field; no style reaches its colours (`s3t_edit_line.c`, `s3t_edit_box.c`).
- **Lacci today:** until 28 Sep EditLine and EditBox declared `stroke` (the text's colour) but not `fill` or `border_color`, which were dropped as unknown keywords. Now both are styles of their own on both.
- **Spec:** `element.edit_line__colors` (native): `fill:` paints the box and `border_color:` its edge, on an edit line and an edit box; a field given no colours stays white with a blue halo; once `stroke:` colours the text, the focus halo and the caret take that colour instead of blue. Lacci's `test_fields_keep_their_colours` pins the styles.
- **Native:** `edit_line::Colors` reads `fill` (default white), `border_color` (default #c7c7cc) and `stroke` (default the accent blue) for the box, its edge, and the focused edge, halo and caret, as CSS's caret-color follows currentColor. The windowed `ask` dialog keeps the plain field. Webview ignores them.

## H. Events

### H1. `keypress` key values

**Ruling: MANUAL,** with **S3**'s platform mapping for macOS, **ruled 27 Sep 2026 (Q5)** by the orchestrator (Nick may overrule): **Cmd arrives as `alt_`** (`:alt_q`), as in Shoes 3. The default app menu may still quit on Cmd-Q before the app sees it. Shoes 4's `super_` is **EXT**.

- **Manual:** characters arrive as Strings; special keys and combinations as Symbols. "The modifier keys are `control`, `shift` and `alt`. They appear in that order." (manual 2219-2221). Shift only shows on special keys; Return is `"\n"`, but with modifiers it becomes `:control_enter`, `:shift_alt_enter` and so on; `Shift-Alt-7` is `:alt_&` (manual 2207-2249).
- **Shoes 3, GTK:** Return is `rb_str_new2("\n")` (`s3_gtk.c:760-762`); Ctrl or Alt plus a character becomes a Symbol (`:765-778`); a modified Return becomes `:enter` (`:817-819`); modifiers are applied alt, then shift, then control, each as a prefix (`:821-830`), giving `control_shift_alt_...`.
- **Shoes 3, Cocoa:** **Cmd and Alt both become `alt_`** (`if ((modifier & NSCommandKeyMask) || (modifier & NSAlternateKeyMask)) KEY_STATE(alt);`, `s3_cocoa.m:287-288`, and for plain characters `:296-297`); Ctrl is `control_` (`:291-292`).
- **Shoes 4:** CR is `"\n"`; prefixes `control_`, `shift_` (special keys only), `alt_`, `super_` for Cmd (`s4swt_key_listener.rb:27, 85-91`); any modified key becomes a Symbol (`:143-145`).
- **Examples:** `for_playtest/shoes-contrib/simple/simple-editor.rb:19-23` and `philippe_checked/editor.rb:19-23` bind `:alt_q` (quit), `:alt_c` (copy), `:alt_v` (paste), which are Cmd-Q, Cmd-C and Cmd-V on a Mac under Shoes 3. `philippe/minimal_editor.rb:119` accepts `:control_a, :alt_a`. `needs_deps/expert-irb.rb:80` waits for `"\n"`.
- **Lacci / WV today:** WV maps Enter to `:return` (`wv/subscription_item.rb:127`); prefixes are `alt_`, then `control_`, then `shift_` (`:147-158`); Cmd (Meta) is ignored; a modified special key loses its `:` and arrives as the String `"alt_left"` (`:158`); a modified character arrives as the String `"alt_q"` because Lacci only symbolises values that start with `:` (`subscription_item.rb:67-77`). Plus the double fire (X1).
- **Spec:** `press_key "a"` gives `"a"`; Shift-a gives `"A"`; F1 gives `:f1`; Return gives `"\n"`; Control-Return gives `:control_enter`; Control-Shift-Alt-PageUp gives `:control_shift_alt_page_up`; Alt-q gives `:alt_q`. `press_key` takes Shoes key names, so no case can press Cmd; the Cmd mapping (Cmd-q gives `:alt_q`) is checked in the native backend's own tests (`window.rs`, `command_is_named_alt`).
- **Native:** DESIGN 4.4. Since 27 Sep Cmd is named `alt_` (and still edits like Control in text fields), and Shift folds into characters with a US map, so `:shift_7` is `"&"` and `:shift_alt_7` is `:alt_&`. DESIGN 4.4 said Cmd maps to `control_` until then.
- **The colon key, 28 Sep 2026 (w9):** special keys cross the wire with a leading colon (`":left"`), and Lacci made a Symbol of any key name that starts with one, so the colon key's own `":"` arrived as `:""` and Hackety Hack's editor could not type `:width` or `b: 2`. Now a lone `":"` stays the String `":"`. **Spec:** `events.keypress.colon`.

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

**Ruling: S3, ruled 27 Sep 2026 (Q4)** by the orchestrator; Nick may overrule. `click`, `release` and `motion` report window (app canvas) coordinates for every slot, nested and scrolling ones included. Shoes 3's slot-relative frame inside slots with their own native surface is dropped; no example depends on it.

- **Manual:** silent. The motion example moves an oval by the reported coordinates in an app-level handler (manual 2264-2275), where every frame agrees.
- **Shoes 3:** the slot's click block gets the `x, y` it was called with (`s3_canvas.c:1056-1061`), and nested slots are called with the same coordinates unless the child canvas has its own origin (`:1045-1051, 1065-1068`). That flag is set only for a child slot drawn on its own native surface (`DC(c->slot) != DC(pc->slot)`, `:445-450, 586-590`), which Shoes 3 gives to scrolling slots; not traced further. Inside such a slot, coordinates are slot-relative. Motion is the same (`:1181-1193`). The app's top slot adds its scroll offset (`:1053-1054`).
- **Examples:** almost every coordinate reader binds at app level (`minesweeper.rb:256`, `tankspank.rb:362`, `othello.rb:304`, `curve-control-point.rb:33`, `mice-satellites.rb:24`). The one nested reader found, `examples/para_cursor_demo.rb:69-79`, passes x and y to `Para#hit`, which ignores them (`para.rb:232-234`).
- **Lacci / WV today:** WV computes coordinates relative to `e.currentTarget.getBoundingClientRect()`, that is slot-relative (`wv/subscription_item.rb:66-100`).
- **Spec:** app-level `click` reports window coordinates (every model agrees; every existing coordinate case sits at the window origin). `events.click__nested_window_coords`: a click at window (150, 40) on a stack placed at (100, 0) reports (150, 40).
- **Native:** since 27 Sep drawable clicks and SubscriptionItem `click`/`release`/`motion` all carry window coordinates (DESIGN 4.3), as **wire contract (g), 27 Sep 2026** says. Shoes 3's own motion adds the top slot's scroll offset while its click takes it away (`s3_canvas.c:1053-1061, 1181-1193`); native uses the window's coordinates for both. DESIGN 4.3 made SubscriptionItem coordinates parent-relative, WV's frame, until then.

### H4. The extra `mods` argument

**Ruling: MANUAL** arity. A trailing `mods` is **EXT** (procs tolerate it; lambdas would not).

- **Manual:** `click { |button, left, top| }`, `motion { |left, top| }` (manual 2187, 2259).
- **Shoes 3:** click and release get a fourth `mods`, motion a third (`s3_canvas.c:1061, 1193`); the strings are `"control"`, `"shift"`, `"control_shift"` (built for wheel at `s3_app.c:744-751`).
- **Lacci today:** motion calls `(x, y, mods)` with those same strings (`subscription_item.rb:47-54`); click and release pass three arguments.
- **Spec:** a `motion { |x, y| }` block gets two usable coordinates; `examples/motion_events.rb` (`|x, y, mods|`) runs under `ext-s33`.
- **Native:** sends `[x, y, ctrl, shift]`; Lacci builds `mods` (DESIGN 4.3).

### H5. `hover` and `leave` hand the block the slot

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.**

- **Manual:** the block "gets `self`, meaning the object which was hovered over" (manual 2200-2205, 2251-2257).
- **Shoes 3:** `CHECK_HOVER` calls the proc with `self`, the canvas (`s3_ruby.h:167-176`).
- **Examples:** `for_playtest/simple/menu1.rb:18` and `shoes-contrib/simple/simple-menu1.rb:18` (`hover do |box| if box.width < 170`).
- **Lacci today:** slot-level `hover { }` passes the SubscriptionItem, not the slot (`subscription_item.rb:37-46`), then a kwargs Hash on the double fire (X1); element-level `el.hover { }` passes nothing (`drawable.rb:416-422`). Since 27 Sep (`8d4e3ef`) `hover` and `leave` hand over the slot or the element.
- **Spec:** inside `stack { hover { |s| $s = s } }`, hovering sets `$s` to the stack.
- **Native:** sends `hover`/`leave` on transitions (DESIGN 4.3).

### H6. Registering a slot event twice: replace or add?

**Ruling: S3, 28 Sep 2026 (w9).** A slot keeps one handler per event: a second `click`, `keypress`, `hover`, `leave`, `motion`, `release` or `wheel` block given to the same slot replaces the first, as in Shoes 3. The manual is silent. The ruling was BOTH while nothing depended on either; Hackety Hack does. **Lacci change, done 28 Sep 2026.**

- **Shoes 3:** `EVENT_HANDLER` stores one proc per slot per event (`s3_canvas.c:934-955`), so the second replaces the first.
- **Shoes 4:** `motion` appends; change listeners accumulate (`s4_dsl_interaction.rb:23-26`, `s4_common_changeable.rb:13-16`).
- **Examples:** Hackety Hack's editor rebuilds its slot with `clear` for every program it opens and calls `keypress` again (`app/ui/editor/editor.rb`, `on_keypress`). `clear` keeps the slot's handlers (H9), so with handlers adding up, each key was typed twice once a second program had opened, three times after a third. No example gives one slot the same event twice at once: `native/legendary/weather_window.rb` and `ledger.rb` give each page its own `keypress`, and `visit` starts every page from nothing.
- **Lacci today:** slot and app events make a new SubscriptionItem per call (`app.rb:459-466`); element `click`/`change` replace `@block`. Since 28 Sep the new SubscriptionItem destroys any earlier one for the same event in its slot (`SubscriptionItem#replace_earlier_handlers`). Timers still add up: in Shoes 3 each is an object of its own, not a slot's style.
- **Spec:** `events.keypress__again_replaces` (a slot rebuilt with `clear` and given another `keypress` hears a key once, in the new block) and `events.click__again_replaces` (native); `lacci/test/test_slot_events.rb` checks the handler left behind. **Native:** nothing; the replaced SubscriptionItem is destroyed like any drawable.

### H7. `wheel`

**Ruling: EXT.** The spec asserts only that the first argument is positive exactly when the wheel moves up.

- **Manual:** silent (Shoes 3.3 added it).
- **Shoes 3.3:** the slot's wheel block gets `(dir == up ? 1 : 0, x, y, mods)` (`s3_canvas.c:1250-1251`). The app's top slot scrolls 32 px per notch whenever it has a scrollbar, block or no block (`s3_app.c:743`). Cocoa sends one event per unit of delta (`s3_cocoa.m:235-236`).
- **Examples:** `for_playtest/shoes3-tests/wheel/wheel1.rb` (Shoes 3.3 style), `for_playtest/shoes_manual/wheel.rb` (Scarpe-authored, `delta.round(2)`).
- **Lacci / WV today:** `(delta_float, x, y)`, positive is up (`wv/subscription_item.rb:171-184`, `subscription_item.rb:78-84`).
- **Spec:** wheel up gives a first argument above 0, wheel down gives one at or below 0.
- **Native:** sends `[delta, x, y]`, delta > 0 up (DESIGN 4.3), and scrolls the root independently of any wheel block (C6).

### H8. `start` and `finish`

**Ruling: MANUAL** for `start` and `finish` on slots, each handed the slot. `keydown`, `keyup`, `keyrelease` and `resize` are **EXT**. **Lacci change, done 27 Sep 2026.**

- **Manual:** `start { |self| }` fires "The first time the slot is drawn"; `finish { |self| }` fires on removal (manual 2195-2198, 2286-2289). See M26 for App `start` against `started?`.
- **Shoes 3:** `start` is a slot method (`s3_canvas.c:974-988`), sent after the first paint (`:180`, `:990-1016`); `finish` receives the slot (`:1030-1036`); `keydown`/`keyup` exist (`:950-952`).
- **Shoes 4:** adds `keyrelease` and `resize` (`s4_dsl_interaction.rb:32-35, 78-81`).
- **Lacci today:** `start` exists only on App and runs after the body with no argument (`app.rb:146-159`); `finish` on Slot fires on destroy with no argument (`slot.rb:209-219`, commit `1ce13b0`). No `keydown`, `keyup`, `keyrelease`, `resize`. Worse than a missing argument: `finish { }` written inside a slot's block runs against the App (B1) and raises `NoMethodError` at load time (the events writer's report). Since 27 Sep (`8d4e3ef`) slots have `start { |slot| }`, run once on the first heartbeat after it is registered (the display draws before that), and `finish` hands over the slot; written inside a slot's block, both belong to that slot. App-level `start` keeps its old timing.
- **Spec:** `stack { start { |s| $started = s } }` sets `$started` to the stack after the first frame; `finish { |s| }` gets the slot on `clear`.
- **A window closing, 28 Sep 2026 (w9):** Shoes 3 sends `finish` to every slot as its window closes: the window's own slot first (`shoes_app_remove`, `s3_app.c:107-114`), then each slot as `shoes_canvas_clear` removes it, after the slots inside it (`s3_canvas.c:282-308, 481-495`, `s3_ruby.c:599-608`), hidden slots too. Lacci's `App#destroy`, which every way a window closes goes through (its own close button, `close`, `quit`, Ctrl-C), now does the same, once per app, and logs a `finish` block that raises instead of keeping the window open. Hackety Hack saves the child's program and its window size from its lesson stack's `finish`, so closing it with the red button lost both. **Test:** `test/native/app_test.rb`, where the fake renderer closes the window.
- **Native:** the pump dispatches the first `heartbeat` after the first frame; `start` hangs off that point (DESIGN 5.4). Since the wave-5 shim lane, Shoes-Spec test code and `scarpe peek`'s steps run once every handler of that first heartbeat has run (`Scarpe::Native.after_first_heartbeat`), so the slots have started, and `wait_frames` beats the heart as the pump does, so a slot made by test code starts by the next frame. `events.start` passes; before, test code ran inside that heartbeat, ahead of the slot's own subscriber.

### H9. Slot event handlers survive `clear`

**Ruling: MANUAL** (Shoes 3 agrees). **Lacci change, done 27 Sep 2026.** New row, requested by the events writer.

- **Manual:** the hover/leave example clears its own stack in both handlers, and the background turns blue on hover and red again on leave (manual 2167-2185). That only works if `clear` leaves the handlers in place.
- **Shoes 3:** a slot's handlers live in its style hash (`EVENT_HANDLER`, `s3_canvas.c:934-944`), and `clear` walks only `contents` (`:759-775`).
- **Lacci today:** slot event methods make a SubscriptionItem child of the slot (`app.rb:414-422`), and `clear` destroys every child (`drawables/slot.rb:263-265`), so the first hover's `clear` removes the leave handler and the stack stays blue. Since 27 Sep (`8d4e3ef`) `clear` keeps the slot's SubscriptionItems, so its handlers survive, and so do its timers (B7); `visit` still starts from nothing.
- **Spec:** `events.hover_leave_example__back_to_red`: hover, then leave, and the stack is red again.
- **Native:** SubscriptionItems are doc nodes under the slot; once Lacci stops destroying them, the shim sends no `destroy` and Rust keeps routing to them.

### H10. Hotkeys the manual reserves for the console

**Ruling: MANUAL for Alt-/, since 28 Sep 2026** (Nick asked for the console that day; K8): Alt-/ opens the Shoes console, and the app never hears it. **OOS** for Alt-. and Alt-?, which open Shoes 3's file selector and manual: they reach the app as before. New row, requested by the events and app writers.

- **Manual:** "Alt-Period (`:alt_.`), Alt-Question (`:alt_?`) and Alt-Slash (`:alt_/`) are reserved for Shoes" (manual 2239-2240); Alt-/ (Cmd-/ on OS X) opens the Shoes console (manual 721-722, 843-844).
- **Shoes 3:** `shoes_app_keypress` looks at the key before any app handler: `alt_/` runs `Shoes.show_log`, `alt_?` `Shoes.show_manual`, `alt_.` `Shoes.show_selector`, and only another key goes on to the app (`s3_app.c:773-783`).
- **Scarpe until 28 Sep:** had no console window; nothing reserved these keys, so an app received them like any other.
- **Native:** since 28 Sep (the w10 scarpe lane) Rust answers `:alt_/` (Cmd-/ on a Mac, Q5) with a `console` message before a focused field or a `keypress` block sees it (`input.rs` `key_input`, DESIGN 4.2 and 4.4), and the shim opens the console (`Shoes.show_console`). **Test:** `tests/protocol.rs` (`alt_slash_asks_for_the_console_and_the_app_never_hears_it`) and `test/native/errors_test.rb`.
- **Spec:** no case; `events.keypress.reserved_hotkeys` stays in its `UNTESTABLE.md` (Alt-. and Alt-? are still out of scope), and `builtins.console_hotkey` is checked by `test/native/errors_test.rb`, since opening a second window is more than a spec case asserts.

## I. Timers

### I1. `animate`, `every` and `timer`: rate and counting

**Ruling: MANUAL** for `animate` (10 fps by default, the first frame is 0). **S3** for `every` (the count starts at 0) and `timer` (the spec does not assert its block's arity). **Needs fix 10.1** (the double fire).

- **Manual:** "If no number is given, the `fps` defaults to 10" (manual 1896-1897); "Starting with zero, the `frame` number tells the block how many frames of the animation have been shown" (manual 1883-1884); `every(seconds) { |count| }` without saying where `count` starts (manual 1989-1994, M31); `timer(seconds) { ... }` with no block argument (manual 2111-2114).
- **Shoes 3:** the default rate is 12 fps (`s3t_timerbase.c:83`); every timer kind calls its block with `frame`, reset to 0 on first draw and incremented after each call (`:34-36, 41-44`), so `every` counts 0, 1, 2 and `timer` gets 0.
- **Shoes 4:** `@framerate = @style[:framerate] || 10` and `@current_frame = 0` (`s4_animation.rb:17-20`); `every(n)` is `animate 1.0 / n` (`s4_dsl_animate.rb:32-34`).
- **Examples:** 23 files read `animate`'s frame. Two read `every`'s count (`examples/animate.rb:15`, `shoes3_only/switch/switch.rb:19`); neither depends on where it starts.
- **Lacci / WV today:** WV defaults to 10 fps (`wv/subscription_item.rb:24`) but pre-increments, so the first frame and the first count are **1** (`:25-39`); Lacci calls the `timer` block with nothing (`subscription_item.rb:33-36`); every callback fires twice (X1).
- **Spec:** the first `animate` frame is 0 and frames increase by 1; `animate` with no fps ticks about 10 times per `advance(1)`; the first `every` count is 0; `timer(0.1)` fires exactly once.
- **Native:** the Ruby pump owns timers (DESIGN 5.4); since 27 Sep `every` counts from 0 there, as `animate` does. Since 28 Sep (wave 8) a delay under a millisecond, `timer(0)` and `every(0)` included, is one millisecond, as Shoes 3 clamps it (`s3t_timerbase.c:72`); it had waited the default second, so the first of `5.times { |i| timer(i * 0.12) { } }` came last. **Spec:** `element.timer__zero_seconds`. Since 28 Sep (the w9 polish lane) a `timer(0)` runs once what was made before it is laid out, as Shoes 3 draws a canvas before it fires a timer: when one is due and the shim has sent Rust changes since, it pings Rust, which lays out what it was sent and pushes the rects before it answers, and reads them. Hackety Hack's tooltips make a para and size their background to it in a `timer(0)` (`app/ui/widgets.rb:141-146`); the timer used to run before Rust had the para, read its width as nil and raised `TypeError: nil can't be coerced into Integer`. **Spec:** `timers.classes__zero_after_layout` (native).
- **Wire contract (f), 27 Sep 2026:** `every`'s count starts at 0, and `animate`'s first frame is 0. DESIGN 5.4 said "every (count starts at 1)" until the layout lane moved it to 0 on 27 Sep, with Shoes 3 and Shoes 4.

### I2. `Shoes::Animation`, `Shoes::Every` and `Shoes::Timer`

**Ruling: MANUAL** (Shoes 3 agrees). **Lacci change, done 27 Sep 2026.** New row, requested by the events and elements writers.

- **Manual:** "Shoes contains three timer classes: the Animation class, the Every class and the Timer class" (manual 3411-3413); `animate » Shoes::Animation`, `every » Shoes::Every`, `timer » Shoes::Timer` (manual 1877, 1989, 2111).
- **Shoes 3:** `Animation`, `Every` and `Timer` subclass `TimerBase` (`s3t_timerbase.c:11-22`), and `animate`, `every` and `timer` make one each (`:131-153`).
- **Shoes 4:** `Shoes::Animation` and `Shoes::Timer`; `every` is an Animation (`s4_dsl_animate.rb:21-45`).
- **Lacci today:** all three return a `Shoes::SubscriptionItem` (`app.rb:414-422`, `drawables/subscription_item.rb:17`); none of the three classes exists. Since 27 Sep (`41a9811`) all three exist as SubscriptionItem subclasses, which `animate`, `every` and `timer` return; each announces itself to the display as `"SubscriptionItem"` (contract e).
- **Spec:** `timers.classes`, `element.animate__returns_animation`, `element.every__returns_every`, `element.timer__returns_timer`.
- **Native:** **wire contract (e), 27 Sep 2026:** if Lacci adds `Shoes::Animation`, `Shoes::Every` and `Shoes::Timer` as SubscriptionItem subclasses, they still announce themselves to the display as `"SubscriptionItem"`, so neither Rust nor the shim changes.

## J. Navigation

### J1. `url`, `visit` and pages

**Ruling: BOTH** for class-level and instance-level `url`. `page(:name)` is **EXT**. Add `location` (**MANUAL**, **Lacci change, done 27 Sep 2026**).

- **Manual:** only `visit(url)` and `location()` (manual 980-982, 1012-1018); no `url` entry; "When you switch URLs, a new App object is created" (manual 848-849, see M29).
- **Shoes 3 / Shoes 4:** class-level `url` on `class Foo < Shoes`. Shoes 4 anchors the page string as `/^page$/`, passes one capture, and makes a fresh instance of the class per visit (`s4_url.rb:4-43`); `visit` clears the app and sets `location` (`s4_dsl_interaction.rb:97-107`).
- **Examples:** `examples/url_routing_example.rb` (instance-level), `examples/shoes_subclass_app.rb`, `examples/internal_link_navigation.rb` (pages plus `link(click: "/page2")`); 7 files use `url`, 9 use `visit`.
- **Lacci today:** both class-level (`lacci/lib/shoes.rb:98-114`, copied onto the app through `pending_app_class`, `:152-190`) and instance-level `url` inside `Shoes.app` (`app.rb:401-409`); strings containing `(` become regexes; all captures are passed; an unknown URL prints `Error: URL '...' not found` (`app.rb:364-399`); `"/"` renders on first boot only when it is routed to `:index` (`app.rb:598-604`), so an app that routes `"/"` to another method shows nothing until it visits. Scarpe-only `page(:name) { }` with `visit(:name)` (`app.rb:355-362`, `docs/SCARPE_FEATURES.md:15-38`). No `location`. Since 27 Sep (`8e5a4cf`) `App#location` is the URL of the page on show, `"/"` until a visit. Since wave 5 the app shows `"/"` at boot whatever method it routes to (`app.visit__root_route`), so `expert/url.rb` draws its setup screen.
- **Spec:** after `visit "/about"`, the `/about` handler's content is shown and `location == "/about"`. Nothing about App identity across visits.
- **Native:** nothing special: a visit is a `clear` plus new creates.

### J2. `link(..., click: "/path")` visits the path

**Ruling: MANUAL.** Concordant. Shoes 3 calls `shoes_app_goto` (`s3_canvas.c:1116-1119`); Shoes 4 calls `app.app.visit` (`s4_link.rb:25-35`); Lacci calls `app.visit(@click)` for strings starting with `/` (`link.rb:14-31`). **Spec:** clicking `link("go", click: "/two")` shows the `/two` content. **Native:** sends `click` on the link.

## K. Built-ins and dialogs

### K1. What `ask` returns on Cancel, and its options

**Ruling: MANUAL, ruled 27 Sep 2026 (Q6)** by the orchestrator; Nick may overrule. `ask` returns `""` when the user cancels: the manual promises a String (manual 629-641), and Nick's commit `6ce3d28` chose `""` on purpose so legacy scripts can compare the answer. Shoes 3's `nil` loses. Accept `secret:` and `title:`. **Needs fix 10.6.**

- **Manual:** `ask(message)` returns a string (manual 629-641); `:secret` is "For: ask, edit_line" (manual 1385-1391).
- **Shoes 3:** `ask(msg, opts)` reads `:title` and `:secret`; the answer starts as `Qnil` and is set only on `GTK_RESPONSE_OK` (`s3_gtk.c:1772-1826`).
- **Docs:** "Classic Shoes: ask() returned nil on cancel; Scarpe returns """ (`docs/scarpe_shoes_incompatibilities.md:104-107`). Commit `6ce3d28` says the opposite ("Shoes3 likely returned empty string") to stop Hackety Hack's guessing game crashing on `nil.to_i`.
- **Lacci today:** `ask(message_string)` takes one argument (`builtins.rb:20-22`); WV returns `""` on Cancel; a `nil` answer would trigger the `osascript` fallback (X8). Since the wave-4 Lacci lane `ask` takes `secret:` and `title:` (and any other option) and hands them to the display as a third builtin argument; a plain `ask` still sends one. The native shim passes both on since wave 5.
- **Spec:** the runner answers an unanswered `ask` with `""`, the Cancel answer, and `harness/dialogs_never_open` pins it; no `osascript` runs. `builtins.ask.secret`: `ask("x", secret: true)` is accepted. A stubbed `nil` still comes back as nil (the stub is only a stand-in for a display).
- **Native:** the dialog reply carries `value` null and `cancelled: true` (DESIGN 4.1); since 27 Sep the shim turns a cancelled `ask` into `""` (`app_test.rb`, `test_a_cancelled_ask_is_an_empty_string`). Headless mode already answered `""` (DESIGN 5.2). Since the wave-5 shim lane the shim sends `secret` and `title` with the dialog request, and Rust's in-window modal shows a secret answer as bullets under the title in bold.

### K2. Option hashes on dialogs

**Ruling: EXT.** Accept and ignore unknown keys. Shoes 3.3 has `alert(msg, title:)` and `ask_open_file(title:)` (examples `shoes3_only/menus/menu2.rb:5`, `shoes3_only/cardflip.rb:80`); Lacci's built-ins take one positional argument each (`builtins.rb:20-50`), so these raise `ArgumentError`. **Spec:** `ext-s33` only. **Native:** passes a `title` through to the dialog when present. **Lacci change, unscheduled.**

### K3. `debug`, `info`, `warn` and `error`

**Ruling: MANUAL.** Route all four to the Shoes log. **Lacci change, unscheduled.**

- **Manual:** loggers for the Shoes console; `error` accepts exceptions (manual 719-844).
- **Lacci today:** `debug`/`info` print `[DEBUG]`/`[INFO]` (`builtins.rb:54-60`), and App aliases both to `puts` (`app.rb:546-547`); `warn` is Ruby's `Kernel#warn`; `error` is undefined, so it raises `NoMethodError` inside an app. Since the wave-4 Lacci lane `error` is a built-in: it prints `[ERROR]` and the message, or an exception's class and message, on stderr and returns nil. None of the four goes through `Shoes::Log` yet. Since 28 Sep (the w10 scarpe lane) `debug`, `info` and `error`, the built-ins and an app's own `info` and `debug`, also go to the Shoes console (K8), an exception with where it came from, and still print as before. `warn` stays Ruby's own `Kernel#warn`, which prints to stderr as before and does not reach the console.
- **Spec:** each call returns without raising, and the message reaches `Shoes::Log`. The app writer's cases look for the text on stdout or stderr, so they assume `debug` and `info` are not filtered by the log level; a level filter would turn them red.
- **Native:** nothing; the log is Ruby-side, and Rust `log` messages join it (DESIGN 4.2).

### K4. `font(path)` returns the family names

**Ruling: MANUAL.** **Lacci change, done 27 Sep 2026.** New row.

- **Manual:** "If the font is properly loaded, you'll get back an array of font names found in the file. Otherwise, `nil` is returned if no fonts were found in the file." (manual 766-767).
- **Lacci today:** sends the `font` builtin, then returns `Shoes::FONTS << File.basename(path, ".*")` whatever happened (`builtins.rb:13-18`): `font("/nonexistent.ttf")` returns an array ending in `"nonexistent"`. Since 27 Sep (`8e5a4cf`) `Shoes::FontFile` reads the family names from the file's name table; `font` returns them and adds them to `Shoes::FONTS` before asking the display to register the file, and a missing file or a non-font returns nil and is not sent. A URL still answers with its file name, since the file cannot be read before the display fetches it.
- **Spec:** `font("missing.ttf")` returns nil; loading a bundled Inter file returns an array that includes `"Inter"`.
- **Native:** registers the file (DESIGN 4.1 `font`) but sends no answer. To satisfy the ruling, the `font` builtin needs a reply with the family names the file contains.

### K5. `download` and its events

**Ruling: MANUAL.** Specced under a `network` tag that is off by default. **Lacci change, done 27 Sep 2026.** New row.

- **Manual:** runs in the background and "fires `start`, `progress` and `finish` events" (manual 906-975); only `finish` is shown (M30).
- **Lacci today:** `Shoes::App#download` (`download.rb:31-125`) calls `handle_failure` with one argument though it takes two, so every non-2xx response logs an `ArgumentError` instead; it requires `nokogiri` unconditionally; it runs the user's block on a background `Thread` (report 04, C4). Since the wave-4 Lacci lane `download` takes `start:`, `progress:` and `finish:` (a block is `finish`), each handed a `Download` with `response`, `length`, `transferred` and `percent`; `headers:` and `body:` shape the request beside `method:`; and `save:` writes the file, hands the finish event the download too, and leaves `response.body` nil with the headers kept. It no longer needs `nokogiri`. The whole body is read at once, so `progress` fires once, at 100 percent, and every event still runs on the download's thread.
- **Spec:** against a local HTTP server, `finish` fires once with the body and `start` fires before it. The imported `simple-downloader` case (wave 4) clicks its Download button with a URL on a closed local port and checks the row it appends; it passes on both displays since the wave-4 Lacci lane's `download` took `progress:` and `finish:` (it was held as `expect: fail` while they raised `ArgumentError: unknown keywords`).
- **Native:** display updates can arrive from that background thread; DESIGN 5.2 guards writes with a Mutex, which covers it.

### K6. `exit` stops the program at once

**Ruling: MANUAL.** **Lacci change, unscheduled.** New row, requested by the app writer.

- **Manual:** "Stops your program. Call this anytime you want to suddenly call it quits." Ruby's own is reachable as `Kernel.exit` (manual 741-746).
- **Shoes 3:** `exit` becomes `shoes_app_quit` only through `secret_exit_hook`, which is marked unused (`s3_ruby.c:864-866, 880-882, 909-912`); otherwise it is Ruby's `Kernel#exit`, which stops at once. Not traced further.
- **Lacci today:** `exit` is an alias of `Shoes.quit` (`lacci/lib/shoes.rb:258-261`, `app.rb:597-602`), which destroys every app and returns, so the rest of the block and the file keep running.
- **Spec:** `builtins.exit`: in a child program, nothing after `exit` runs, not even the rest of the block, and the program ends cleanly.
- **Native:** the pump must let a `SystemExit` end the process after telling Rust to `quit`.

### K7. `Shoes.show_manual` opens the manual in a window

**Ruling: S3.** **Lacci change, done 28 Sep 2026.** New row, from the Hackety Hack lane (w9).

- **Manual:** "welcome to Shoes' built-in manual. This manual is a Shoes program itself!" (manual 31). `Shoes.show_manual` is not documented; it is how Shoes 3's own console and Hackety Hack open it.
- **Shoes 3:** the manual is a Shoes app shipped with Shoes (`lib/shoes/help.rb`, not fetched), opened in a window of its own: the chapters and their sections down the left, the page on the right.
- **Examples:** Hackety Hack's Help tab calls `Shoes.show_manual` (`app/ui/mainwindow.rb:76-78`). An app for children should not send them to a browser: the Shoes Store's Kids shelf promises no links out.
- **Lacci until 28 Sep:** `show_manual` ran `open https://github.com/scarpe-team/scarpe/wiki`, which a test sandbox traps. Since 28 Sep it opens "The Shoes Manual" beside the app that asked (or as the app, with none running), drawn from `docs/static/manual.md` by `Shoes::Manual`: the index of chapters and sections as links, the page with its headings, paragraphs, code, lists, inline code and emphasis, and its `[[links]]` turning to the section they name. The pictures do not come with the manual, so they are left out. A copy of Scarpe without `docs/` says so in an alert rather than opening a browser. Since 28 Sep (the w9 integrate lane) a native package carries `docs/static/manual.md` beside Lacci, at the path `Shoes::Manual` reads, so a packaged app opens the manual too (`test/package/native_package_test.rb`), and reads it as UTF-8 whatever the locale: started from Finder, a packaged app has none, and read it as US-ASCII (`lacci/test/test_manual.rb`).
- **Pictures and lists, 28 Sep 2026 (w9 polish):** the pictures do come with Scarpe: every one the manual names sits beside it in `docs/static`, so the page draws each under the words it closes ("On Linux, here's how this might look:" and the screenshot). Where the text holds `{COLORS}` and `{INDEX}`, the window draws what Shoes 3's did (`help.rb` `color_page` and `index_page`, the w9 fidelity lane's `web/shoes3_help.rb`): every named colour on a swatch of itself, three to a row, its name and its `rgb` numbers on it, and the drawables under the class they come from, each linking to its section. `{SAMPLES}` listed the samples Shoes 3 came with; no samples come with this manual, so it draws nothing. A native package carries the pictures with the manual. The learner lane found the braces printed, and Basic Programming 4.6 sends children to the colour list. **Test:** `lacci/test/test_manual.rb` (`test_the_manual_draws_its_colours_classes_and_pictures`) and `test/package/native_package_test.rb`.
- **Spec:** `intro.manual_is_shoes_program` (both displays); `lacci/test/test_manual.rb` also turns a page.
- **Native:** nothing; the window is an ordinary Shoes app.

### K8. The Shoes console

**Ruling: MANUAL:** Alt-/ opens the Shoes console, and `debug`, `info` and `error` log to it (manual 719-844). **S3** for what it lists and how: Shoes 3's log window. **Native and Lacci change, done 28 Sep 2026** (the w10 scarpe lane, from Nick's decision that errors inside a running program's blocks be seen). New row.

- **Manual:** "Sends a debug message to the Shoes console. You can bring up the Shoes console by pressing `Alt-/` on any Shoes window (or `⌘-/` on OS X.)" (manual 719-722); "To view warnings and errors, open the Shoes console" (manual 843-844). Silent on what it looks like.
- **Shoes 3:** `Alt-/` runs `Shoes.show_log` (`s3_app.c:773-776`), a window of the log's entries, and a handler that raises is logged there by `shoes_canvas_error`, the same function Kernel's `error` is (`s3_ruby.c:269, 887`). A file that fails to load is logged and the log window opened (`s3_world.c:150-157`). `Shoes.show_console` (3.2.23) opens a terminal instead (`s3_app.c:1059-1073`, `s3_ruby.c:862`).
- **Scarpe until 28 Sep:** no console; `debug` and `info` printed, `error` printed to stderr, and a handler's error was a log line on stderr, which a packaged app double-clicked sends to a log file nobody reads.
- **Now:** `Shoes::Console` (`lacci/lib/shoes/console.rb`) keeps the last 500 lines: the three log built-ins, every error `Shoes.on_error` hears (K9), with where it happened and the program's own backtrace frames, and on native Scarpe's log lines at its log level. `Shoes.show_console`, Shoes 3's `Shoes.show_log`, and Alt-/ (H10) open "Shoes Console" in a window of its own, newest first, with a Clear button; one console a process. Unlike Shoes 3's, it never opens by itself, even when a file fails to load: Nick asked that it not pop open for ordinary apps. A program `Shoes.run_program` started has a console of its own. On the webview, which opens one window, `Shoes.show_console` cannot open it.
- **Spec:** none; opening a second window is checked by `lacci/test/test_console.rb` (Niente) and `test/native/errors_test.rb`.

### K9. `Shoes.on_error`

**Ruling: EXT** (`ext-scarpe`), a Scarpe addition, **done 28 Sep 2026** (the w10 scarpe lane). New row.

- **Manual and Shoes 3:** silent; Shoes 3 sent every error to its console (K8), where only a person could read it.
- **Scarpe:** `Shoes.on_error { |err| }` hands every block given it each error a handler, a timer or the startup raises, on the event loop, besides logging it; the app goes on, as with no block. `err` is a Hash with String keys (`Shoes::ErrorReport`): `class`, `message`, `backtrace`, `path` and `line` (the innermost frame outside Scarpe's code and Ruby's library, or where Ruby says a SyntaxError is; for a startup error, a frame in the program's own file first, however its path is spelled, since Ruby names a loaded file by its real path and on a Mac `/var` and `/tmp` are links into `/private`), and `during`: `startup` (reported by `Shoes.run_app` before the error goes on up), `handler`, `timer`, or `exit` (a program ended by an error, K10). Niente and the webview report startup errors only; their displays do not hand handler errors over. DESIGN 5.6.
- **The log, since the w10 land lane:** a timer or an animation that raises raises every time it runs, often in words that change (`[1, 2, 3].fetch(i)` says "index 4", then "index 5"), and native logged a line each time: an `animate(30)` whose block raised grew a packaged app's log on disk by some 23 MB an hour, and a 1 ms timer with a changing message by 1.2 MB in 5 s. Now the log says an error in full the first time it comes from a place (its class, the program's line, the kind of block), then one line as the count there reaches 10, 100, 1000 and so on, with the latest words. `Shoes.on_error` and the console still hear every one.
- **Test:** `lacci/test/test_error_report.rb` (with `test_the_program_frame_is_found_through_a_link_in_its_path`, w10 integrate lane); `test/native/errors_test.rb` (`test_shoes_on_error_hears_handlers_timers_and_startup`, and `test_an_error_raised_again_and_again_is_logged_once_then_counted`, w10 land lane).

### K10. `Shoes.run_program` runs a program in a process of its own

**Ruling: EXT** (`ext-scarpe`), a Scarpe addition, **done 28 Sep 2026** (the w10 scarpe lane, from Nick's decision that a program which never stops must not freeze Hackety Hack). New row.

- **Manual and Shoes 3:** silent. Shoes 3 ran a program inside itself: Hackety Hack's Run evaluated the child's code in Hackety Hack's own process (`lib/editor/code_editor.rb` `run`), so `while true` with no way out froze the whole window.
- **Scarpe:** `Shoes.run_program(path, dir: File.dirname(path), args: [])` returns a `Shoes::Program` with `pid`, `running?`, `status`, `stop` (TERM, KILL a second later, its renderer with it), `on_exit { |status| }`, `on_error { |err| }` (K9's Hash) and `on_output { |stream, line| }`, every block on the event loop. On native the program runs on the same Ruby and Scarpe (`exe/scarpe --native`, or a packaged app's own launcher with `SCARPE_RUN_FILE`, handed to `spawn` as one word so a path like `Hackety Hack.app` is not split at its space), reports on an inherited pipe (`SCARPE_REPORT_FD`, JSON lines) and stops when its parent does (`SCARPE_PARENT_FD`). Niente and the webview run it inside the app with a warning, as Shoes 3 did. DESIGN 5.5.
- **Test:** `test/native/program_test.rb` (a program that loops forever is stopped within 2 s and leaves no process; a button's error reports `handler` with its line; a syntax error reports `startup`; output arrives in order; killing the parent ends the program and its renderer; a launcher in a folder with a space in its name starts the program), `lacci/test/test_program.rb`, and `test/package/native_package_test.rb` (the launcher runs a given file; a packaged app runs a program of its own from a Finder-like start).

## L. Loader and environment

### L1. Where app code runs

**Ruling: S3** (top level). The manual's "Raisins" rule runs each app in an anonymous class, but the same note says Policeman, the Shoes 3 release this manual describes, "uses TOPLEVEL_BINDING" (manual 487-533). Lacci's `Shoes.run_app` does `load path` at top level (`lacci/lib/shoes.rb:205-240`). **Spec:** nothing about the sandbox. **Native:** nothing.

### L2. Case-insensitive `require`

**Ruling: OOS.** Shoes 3 on JRuby and Windows tolerated `require 'CSV'`; Lacci installs a `Kernel#require` shim with a map and a downcase fallback (`compat_require.rb:11-40`, commit `36fc931`). Loader policy, kept in the runner, not specced.

### L3. Constants

**Ruling: MANUAL** for the names, values unspecified. The manual lists `Shoes::RELEASE_NAME`, `RELEASE_ID`, `REVISION` (a Subversion revision) and `FONTS` (manual 600-614). Lacci parses them from `CHANGELOG.md` (`changelog.rb:17-50`), sets `REVISION` to a git SHA, and adds `RELEASE_TYPE = "LOOSE_SHOES"`, `VERSION = "0.5.0"`, top-level `::VERSION`, `::ShoesGemJailBreak = true`, `DIR` and `LIB_DIR` (`constants.rb:6-76`). **Spec:** each manual constant is defined. `REVISION` is blank whenever the app's working directory is not a git checkout, because `changelog.rb` runs `git rev-parse` in the current directory (so it is blank in every spec sandbox). Since the wave-4 Lacci lane it asks the Scarpe checkout itself (`git -C`), so `builtins.const.REVISION` passes from any directory; outside a checkout (a packaged app) `REVISION` is nil. Since wave 5 it reads the checkout's `.git` files (HEAD, loose refs, `packed-refs`, worktrees) instead of running git, which cost 13 to 19 ms per launch. **Native:** nothing.

### L4. Shoes 3 only widgets

**Ruling: OOS.** `plot`, `terminal`, `systray`, `spinner`, `switch`, `video` (VLC), `svghandle`, `menu`/`menubar`, `Shoes.settings`/`monitor`, `event`/`shoesevent`, `decoration`, `cache` (`docs/scarpe_shoes_incompatibilities.md:10-40`, `examples/legacy/shoes3_only/README.md`). Shoes 3 also ships `slider` (`shoes/types/slider.c`), which neither list mentions. The manual documents Video in full (manual 3435-3516) but ties it to VLC and optional builds, so it stays out of `core`. **Native:** DESIGN 7 reserves `Video` and `Slider` kinds; drawing a placeholder box is enough.

### L5. Scripts with no `Shoes.app`

**Ruling: MANUAL:** they must run. The spec smoke-tests them instead of asserting inside them. New row.

- **Manual:** the built-in examples run at the top level with no app (fences 581-584, 620-623, 634-637 and others; report 03).
- **Lacci today:** test code is hooked from `Shoes::App#initialize` (`app.rb:95-103`), so a script without `Shoes.app` can never run spec code, and the spec process writes no result (report 04, Surprise 3).
- **Spec:** the runner executes each such script with dialogs stubbed and asserts exit 0, no Ruby error, and no `osascript` spawn.
- **Native:** must answer built-ins with no App open (A5).

## N. Screen readers

### N1. A screen reader reads and works what Scarpe draws

**Ruling: EXT** (`ext-scarpe`). New row, 27 Sep 2026, after Nick ruled that Scarpe draws its own controls ("our buttons are OUR buttons"): what the operating system's controls gave a screen reader for free, Scarpe now has to give it.

- **Manual:** silent on screen readers. Its controls are the platform's own: "native controls (like edit lines and edit boxes) will match the look of the window theme" (manual 76-79).
- **Shoes 3:** native Cocoa and GTK controls (`s3_cocoa.m:1283-1289` sets an `NSTextField` and an `NSProgressIndicator`), which VoiceOver reads like any others. Text, shapes and images are painted into each slot's `ShoesView` (`s3_cocoa.m:1145`), and neither `s3_cocoa.m` nor `s3_gtk.c` mentions accessibility, so nothing tells a screen reader what is painted there.
- **Shoes 4:** SWT's native widgets, likewise.
- **Examples:** none ask for anything.
- **Lacci today:** nothing to name a picture with. Since 27 Sep, `image(path, alt: "...")` (`e51c23c`).
- **Spec:** `spec/accessibility/` (`display: native`): a button is named by its label; a check or radio carries its state and the text block after it; a field its live text (bullets when secret) and the text block before it; a list box its choice and items; text is static text, big text a heading, a link a link; decoration and hidden things stay out; and a screen reader's click, focus and new value run the app's own blocks.
- **Native:** every window carries an AccessKit adapter built from the document and layout, and the `a11y` and `a11y_action` ops read and work that tree (DESIGN 12, "Screen readers"). A ghost-window test reads it back through AppKit, as VoiceOver does.

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
| X15 | `alias_method :remove, :destroy` on Drawable binds the base `destroy`, so `slot.remove` skips the cascade and `finish`. | `drawable.rb:615`, `drawables/slot.rb:231-235` | Removed slots leak their children in Lacci; `finish` never fires on `remove`. | B5 | fixed 27 Sep (`64e1ca6`) |
| X16 | `App#destroy` (and its alias `close`) sends a nil-target `destroy`, which every App obeys. | `app.rb:109-113, 280-287` | Closing one window closes all of them. | A8 | fixed (wave 5): `close` closes one window while another is open |
| X17 | `all_drawables` seeds its queue with `[@document_root, @document_root.children]`, so the children Array itself lands in the result. | `app.rb:289-299` | Class-filtered finders hide it; `drawables()` with no filter returns an Array among the drawables. Matters to the spec finders. | spec API | unscheduled |
| X18 | `download`'s failure path calls `handle_failure(code)` against `def handle_failure(code, logger)`, requires `nokogiri` unconditionally, and runs blocks on a background Thread. | `download.rb:31-125` | Every non-2xx response logs an ArgumentError instead of failing cleanly. | K5 | failure path fixed 27 Sep (`3dcf19a`); `nokogiri` dropped in wave 4 (K5); blocks still run on the download's thread |
| X19 | Webview subscribes to `full_redraw_request`, `focus` and `scroll_top` with the wrong target (nil against id, or the reverse). | `drawables/slot.rb:243, 267` against `wv/slot.rb:14`; `edit_line.rb:45` against `wv/edit_line.rb:19`; `drawables/stack.rb:29` against `wv/stack.rb:8` | `slot.clear { }` never redraws in Webview; `focus` and `scroll_top` never arrive. The native shim subscribes by id and ignores `full_redraw_request` (DESIGN 5.2). | C5, G9 | WV only |
| X20 | The draw context's `fill`, `stroke`, `strokewidth`, `rotate`, `transform` and `translate` are copied onto every drawable that declares the style, text blocks and controls included, unless the call supplied it. | `drawable.rb:288, 353-361` | `stroke "#BBB"; button "Expert"` sends `stroke: [187, 187, 187]` on the Button and on later paras (confirmed on the wire): `simple/control-sizes.rb` draws every control in #dde, and minesweeper's buttons turn grey after a redraw. The manual's `stroke` and `fill` colour "any subsequent shape" (manual 1682-1687, 1833-1836). | D8, E10 | fixed 27 Sep (`668cbf0`); pinned by `art.stroke__shapes_only` |

## M. Manual errata and vague spots

M1 to M37 carry the numbers of the contradictions in `native/research/03_manual_inventory.md`, so "contradiction 12" and "M12" are the same thing. M38 and M39 come from the seed's errata table, and M40 from the Q8 ruling (B7). Where a behaviour row above already argues the point, the M row points at it.

### M1. `oval` radius: diameter or half?

**Ruling: ERRATA.** See E1. The manual contradicts itself: the `:radius` style is "half of the diameter" and doubling (manual 1352-1354), but `oval(styles)` calls `radius` "the width and height of the circle" (manual 1742), and two examples treat it as a diameter: White Circle puts `radius: 160` in a 200x200 window (manual 869-873), and the Art intro calls `radius: 100` "One-hundred pixels wide" (manual 1639-1645). Shoes 3 and Shoes 4 both double the style. **Spec:** `radius:` doubles; do not transcribe manual 1742, 869-873 or 1644-1645 as expectations. Inventory ids: `styles.radius`, `art.oval.positional`, `art.oval.styles`, `app.white_circle_example`, `art.stroke_fill_oval_example`.

### M2. `oval` with four arguments

**Ruling: MANUAL.** `oval(left, top, width, height)` (manual 1734), as the motion example uses it (`oval 0, 0, 100, 100`, manual 2269). Lacci draws that 200x100 (X14). See E1.

### M3. `rect` argument order

**Ruling: ERRATA.** See E3.

### M4. `border`'s first argument is a pattern

**Ruling: ERRATA.** The heading says `border(text, strokewidth: a number)` (manual 1925); the prose (manual 1927) and every example (manual 2826, 2839) pass a colour or pattern. **Spec:** `border red, strokewidth: 2` strokes 2 px of red inside the slot box. **Native:** DESIGN 6 strokes borders inside the box.

A border's width is its own, 1 unless given: Shoes 3 strokes it with `ATTR2(dbl, attr, strokewidth, 1.)` (`s3t_pattern.c:219`) and never reads the pen. Until 28 Sep 2026 Lacci's Border took an unset `strokewidth` from the draw context, so Weather Window's hairline chips came out 4 px wide after its mug handle set `strokewidth 4`. **Spec:** `element.border__own_strokewidth` (native).

### M5. `EditBox#text` and `EditLine#text` return a String

**Ruling: ERRATA.** The headings say `text() » self` (manual 3049, 3097); the prose says "Return a string of characters" (manual 3051, 3099). **Spec:** `edit_line(text: "hi").text == "hi"`. Since 27 Sep Lacci's `text` is a String from the start, `""` until something sets it (`c91ffd6`, G12).

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

**Ruling: MANUAL:** pixels. `:size` is a "pixel size" (manual 1398) and the text blocks are "N pixels high" (manual 1923-2129, 3378-3384); the `:font` string's size is "in points" unless suffixed `px` (manual 1221-1223), which is Pango's convention leaking through. **Spec:** relative sizes only (a `title` is taller than a `para`; `font: "Arial 20px"` and `size: 20` lay out the same height). **Native:** treats every size as logical pixels.

**Shoes 3, checked 28 Sep 2026 (w9 polish):** Shoes 3 read every text size as points at 96 dpi. A numeric `:size` becomes `pango_attr_size_new_absolute(ROUND(i * PANGO_SCALE * (96./72.)))` (`s3t_textblock.c:288-293`), a String's number is taken with `to_i` first, and the default font is Arial at 14 points the same way (`s3_world.c:46-48`); the class sizes (para 12, title 34) go through the same line. So a Shoes 3 para was 16 px tall and a title 45. The fidelity lane measured it on screenshots of Hackety Hack 1.0 and 1.0.1: the editor's line pitch is 19 to 20 px there against 16 on native, and "Last saved less than a minute ago." is 245 px wide against 180. Every program written for Shoes 3 was laid out for text a third bigger than native draws it. **Extension, 28 Sep 2026: EXT** (`ext-scarpe`). A program can ask for Shoes 3's text before its first window with `Shoes.text_mode = :shoes3`: sizes are then points at 96 dpi, "px" stays pixels, a text block that names no face gets Arial, each line is as tall as its own text, as Pango sets lines (Hackety Hack's intro title is a 15 point " Welcome to" line over a 34 point "Hackety Hack"), and a para's marked range is yellow behind its text under a black caret, as Shoes 3 drew them (`s3t_textblock.c:187-197, 479-483`; DESIGN 4.1 `text_mode`, DESIGN 6). Hackety Hack asks for it. The default stays pixels, which every app built on native was laid out for; whether Shoes 3's reading should become the default is Q12. **Spec:** `styles.size__shoes3_text_mode` (native). **Test:** `text::rich::tests::shoes3_text_is_sized_in_points`, the protocol test `text_mode_shoes3_sizes_text_in_points`, and `lacci/test/test_app.rb`.

### M15. Style "For:" lists

**Ruling: OOS.** The lists name inline fragments where block alignment cannot apply, give `:leading` only to blocks, and mention `mask` and an element-level `gradient` that have no creation entry (manual 1144-1148 and the rest of the Styles Master List). The spec does not test style applicability from the For-lists.

### M16. The Styles Master List is not complete

**Ruling: ERRATA.** It claims to be "a complete list of every style" (manual 555) but omits the app styles `:title`, `:width`, `:height`, `:resizable` (manual 869-870), the download styles `:save`, `:method`, `:headers`, `:body` (manual 946, 958), and arc's `:angle1`/`:angle2` (manual 1669). The spec covers each where its own section documents it.

### M17. A Range of colours is a gradient

**Ruling: MANUAL,** as Shoes 3 reads it. `:fill`/`:stroke` accept "a range of either" (manual 1202, 1453) without explanation; Shoes 3 turns a Range into a linear gradient (`s3t_pattern.c:86-89`). See D6.

### M18. Is a String a colour or an image path?

**Ruling: S3.** A String that parses as a colour (hex, a named colour, `rgb(...)`) is a colour; anything else is an image path. The manual uses both (`fill "static/avatar.png"`, manual 1693; `"#DFA"`, 118; `"#333"`, 1793) with no rule. Shoes 3 tries `shoes_color_parse` first (`s3t_pattern.c:91-94`). **Native:** DESIGN 5.3 turns image paths and URLs into `{"image": path}` after colour parsing fails.

### M19. `background ... right: 50` is "on the right-side"

**Ruling: MANUAL, 28 Sep 2026 (w9 polish);** it was ERRATA; Nick may overrule. `background black, width: 50, right: 50` (manual 2792) is described as "a fifty pixel column on the right-side of the window", and that is how Shoes 3 draws it. A background or border is placed with `shoes_place_decide(..., REL_TILE)`, which measures a `right` or `bottom` offset against the pattern's own size, not the size given it: `tw` and `th` start as the `dw` and `dh` the pattern passes and are not replaced for REL_TILE (`s3_ruby.c:473-520`), and those are `PATTERN_DIM(self_t, width)` and `(..., height)` (`s3t_pattern.c:175, 217`), which is `self_t->cached != NULL ? self_t->cached->x : 1` (`shoes/types/pattern.h`, fetched 28 Sep 2026 as `native/research/sources/s3t_pattern.h`). So a colour or a gradient counts as 1 px: the column's left edge sits 51 px in from the window's right edge, and it runs to 1 px short of it. The v1 ruling read `:right` as it reads for elements (manual 1356-1364, C10), which put the column 50 to 100 px in.

- **Examples:** Hackety Hack draws the gradient at the foot of its window with `background "#e9efe0".."#c1c5d0", :height => 150, :bottom => 150` (`app/ui/mainwindow.rb:63`); the Ubuntu 1.0.1 screenshot shows it along the bottom 150 px, where native hung it at y 249 to 399 with a hard edge across Home, the Editor and the Lessons list (the w9 fidelity lane). `shoes-contrib/elements/background-column.rb` draws the manual's column. A background or border given a far-edge offset and no size keeps the inset reading, which Shoes 3 would have put almost wholly past the slot: nothing written for Shoes 3 does that, and the legendary kanban's cards (`background white, curve: 10, bottom: 2`) lean on it. A picture keeps its own size as its measure, which in every example is the width given it (form.rb's 55 px `menu-right.png`).
- **Spec:** `background.right_column`: the column covers x (width - 51) to (width - 2). **Native:** `layout::decor_box`; tests `a_sized_colour_or_gradient_is_placed_from_the_far_edge_by_one_pixel` and `right_and_bottom_place_from_the_far_edges`. See C10.

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

**Ruling: MANUAL.** Slot `start` fires the first time the slot is drawn (manual 2288); `App#started?` refers to "the start event which fires once the window is open" (manual 1008-1010). **Spec:** `started?` is false inside the app body and true inside a handler dispatched after the first frame. See H8. Since 27 Sep (`8e5a4cf`) Lacci's `started?` is false while the app block builds the window and true once it is open.

### M27. Can a click unmark a radio?

**Ruling: S3** (Lacci agrees): a click marks and never unmarks. The manual says clicks are sent "for both marking and unmarking" (manual 3354) and that Enter "toggles" a focused radio (manual 3358-3359), which fights the one-marked-per-group rule. Shoes 3 uses native radio buttons; Lacci's click handler "always check[s] on click (never toggle)" (`radio.rb:27-35`). **Spec:** clicking a marked radio leaves it marked and calls its block once; marking a second radio in the group unmarks the first. Whether the unmarked radio's block runs too is G14.

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

**Ruling: ERRATA.** `{INDEX}`, `{COLORS}` and `{SAMPLES}` (manual 1564, 1576, 3525) were never expanded in the text: Shoes 3's built-in manual drew them when it showed the page (`help.rb` `index_page`, `color_page`, `sample_page`). The colour list comes from Shoes 3's colour table and Lacci's `Shoes::COLORS`. Since 28 Sep Scarpe's manual window draws the first two the same way (K7).

### M39. The Messenger fix

**Ruling: ERRATA.** See B2.


### M40. `clear` and timers

**Ruling: ERRATA.** See B7 (Q8). "Empties the slot of any elements, timers and nested slots" (manual 2327-2329): Shoes 3's `clear` leaves the timers running (`s3_canvas.c:759-781`), and ten examples that clear their own slot from inside `animate` depend on it. **Spec:** `clear` keeps the slot's timers; do not transcribe manual 2327-2329's "timers" as an expectation. Inventory id: `manip.clear.stops_timers`.
## Where DESIGN.md disagrees with this ledger

`native/DESIGN.md` says "If the code and this document disagree, fix one of them in the same change." These are the places where DESIGN and a ruling above disagreed. Items marked Resolved were fixed in DESIGN on 27 Sep 2026 and stay listed for the record. Since the docs pass of the fourth build wave (27 Sep) every item is resolved.

1. **Cmd on macOS (H1, ruled with Q5).** Resolved 27 Sep: DESIGN 4.4 names Cmd `alt_`, as Shoes 3's Cocoa backend did (`s3_cocoa.m:287-288, 296-297`) and as the examples' `:alt_q`, `:alt_c`, `:alt_v` expect.
2. **`every`'s first count (I1).** Resolved 27 Sep: DESIGN 5.4 and the pump now count from 0, as Shoes 3 (`s3t_timerbase.c:35, 43-44`) and Shoes 4 (`s4_animation.rb:20`) do.
3. **Control widths (C4).** Resolved 27 Sep: DESIGN 6 and Rust give list_box and progress the manual's 200 px (manual 3183, 3245).
4. **Text in a flow (C7, ruled with Q2).** Resolved 27 Sep: DESIGN 6 and the layout continue text as one paragraph, as the ruling, the manual and Shoes 3 do.
5. **Text-block margins (C9, ruled with Q3)** and **leading (F10).** Resolved 27 Sep: DESIGN 6 and the layout give text Shoes 3's 4 px margins (12 px below) and 4 px of leading between lines.
6. **Nested-slot event coordinates (H3, ruled with Q4).** Resolved 27 Sep: DESIGN 4.3 gives SubscriptionItem `click`, `release` and `motion` window coordinates, as the ruling and contract (g) say.
7. **Default window (A1, ruled with Q1).** Resolved 27 Sep: DESIGN 6 and Rust fall back to 600x500, as Shoes 3 and Shoes 4 do, and Lacci's own default moved there the same day.
8. **Smaller points.** Resolved 27 Sep: DESIGN 6 states the Float rule `dim.rs` follows (C1). It had said "between 0 and 1 exclusive" and "1.0 = 100%" in the same breath; Shoes 3 treats every Float as a fraction. DESIGN 6 describes `right`/`bottom` (C10) and a fixed height clipping (C13) since 27 Sep. DESIGN 4.1's `ask` reply is `null` on Cancel in a window (`""` headless), and the shim hands Lacci `""` for either (K1, DESIGN 4.1 and 5.2).
9. **Wire contracts from 27 Sep 2026.** (a) the `layout` push (A4, C5); (b) `translate`, `transform` and `cap` in the draw context (E10); (c) the `image(w, h) { }` canvas (E9); (d) `underline`/`strikethrough` `"none"` (F7); (e) timer classes announced as `SubscriptionItem` (I2); (f) `every` from 0 and `animate` from frame 0 (I1); (g) window coordinates for SubscriptionItem mouse events (H3). Since 27 Sep DESIGN carries (a) in 4.2, (g) in 4.3, (f) in 5.4, and (b) and (c) in 12. (d) and (e) need no Rust change; since the docs pass DESIGN 4.5 lists all seven with where each lives. Resolved.

## Rulings on the questions (27 Sep 2026)

The evidence was balanced on each of these, so v1 asked Nick. The orchestrator ruled all seven on 27 Sep 2026, and Q8 later that day; Nick may overrule any of them, and his answer then replaces the ruling in the row. Each question is kept as it was asked, with the ruling under it.

- **Q1 (A1).** Should an app with no size open at **600x500 titled "Shoes"**, as Shoes 3 and Shoes 4 both do, or stay at Scarpe's **480x420 "Shoes!"**? The manual is silent. Changing it moves every snapshot of every example that does not pass a size (about 70% of them).

  **Ruled:** 600x500 titled "Shoes" (A1).
- **Q2 (C7).** Two `para`s side by side in a flow: should the second **continue the first as one paragraph**, its later lines wrapping back to the flow's left edge (manual 1610-1612 and Shoes 3), or be **its own box** beside or below the first (Webview today, DESIGN 6)? Single-line paras look the same either way. The paragraph model needs a first-line indent in the text layout.

  **Ruled:** one paragraph. A text block after other inline content starts at the current x (first-line indent), and its later lines wrap back to the flow's left edge (C7).
- **Q3 (C9).** Should text blocks get Shoes 3's **default margins (4 px, 12 px below)**, or Webview's **zero**? Shoes 3 examples were written with the gap; Scarpe-authored examples were written without it.

  **Ruled:** Shoes 3's margins, 4 px, 12 px below (C9).
- **Q4 (H3).** When a stack nested at (100, 100) has its own `click` handler, should a click at window (150, 120) report **(150, 120)** (Shoes 3) or **(50, 20)** (Webview, DESIGN 4.3)? No example found depends on either.

  **Ruled:** (150, 120), window coordinates (H3, wire contract g).
- **Q5 (H1).** On a Mac, should **Cmd-q arrive as `:alt_q`**, as in Shoes 3 and as the example editors expect, or as `:control_q`, as DESIGN 4.4 says? And should Cmd-Q still quit through the app menu before the app sees it?

  **Ruled:** Cmd arrives as `alt_` (`:alt_q`), like Shoes 3; the default app menu may still quit on Cmd-Q (H1).
- **Q6 (K1).** When the user cancels `ask`, should it return **nil** (Shoes 3's source) or **""** (your commit `6ce3d28`, which kept Hackety Hack's guessing game alive)?

  **Ruled:** `""`, Nick's deliberate choice (K1).
- **Q7 (G5), lower priority.** Your commit `eda8975` makes `edit_line.text = "x"` fire `change`, on purpose. Should the spec pin that under `ext-scarpe`, or keep asserting neither?

  **Ruled:** pinned under `ext-scarpe` (G5, `edit_line.text=__fires_change`).
- **Q8 (B7), found at the 27 Sep 2026 merge.** Does `clear` stop the timers started inside the slot, as the manual says (manual 2327-2329), or leave them running, as Shoes 3's source does and ten examples that clear the app from inside their own `animate` need?

  **Ruled:** `clear` keeps the timers (S3); the manual's line is ERRATA (M40). `visit` still stops them (B7).
- **Q9 (C14), found in wave 4.** Is an explicit `width` (or `height`) the element's **margin box**, margins inside it, as Shoes 3 does for slots and text blocks (`s3_ruby.c:506, 537`, `s3t_textblock.c:125-126`), or its **border box**, margins added outside, as DESIGN 12 and Webview do? The manual is silent. `menu1.rb`'s panels fit a row only under Shoes 3's rule; changing the rule moves every element that has both a px size and a margin.

  **Ruled:** the margin box (S3), so `menu1.rb` and `simple-control-sizes.rb` lay out as written (C14). The same day: a negative `left` or `top` on art is a plain coordinate (C15), and Scarpe's controls are its own (G15, Nick).

## Open questions (28 Sep 2026)

Raised by the Hackety Hack lane (w9). Each is asked the way the questions above were, with what Scarpe does until someone rules.

- **Q10 (C10, C15).** Should a negative `left` or `top` on an element that is not art be a plain coordinate, past the slot's left or top edge, as Shoes 3 reads every position (`shoes_px2` with `nv` 0, `s3_ruby.c:298-337`), or stay the slot less that much, as DESIGN 6 and C15 have it? Since 28 Sep a negative `right` or `bottom` follows Shoes 3 (C10). Hackety Hack's splash starts its hand at `top: -400`, above the window, and slides it down into view; native shows it 150 px down a 550 px window at once. `legacy/for_playtest/expert/othello.rb` puts its Undo button at `left: -150` and relies on today's reading to show it at the right; under Shoes 3 it would sit off the window.

  **Ruled by Nick, 28 Sep 2026:** "sounds good do it". A negative `left` or `top` is a plain coordinate on every element, as Shoes 3 reads it (C18). The Othello samples were written two months before _why made the change, and Shoes 3 put their Undo button off the window too, so they stay as written.

- **Q11 (E10).** Should every shape turn about its own centre by default, as Shoes 3.3's source does (`shoes_transform_new` starts in `s_center`, and `shoes_apply_transformation` turns about the shape's middle, `s3_canvas.c:31-41, 192-205`), making the manual's "Shoes defaults to `:corner`" (manual 1857-1860) ERRATA? Since 28 Sep a star and an arrow turn about the centre their `left` and `top` name. Rects, ovals, arcs and shape blocks still turn about their corner, which Scarpe's `rotate_shapes.rb` and the `art.rotate` cases are written against; `shoes-contrib/animation/rotating-star.rb` spins in place only about the centre, and `for_playtest/simple/path-animation.rb` asks for it with `center: true`.

  **Meanwhile:** the corner, as E10 ruled, with stars and arrows turning about their centre.

- **Q12 (M14).** Should a text size be points at 96 dpi by default, as Shoes 3 drew it (`s3t_textblock.c:293`), rather than pixels, as the manual says ("pixel size", manual 1398)? Every Shoes 3 program, the examples under `legacy/` among them, was laid out for text a third bigger than native draws; every app built on native (the showcase, the legendary and Kids apps) was laid out for pixels, and would grow a third. Since 28 Sep a program can ask for Shoes 3's text with `Shoes.text_mode = :shoes3`, and Hackety Hack does.

  **Meanwhile:** pixels, as M14 ruled; a program asks for points with `Shoes.text_mode = :shoes3`.

- **Q13 (C17).** Should an element given only `top` or `bottom` keep the x its flow stood at, and one given only `left` or `right` keep the flow's y and take its place in the line, as Shoes 3 places them (`s3_ruby.c:521-525`, `s3_ruby.h:246-255`)? Today any one of the four takes an element out of the flow, placed from its slot's corner on the other axis. Programs written for Shoes 3 that place something by one axis after other content, such as Hackety Hack's turtle, would read as their authors saw them; nobody has counted the examples that lean on today's reading, and a `left`-only element that took a place in the line would move whatever follows it.

  **Meanwhile:** out of the flow, from the slot's corner.

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

- The fetched Shoes 3 and Shoes 4 files are vendored in `native/research/sources/` (MIT, fetched 27 Sep 2026), under the file names this page cites. A reader re-checks a citation there, or against `shoes/shoes3@master` or `shoes/shoes4@main` with the file-name mapping in "How to read this".
- When a Lacci fix lands, update the row's "Lacci today" field and the X row, and leave the ruling alone. If Nick overrules one of the 27 Sep 2026 rulings, replace the ruling line with his answer and its date, and retag the cases that cite the row.
- Line numbers in rows added on 27 Sep 2026 (A9, B6, C13, D9, E11, F12, G10 to G14, H9, H10, I2, K6, X20) are as of commit `36c6282`.
- New disagreements get the next free id in their area (C13, H9, ...). Ids are never reused or renumbered.

