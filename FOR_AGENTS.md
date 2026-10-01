# FOR_AGENTS.md

You are a coding agent, and your person asked you to make a desktop app with Scarpe. This page
is what you need to do that on their machine with no detours: set up, write the app, look at it
without a screen, test it, and package it. Everything here was checked on 28 Sep 2026 on macOS
26.2 (Apple silicon) with Ruby 4.0.1 and Rust 1.93, headless; the Linux lines come from CI.

## What Scarpe is

- Scarpe runs [Shoes](docs/static/manual.md) apps: a small Ruby DSL for desktop windows
  (`Shoes.app { para "Hi" }`).
- With the native display, Ruby runs your app and a Rust program (`native/`) lays it out, paints
  it and reads the mouse and keys.
- Always use the native display: `--native` to run, `peek` to look (it implies native). The
  default display is a webview; do not build on it.

## Four rules on someone's machine

1. Never put a window on their screen for your own checks. Look with `scarpe peek` (no window
   at all). If you need a real window, make it a ghost (`SCARPE_NATIVE_GHOST=1`): it presents
   frames, nobody can see or click it, and it never takes focus.
2. Never make a sound, open a dialog or touch their clipboard. Put `spec/support/fakebin` first
   on `PATH` for every run: it traps `afplay`, `say`, `open`, `osascript`, `caffeinate` and
   `SwitchAudioSource`, and keeps `pbcopy`, `pbpaste` and `xclip` in a file. Point
   `SCARPE_CLIPBOARD_FILE` at a file too: `app.clipboard` uses it in place of the system one.
3. Give the app a scratch `HOME` whenever it might save something.
4. Let the person open the app themselves: hand over the command or the packaged `.app`.

