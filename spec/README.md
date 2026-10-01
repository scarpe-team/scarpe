# The Shoes spec suite

Executable claims about Shoes, checked against a display service. Most cases come from the
Shoes manual (`docs/static/manual.md`), one or more per entry in
`native/research/manual_inventory.json`. The format is Noah Gibbs' Shoes-Spec `.sspec`, the
same one his display-agnostic test system used, so any Scarpe display service can run them.

```
spec/
  run                     the runner (spec/run --help)
  README.md               this guide
  manual/<group>/         cases written from the manual, one directory per group
  manual/_examples/       three worked cases to copy from
  shoes_spec/             cases imported from Noah's Shoes-Spec corpus (generated)
  showcase/               a native check per app in examples/native/showcase
  kids/                   a native check per app in examples/native/kids
  accessibility/          what a screen reader meets and does (ledger N1, native only)
  harness/                self-tests for spec/run
  examples.yml            every example under examples/ and what we expect of it
  LEDGER.md               rulings where the manual, Shoes 3, Shoes 4 and Lacci disagree
  import_shoes_spec.rb    regenerates shoes_spec/
  generate_examples_yml.rb  refreshes examples.yml
  support/                runner code, the dialog stub, test assets, fakebin (trapped commands,
                          the sandboxed clipboard) and test/ (unit tests for the runner itself)
  results/                run output (git-ignored)
```

## Validate a case

From the repo root:

```sh
spec/run spec/manual/elements-common/element.button.block.sspec             # one case, on niente
spec/run spec/manual/widgets-text                                           # a whole directory
spec/run --check spec/manual/widgets-text                                   # front matter only, runs nothing
spec/run --display native spec/manual/widgets-text                          # on the Rust display
spec/run --keep -v spec/manual/elements-common/element.button.block.sspec   # keep the sandbox, show every message
```

Paths may also be given relative to `spec/` (`spec/run manual/widgets-text`). With no paths it
runs everything under `spec/`. The same runs through rake: `rake spec:run`, `rake spec:run[native]`,
`PATHS="manual/widgets-text" rake spec:run`, `rake spec:check`, `rake spec:examples`.

Your case is done when `spec/run --check` accepts it and `spec/run` reports it `pass`
(or `not_applicable` on niente for a `display: native` case, then `pass` on native once
the Rust display can run it).

## The file

```
---
manual: element.edit_line.block
lines: [1981, 1982]
testability: interactive
display: native
----------- app code
Shoes.app do
  @echo = para "nothing yet"
  @line = edit_line { @echo.replace "saw #{@line.text}" }
end
----------- test code
click_on edit_line
type_text "hi"
assert_equal "saw hi", para.text, "the block ran as the user typed"
```

Three parts, split by lines of dashes: YAML front matter, then `----------- app code`,
then `----------- test code`. The loader splits on any line that starts with five or more
dashes, so never put such a line inside your app code (not even in a heredoc).

Name the file after the manual entry: `spec/manual/<group>/<entry-id>.sspec`, where the group
is the directory your brief gives you (by default the part of the id before the first dot).
A second case for the same entry is `<entry-id>__<what differs>.sspec`,
e.g. `styles.width.percent_string__in_flow.sspec`. Windows cannot check out a path with a `?`
in it, so a predicate's `?` becomes `_p`, as in Ruby's own C: `check.checked?` is
`check.checked_p.sspec`, and its front matter still says `manual: check.checked?`.

### Front matter

| key | required | value |
|---|---|---|
| `manual` | yes | the entry id from `native/research/manual_inventory.json` |
| `lines` | yes | `[first, last]` lines of `docs/static/manual.md` the claim comes from |
| `testability` | yes | `api`, `visual`, `interactive` or `dialog` (copy it from the inventory unless you have a reason) |
| `display` | yes | `any`: plain Ruby state, runs on niente and native. `native`: needs layout, pixels or real input |
| `expect` | no | `pass` (default) or `fail`, or per display: `{niente: fail}` |
| `reason` | with `expect: fail` | why it fails today, in one sentence |
| `ledger` | when a ruling applies | the `spec/LEDGER.md` row, e.g. `C4` |
| `dialogs` | no | answers for dialogs the app calls before the test code runs, e.g. `{ask: "Nick", confirm: [true, false]}` |
| `timeout` | no | seconds, when a case needs longer than the default (20 niente, 40 native) |

`spec/run --check` rejects unknown keys, ids that are not in the inventory, and lines outside
the manual.

## The test API

Test code runs once, inside a Minitest test, in the same Ruby process as the app, after the
app block has finished and before any timer fires. Every Minitest assertion is available.

