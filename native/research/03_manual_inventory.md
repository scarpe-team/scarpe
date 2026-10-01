# 03: Shoes manual feature inventory

Lane 03 output. Source of truth: `docs/static/manual.md` (3533 lines, read in full).

Deliverables in `<scratch>/research`:

- `manual_inventory.json`: 539 entries, keys exactly `id, section, signature, claim, example_lines, testability, version_note`.
- `build_inventory.py`: the generator. The inventory lives there as data; section paths and code-fence ranges are computed from the manual file, and it validates every entry (unique ids, every `example_lines` pair is a real fence, every source range inside the manual). Rerun with `python3 build_inventory.py`.
- `write_report.py`: regenerates this file from the JSON.
- `probe_lacci.rb`, `probe_lacci2.rb`, `probe_lacci3.rb`: Niente probes behind the Lacci divergence table below. Run from the repo root with `bundle exec ruby -Ilacci/lib -Ilib -Iscarpe-components/lib <probe>`.

## Reading the JSON

- `id`: stable slug, `<area>.<feature>[.<value>]`. Areas: `styles` (115), `element` (67), `events` (42), `art` (40), `builtins` (32), `rules` (27), `app` (24), `slot` (21), `common` (18), `video` (16), `slots` (11), `image` (11), `list_box` (10), `intro` (9), `radio` (9), `manip` (8), `edit_box` (8), `edit_line` (8), `background` (7), `check` (7), `textblock` (7), `border` (6), `button` (6), `install` (5), `progress` (5), `timers` (5), `colors` (4), `traverse` (3), `elements` (3), `andsoforth` (2), `shoes` (1), `classes` (1), `shape` (1). `slot.*` are the Position-of-a-Slot methods and `slots.*` the Slots overview; `element.*` is Element Creation and `elements.*` the Elements overview.
- `section`: heading path plus the source line range the claim comes from, e.g. `Shoes > Built-in Methods > alert [L616-627]`. The path is computed from the manual's headings, so an entry whose claim sits in another section's prose (e.g. `styles.width.percent_string`, sourced from the `style()` example) carries that section's path.
- `signature`: the heading text verbatim when the entry is a documented method or style (`alert(message: a string) » nil`). Style entries append the manual's `For:` list, e.g. `:align » a string  (For: banner, caption, ...)`. Value and behaviour entries use the literal code the manual shows (`align: "center"`), or `(prose)` when there is none.
- `claim`: one normative sentence, phrased so a spec can assert it.
- `example_lines`: `[start, end]` of whole code fences (the ```` ``` ```` lines inclusive). Every pair is a real fence; 91 of 92 fences are referenced. The one left out, `[589, 595]`, is plain Ruby (`"Plaster of Paris".reverse`).
- `testability`: `api` (Ruby object state alone), `visual` (needs pixels or layout, including computed `width`/`left` style metrics), `interactive` (needs a click, key, drag, hover or typing), `dialog` (native modal), `untestable` (install steps, history, performance claims, internal caching).
- `version_note`: only for Shoes-version-, platform- or era-specific behaviour, or a doc defect that changes how the entry should be read. Lacci divergences are NOT in the JSON; they are in the table below.

## Counts

| testability | entries |
|---|---|
| api | 197 |
| visual | 225 |
| interactive | 85 |
| dialog | 11 |
| untestable | 21 |
| **total** | **539** |

- 159 entries cite at least one example fence; 84 carry a version note.
- Interactive entries by the input they need (85): keypress 34, click 20, change (typing / selection) 13, focus + Enter/arrow keys 6, native control state / window chrome 5, hover / leave 4, motion / pointer position 2, release (mouse-up) 1.
- What Niente's Shoes-Spec DSL can drive today (`lacci/lib/scarpe/niente/shoes_spec.rb:170-175`): `trigger_click`, `trigger_hover`, `trigger_leave` on a proxy found by a finder named after the drawable (`button()`, `paras()`, `edit_line()`, plus `title()`/`banner()`/... by Para size, `find_button(text)`, `drawable(*specs)`). There is no synthetic trigger for change, keypress, motion, release, focus or Enter, so 61 interactive entries have no driver yet.
- The dialog class (11 entries) needs a stub: several examples call dialogs at the top level before any `Shoes.app` exists (fences 581-584, 620-623, 634-637, 649-655, 663-669, 676-679, 687-693, 701-704, 712-717, 773-779).

## Section map

Line ranges run from a heading to the line before the next heading of the same or higher level. Entries are counted by the start line of their source range.

| heading | lines | entries | fences | api | visual | interactive | dialog | untestable |
|---|---|---|---|---|---|---|---|---|
| # Hello! | 6-32 | 3 | 1 | 0 | 0 | 1 | 0 | 2 |
| ## Introducing Shoes | 33-80 | 4 | 0 | 0 | 3 | 0 | 0 | 1 |
| ## Installing Shoes | 81-149 | 8 | 1 | 2 | 1 | 0 | 1 | 4 |
| ## The Rules of Shoes | 150-534 | 29 | 17 | 18 | 7 | 1 | 0 | 3 |
| # Shoes | 535-570 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| ## Built-in Methods | 571-845 | 31 | 16 | 18 | 1 | 1 | 9 | 2 |
| ## The App Object | 846-1019 | 26 | 5 | 20 | 4 | 2 | 0 | 0 |
| ## The Styles Master List | 1020-1557 | 114 | 3 | 9 | 96 | 8 | 1 | 0 |
| ## Classes List | 1558-1565 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| ## Colors List | 1566-1577 | 2 | 0 | 1 | 1 | 0 | 0 | 0 |
| # Slots | 1578-1622 | 11 | 0 | 3 | 8 | 0 | 0 | 0 |
| ## Art for Slots | 1623-1869 | 40 | 7 | 6 | 34 | 0 | 0 | 0 |
| ## Element Creation | 1870-2155 | 61 | 6 | 35 | 19 | 7 | 0 | 0 |
| ## Events | 2156-2290 | 42 | 3 | 2 | 0 | 40 | 0 | 0 |
| ## Manipulation Blocks | 2291-2364 | 7 | 3 | 7 | 0 | 0 | 0 | 0 |
| ## Position of a Slot | 2365-2514 | 23 | 4 | 11 | 12 | 0 | 0 | 0 |
| ## Traversing the Page | 2515-2533 | 3 | 0 | 3 | 0 | 0 | 0 | 0 |
| # Elements | 2534-2558 | 3 | 0 | 1 | 2 | 0 | 0 | 0 |
| ## Common Methods | 2559-2751 | 19 | 5 | 8 | 11 | 0 | 0 | 0 |
| ## Background | 2752-2804 | 7 | 3 | 3 | 4 | 0 | 0 | 0 |
| ## Border | 2805-2859 | 6 | 2 | 2 | 4 | 0 | 0 | 0 |
| ## Button | 2860-2927 | 7 | 3 | 1 | 0 | 6 | 0 | 0 |
| ## Check | 2928-2999 | 7 | 2 | 3 | 1 | 3 | 0 | 0 |
| ## EditBox | 3000-3056 | 11 | 2 | 5 | 2 | 4 | 0 | 0 |
| ## EditLine | 3057-3104 | 8 | 1 | 2 | 3 | 3 | 0 | 0 |
| ## Image | 3105-3165 | 10 | 2 | 4 | 3 | 0 | 0 | 3 |
| ## ListBox | 3166-3238 | 10 | 2 | 6 | 1 | 3 | 0 | 0 |
| ## Progress | 3239-3271 | 5 | 1 | 3 | 2 | 0 | 0 | 0 |
| ## Radio | 3272-3360 | 9 | 3 | 2 | 1 | 6 | 0 | 0 |
| ## Shape | 3361-3367 | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| ## TextBlock | 3368-3408 | 7 | 0 | 6 | 1 | 0 | 0 | 0 |
| ## Timers | 3409-3434 | 5 | 0 | 5 | 0 | 0 | 0 | 0 |
| ## Video | 3435-3516 | 16 | 0 | 10 | 4 | 0 | 0 | 2 |
| # AndSoForth | 3517-3520 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| ## Sample Apps | 3521-3526 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| ## FAQ | 3527-3533 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

Level-3 headings (every documented method or style, 236 of them) all have an entry whose `signature` is the heading verbatim. Level-4 headings are prose sub-sections (Rules of Shoes, Stacks, Flows, and similar).

## The examples as a test corpus

- 92 fences. 77 contain `Shoes.app` and run as-is. The 15 that don't: `168-173` and `589-595` (plain Ruby), `277-288` and `300-313` (the Messenger class alone), and top-level builtin snippets `581-584, 620-623, 634-637, 676-679, 701-704, 724-727, 773-779, 795-798, 806-810, 822-825, 829-832`.
- 66 fences open with a `#!ruby` line. It is a Ruby comment, so harmless, but strip it when printing examples.
- Network or asset dependent: `916-929`, `938-951`, `962-975` (google.com), `3127-3132` (hacketyhack.heroku.com, dead), `1690-1696` (`static/avatar.png`), `3113-3119` (`static/shoes-manual-apps.gif`). Both static paths are relative, and the manual never says relative to what (contradiction 34).
- Fences that pop dialogs (need a dialog stub to run headless): `14-17, 581-584, 620-623, 634-637, 649-655, 663-669, 676-679, 687-693, 701-704, 712-717, 773-779, 2118-2125, 2698-2707, 2734-2744, 2953-2971`.
- Shoes-Spec has exactly one case taken from the manual: `ref/shoes-spec/cases/manual/examples/example_1.sspec` (the one-liner; its test body is `button().trigger_click` plus a TODO for asserting the alert). The other 804 cases are `scarpe_examples` (783), `drawables` (9 sspec), `test_code` (6), `legacy_examples` (4), `dsl` (2).

## Signature notation (read this before parsing signatures)

The manual's `name: description` inside parentheses is usually a DESCRIBED POSITIONAL argument, not a Ruby keyword. Treating them as keywords breaks those calls.

- Positional despite the colon: `alert(message: a string)`, `ask(message: a string)`, `ask_color(title: a string)`, `font(message: a string)` (really a file path), `visit(url: a string)`, `download(url: a string, styles)`, `rotate(degrees: a number)`, `radio(group name: a string or symbol)`, `displace(left: a number, top: a number)` (both places), `move(left: a number, top: a number)`, `choose(item: a string)`, `gray(the numbers: darkness, alpha)`, `rgb(a series of numbers: red, green, blue, alpha)`.
- Real keyword/style arguments: `link(text, click: proc or string)`, `list_box(items: [strings, ...])`, `border(text, strokewidth: a number)`.
- `(styles)` means a trailing style Hash. `» X` is the return value. `x = a type` headings are setters. `{ |a, b| ... }` gives block parameters. `:name » type` headings are style keys.
- Manual markup left unconverted from the Shoes built-in manual: `` `'text`' `` is Shoes emphasis (45 lines), `!man-*.png!` inline images (lines 46, 58, 71, 96, 100, 101, 110, 111, 129, 130), 117 `[[Target Label]]` wiki cross-references, `[[BR]]` line breaks (line 320-321), and unrendered placeholders `{INDEX}` (1564), `{COLORS}` (1576), `{SAMPLES}` (3525).

## Contradictions and vague spots

Numbered so builders can cite them. Line numbers are manual lines. Where Lacci picks a side, the probe result is given.

1. **oval radius: diameter or half?** Styles `:radius` (1352-1354) says half the diameter, so width = height = 2 x radius. But `oval(left, top, radius)` (1718-1719) says 'a width and height of `radius` pixels', `oval(styles)` (1742) says '`radius`: the width and height of the circle', and two examples only make sense with radius-as-diameter: White Circle (869-873, `radius: 160` inside a 200x200 window) and the Art intro (1639-1645, `radius: 100` is 'One-hundred pixels wide'). Lacci follows 1352: `oval top: 20, left: 20, radius: 160` has width 320, overflowing the example's window. Ids: `styles.radius`, `art.oval.positional`, `art.oval.styles`, `app.white_circle_example`, `art.stroke_fill_oval_example`.
2. **oval with four arguments.** 1734 documents `oval(left, top, width, height)`, used by the motion example (2269, `oval 0, 0, 100, 100`). Lacci's `init_args :left, :top` / `opt_init_args :radius, :height` (`lacci/lib/shoes/drawables/oval.rb:18-19`) makes that 200 wide by 100 high, an ellipse, not the 100x100 circle the example means.
3. **rect argument order.** The heading `rect(top, left, width, height, corners = 0)` (1749) and prose '(top, left)' (1751) disagree with every other shape (`left, top`), with `rect(styles)` (1774-1775), and with the example (1762, which works either way because both are 10). Lacci uses `init_args :left, :top, :width, :height` (`rect.rb:8`). Treat (left, top) as normative.
4. **border's first argument.** `border(text, strokewidth: a number)` (1925) names the first argument `text`; the prose (1927) and every example (2826, 2839) pass a colour or pattern.
5. **EditBox#text / EditLine#text return type.** Headings say `text() » self` (3049, 3097); the prose says 'Return a string' (3051, 3099).
6. **EditLine default size.** '200 pixels wide and 28 pixels wide' (3063). The second 'wide' means high; ListBox (3183) says '200 pixels wide and 28 pixels high'.
7. **keypress shift example.** 'you'll get the string "&" rather than `:shift_5`' (2224-2225) is about Shift-7, so the symbol should read `:shift_7`.
8. **motion block parameter names.** Documented as `motion { |left, top| }` (2259, 2262); the example (2271-2272) names them `|top, left|` and calls `@circ.move top - 50, left - 50`. Positionally consistent (first arg goes to move's left) but the names are swapped.
9. **displace wording.** 'displace it 2 pixels left and 6 pixels on top ... (22, 46)' (2597-2599): the element moves right and down. `:displace_left` (1165-1167) is clear that positive means right.
10. **width/height value types.** `:width`/`:height` are documented as 'a number' (integer pixels or decimal fraction, 1243-1245, 1543-1545). The manual also uses strings `"100%"` (2482, 2738), negative widths (`-200` = 100% minus 200, 337), `"10px"` strings (2696), and a decimal margin (`margin: 0.1`, 3250) that no style entry explains.
11. **gray's argument.** 'a level of darkness' (792), yet `gray(0.0)` is black and `gray(1.0)` white (796-797), so it is lightness. No default is documented; Lacci defaults `gray()` to 128 (`colors.rb:162`).
12. **Check section copy-paste.** 'Button methods are listed below' (2976) inside the Check section.
13. **Timers: two or three?** 3411-3413 lists three classes (Animation, Every, Timer), then 3421 says 'Both types of timers automatically start themselves'.
14. **font size units.** `:size` is 'pixel size' (1398) and text blocks are 'N pixels high' (1923-2129, 3378-3384), but the `:font` string's SIZE is 'size in points' unless suffixed `px` (1221-1223).
15. **style For-lists.** `:align`, `:justify`, `:emphasis` and friends list inline fragments (`em`, `link`, `span`, `sub`...) where block alignment can't apply, while `:leading` lists only block types. `:cap` lists `border`, `flow`, `stack`, `image` and `mask`. `mask` (in :cap, :click, :fill, :stroke, :strokewidth) and `gradient` as an element (:angle, :radius) have no creation entry anywhere.
16. **Styles Master List is not complete.** It claims to be 'a complete list of every style' (555) but omits app styles `:title`, `:width`, `:height`, `:resizable` (869-870), download styles `:save`, `:method`, `:headers`, `:body` (946, 958), arc's `:angle1`/`:angle2` (1669), and anything for download `start`/`progress` handlers (910).
17. **Range of colours.** `:fill`/`:stroke` accept 'a range of either' (1202, 1453). Never explained (presumably `red..blue` as a gradient).
18. **String: colour or image path?** `fill "static/avatar.png"` (1693) paints with an image, while `"#DFA"` (118) and `"#333"` (1793) are colours. No rule says how a string is classified.
19. **background column on the right.** `background black, width: 50, right: 50` (2792) is described as 'a fifty pixel column on the right-side of the window', but `:right` (1356-1364) puts the right edge 50px in from the slot's edge, so the column should float 50px in from the side.
20. **background tiling colours.** 'Colors and images will tile across the background' (1901-1902); tiling means nothing for a flat colour. The same sentence appears for border (1928).
21. **shape blocks: filled or not.** Rules (403-408) say shapes merged in a `shape` block are unfilled. The `shape` entry (1820-1824) says art inside a shape is 'not part of the line' and 'drawn as one' without saying whether fill applies.
22. **shape and skew signatures.** `shape(left, top)` (1799), but the only example calls `shape` with no arguments (1810). `line_to`, `curve_to` have no documented arguments; `arc_to` only by example (1812). `skew` is named in `transform` (1859) and documented nowhere.
23. **image(w, h) { } block.** Used in the Rules (415) to rasterise shapes; not documented under `image(path)` (2006).
24. **two click signatures.** `click { |button, left, top| }` (2187) is the slot/generic mouse event, while Button/Check/Radio `click() { |self| }` (2918, 2988, 3349) pass the control. Both are named `click`; which signature applies to which receiver is only implied.
25. **which elements get mouse events.** Events are documented for slots (2158-2161), but `:click` is a style on many elements (1146-1148) and `hover`/`leave` are only shown on slots. Lacci registers hover/leave/motion on every Drawable (`drawable.rb:18`).
26. **start event vs started?** `start` fires 'the first time the slot is drawn' (2288); App#started? (1008-1010) refers to 'the start event which fires once the window is open'. App-level vs slot-level start is not distinguished.
27. **radio unmarking.** Radio click fires 'for both marking and unmarking' (3354) and Enter 'toggles' a focused radio (3359), which conflicts with only-one-marked semantics: can the user unmark the last marked radio?
28. **prepend/before/after in handlers.** In a button handler you can call `para` directly without `append`, but 'this isn't the case with prepend, before or after' (2910-2913). Where the directly-added para lands (app's top slot or the button's slot) is unstated.
29. **App vs URL.** 'When you switch URLs, a new App object is created' (848-849), while `visit` 'changes the location' (1014). URL routing (the `url` class method, App subclasses) is not documented at all, though Lacci implements `url`/`page`/`visit` (`app.rb:355-401`).
30. **download events.** `download` 'fires start, progress and finish events' (910); only the finish block is documented.
31. **every's count.** `every(seconds) { |count| }` (1989) never says whether count starts at 0 or 1 (animate's frame starts at 0, 1883). Fractional seconds for `every`/`timer` are unspecified.
32. **change on programmatic text=.** Whether `edit_box.text = s`, `edit_line.text = s` or `list_box.choose(s)` fire the change block is unstated (3017-3019, 3040, 3213).
33. **:state on buttons, checks, radios.** `:state` lists button, check and radio (1412), but 'readonly' ('active but cannot be edited', 1420) has no clear meaning for a button.
34. **relative paths.** `image "static/shoes-manual-apps.gif"` (3117) and `fill "static/avatar.png"` (1693) don't say what the relative path resolves against (the script's directory or the current working directory).
35. **styling a whole class.** 'In some cases, you can even style an entire class of elements' (1023-1024), with no API documented.
36. **UTF-8 claim.** 'Ruby itself isn't Unicode aware' (434) is a Ruby 1.8-era statement.
37. **dead cross-references.** [[Search]] (560) and 'the `ListBox` section under `Native` controls' (2057-2058) point at pages that don't exist in this document; [[oval]] (1668) is a bare target without a section prefix.

