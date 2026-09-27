# 09: Lacci fixes (DESIGN.md section 10, items 1 to 10)

Lane: lacci-fixes. Repo `<repo>`, branch `native-rust`, based on `fdcee7a`.
Line numbers below refer to the files after this change unless marked `(HEAD)`.

Every fix has a focused test in `lacci/test/`. "Fails before" was checked by copying the new
test files into a pristine `git archive HEAD` tree in the lane scratchpad and running them there;
"passes after" by running them in the working tree. Nothing was stashed or reset in the shared tree.

| # | Fix | Ruling (ledger row, research 06) | Test | Before on HEAD | After |
|---|---|---|---|---|---|
| 1 | SubscriptionItem fires each callback once | Lacci bug, research 06 §1.1 | `test_subscription_item.rb` (3) | 3 fail | pass |
| 2 | Shape sends its path after the block | MANUAL, E7 | `test_shape.rb` (2) | 2 fail | pass |
| 3 | prepend keeps source order; `index` is known at create; `before`/`after` | MANUAL, C5 | `test_slot_insertion.rb` (5) | 5 fail | pass |
| 4 | `list_box { }` is the change block; `choose` notifies the display | MANUAL, G2 and G3 | `test_list_box.rb` (2) | 2 fail | pass |
| 5 | `link(click: proc)` fires; `link.click { }` switches on `has_block` | MANUAL, J2 and F8 | `test_link.rb` (2) | 2 fail | pass |
| 6 | A nil builtin answer is final; `Shoes.rgb`; Niente answers dialogs | MANUAL, A5 and D4 | `test_builtins.rb` (4) | 2 fail, 2 error | pass |
| 7 | `#rgb` expands by 17; `rgb()` reads each component on its own | S3, D5; MANUAL/S3, D2 and D3 | `test_colors.rb` (+3, 1 updated) | 4 fail | pass |
| 8 | `ins` is the `Shoes::Ins` underline fragment | MANUAL, F1 | `test_text_drawables.rb#test_ins_is_an_underline_fragment` | fail | pass |
| 9 | `click`/`release` on non-widget drawables bind and send `has_click`/`has_release` | MANUAL, E8 | `test_pointer_events.rb` (4) | 3 fail, 1 guard passes | pass |
| 10 | Oval third positional argument is a diameter | MANUAL+S3+S4, E1 | `test_oval.rb` (3 updated) | 3 fail | pass |

Suite counts (exact commands in "Verification"):

| Suite | Before (HEAD) | After |
|---|---|---|
| `bundle exec rake lacci_test` | 105 tests, 193 assertions, 0 failures | 131 tests, 241 assertions, 0 failures |
| `bundle exec rake component_test` | 124 tests, 266 assertions, 0 failures | 125 tests, 267 assertions, 0 failures |
| in-process subset of `test/` (see "What was not run") | 21 tests, 96 assertions, 0 failures | 21 tests, 96 assertions, 0 failures |

---

## 1. SubscriptionItem fired every callback twice

- **Defect.** `subscription_item.rb` bound a typed handler per api name, then a second generic
  `bind_self_event(shoes_api_name) { |*args| @callback&.call(*args) }` (HEAD `:89-91`). Every
  `animate`, `every`, `timer`, `keypress`, `motion`, `click`, `release`, `wheel`, `hover` and `leave`
  block ran twice per display event; the second call got raw args plus a trailing
  `{event_name:, event_target:}` Hash (`keypress` saw `:left` then `":left"`).
- **Ruling.** Not a disagreement between sources; a Lacci bug (research 01 §4, research 06 §1.1).
  Manual: `animate(fps) { |frame| }` (`manual.md:1877`), `keypress { |key| }` (`manual.md:2207`).
- **Change.** Deleted the generic rebind in `lacci/lib/shoes/drawables/subscription_item.rb`.
  `@unsub_id` now holds the typed handler, which `#destroy` already unsubscribes.
- **Test.** `lacci/test/test_subscription_item.rb`: one `animate` dispatch gives `[0]`; one
  `keypress ":left"` gives `[:left]`; one slot `click` gives `[[1, 5, 6]]`. All three fail on HEAD.