### Finding drawables (every display)

- One finder per drawable class, singular and plural: `button`, `buttons`, `para`, `paras`,
  `edit_line`, `edit_lines`, `list_box`, `list_boxes`, `check`, `radio`, `stack`, `oval`...
  The singular raises unless exactly one matches.
- Selectors are a class, `"@ivar"` (an instance variable of the app), `"$global"` or `"id:N"`.
  `button("@save")` works; `button("Save")` raises. Use `find_button("Save")` for a label.
- Name what you will assert on with an `@ivar` in the app code. Plural finders return
  drawables breadth-first, not in document order, so never index into `paras` for meaning.
- `title`, `subtitle`, `banner`, `tagline`, `caption`, `inscription` find paras by size.
  In Lacci they are Para subclasses (`Shoes::Title` and so on), so `paras` includes them
  (ledger F2). They match on the size name, so `title "x", size: 16` is only found as
  `para("@ivar")`.
- `drawable(MyWidget)` finds `Shoes::Widget` subclasses, which get no named finder.
- A finder returns a proxy that forwards to the Lacci drawable: `.text`, `.text=`,
  `.checked?`, `.style`, `.hide`, `.contents` and the rest. `respond_to?` answers for the
  drawable on both displays. `to_s` does not forward (the proxy's own `Object#to_s` wins):
  assert on `.text`, or call `to_s` in the app code and keep the result in a global.
- **Text fragments are not in the drawable tree.** `link`, `strong`, `em`, `code` and the
  rest live inside their para's text, so no finder reaches them (`codes` finds nothing).
  Keep the fragment in an `@ivar` or `$global` and, under niente, fire its event directly:
  `Shoes::DisplayService.dispatch_event("click", $link.linkable_id)`. On native,
  `click_on("link text")` clicks it through Rust, and `layout_tree` lists each fragment
  right after its para.

**Manipulate the app from app code, not test code.** Test code runs with the Minitest test as
`self`, so `$slot.append { para "x" }` in test code calls the `para` *finder*, which raises
`Don't know how to find drawables by "x"`. Put the `append`, `clear` or `prepend` in a button
handler in the app code and `trigger_click` it from the test.

### `display: any`

Assert on Ruby state. Drive the app with the proxy triggers:

| call | does |
|---|---|
| `proxy.trigger_click` | the drawable's click event (Check and Radio toggle as if clicked) |
| `proxy.trigger_change(value)` | EditLine and EditBox text, ListBox choice |
| `proxy.trigger_hover`, `trigger_leave`, `trigger_release(button, x, y)`, `trigger_motion(x, y)` | those events |
| `stub_dialog(kind, value)` | answer the next `alert`, `confirm`, `ask`, `ask_color`, `ask_open_file`... with `value` |
| `dialog_calls` | every dialog the app called, in order: `[[:alert, "Saved"], [:ask, "Name?"]]` |

On niente the triggers fire the Lacci event directly. On native `trigger_click` goes through
Rust's hit-testing, so the drawable must be visible and on top. Write `display: any` cases
that are true on both.

### `display: native`

Everything above, plus the native API (DESIGN.md section 8):

| call | does |
|---|---|
| `click_on(proxy_or_text)`, `click_at(x, y, button: 1)` | a real click through layout and hit-testing |
| `hover_at(x, y)`, `move_mouse(x, y)` | pointer motion |
| `drag([x, y], [x, y], ...)` | press, move through the points with the button down, release at the last; no time passes |
| `type_text(str)`, `press_key(name)` | keys into the focused input or the app (`"a"`, `:left`, `:control_a`, `"\n"`) |
| `wheel(dy, x:, y:)` | scroll at window point (x, y); see below for the sign |
| `layout_of(proxy)` | a Rect with `x`, `y`, `w`, `h` in window coordinates |
| `layout_tree` | every laid-out node as a Hash with **Symbol** keys (`:id`, `:kind`, `:x`, `:y`, `:w`, `:h`, `:visible`, `:text`), in paint order |
| `pixel_at(x, y)` | `[r, g, b, a]` |
| `snapshot(name)` | writes `spec/results/snapshots/<name>.png`, returns the path |
| `wait_frames(n = 1)`, `advance(seconds)` | pump the loop; `wait_frames` also beats the heart, so a slot made since starts; `advance` fires timers |
| `wait_until(timeout = 10) { cond }` | turn the loop in real time until the block is true, else fail: for what comes from outside the app, such as a program `Shoes.run_program` started, whose news arrives in real time while `advance`'s clock stands still |
| `focused_drawable` | proxy or nil |
| `a11y_tree`, `a11y_nodes` | what a screen reader meets: the window's Hash (Symbol keys: `:role`, `:name`, `:value`, `:toggled`, `:actions`, `:bounds`...) with `:children`, or every node in a flat list |
| `a11y_action(target, action, value = nil)` | what a screen reader does to a drawable, an id or a tree node: `:click`, `:focus`, `:set_value`, `:expand`, `:collapse` |

Every event a synthetic input causes has been dispatched by the time the call returns
(DESIGN 4.1), so assert straight after `click_on` or `type_text`. Use `advance` for
`animate`, `every` and `timer`; never `sleep`. Layout is deterministic because native runs
headless with bundled fonts (spec/run passes `--fonts bundled` through `SCARPE_NATIVE_ARGS`).

`wheel(dy, x:, y:)` takes `dy` in logical pixels with the browser's sign: `dy > 0` scrolls
down, towards the end of the content, so the content moves up by `dy`. A `wheel { |delta, x, y| }`
handler receives `delta = -dy`, positive for up (DESIGN 12, ledger H7). So `wheel 40, x: 10, y: 10`
scrolls whatever scrolls under (10, 10) down by up to 40 px and hands a wheel handler -40.
Without `x:` and `y:` it aims at the middle of the first window.

Mouse coordinates are window coordinates everywhere: `click_at`, `layout_of`, and the
`[button, x, y]` a `click`, `release` or `motion` handler receives, nested slots included
(ledger H3, ruled 27 Sep 2026; `events.click__nested_window_coords` fails on native until the
backend follows the ruling).

## Rules

1. **One behaviour per case.** If the claim has two halves, write two cases.
2. **Cite the manual.** `manual:` and `lines:` point at the sentence you are testing. If the
   manual is wrong or silent, find or request the `spec/LEDGER.md` row and cite it in `ledger:`.
3. **Assert what would break.** Every assertion must fail if the behaviour were wrong.
   `assert button` proves nothing: the finder already raised if it was missing. Prefer
   `assert_equal expected, actual, "what this means"`. Check the state before an action as
   well as after it, so a case cannot pass by doing nothing.
4. **No `dom_html`**, no webview helpers, no `Shoes::App.find_drawables_by` when a finder will do.
5. **Never a real dialog.** Answer dialogs with `stub_dialog` or front matter `dialogs:`.
   Unanswered ones get the headless answers (alert nil, confirm false, ask `""`, file and colour
   dialogs nil), which are also what each dialog returns on Cancel (ask's `""` is ledger K1),
   and are still recorded in `dialog_calls`. The runner fails any case that
   reaches `osascript`.
6. **No network, no sleeping, no writing outside the working directory.** Each case runs in a
   throwaway directory with its own `HOME`, `TMPDIR` and image cache; `say`, `open`, `afplay`
   and `osascript` are trapped.
   The clipboard is the file `ENV["SPEC_CLIPBOARD_FILE"]` in the sandbox, not the real one:
   `app.clipboard` reads it on every display and platform (the runner names it in
   `SCARPE_CLIPBOARD_FILE` too, which Lacci and the native renderer use in place of the system
   clipboard), and `pbcopy`, `pbpaste` and `xclip` read and write it for an app that runs them
   itself. Write that file to seed the clipboard, read it to see what the app copied.
7. **Images and fonts:** `spec/support/assets/` is copied to `assets/` in the case's working
   directory. Never inline base64 files or read fonts from the checkout; add small files here.

   | file | what it is |
   |---|---|
   | `red-40x30.png` | solid #ff0000 |
   | `red-40x30.jpg` | solid red JPEG (decodes to about #fe0000) |
   | `blue-40x30.jpg` | solid blue JPEG (about #0000fe) |
   | `green-40x30.gif` | solid #00ff00 GIF |
   | `checker-20x20.png` | 10 px black and white squares, black at the top left |
   | `Pacifico.ttf` | the Pacifico family (SIL OFL 1.1, `Pacifico-LICENSE`): `font File.expand_path("assets/Pacifico.ttf")` |
8. **`expect: fail` is a promise, not a hiding place.** Use it when the behaviour is right in
   the manual and wrong in Scarpe today, give the `reason`, and cite the ledger row. When the
   code is fixed the case reports `unexpected_pass` and fails the run until someone removes the
   `expect`. Use `{niente: fail}` for what Niente cannot do (timers, layout) but native should.
9. **`untestable` entries get no case.** Install steps and history stay in the inventory only.

## Statuses

| status | meaning | fails the run |
|---|---|---|
| `pass` | every assertion held | |
| `fail` | an assertion failed | yes |
| `error` | an exception, a crash before the test ran, an invalid case, or a real dialog attempt | yes |
| `skip` | the test code called `skip` | |
| `expected_fail` | failed or errored, and front matter says `expect: fail` | |
| `unexpected_pass` | passed, but front matter says `expect: fail` | yes |
| `not_applicable` | a `display: native` case on niente | |
| `timeout` | no result before the timeout | yes |

One case skips on purpose: `spec/harness/skipped.sspec` is the runner's own check that `skip`
reports `skip`. The imported cases that used to stop at a `skip` now drive the app instead
(`DRIVEN` in `spec/import_shoes_spec.rb`), or say in `expect: fail` what still stops them.

Failure messages point at the case file and line, e.g.
`Expected: "y" Actual: "x" (manual/para/element.para.sspec:14)`.

Each run prints a scoreboard grouped by directory and merges its rows into
`spec/results/<display>.json` (keyed by path, with counts), so separate runs of separate
directories add up to one picture. `spec/results/examples-<display>.json` holds the examples.

## Examples

`spec/examples.yml` lists all 473 examples under `examples/` with a `status`: `loads`,
`fails` (known broken, with a `reason`) or `skip` (Shoes 3 only, missing gems, the network,
side effects). `spec/run --examples` smoke-runs every non-skipped one:

- niente: the example loads with no Ruby error and keeps running for `--wait` seconds
  (default 3) or exits 0.
- native: `scarpe peek EXAMPLE --wait 1.5 --shot spec/results/gallery/<slug>.png`, then no Ruby
  error, no Rust panic, and a snapshot that is not one flat colour. Add `steps:` to click or
  type before the shot (`click`, `click_at`, `type`, `key`, `drag` through a list of points
  with the button down, and `wait` to let a timer tick, since the shot follows the last step at
  once). `dialogs:` answers the example's dialogs on both displays, the way a case's front
  matter does, so an app that asks before it draws (`if confirm(...)`) shows what it draws.
  `pixels:` lists `[x, y, "#rrggbb"]` the snapshot must show, for an example that draws
  something, just not the right thing (`expert/colours.rb`).
  `ruby:` names the Rubies a status holds on (`">= 4.0"`); on any other Ruby the example must
  load, so CI's oldest and newest Rubies run the same list.

Every `--examples` run also writes `spec/results/gallery/index.html`: one card per example with
its native snapshot, its path, and each display's status and error line, broken examples
first. It is built from both merged results files, so runs of separate subtrees and displays
add up to one page. Open it in a browser.

`spec/run --examples examples/legacy/working` runs a subtree. `--include-skipped` runs the
skipped ones too. When an example's status changes, edit its line in `examples.yml`;
`ruby spec/generate_examples_yml.rb` keeps your edits and picks up new or deleted examples.

## Screen readers

`spec/accessibility/` checks what a screen reader meets in a Scarpe window, which draws its own
controls and so owes the screen reader a description of them (ledger N1). The manual is silent
on screen readers, so these cases cite the ledger row and no manual entry. Static text carries
its words as `:value`; a control's `:name` is its label, or the text block beside it (after a
check or radio, before a field or list box):

```
flow do
  @keep = check
  para "Remember me"
end
...
node = a11y_nodes.find { |n| n[:role] == "check_box" }
assert_equal ["Remember me", false], node.values_at(:name, :toggled)
```

## The imported Shoes-Spec corpus

`spec/shoes_spec/` holds the 181 cases from Noah's Shoes-Spec corpus that make a real
assertion. `import_manifest.yml` records every one of the 805 source cases and why it was
imported, merged into a duplicate, dropped or rejected. The files are generated: change them
through `RULINGS` or `FIXES` in `spec/import_shoes_spec.rb` and re-run
`ruby spec/import_shoes_spec.rb PATH/TO/shoes-spec/cases`. Do not copy them into
`spec/manual/`; they test examples, not manual claims.

## When a case misbehaves

- `no result (exit 1): ...` means the app raised before the test code ran. The message shows
  the case line.
- `no result (exit 0): the test code never ran` means the app never called `Shoes.app`.
- `--keep` leaves the sandbox (`app.rb`, `test.rb`, `output.log`, `result.json`) and prints
  where it is. Re-run that `app.rb` by hand with the env from `spec/support/suite/sandbox.rb`.
- The runner never needs `bundle exec`; it builds each child's environment from scratch.
- Changing the runner? `ruby spec/support/test/run.rb` (or `rake spec:selftest`) runs its unit tests.