## Lacci divergences found by probe (Niente, this clone)

Not part of the manual inventory, but builders will trip on them. Each row names the inventory id it bears on.

| inventory id | manual says | Lacci does (observed) |
|---|---|---|
| `element.ins` | `ins(text)` returns an `Ins` fragment with a single underline (2025-2028) | `ins "x"` returns a `Shoes::Para` because `Drawable#ins` is `alias_method :ins, :inscription` (`drawables/para.rb:315`). A correct `Shoes::Ins` class exists (`text_drawable.rb:127`, default `underline: "single"` at line 131) but the DSL can't reach it. |
| `colors.hex_strings` | `"#DFA"` (118) | `Shoes::Colors.to_rgb("#DFA")` returns `[208, 240, 160, 255]`; CSS expansion is `[221, 255, 170]` (digit x 17, not x 16; `colors.rb` 3-digit branch). |
| `art.oval.four_args / styles.radius` | see contradictions 1-2 | `oval 0,0,100,100` gives w=200 h=100; `oval 10,10,50` gives w=100; `oval radius: 160` gives w=320. |
| `builtins.gradient / styles.angle` | default gradient runs top to bottom (1077-1078) | `Gradient#angle` defaults to 45 (`colors.rb:198`, `@angle = angle || 45`). |
| `builtins.rgb.* / colors.named_methods` | returns a `Shoes::Color` | Returns a plain Array (`[r, g, b, a]`). `black(0.1)` gives `[0, 0, 0, 0.1]`, mixing integer channels with a float alpha. |
| `builtins.rgb.module_function` | `Shoes.rgb` works (834) | `NoMethodError: undefined method 'rgb' for class Shoes`. |
| `builtins.error` | `error(message)` logs (732) | `NoMethodError` inside an app. |
| `builtins.font` | returns nil when no fonts found (767) | `font("/nonexistent.ttf")` returns `["nonexistent"]`. |
| `app.started?, app.location, element.imagesize` | documented (1006, 980, 2017) | All three raise `NoMethodError`/`NameError`. |
| `app.Shoes.APPS` | `Shoes.APPS` | `Shoes.APPS` works; there is no `Shoes::APPS` constant. |
| `manip.before, manip.after` | documented (2315, 2320) | `Shoes::Stack#before` / `#after` raise `NoMethodError`. |
| `slot.scroll_height, slot.scroll_max, slot.gutter` | documented on slots | Raise `NoMethodError` on a Stack (`gutter` exists on App only, `app.rb:551`; `scroll_top` is a style and returns 0). |
| `events.start` | on slots (2286) | `stack.start {}` raises; `start` exists only on App (`app.rb:146`). `finish` works on slots. |
| `art.transform` | documented (1857) | `transform(:center)` raises on App (Image has its own `transform`, `image.rb:74`). |
| `image.full_width, image.full_height, image.path, image.path=` | documented (3143-3164) | Raise `NoMethodError` (Image has `url`, `size`, `replace(url)`). |
| `button.focus` | documented (2923) | Raises `NoMethodError` (ListBox, EditBox, EditLine have `focus`). |
| `video.play and the rest of Video` | documented (3450-3515) | `Shoes::Video` has only a `url` style; `play` raises. |
| `element.para.non_string_args` | unspecified | Arrays are joined (`para(["a","b"]).text == "ab"`), other objects use `inspect`/`to_s` (`#<Storage:...>`). |
| `element.fragment.text_setter_non_string` | `@counter.text = e.text.size` (3025) | Works: `strong("0").text = 5` reads back `"5"`. |
| `app.style.title` | unspecified default | Default title is `"Shoes!"`. |