- **Visible change.** Every app using slot or app level events or timers now runs its block once per
  event. Under webview, `animate` and `every` blocks used to advance twice per tick, so animations
  run at half the speed they showed before (which is the correct speed), counters count by one, and
  keypress editors stop double-typing. Affected: `examples/animate.rb`, `examples/motion_events.rb`,
  `examples/para_cursor_demo.rb`, `examples/progress.rb`, and 85 files under `examples/legacy/`
  (clock, pong, tankspank, the animation and events folders, and others; the Prism scan in the lane
  scratchpad lists them).

## 2. Shape sent `shape_commands: []` and mutated it afterwards

- **Defect.** `Shape#initialize` created the display drawable with an empty `shape_commands` Array,
  then filled that same Array inside the block with no `prop_change` (HEAD `shape.rb:25-32`).
  In-process displays saw the path only through aliasing; a display in another process never did.
- **Ruling.** MANUAL: a shape is one path built by `move_to`/`line_to`/`curve_to`/`arc_to` inside
  the block (`manual.md:1799-1812`); ledger E7. Research 01 §1b and §8 item 3 name the fix.
- **Change.** `lacci/lib/shoes/drawables/shape.rb`: the block runs inside a private `draw`, which
  suppresses per-command sends and then sends one `prop_change {"shape_commands" => full list}`
  (a copy). Commands added later through `shape.app { line_to ... }` each send the full list.
- **Test.** `lacci/test/test_shape.rb`: exactly one `shape_commands` prop_change carrying all three
  commands, and the Niente display holds the list; a later `line_to` is sent too. Both fail on HEAD.
- **Visible change.** None for webview (it re-renders on the prop_change). Displays out of process now
  receive the path.

## 3. prepend reversed its children; displays were not told positions; `before`/`after` missing

- **Defect.** `Slot#add_child` used `unshift` while prepending (HEAD `slot.rb:48-55`), so
  `prepend { para "p1"; para "p2" }` produced `[p2, p1, ...]`. The display was told only `parent_id`.
  `Slot#before`/`#after` did not exist.
- **Ruling.** MANUAL: `prepend` "Adds elements to the beginning of a slot" (`manual.md:2349`);
  `after(element) { }` and `before(element) { }` insert next to a child and return self
  (`manual.md:2315-2323`); Shoes 3 has both (`s3_canvas.c:731-743`); ledger C5.
- **Change.** `lacci/lib/shoes/drawables/slot.rb`: an insertion anchor. While `prepend`, `before` or
  `after` runs, `add_child` inserts each new child in front of the anchor sibling, so several children
  keep source order and nested inserts stay correct. `prepend` anchors on the first child, `before(el)`
  on `el`, `after(el)` on the child after `el` (nil anchor appends). A non-child raises
  `Shoes::Errors::InvalidAttributeValueError`. `append` and `prepend` share one block runner
  (`fill_with`), keeping the external-self behaviour. `App#before`/`#after` delegate to the current
  slot like `append`/`prepend` (`lacci/lib/shoes/app.rb`).
  Every drawable is in `parent.contents` before its `create_display_drawable_for` call (set_parent runs
  in `Drawable#initialize`, create runs at the end of each subclass initialize), so the shim's
  `index = parent.contents.index(drawable)` is right at create time.
  Niente now places display children at that index (`Niente::DisplayService#index_in_shoes_parent`,
  `Niente::Drawable#add_child(child, index:)`), so it models what a remote display should do.
- **Test.** `lacci/test/test_slot_insertion.rb`: prepend order `["p1", "p2", "a"]`; a spy on
  `create_display_drawable_for` records `[["a",0],["b",1],["p1",0],["p2",1]]`; Niente children follow
  Lacci order; `before`/`after` give `a a2 b1 b2 c d`; `before` with a non-child raises. All five fail
  on HEAD.