`scarpe.sh` in [Run it safely](#run-it-safely) does rules 2 and 3 for every run and peek.

## The whole path

1. Clone, `bundle install`, run one `peek` (it builds the renderer). [Set up](#set-up)
2. Make a folder for the app, outside the clone, with `scarpe.sh` in it. [Run it safely](#run-it-safely)
3. Loop: edit, `./scarpe.sh peek my_app.rb --scale 2 --shot shots/x.png --layout`, look at the
   PNG, fix. [The loop](#the-loop)
4. Pin what works with checks in `checks/*.sspec`, run by `~/scarpe/spec/run`. [Testing](#testing)
5. Package from the clone: `cd ~/scarpe && bundle exec ruby exe/scarpe package
   ~/my_app/my_app.rb --native --dmg --output ~/my_app/dist`. [Packaging](#packaging)

## Set up

| need | version | notes |
|---|---|---|
| macOS | Apple silicon, tested | the only platform that packages apps |
| Linux | runs headless | CI runs the native tests and the spec suite on Ubuntu 24.04 |
| Windows | not yet | the renderer compiles; the Ruby side is Unix-only |
| Ruby | 3.2.11 or newer; CI runs 3.2 and 4.0 | the repo's `.ruby-version` says 3.2.0: ignore it, since 3.2.0 to 3.2.2 cannot build nokogiri with Xcode 26's clang (`docs/native_ci.md`) |
| Bundler | 2.4.10, as the lockfile says | `gem install bundler -v 2.4.10` |
| Rust | 1.89 or newer, with `cargo` | `rust-version` in `native/Cargo.toml` |
| macOS: `xzcat` | any | nokogiri builds from source: `command -v xzcat \|\| brew install xz` |
| Linux: GTK 3 and WebKitGTK | dev packages | `webview_ruby` compiles during `bundle install` (below) |

```sh
git clone --branch native-rust https://github.com/scarpe-team/scarpe.git ~/scarpe   # main once PR #591 merges
cd ~/scarpe
ruby -v                     # 3.2.11 or newer; if a version manager picks 3.2.0 here, choose another Ruby for this folder
gem install bundler -v 2.4.10
bundle install              # about 1.5 minutes: compiles nokogiri, sqlite3 and webview_ruby
PATH="$PWD/spec/support/fakebin:$PATH" bundle exec ruby exe/scarpe peek examples/button.rb --layout
```

The last command builds the renderer first (`cargo build --release` in `native/`: 68 s here,
about 400 MB in `native/target`) and says `scarpe-native: building ... (cargo build --release)`
on stderr. It ends with lines like `#3 Button 0,0 78x28 "Push me"`. Later runs start in under a
second and rebuild only when something under `native/src` or a Cargo file changes.

No `cargo`? The run fails with `cargo build --release failed in .../native
(Scarpe::Native::ChildNotFound)`. Install Rust with rustup (https://rustup.rs), open a new shell
so `cargo` is on `PATH`, and run it again. The shim looks for `$CARGO`, then `cargo` on `PATH`,
then `~/.cargo/bin/cargo`.

On Ruby 4.0, Bundler 2.4.10 prints `warning: already initialized constant Gem::Platform::...`
lines on every command. They are harmless.

Linux (Ubuntu 24.04), before `bundle install`, as `.github/workflows/native.yml` does it:

```sh
sudo apt-get install -y --no-install-recommends libgtk-3-dev libwebkit2gtk-4.1-dev
mkdir -p ~/.local/lib/pkgconfig      # webview_ruby asks for webkit2gtk-4.0; 4.1 answers to that name
printf '%s\n' 'Name: webkit2gtk-4.0' 'Description: webkit2gtk-4.1 under its old name' \
  'Version: 2.0' 'Requires: webkit2gtk-4.1' > ~/.local/lib/pkgconfig/webkit2gtk-4.0.pc
export PKG_CONFIG_PATH=~/.local/lib/pkgconfig
```

## Hello world

`~/my_app/my_app.rb`:

```ruby
Shoes.app(title: "My App", width: 400, height: 240, resizable: false) do
  background "#fdf6e3"
  stack(margin: 24) do
    title "Hello", stroke: "#073642"
    @note = para "Nothing pushed yet", size: 14
    button("Push me") { @note.text = "Pushed" }
  end
end
```

The person opens it with `cd ~/scarpe && bundle exec ruby exe/scarpe --native ~/my_app/my_app.rb`.
That is a real window, so you look at it with `peek` instead.

## Run it safely

Save this as `~/my_app/scarpe.sh` and `chmod +x` it. Every run and peek below goes through it;
`spec/run` sandboxes its checks itself, and packaging runs from the clone.

```sh
#!/bin/sh
# Runs Scarpe from your clone without disturbing the person at this machine: dialogs, sounds and
# the clipboard go to Scarpe's stand-ins, and the app's HOME is a scratch folder of its own.
SCARPE="${SCARPE:-$HOME/scarpe}"                          # your clone of Scarpe
APP_DIR="$(cd "$(dirname "$0")" && pwd)"                  # the folder this script sits in
BOX="${SCARPE_HOME:-${TMPDIR:-/tmp}/scarpe-home-$(basename "$APP_DIR")}"  # this app's HOME
RUBY="$(cd "$SCARPE" && ruby -e 'print RbConfig.ruby')"   # the clone's Ruby, past any version-manager shim
mkdir -p "$BOX"
exec env PATH="$SCARPE/spec/support/fakebin:$PATH" HOME="$BOX" \
  SPEC_TRAP_FILE="$BOX/trapped.txt" SPEC_CLIPBOARD_FILE="$BOX/clipboard.txt" SCARPE_CLIPBOARD_FILE="$BOX/clipboard.txt" \
  RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}" CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}" \
  BUNDLE_GEMFILE="$SCARPE/Gemfile" "$RUBY" "$SCARPE/exe/scarpe" "$@" --dev
```

- `./scarpe.sh peek my_app.rb ...` looks at the app headless (next section).
- `SCARPE_NATIVE_GHOST=1 SCARPE_NATIVE_ARGS='--exit-after 5' ./scarpe.sh --native my_app.rb`
  runs it in a ghost window for five seconds, when you need a real window (timing, frame rates).
- `$BOX` is `${TMPDIR:-/tmp}/scarpe-home-my_app`, one per app folder. What the app saves lands
  under it (`$BOX/Library/Application Support/...` on a Mac); `rm -rf` it for a first run.
- Every trapped command is a line in `$BOX/trapped.txt`, e.g. `afplay /var/.../pop.wav`.
- `--dev` makes `exe/scarpe` load the clone's own `lib` and its Gemfile's gems, as `bundle exec`
  would. It builds nothing. `exe/scarpe` has no `--help`; `./scarpe.sh peek --help` has one.
- The wrapper resolves Ruby, and points rustup at its toolchains, before it moves `HOME`, so
  version-manager shims keep working and the renderer can still rebuild itself.

## The loop

You cannot see a screen, so every change goes the same way: edit, render, look, act, look again.

```sh
cd ~/my_app
./scarpe.sh peek my_app.rb --scale 2 --shot shots/start.png --layout
# now open shots/start.png with your image-reading tool and judge it as a designer would
./scarpe.sh peek my_app.rb --click "Push me" --scale 2 --shot shots/pushed.png --layout --a11y
```

```
click "Push me" -> #7 at 63,127.6
shot /Users/you/my_app/shots/pushed.png (800x480)
#2 DocumentRoot 0,0 400x240
#3 Background 0,0 400x240
#4 Stack 24,24 352x117.6
#5 Para 28,28 344x40.8 "Hello"
#6 Para 28,84.8 344x16.8 "Pushed"
#7 Button 24,113.6 78x28 "Push me"
#1 window "My App"
  #5 heading "Hello"
  #6 label = "Pushed"
  #7 button "Push me" (focused)
```

Each `--layout` line is `#id Kind x,y wxh "text"` in window points, after layout: check sizes,
overlaps and wrapping there, not only by eye. The `--a11y` lines are what a screen reader meets;
a control with no name there (`#15 check_box (unchecked)`) needs a text block beside it.

| peek flag | does |
|---|---|
| `--shot FILE.png` | save a picture of the window (makes missing folders) |
| `--scale 2` | draw every picture at 2x, as a Retina screen does |
| `--size WxH` | resize the window before any step |
| `--click TEXT` | click what shows TEXT: an exact match first, then the first that contains it (buttons, links, list items, text) |
| `--click-at X,Y` | click a window point |
| `--drag X,Y,X,Y...` | press at the first point, move through the rest, release at the last |
| `--type TEXT` | type into the focused field (click the field first) |
| `--key NAME` | press one key: `a`, `A`, `space`, `enter`, `escape`, `tab`, `backspace`, `left`, `page_down`, `f1`, `control_a`, `shift_tab`, `alt_q`, `command_q` |
| `--wheel DY[,X,Y]` | scroll at a point; positive DY scrolls down |
| `--wait SECS` | let timers and animations run, in real time |
| `--window N`, `--app ID` | send the steps after it to another window |
| `--layout` | print every laid-out node |
| `--a11y` | print the accessibility tree |

- Steps run in the order given, so a `--shot` before and after `--click` shows both. `--size`
  and `--scale` apply to the whole run.
- With no `--shot`, `--layout` or `--a11y`, peek writes `peek.png` in the current folder.
- Clicks and shots print a line each; `--type`, `--key` and `--wait` print nothing, so read
  `--layout` or a shot to see what they did.
- A step that fails prints `peek: ...` and exits 1: a click on nothing
  (`peek: click failed: no visible drawable shows ...`), a handler that raises
  (`peek: NameError: ...`), or a file that never calls `Shoes.app`.
- Coordinates are window points everywhere. Pixel (x, y) of a `--scale 2` picture is point
  (x/2, y/2).
- `SCARPE_NATIVE_ARGS='--fonts bundled' ./scarpe.sh peek ...` swaps the system fonts (San
  Francisco on a Mac) for the bundled Inter and Fira Mono, so pixels match on every machine.
  Checks always use the bundled fonts, and text widths differ between the two, so leave slack.
- Keep pictures in `shots/`: PNGs lying loose beside the app get packaged with it.
- `--key "\n"` does not press Return from a shell (the shell passes a backslash and an n). Use
  `--key enter`.

## DSL cheat sheet

Everything here draws on the native display today. `docs/static/manual.md` is the full
reference; skim its table of contents before building anything unusual.

App, slots and backgrounds:

```ruby
Shoes.app(title: "Name", width: 640, height: 480, resizable: false) do  # default 600x500, "Shoes"
  background "#fdfaf4".."#efe6d6"          # colour, gradient Range (top to bottom), or image path (tiled)
  stack(margin: 16) do                     # a column: children top to bottom
    flow do                                # a row that wraps: children left to right
    end
  end
  stack(width: 200, height: 120, scroll: true) { }  # a fixed height clips; scroll: true scrolls it
  stack(left: 20, top: 40, width: 100) { }          # placed: out of the flow, from its slot's corner
  stack(margin: [10, 0, 10, 20]) { }                # left, top, right, bottom, text too; or margin_bottom: 20
  stack(width: 220, margin: 6) do         # a slot is as tall as what it holds, so an empty one shows nothing
    background "#c0392b", curve: 8        # fills its slot, rounded
    border "#264653", strokewidth: 2, curve: 8
    para "A card", stroke: white
  end
end
```

Text:

```ruby
title "Big"            # banner 48, title 34, subtitle 26, tagline 18, caption 14, para 12, inscription 10 px
para "Plain, ", strong("bold"), ", ", em("italic"), ", ", code("code"), ", ",
  span("red", stroke: red), " and ", link("a link") { @status.text = "clicked" }
para "Styled", size: 16, stroke: "#333", font: "Georgia", align: "center", margin: 0
para link("Home", click: "/")               # a link that visits a page
@status = para "ready"
@status.text = "new text"                   # or @status.replace "new ", strong("text")
style(Shoes::Para, size: 14)                # a default for every para made after it
```

Controls:

```ruby
button("Save") { save }                              # Return or Space clicks a focused button
@name = edit_line(width: 200) { |e| @hint.text = e.text }   # runs on every edit
@name.finish = proc { |e| submit(e.text) }           # runs on Return in the field
@notes = edit_box(width: 300, height: 120)
@done = check { |c| @hint.text = c.checked?.to_s }
para "Done"                                          # the text beside a control names it for screen readers
@done.checked = true                                 # ticks it without running its block
radio(:size) { |r| }; para "Small"                   # radios sharing a group are exclusive
radio(:size) { |r| }; para "Large"
@pick = list_box(items: ["Tea", "Coffee"], choose: "Tea") { |lb| @hint.text = lb.text }
@bar = progress(width: 1.0)
@bar.fraction = 0.4
@hint = para ""
```

Images (a path is relative to the app's folder; png, jpg, gif, bmp):

```ruby
image "pic.png"
image "pic.png", width: 120, alt: "What it shows"   # keeps its aspect; alt is read to screen readers
image(200, 100) { fill red; oval 10, 10, 80 }       # a canvas you draw into
```

Art. Every number is a pixel from the slot's corner, and art is always placed, never flowed.
Pens set with `fill`, `stroke`, `strokewidth`, `nofill`, `nostroke` and `cap` apply to the art
drawn after them. Unset fill and stroke are black, 1 px.

```ruby
stroke "#3b2f2f"; strokewidth 2; fill "#f4c95d"
rect 20, 20, 120, 70, 12                        # left, top, width, height, corner radius
oval 160, 20, 70                                # left, top, diameter (or width, height)
oval 230, 55, 30, center: true                  # centred on left, top
line 250, 20, 320, 90
star 370, 55, 5, 35, 15                         # centre x, y, points, outer and inner radius
arrow 450, 55, 60                               # centre x, y, width; points right
arc 500, 20, 70, 70, 0, Math::PI, wedge: true   # box, then radians clockwise from 3 o'clock
shape { move_to 20, 120; line_to 80, 170; curve_to 120, 120, 160, 200, 200, 140 }
rect 220, 120, 50, 50, fill: blue, strokewidth: 0     # pens for one shape (stroke: nil does not remove the outline)
nostroke; cap :curve                            # cap :curve rounds line ends; :rect is the default
@dot = oval(300, 150, 30)
@dot.move(340, 150)                             # move art, or anything placed
@dot.style(rotate: 30)                          # turn it, counter-clockwise, about its top-left corner
transform :center                               # art after this turns about its centre
```

Colours: `"#3366cc"`, `"#36c"`, `red` and 138 more CSS names (`cornflowerblue(0.5)` for half
opacity), `rgb(51, 102, 204)`, `rgb(51, 102, 204, 0.5)`, `gray(0.3)`, `gray(0.3, 0.5)`,
`"#fff".."#eee"`, `gradient("#fdf0d5", "#f4a261", angle: 90)` (angle 0 runs top to bottom, 90
left to right). Each `rgb` or `gray` part is an Integer from 0 to 255 or a Float from 0.0 to 1.0,
decided part by part, so `rgb(1, 1, 1)` is black and `rgb(1.0, 1.0, 1.0)` is white.
Not drawn today: radial gradients, dashed lines, `blur`, `glow`, `shadow`, video playback.

Events, on the app or any slot, with window coordinates:

```ruby
click    { |button, x, y| }      # button 1 left, 2 middle, 3 right
release  { |button, x, y| }
motion   { |x, y| }
hover    { |slot| }
leave    { |slot| }
keypress { |key| }               # "a", "A", " ", "\n", :left, :escape, :tab, :f1, :control_s, :alt_q
wheel    { |delta, x, y| }       # delta > 0 is up
@dot.click { |button, x, y| }    # art, images and text blocks take click and release too
```

Timers:

```ruby
@anim = animate(30) { |frame| }  # frames a second (10 if you give none); frame counts from 0
every(1) { |count| }             # every second; count from 0
timer(2) { }                     # once, 2 s from now
@anim.stop; @anim.start; @anim.toggle
```

Changing what is on screen:

```ruby
@list.append { para "added" }
@list.prepend { para "first" }
@list.clear { para "fresh" }     # empties the slot and fills it again; its timers keep running
@list.contents                   # its children
@list.contents.last.remove
@panel.hide; @panel.show; @panel.toggle     # slots, text, controls and art; hidden takes no space
@box.move(x, y)                  # for placed things; cheap enough for every frame
@box.style(width: 200, fill: blue)
@list.scroll_top = 0             # a scroll: true slot: 0 is the top, @list.scroll_max the end
timer(0) { @list.scroll_top = @list.scroll_max }   # to the end after an append (below)
```

`scroll_max` answers from the last layout, so right after `append` or `clear` it still gives the
old end. Read it in a `timer(0)`, which runs once what you made is laid out. In peek, put
`--wait 0.1` after the click so that timer runs; in a check, `advance(0.1)`.

Pages. The app starts at `"/"`, `visit` replaces the whole window and stops the old page's
timers, and `location` is the current path:

```ruby
Shoes.app(title: "Pages") do
  url "/", :home
  url "/item/(\\d+)", :item        # each capture arrives as an argument

  def home
    para "Home"
    button("Open 7") { visit "/item/7" }
  end

  def item(id)
    para "Item #{id} at #{location}"
    para link("Back", click: "/")
  end
end
```

Structure. Inside `Shoes.app`, `self` is the App: `def` makes app methods, and blocks given to
slots, events and timers keep that `self`, so `@ivars` inside them are the app's. Define helper
methods before the code that calls them.

```ruby
class Card < Shoes::Widget               # the class name is the DSL name: card "Red", width: 130
  def initialize(label, **)              # ** takes styles like width:, which place the widget
    stack(margin: 6) do
      background "#c0392b", curve: 8
      para label, stroke: white
    end
  end
end

class Score                              # a plain object draws through the app it holds
  def initialize(app)
    @app = app
    @total = 0
    @shown = @app.para "Score 0"
  end

  def add(points)
    @total += points
    @shown.text = "Score #{@total}"
  end
end

Shoes.app do
  flow do
    card "Red", width: 130               # a widget is as wide as its parent unless given a width
    card "Blue", width: 130
  end
  @score = Score.new(self)
  button("Add") { @score.add(5) }
end
```

Fonts, dialogs, clipboard and windows:

```ruby
FACE = font(File.join(__dir__, "fonts", "Nice.ttf")).first  # its family name: para "x", font: FACE
alert "Saved"                    # native dialogs on screen; headless answers nil, false, "", nil
confirm "Sure?"
ask "Name?"
ask_open_file                    # also ask_save_file, ask_open_folder, ask_save_folder, ask_color
self.clipboard = "text"          # through pbcopy and pbpaste
clipboard
close                            # closes this window; exit quits the app
```

## Rules that surprise

Each of these bit someone building the apps in `examples/native`. The rulings behind them are in
`spec/LEDGER.md`.

1. The window's own slot is a flow: things sit side by side until the row is full. Put a column
   in a `stack`. In a flow, a slot with no `height` beside a taller one reaches down to that
   row's bottom, and its background fills it all (C16).
2. Text blocks have margins, 4 px on each side and 12 px below, so two paras in a stack are 16 px
   apart. `margin: 0` removes them. `--layout` and `layout_of` give the box inside the margins;
   the Ruby getters `left`, `top`, `width` and `height` include them (C9, A4).
3. A width or height you give is the margin box: `stack(width: 100, margin: 10)` is 80 px inside
   (C14).
4. A position is a plain number, negative ones too: `stack(top: -40)` starts 40 px above its
   slot, and `left: -40` sits 40 px past its left edge, as art does (C18). `right` and `bottom`
   count from the far edges. A size is different: a negative `width` or `height` is the parent
   less that much (`width: -100`). A Float between -1 and 1 is a share of the parent for both
   (`left: 0.5` is halfway), and a float above 1 is pixels, so give anything that moves whole
   pixels (`x.round`) or it jumps as it passes through a fraction (C1, docs/native.md).
5. On art every number is pixels, negatives and fractions included (C15).
6. A fixed `height` clips the slot, with or without `scroll: true` (C13).
7. `left` and `top` answer in two frames. Something its slot flowed answers window coordinates;
   something you placed (`left:`, `top:`, `move`, all art) answers the numbers you gave, from its
   slot's corner. Events, `--layout` and `layout_of` are always window coordinates (A4).
8. A press runs the `click` block of every slot under the pointer, covered slots included (the
   window's first, then inner slots, the topmost of siblings first), then the clicked shape's
   own. Controls (buttons, check boxes, radios, list boxes, fields) and links keep their press to
   themselves: a check box in a card with its own `click` toggles once, and the card hears
   nothing. When you show an overlay such as a sheet or a menu, make the handlers beneath it
   check a flag (`return if @sheet_open`), as Kanban does (E8, DESIGN 4.3).
9. The App owns `@app`, `@title`, `@width`, `@height`, `@resizable`, `@owner`, `@features`,
   `@log`, `@subscriptions` and `@linkable_id`. Do not use those names for your own: after
   `@width = 17`, the app's `width` answers 17. Write `@heading = title "Hi"`.
10. Keys: printable keys arrive as Strings (`"a"`, `"A"`, `" "`, `"&"`), Return as `"\n"`, other
    keys as Symbols (`:left`, `:escape`, `:backspace`, `:f1`). Modifiers are prefixes in the
    order `control_`, `shift_`, `alt_`, with shift only on non-printables, and Cmd arrives as
    `alt_` (`:alt_q`). While a text field has focus, `keypress` hears only Escape and modified
    keys, so read Return with `edit_line.finish = proc { }` (H1, G16).
11. `animate` runs 10 fps unless you give a rate. `animate` frames and `every` counts start at 0.
    `clear` keeps a slot's timers; `visit` stops the page's (I1, B7).
12. Default text is small: a para is 12 px. Choose sizes on purpose.
13. A widget, like any slot, is as wide as its parent unless you give it a `width:`.

## Making it look good

- Set `title:`, `width:` and `height:` on `Shoes.app`, and `resizable: false` for a fixed
  layout.
- Give the window a background, the content a margin (`stack(margin: 24)`), and text real
  sizes (`title` for headings, `para ..., size: 14` or `style(Shoes::Para, size: 14)` for body
  text).
- Pick a palette of three to five hex colours and use `stroke:` on text and `fill`/`stroke` on
  art; round corners with `curve:`; soften with gradients.
- Look at every screen at `--scale 2`. Check alignment against the `--layout` numbers.
- Ship a font with the app in `fonts/` and load it with `font(...)` if the look depends on it.
- Put a text block beside every control, so screen readers can name it (`--a11y` shows it).

## Testing

A check is an `.sspec` file: YAML front matter, then the app code, then Minitest code that runs
in the same Ruby process after the app has drawn, before any timer fires. Put checks next to the
app in `checks/`:

```
---
display: native
----------- app code
load "/Users/you/my_app/my_app.rb"
----------- test code
note = para("@note")
assert_equal "Nothing pushed yet", note.text
click_on "Push me"
assert_equal "Pushed", note.text, "the button's block ran"
box = layout_of(button("Push me"))
assert_operator box.w, :>=, 28
r, g, b, _a = pixel_at(5, 5)
assert_equal [253, 246, 227], [r, g, b], "the background is #fdf6e3"
```

```sh
cd ~/my_app
~/scarpe/spec/run --display native checks                  # every check in the folder
~/scarpe/spec/run --display native checks/my_app.sspec     # one check
~/scarpe/spec/run --display native --keep checks           # a failure keeps its sandbox and says where
```

- Pass `--display native`. Without it the runner uses Niente, a display with no layout, and
  reports every `display: native` case as `n/a`.
- Each case runs in its own sandbox: its own `HOME`, temp folder, clipboard file and fakebin, 8
  at a time. That `HOME` is why the `load` path must be absolute: `~` is the sandbox there.
  It also means the app starts with nothing saved; write a state file in the app code segment,
  before the `load`, to start from a saved state.
- A failure prints your message and the file and line:
  `Expected: "Pushed!"` then `Actual: "Pushed" (/Users/you/my_app/checks/my_app.sspec:9)`.
- A singular finder (`para(...)`) raises unless exactly one drawable matches, and the case shows
  `error`: `MultipleDrawablesFoundError` means select by `"@ivar"` instead, and
  `NoDrawablesFoundError` means nothing matched. For a readable failure, assert on the plural:
  `assert_includes paras.map(&:text), "Saved"`.
- Test code runs as one block, so a `def` in it cannot be called (NameError). Write helpers as
  lambdas, as the reference checks do: `note = -> { para("@note").text }`, then `note.()`.
- `Results: results/native.json` at the end means `~/scarpe/spec/results/native.json`.
- Checks draw with the bundled fonts. `timeout: 60` in the front matter raises the 40 s limit.
- `advance` runs a frozen clock: timers fire exactly and at once, but `Time.now` does not move.
  Drive what you want to test from `animate` frames, `every` counts or your own counters.

The native test API:

| call | does |
|---|---|
| `button`, `para`, `title`, `edit_line`, `list_box`, `check`, `radio`, `stack`, `image`, `oval`... | one finder per drawable class; raises unless exactly one matches |
| `buttons`, `paras`, `stacks`... | every match, breadth first (not document order) |
| selectors | `"@ivar"` (the App's), `"$global"`, `"id:N"`, a class, exact text (`button("Save")`), a Hash (`para(text: "Hi")`) |
| `proxy.text`, `.style`, `.checked?`, `.hidden`... | a finder's result forwards to the drawable |
| `proxy.trigger_click`, `proxy.trigger_change(value)` | fire its click, or change a field's text or a list box's choice |
| `click_on(proxy_or_text)`, `click_at(x, y)` | a real click, through layout and hit-testing |
| `hover_at(x, y)`, `drag([x, y], [x, y], ...)`, `wheel(dy, x:, y:)` | pointer input; no time passes |
| `type_text("hi")`, `press_key("a")` | keys; names as for `--key`, or `"\n"` and `:left` |
| `layout_of(proxy)` | a Rect with `x`, `y`, `w`, `h` in window points |
| `layout_tree` | every laid-out node as a Hash (`:id`, `:kind`, `:x`, `:y`, `:w`, `:h`, `:visible`, `:text`) |
| `pixel_at(x, y)` | `[r, g, b, a]` at a window point |
| `snapshot("name")` | writes `~/scarpe/spec/results/snapshots/name.png` and returns the path: look at it |
| `advance(seconds)`, `wait_frames(n)` | fire the timers due in that span; pump n frames |
| `resize_window(w, h)`, `focused_drawable` | resize; the proxy that has focus, or nil |
| `a11y_nodes`, `a11y_action(proxy, :click)` | what a screen reader meets, and what it does |
| `stub_dialog(:ask, "Nick")`, `dialog_calls` | answer the next dialog; every dialog asked, as `[[:ask, "Name?"]]` |

Every Minitest assertion works. `spec/README.md` has the whole format, and each app under
`examples/native/legendary/*/checks/` has a real check to copy.

## Sound

The native display plays nothing itself. The apps here write each sound once as a WAV file in
plain Ruby and hand it to `afplay` (macOS) in the background, and stay silent where there is no
`afplay`. Keep volumes at 0.3 or below and give the person a mute.

```ruby
require "fileutils"
require "tmpdir"

module Beep
  RATE = 22_050
  DIR = Dir.mktmpdir("my-app-sounds")
  at_exit { FileUtils.rm_rf(DIR) }

  class << self
    attr_accessor :muted

    def play(hz = 660, seconds = 0.12, volume = 0.25)
      return if muted

      path = File.join(DIR, "#{hz}-#{seconds}.wav")
      write(path, hz, seconds, volume) unless File.exist?(path)
      Process.detach(spawn("afplay", path, out: File::NULL, err: File::NULL))
    rescue SystemCallError
      # no afplay here (Linux, Windows): stay silent
    end

    private

    # A 16-bit mono WAV: a 44-byte header, then the samples, faded in and out so nothing clicks.
    def write(path, hz, seconds, volume)
      samples = Array.new((RATE * seconds).round) do |i|
        t = i.fdiv(RATE)
        fade = [t / 0.005, (seconds - t) / 0.02, 1].min
        (Math.sin(2 * Math::PI * hz * t) * volume * fade * 32_767).round
      end
      data = samples.pack("s<*")
      header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16, "data", data.bytesize]
      File.binwrite(path, header.pack("a4Va4a4VvvVVvva4V") + data)
    end
  end
end

# in the app: Beep.play(520); keypress { |k| Beep.muted = !Beep.muted if k == "m" }
```

Under `scarpe.sh` or `spec/run` every `afplay` lands in the trap file instead of the speakers.
`afplay` runs in the background, so put `--wait 0.3` after the click before peek exits if you
read `$BOX/trapped.txt`. `examples/native/kids/balloon_pop/balloon_pop.rb` is the full pattern:
chords, a cap on sounds at once, a mute button.

## Saving state

Write to Application Support on a Mac (XDG on Linux), never beside the app: a packaged app's
folder is inside its `.app`. Stick to the standard library (`json`, `fileutils`); a packaged
app carries no gems.

```ruby
require "json"
require "fileutils"

DATA_DIR = if RUBY_PLATFORM.include?("darwin")
  File.join(Dir.home, "Library", "Application Support", "My App")
else
  File.join(ENV.fetch("XDG_DATA_HOME", File.join(Dir.home, ".local", "share")), "my_app")
end
SAVE = File.join(DATA_DIR, "state.json")

def load_state
  JSON.parse(File.read(SAVE))
rescue Errno::ENOENT, JSON::ParserError
  { "count" => 0 }
end

def save_state(state)
  FileUtils.mkdir_p(DATA_DIR)
  File.write("#{SAVE}.tmp", JSON.pretty_generate(state))
  File.rename("#{SAVE}.tmp", SAVE) # a crash mid-write never leaves half a file
end
```

For a file the person should see (an export), ask with `ask_save_file`, as Ledger does, or
write under `~/Documents/<App>/`, as Typewriter does.

## Packaging

macOS only. Run it from the clone with your real `HOME`, not through `scarpe.sh`: packaging opens
no window, plays nothing and never runs the app, and it keeps its Ruby runtime in
`~/.scarpe/packager-cache`, which the wrapper's scratch `HOME` lacks (it would download it again).

```sh
cd ~/scarpe
bundle exec ruby exe/scarpe package ~/my_app/my_app.rb --native --dmg \
  --name "My App" --icon ~/my_app/icon/icon.png --include data --output ~/my_app/dist
```

- It writes `dist/My App.app` (about 34 MB) and `dist/My App.dmg` (about 15 MB). Without
  `--output`, both land in the current folder, the clone. Without `--name`, the name is the file
  name in CamelCase (`my_app.rb` is `MyApp`). `bundle exec ruby exe/scarpe package --help` lists
  every flag.
- The first build also downloads Traveling Ruby 3.4.7 (59 MB). A build with it cached took 13
  to 40 s here. The app runs on that bundled Ruby 3.4.7, whatever Ruby you develop on, so keep
  the app's code to what Ruby 3.4 and its standard library have.
- Copied with the app: the `.rb` file; loose `png jpg jpeg gif svg ico wav mp3 ogg ttf otf woff
  woff2 css js html` files beside it (unless it sits directly in `/`, `/tmp`, your home or the
  temp folder); and the `images`, `assets`, `fonts` and `sounds` folders. Anything else needs
  `--include PATH` (repeatable; a path relative to the app's folder), including other `.rb` files
  the app requires.
- `--icon` takes a `.png` (turned into `.icns` with `sips` and `iconutil`) or an `.icns`. A
  path that does not exist is skipped without an error, so look for `Converted PNG to ICNS` in
  the output.
- It is always ad-hoc signed and never notarised: `codesign -dv` says `Signature=adhoc`, and
  `spctl --assess` says `rejected`. It runs on the Mac that built it. A downloaded copy is
  blocked the first time it is opened: on macOS 15 and later the person opens it once, then
  chooses Open Anyway in System Settings, Privacy & Security, or runs
  `xattr -dr com.apple.quarantine "/Applications/My App.app"`. Tell them this when you hand it over.
- Check a build without a window, with a scratch `HOME`. It prints nothing and exits 0:

  ```sh
  env PATH="$HOME/scarpe/spec/support/fakebin:$PATH" HOME="$(mktemp -d)" SCARPE_NATIVE_HEADLESS=1 \
    SCARPE_NATIVE_ARGS='--exit-after 2' "$HOME/my_app/dist/My App.app/Contents/MacOS/scarpe-launcher"; echo $?
  ```

- Its Ruby is precompiled for `/Applications/My App.app` (`--install-dir DIR` names another
  place). Run from anywhere else, `dist/` included, it loads from source: up to about 20 ms
  slower to start, and otherwise the same.
- Started from Finder, its output goes to `~/Library/Logs/My App/launcher.log`.
- More: `docs/native_packaging.md`.

An icon drawn with Scarpe, in `~/my_app/icon/icon.rb` (a folder that is not packaged): a
1024 px window with the tile on macOS's icon grid (824 px, 100 in from each edge). Pictures are
always opaque, so cut the corners afterwards (ImageMagick here), or leave the square.

```ruby
Shoes.app(title: "My App icon", width: 1024, height: 1024, resizable: false) do
  background white
  nostroke
  fill "#f7c948".."#e08a1e"
  rect 100, 100, 824, 824, 185
  fill "#3b2f2f"
  oval 512, 512, 420, center: true
end
```

```sh
cd ~/my_app
./scarpe.sh peek icon/icon.rb --shot icon/square.png
magick icon/square.png \( -size 1024x1024 xc:none -fill white \
  -draw "roundrectangle 100,100 923,923 185,185" \) -compose DstIn -composite icon/icon.png
```

`examples/native/showcase/shoe_icon.rb` is a finished one.

## Performance

- Move things instead of rebuilding them. Moving 200 ovals cost 8 ms of Ruby a frame here;
  clearing a slot and drawing the same 200 again cost 93 ms.
- Every style you change costs Ruby a few microseconds and Rust some paint, so change only what
  moved. Many translucent shapes moving at once cost the most to paint.
- Pick the rate you need: `animate(30)` for ambient motion, `animate(60)` for things that follow
  the hand. Stop timers when nothing moves (`@anim.stop`); a still app with no timers uses almost
  no CPU.
- A picture drawn at another size is resampled once and kept, so scaling an image is cheap.
- Measure with `SCARPE_NATIVE_STATS=DIR`: each process writes where its time went when it exits
  (`DIR/ruby.json`: phases such as `timers` with `n`, `total_ms`, `max_ms`; `DIR/rust.json`:
  `parse`, `apply`, `layout`, `paint`, `present` and per-frame rows). For frame rates, run a ghost
  window (`SCARPE_NATIVE_GHOST=1`) rather than peek. `native/PERF.md` has the rest.

## Reference apps

Copy from these; each runs under `peek` and has a check.

| app | steal |
|---|---|
| `examples/native/showcase/sketchpad.rb` | drawing with `click`, `motion` and `release`; undo |
| `examples/native/showcase/snake.rb` | arrow keys, a game loop on `every`, a game-over overlay, restart |
| `examples/native/showcase/pomodoro.rb` | an animated arc ring, `every` and `animate`, pausing timers |
| `examples/native/showcase/notes.rb` | an `edit_box` with a live word count, a `list_box`, a sidebar |
| `examples/native/legendary/kanban/kanban.rb` | drag and drop, a slide-in sheet, guarding presses under it, JSON saved with a rename |
| `examples/native/legendary/ledger/ledger.rb` | pages with `url` and `visit`, charts drawn from art, CSV export through `ask_save_file` |
| `examples/native/legendary/constellations/constellations.rb` | routes with captures, a seeded sky, a catalog in Application Support |
| `examples/native/legendary/marble_machine/marble_machine.rb` | physics in `animate(60)` with hundreds of moving shapes |
| `examples/native/legendary/pixel_pet/pixel_pet.rb` | state that remembers time away, sound, pixel art from ASCII |
| `examples/native/kids/balloon_pop/balloon_pop.rb` | synthesised sound with a mute, confetti, a font carried with the app |

Their checks: `spec/showcase/*.sspec`, `spec/kids/*.sspec` and
`examples/native/legendary/*/checks/*.sspec`. Each legendary and kids app has an `icon.rb`.

## Troubleshooting

| you see | do |
|---|---|
| `cargo build --release failed in .../native (Scarpe::Native::ChildNotFound)` | install Rust 1.89+ with rustup and put `cargo` on `PATH`, or set `SCARPE_NATIVE_BIN` to a built `scarpe-native` |
| `bundle install` fails in nokogiri: `xzcat not found`, or `nokogiri_gumbo.h` not found | macOS: `brew install xz`; use Ruby 3.2.11 or newer, not the 3.2.0 in `.ruby-version` |
| `peek: ... never started a Shoes app` | the file must call `Shoes.app` |
| `peek: click failed: no visible drawable shows ...` | the text is not on screen, is covered, or differs: read `--layout`, or use `--click-at` |
| `peek: NameError: ...` (or any error) after a click | a handler raised; the message names it, and peek fails the run |
| things jump to the middle or a corner as they move | rule 4: round positions to whole pixels (`x.round`) |
| an error in a click or a timer, and the app goes on | it is logged, and one that repeats is logged once and then counted; `Shoes.on_error { \|err\| }` hears every one, and Alt-/ (Cmd-/ on a Mac) opens the Shoes console (docs/native.md) |
| a check says `n/a` | add `--display native` |
| `peek: key failed: unknown key name` | use the names in the `--key` row, e.g. `enter` |
| an old renderer runs | a `scarpe-native` on your `PATH` wins over the clone's build: remove it, or set `SCARPE_NATIVE_BIN` |

Environment variables worth knowing: `SCARPE_NATIVE_ARGS` (flags for the renderer: `--fonts
bundled`, `--exit-after SECS`, `--scale F`, `--trace`), `SCARPE_NATIVE_HEADLESS=1`,
`SCARPE_NATIVE_GHOST=1`, `SCARPE_NATIVE_BIN`, `SCARPE_NATIVE_STATS=DIR`,
`SCARPE_NATIVE_TRACE=1` (every message both ways on stderr), `SCARPE_NATIVE_CACHE` (where
downloaded images and fonts go).

## Read more

- `docs/static/manual.md`: the Shoes manual, the reference for every DSL call.
- `docs/native.md`: the native display service in depth.
- `spec/README.md`: the check format and the whole test API.
- `spec/LEDGER.md`: every place Shoes 3, Shoes 4 and the manual disagree, and the ruling.
- `native/DESIGN.md`: the protocol and every layout rule.
- `docs/native_packaging.md` and `native/PERF.md`.