Confirmed working under Niente (no divergence): `Shoes.APPS`, `mask`, rgb floats, named colours (`tomato` = `[255, 99, 71, 255]`), `TWO_PI`, `Window`, `owner` (nil), `check.checked=`, `radio.checked=`, `progress.fraction=`, `list_box` `items`/`choose`/`text`/`items=`, `edit_line`/`edit_box` `text`/`text=`, `para.replace`/`to_s`, `timer` stop/start/toggle, `style[:width]` readback (`"100%"`, `-200`), `title "x", size: 16`, `star` defaults `[10, 100.0, 50.0]`, `image(300, 300) { }` accepted, `keypress`/`release` return `SubscriptionItem`, `displace` leaves `left`/`top` untouched, `move` sets them.

## Version- and platform-specific material

- **Raisins vs Policeman** (the only explicit version split): rules 'The Main App and Its Requires' (487-533). Raisins runs each app in an anonymous `(shoes)` class with `include Shoes`; Policeman evaluates at `TOPLEVEL_BINDING`, so `main` is Ruby's top-level object and `Shoes::Para` must be written out outside `Shoes.app`. Ids: `rules.main_app_anonymous_class`, `rules.main_app_isolation`, `rules.temporary_vs_required_classes`.
- **Release constants**: `Shoes::RELEASE_NAME`/`RELEASE_ID` (Curious = 1) and a 'Subversion revision' `REVISION` (605-611). Lacci reads these from its changelog (`constants.rb:63-69`) and adds `Shoes::VERSION = "0.5.0"`.
- **Video** (3435-3515, `:autoplay`): VLC/ffmpeg-backed, optional per build ('novideo', none on PowerPC). All 16 `video.*` entries and `styles.autoplay` carry the note.
- **Console and hotkeys**: `debug`/`info`/`warn`/`error` write to a Shoes console opened with Alt-/ or Cmd-/ (721-722, 843-844); Alt-., Alt-? and Alt-/ are reserved (2239-2240).
- **Platform-only statements**: `ask_save_folder` is an alias of `ask_open_folder` on OS X (698-699); the font-format table (754-764); the OS X font-cache caveat (781-783); Japanese font names per OS (469-478, keyed on `RUBY_PLATFORM`); PowerPC has no video (44-45); edit_line/edit_box fonts can't be changed 'in current versions of Shoes' (3078-3079).
- **Packaging-era statements** (relevant to the packaging goal, untestable as written): no Ruby needed (86), .dmg/.exe installers and Linux self-build (100-102), launching with no file opens a file picker (129-131), Shy files (812-813).
- **Syntax**: this copy writes style hashes as `key: value` (Ruby 1.9+), front matter at 1-4 marks it as a Jekyll page, so it is a modernised copy of the Shoes built-in manual rather than a verbatim one. Nothing in it covers Shoes 4 (JRuby/SWT) differences.

## Suggested use by the spec builders

1. One spec file per JSON id, grouped by the id's first segment. `api` entries can run under Niente today. `visual` entries need the native backend's layout tree or a screenshot. `interactive` entries need new synthetic triggers (change, keypress, motion, release, focus) in addition to Niente's `trigger_click`/`hover`/`leave`.
2. Settle the contradictions before writing expectations. Items 1-3 (oval radius, oval four arguments, rect argument order) change drawn geometry, so whichever side is chosen decides what every screenshot or layout assertion involving ovals and rects expects.
3. Treat the 77 runnable fences as smoke tests: each must load without raising. The 15 fragments need wrapping in `Shoes.app` or a dialog stub.