- **Visible change.** `slot.contents` order after a multi-child prepend is now source order.
  Webview still appends every new child at the end of its own DOM list (`wv/drawable.rb` `add_child`),
  so webview shows prepended content last, as before. The two prepend examples
  (`examples/legacy/for_playtest/shoes_manual/prepend.rb`,
  `examples/legacy/for_playtest/shoes-contrib/manipulation/prepend-slot.rb`) prepend one child,
  so their Lacci order is unchanged.

## 4. ListBox dropped its block and `choose` told nobody

- **Defect.** `list_box(items: ...) { }` passed the block to `Drawable#initialize`, which ignores it;
  `@callback` was only set by `#change` (HEAD `list_box.rb:15-29`). `choose(item)` set `@chosen`
  with no `prop_change` and returned the item (HEAD `:35-41`).
- **Ruling.** MANUAL: the block is the change block (`manual.md:3186-3206`), `choose(item) » self`
  (`manual.md:3213`); Shoes 3 `s3t_list_box.c:106-107`, Shoes 4 `s4_dsl_element.rb:90-91`; ledger G2, G3.
- **Change.** `lacci/lib/shoes/drawables/list_box.rb`: `@callback = block`; `choose` goes through
  the `chosen=` setter (one `prop_change {"chosen"}`) and returns self.
- **Test.** `lacci/test/test_list_box.rb`: a `change "b"` calls the creation block with the box;
  `choose("c")` returns the box and the Niente display's `@chosen` is `"c"`. Both fail on HEAD.
- **Visible change.** List boxes with a creation block now react to selection:
  `examples/legacy/for_playtest/good/svgview.rb`,
  `examples/legacy/for_playtest/shoes-contrib/basic/list_box-select-class.rb`,
  `examples/legacy/for_playtest/shoes_manual/list_box.rb`, `examples/legacy/working/superleg.rb`.
  `choose` now updates the webview `<select>`: `examples/highlander.rb`, `examples/list_box_choose.rb`.

## 5. `link(click: proc)` never fired

- **Defect.** With `click:` a Proc and no block, `has_block` was false and `@block` nil
  (HEAD `link.rb:11-31`), and the Proc was sent to the display as the `click` prop.
  `link("x").click { }` after creation set the block but left `has_block` false, so webview rendered
  an `href` and the event never came.
- **Ruling.** MANUAL: `link(text, click: proc or string)` (`manual.md:2034`); the block gets the link
  (ledger F8, commit `19ad0d0`); internal routes unchanged (J2).
- **Change.** `lacci/lib/shoes/drawables/link.rb`: a `click:` Proc is removed from the styles and
  becomes the handler; `has_block` follows the handler. New `Link#click { }` sets the handler, sends
  `prop_change {"has_block" => true}` if it was false, and returns self. Link keeps its own
  no-argument `click` event (it does not take item 9's `(button, left, top)` binding).
- **Test.** `lacci/test/test_link.rb`: the proc runs with the link; create props carry
  `has_block: true` and no Proc; `link.click { }` turns on `has_block` on the display. Both fail on HEAD.
- **Visible change.** Links built as `link("x").click { }` now work in webview:
  `examples/legacy/for_playtest/shoes-contrib/manipulation/roll.rb`,
  `examples/legacy/for_playtest/shoes-contrib/simple/simple-menu.rb`, `.../simple-menu1.rb`,
  `examples/legacy/for_playtest/simple/menu.rb`, `.../menu1.rb`. No example uses `click: proc`.

## 6. A nil builtin answer was treated as "unhandled"

- **Defect.** `Shoes::Builtins#shoes_builtin` fell back to `osascript` whenever the consumed answer
  was nil (HEAD `builtins.rb:66-75`), so a cancelled file dialog (answer nil) opened a second, native
  dialog. `ask_color` in webview called `Shoes.rgb`, which did not exist; the rescue turned every
  pick into nil (`wv/document_root.rb:151`).
- **Ruling.** MANUAL for built-ins (`manual.md:616-716`; ledger A5). The manual says `rgb` "may also
  be called as `Shoes.rgb`" (`manual.md:815-834`; ledger D4).
- **Change.**
  - `lacci/lib/shoes/display_service.rb`: `DisplayService.builtin_response?` reads the existing
    `@has_builtin_response` flag. `lacci/lib/shoes/builtins.rb`: `shoes_builtin` returns the answer
    whenever one was given, nil included; only an unanswered builtin falls back.
  - `lacci/lib/shoes/colors.rb`: `class Shoes; extend Colors; end` gives `Shoes.rgb`, `Shoes.gray`,
    `Shoes.gradient`. The webview call site is unchanged and now works.
  - `lacci/lib/scarpe/niente.rb` and `niente/display_service.rb`: Niente answers every builtin the
    way a headless display does (`confirm` false, `ask` `""`, everything else nil), subscribed at
    require time, so a Niente run can never pop an osascript dialog. Later subscribers (test stubs)
    still win because the last `set_builtin_response` is the one consumed.
- **Test.** `lacci/test/test_builtins.rb`: `builtin_response?` is true after a nil answer;
  `Shoes.rgb(10, 20, 30)`; a nil answer to `ask_open_file` returns nil with no fallback; Niente
  answers `[confirm, ask, ask_open_file, ask_color]` with `[false, "", nil, nil]`. The Niente tests
  replace `native_builtin_fallback` on the app first, so even the HEAD run opened no dialog.
  Two fail and two error (NoMethodError) on HEAD.
- **Visible change.** Webview: cancelling a file or folder dialog no longer opens a second one;
  `ask_color` returns `[r, g, b, 255]`. Builtins called before any app exists still fall back to
  osascript on every display (nothing is subscribed yet).

## 7. Colours: short hex and per-component `rgb()`

- **Defect.** `to_rgb("#abc")` multiplied each nibble by 16 (`[160, 176, 192, 255]`, HEAD
  `colors.rb:229-235`). `rgb()` chose Float or Integer mode from `r` alone (HEAD `:168-176`), so
  `rgb(0, 0.4, 0)` returned `[0, 0.4, 0, 255]`, and named colours stored a Float alpha verbatim
  (`red(0.2) == [255, 0, 0, 0.2]`). Mixed arrays rendered black in Calzini.
- **Ruling.** S3 for hex: each digit x17, `#DFA` is `#DDFFAA` (`s3t_color.c:286-293`; ledger D5;
  `manual.md:118` uses `"#DFA"`). MANUAL/S3 for `rgb`: `rgb(0, 0.4, 0)` is dark green
  (`manual.md:824-832`); Shoes 3 applies `NUM2RGBINT` per component (Float x255 rounded, Integer as is,
  `s3_ruby.h:130`, `s3t_color.c:216-224`; ledger D2); alpha means opacity (D3).
- **Change.** `lacci/lib/shoes/colors.rb`: `rgb(r, g, b, a = 255)` maps each component through
  `color_byte` (Float to `(x * 255).round`, Integer as is, both clamped to 0..255). `gray` and the named
  colour methods go through `rgb`, so every Lacci colour is four Integers 0..255. Short hex x17.
  `scarpe-components/lib/scarpe/components/calzini.rb`: new `rgba_css(color)` turns an Integer alpha
  into the CSS fraction (a Float alpha passes through); used by the four raw `rgba(...)` emitters in
  `calzini/background.rb`, `calzini/border.rb`, `calzini/slots.rb` (2). Without it, integer alpha
  would make translucent webview backgrounds opaque (CSS clamps `rgba(0,0,0,128)` to alpha 1).
- **Test.** `lacci/test/test_colors.rb`: `rgb(0, 0.4, 0) == [0, 102, 0, 255]`,
  `rgb(255, 0, 0, 0.3) == [255, 0, 0, 77]`, `gray(0.5) == [128, 128, 128, 255]`,
  `to_rgb("#DFA") == [221, 255, 170, 255]`; `test_default_colors_can_accept_alpha` now expects
  `black(0.5) == [0, 0, 0, 128]` and `red(0.2) == [255, 0, 0, 51]` (it asserted the Float before).
  `scarpe-components/test/calzini/test_calzini_slots.rb#test_stack_border_integer_alpha` expects
  `rgba(255, 0, 0, 0.2)`. Four colour tests and the Calzini test fail on HEAD.
- **Visible change.**
  - Code that reads colour arrays now sees Integers (`gray(0.5)` was `[0.5, 0.5, 0.5, 1.0]`).
  - Webview: mixed `rgb(int, float, ...)` colours stop rendering black and show the intended colour:
    `examples/legacy/for_playtest/expert/{curve-animation,minesweeper,tooltips}.rb`,
    `examples/legacy/for_playtest/shoes-contrib/animation/{animate-ovals,happy-trails}.rb`,
    `examples/legacy/for_playtest/simple/follow.rb`. All-float `rgb` colours shift by at most one unit
    per channel (127 vs 128): `examples/para/rainbow_2.rb`, `examples/legacy/working/shoes_manual/rectangle.rb`,
    and four files under `examples/legacy/for_playtest/shoes-contrib/`.
  - Webview: text colours given as short hex on paras go through `to_rgb` and change shade
    (`#abc` was `#A0B0C0`, now `#AABBCC`): `examples/para_cursor_demo.rb`, `examples/parse_xl_funnies.rb`
    and 13 legacy files. Short hex passed straight to CSS (backgrounds, borders) was already right.
  - Webview CSS text for opaque array colours changes from `rgba(0, 0, 255, 255)` to
    `rgba(0, 0, 255, 1.0)`; same pixels.

## 8. `ins` was an alias for `inscription`

- **Defect.** `alias_method :ins, :inscription` on `Shoes::Drawable` (HEAD `para.rb:314-315`, commit
  `2212244`) made `ins("x")` a 10px Para, so the real `Shoes::Ins` fragment (`text_drawable.rb:127-131`)
  was unreachable and `para "a ", ins("b")` created a second, standalone para.
- **Ruling.** MANUAL: `ins(text) » Shoes::Ins`, "Shoes styles with a single underline"
  (`manual.md:2025-2028`); `inscription` is the 10px block (`manual.md:2030`); Shoes 4 agrees
  (`s4_dsl_text.rb:108-116`); ledger F1.
- **Change.** Removed the alias in `lacci/lib/shoes/drawables/para.rb`. `ins` now resolves through the
  normal drawable lookup to `Shoes::Ins` (a TextDrawable, parent nil, `underline: "single"`).
- **Test.** `lacci/test/test_text_drawables.rb#test_ins_is_an_underline_fragment`: `ins` is a
  `Shoes::Ins` with `underline "single"`, and the para's `text_items` are `["can be ", <ins id>]`.
  Fails on HEAD.
- **Visible change.**
  - `examples/span.rb` renders as the manual intends: the underlined words sit inside the para.
    The webview test `test/test_text_drawables.rb#test_bug_with_confusing_ins_and_inscription`
    expects exactly that markup, so it should now pass (not run here, it opens a window).
  - Standalone `ins "..."` lines now create a fragment with no slot, which draws nothing, as in
    Shoes 3: `examples/clear_and_append.rb:5`, `examples/text_sizes.rb:9`, `examples/para/sizes_2.rb:11`,
    `examples/skip_ci/change_my_audio_source.rb:8-9`. These examples used `ins` to mean `inscription`.

## 9. `click`/`release` on non-widget drawables bound nothing

- **Defect.** `Drawable#click` and `#release` stored a block and bound no event (HEAD
  `drawable.rb:789-802`), so `rect.click { }`, `oval.click { }`, `para.click { }` never fired on any
  display. `Drawable#click` also wrote `@block`, which is EditLine's change handler, so
  `edit_line.click { }` silently replaced the change block.
- **Ruling.** MANUAL: `click { |button, left, top| }` and `release` (`manual.md:2187-2193`,
  `2277-2284`), and the `:click` style lists arc, arrow, oval, para, rect, shape, star, text blocks
  and more (`manual.md:1144-1151`); Shoes 3 `Shape#click/release` (`s3t_shape.c:33-36`); ledger E8.
- **Change.** `lacci/lib/shoes/drawable.rb`: `click` and `release` join the base events every
  drawable accepts. `Drawable#click`/`#release` store the block in `@click_block`/`@release_block`,
  bind the display's `click`/`release` event once (`listen_for_pointer`), call the block with
  `(button, left, top)`, send `prop_change {"has_click" => true}` / `{"has_release" => true}` once,
  and return self. Calling `click` again replaces the block without rebinding. Button, Check, Radio,
  Image and Link keep their own no-argument `click`; slots and the app keep the SubscriptionItem
  `click`. `shoes_events` now unions with the parent list (`|`) so `click` is not listed twice.
- **Test.** `lacci/test/test_pointer_events.rb`: rect click and release get `(1, 20, 30)` and
  `(1, 21, 31)`; a para announces `has_click` and `has_release` exactly once and the second block
  wins; a button still gets its no-argument click and no `has_click` (guard, passes on HEAD too);
  `edit_line.click { }` no longer replaces the change handler. Three fail on HEAD.
- **Visible change.** Webview does not route presses on art or text, so nothing changes there beyond a
  re-render on the new prop. On a display that routes by `has_click`, these examples start working:
  `examples/legacy/for_playtest/expert/colours.rb:70` (rects),
  `examples/legacy/for_playtest/expert/curve-control-point.rb:23-27` (ovals, click and release drag),
  `examples/legacy/working/shoes-dep-samples/expert-game-of-life.rb:18` (rects),
  `examples/legacy/shoes3_only/simple-chipmunk.rb:18-20` (ovals).

## 10. Oval third positional argument is a diameter

- **Defect.** `opt_init_args :radius, :height` stored the third positional as a radius and doubled it
  (HEAD `oval.rb:18-19, 33`), so `oval(10, 10, 50)` was 100 across.
- **Ruling.** MANUAL+S3+S4: "a width and height of `radius` pixels" (`manual.md:1716-1722`); Shoes 3
  maps positionals to `left, top, width, height` (`s3t_shape.c:347-352`) and doubles only the
  `:radius` style (`s3_ruby.c:393-395`); Shoes 4 `oval(left, top, diameter)` (`s4_dsl_art.rb:98-125`);
  ledger E1. The `radius:` style stays a true radius (`manual.md:1348-1354`).
- **Change.** `lacci/lib/shoes/drawables/oval.rb`: `opt_init_args :width, :height`. `oval(l, t, d)`
  is `d` across; `oval(l, t, w, h)` is `w` by `h`; `radius` is still derived as `width / 2`.
- **Test.** `lacci/test/test_oval.rb`: `oval 5, 10, 50` gives width 50, height 50, radius 25;
  `oval 5, 10, 50, 35` gives 50 by 35. The two keyword tests are unchanged. Three fail on HEAD.
- **Visible change.** Every oval drawn with three or four positional arguments halves its width
  (four-argument ovals keep their height). `examples/oval.rb` (lines 13 and 19) changes, as research 06
  predicted. Legacy examples, most of which were written for Shoes 3 and now draw as intended:
  `for_playtest/expert/{minesweeper,othello,pong,tankspank}.rb`,
  `for_playtest/philippe/fill_pattern_demo.rb`,
  `for_playtest/shoes-contrib/animation/{flowers,mice-satellites,pink-bubbles,pulsate}.rb`,
  `for_playtest/shoes-contrib/art/{bubble-bullseye,faded,oval-gradient}.rb`,
  `for_playtest/shoes-contrib/basic/{basic-oval-image,basic-oval-shape,basic-oval}.rb`,
  `for_playtest/shoes-contrib/events/motion-detect.rb`, `for_playtest/shoes-contrib/expert/expert-othello.rb`,
  `for_playtest/shoes-contrib/simple/simple-sphere.rb`,
  `for_playtest/shoes_manual/{motion,nested_ovals,oval,ovals,ovals_image}.rb`,
  `for_playtest/simple/path-animation.rb`, `shoes3_only/events/event4.rb`,
  `shoes3_only/simple-chipmunk.rb`, `working/shoes-dep-samples/expert-othello.rb`,
  `working/simple/clock.rb` (all under `examples/legacy/`).

---

## Verification

```sh
cd <repo>
NIENTE_LOG_LEVEL=warn bundle exec rake lacci_test      # 131 tests, 241 assertions, 0 failures
bundle exec rake component_test                        # 125 tests, 267 assertions, 0 failures
# In-process root tests only (no webview window, no dialog):
bundle exec ruby -Itest -Ilib -e '%w[test_flow test_image test_para test_stack test_web_wrangler].each { |f| require_relative "test/#{f}" }' \
  -- -n '/^(TestWebviewFlow|TestWebviewImage|TestWebviewPara|TestWebviewStack|TestWebWranglerMocked)#/'
                                                       # 21 tests, 96 assertions, 0 failures
rm -f lacci/test/niente_test.json                      # the Niente runs write it (gitignored)
```

Every changed Ruby file also parses and runs under Ruby 3.2.2 (a Niente smoke app exercising prepend,
after, shape, rect click, list_box, choose, oval, ins, rgb, confirm and `#abc`).

## What was not run

- `bundle exec rake test` as a whole: nearly every file under `test/` launches `exe/scarpe` with
  `wv_local`, which opens real webview windows (and could steal focus). Only the in-process classes above
  were run: `TestWebviewFlow`, `TestWebviewImage`, `TestWebviewPara`, `TestWebviewStack`,
  `TestWebWranglerMocked`.
- `rake test:check_html_fixtures`: it runs each top-level example in webview. These fixtures will need
  regenerating (`rake test:regenerate_html_fixtures`, which also opens windows) because of this lane:
  `oval` (item 10), `span`, `text_sizes`, `clear_and_append` (item 8), `para_cursor_demo` (item 7: short
  hex text colour and `rgba`), and `border`, `background_with_image`, `margin_check`, `simpler-menu`, `simple_slides`
  (item 7: `rgba(..., 255)` becomes `rgba(..., 1.0)`). I did not hand-edit fixtures.

## Notes for the other lanes

- **Shim, `index`.** Compute `index` as `Shoes::Drawable.drawable_by_id(id).parent&.contents&.index(drawable)`
  inside `create_display_drawable_for`; `Niente::DisplayService#index_in_shoes_parent` does exactly this.
  Rust should clamp it to the current child count.
- **Shim and Rust, pointer routing.** `has_click` / `has_release` arrive only as `prop_change`, never in
  create props (they are not Shoes styles). They can target any non-slot drawable, including a Para and
  text fragments (Strong, Em, Link, Ins), so Rust needs span-level hit tests for fragments. The event
  back is `click`/`release` with `[button, x, y]`. Links still use `has_block` and a no-argument `click`.
- **Shim, builtins.** A `set_builtin_response(nil)` is now final, so answer every builtin, including
  `font` and `alert`. Subscribe to nil-target `builtin` when `scarpe/native` is required, not in the
  service constructor, if pre-app dialogs (`ask_open_file` before `Shoes.app`) should go to Rust instead
  of osascript.
- **Normalisation.** Colours from `rgb`, `gray`, named colours and `to_rgb` are now four Integers 0..255.
  Raw arrays written by users can still hold Floats, so keep the per-component rule from DESIGN 5.3.
  `Shoes.rgb` exists.
- **Shapes.** Expect `create` with `shape_commands: []` and then one `props {shape_commands: [...]}`.
- **ListBox.** `choose` now sends `props {chosen}`.
- **Spec suite.** Niente answers dialogs headlessly (`confirm` false, `ask` `""`, others nil) and keeps
  display children in Lacci order. Relevant LEDGER rows: §1.1, C5, D2, D3, D4, D5, E1, E7, E8, F1, F8,
  G2, G3, J2, A5.
- **Not done, but close by.** The `:click` style (`rect(..., click: proc)`, `manual.md:1144`) still
  warns and is dropped. `Check#click` returns the block, not self. Webview ignores child order on
  insert (prepend shows last), as before.
