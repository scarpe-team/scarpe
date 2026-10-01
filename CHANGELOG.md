## [Unreleased Future]

Here we write upgrading notes for brands. It's a team effort to make them as
straightforward as possible.

### Enhancements
- Added CLAUDE.md for agentic coding assistance
- Removed bloops as a required dependency - sound is now opt-in (install bloops gem separately if needed)
- Added base64 gem dependency for Ruby 3.4+ compatibility
- A native display service: `scarpe --native app.rb` draws with a Rust program (tiny-skia, cosmic-text, winit) instead of a webview, while Lacci and every block stay in Ruby. See docs/native.md and native/DESIGN.md. Dedicated to the late Noah Gibbs.
- `scarpe peek APP.rb` runs an app headless on the native display, clicks, types, scrolls and saves pictures
- `scarpe package --native` builds an ad-hoc signed macOS `.app` (and a `.dmg` with `--dmg`) with precompiled Ruby bytecode, no installed gems, and FastImage copied in for image sizes
- The Shoes spec suite (`spec/run`): 1062 cases from the manual, Noah Gibbs' Shoes-Spec corpus and the native example apps' checks, runnable on Niente and native, with `spec/LEDGER.md` ruling on every place the manual, Shoes 3, Shoes 4 and Lacci disagree
- Lacci: `animate`, `every` and `timer` return `Shoes::Animation`, `Shoes::Every` and `Shoes::Timer`; `Shoes.app`, `window` and `dialog` return the App; methods the manual marks "» self" return self
- Lacci: `left`, `top`, `width` and `height` read laid-out pixels when the display reports them; slots gain `before`, `after`, `scroll_height`, `scroll_max` and `gutter`; `font(path)` returns the family names in the file
- Native text fields undo and redo (Cmd-Z or Control-Z, Cmd-Shift-Z or Control-Y) and take an input method's commit as one edit
- Native windows describe themselves to screen readers through AccessKit: VoiceOver reads and works buttons, checks, radios, fields, list boxes, text, headings, links, progress bars and images. `image(path, alt: "...")` names a picture, and Shoes-Spec gains `a11y_tree`, `a11y_nodes` and `a11y_action`
- Ghost windows (`--ghost`, or `SCARPE_NATIVE_GHOST=1`): real windows that present frames nobody can see or click; every automated windowed run opens them
- `scarpe peek --drag X,Y,X,Y...`, and `drag` in Shoes-Spec test code
- `scarpe package --include PATH` carries any other file or folder an app reads (repeatable); a native package keeps its `--name` as written, spaces and all
- CI for the native display service: `.github/workflows/native.yml` runs clippy and `cargo test` on Rust 1.89 (macOS, Linux and, not yet required, Windows) and the shim, Lacci, spec, example and package suites on Ruby 3.2 and 4.0 (macOS and Linux); `rake ci_native` runs the same steps headless on your machine, and `rake ci_test` no longer runs `brew install` or `git checkout main`
- Lacci: `edit_line.finish = proc` runs when Return is pressed in the line, as Shoes 3.2.15 added; `arc` takes `wedge: true` for a pie slice, as in Shoes 4
- Lacci: `download` takes `start:`, `progress:`, `finish:`, `headers:` and `body:` and no longer needs nokogiri; `Image#path`, `full_width` and `full_height` and the `imagesize` built-in; the `error` built-in; `rgb`, `gray` and the named colours return a `Shoes::Color`, an Array with `red`, `green`, `blue` and `alpha`; `banner`, `title` and the rest of that family are `Shoes::Para` subclasses
- Ten Kids apps in `examples/native/kids`, for ages two to eight: Night Light, Balloon Pop, Paint Puddles, Shape Sorter, Bubble Garden, Peekaboo Moles, Key Splash, Memory Match, Rainbow Lab and Maze Mouse, each with a check in `spec/kids` and an icon drawn in Shoes
- `app.clipboard` works on Windows and on Linux Wayland desktops. On the native display it uses the renderer's clipboard (the one text fields cut and paste through: macOS, Windows, X11 and Wayland, no program to install); Niente and the webview use PowerShell on Windows, `wl-paste`/`wl-copy` on Wayland, `xclip` on X11 and `pbpaste`/`pbcopy` on macOS. `SCARPE_CLIPBOARD_FILE` names a file that stands in for the system clipboard, which the spec suite uses on every platform
- Windows groundwork for the native display: the renderer starts and is stopped the Windows way, its replies are read without `IO.select`'s 10 ms polling, and the native CI runs the Ruby suites on Windows (not yet required)

- `Shoes.show_manual` opens the manual in a window of its own, drawn from `docs/static/manual.md` with its chapters down the left, as Shoes 3's did; it no longer opens a browser
- Lacci: `Para#hit(x, y)` answers the character under a point, and `cursor_top` and the new `cursor_left` where the caret sits in the slot that scrolls it, asked of the native display; `Shoes.app`, `window` and `dialog` take their styles as a Hash too, as Ruby 1.9 programs pass them
- A negative `left` or `top` puts anything past its slot's near edge, as Shoes 3 read it (Nick's ruling of Q10, ledger C18): Hackety Hack's hand drops in from above the window again, and Ready sweeps the intro away to the left
- `Shoes.on_error { |err| }` hears every error a handler, a timer or the startup raises, as a Hash; the Shoes console lists them, newest first, with what `debug`, `info` and `error` said, and opens with Alt-/ (Cmd-/ on a Mac) or `Shoes.show_console`, never by itself; the log says an error a timer raises every frame once, then how often
- `Shoes.run_program(path)` runs a Shoes program in a process of its own and returns a `Shoes::Program` (`stop`, `on_output`, `on_error`, `on_exit`), so a program that never stops freezes only itself; a packaged app's launcher runs `SCARPE_RUN_FILE` instead of the app
### Bugs Fixed
- #569 link(click: "/path") now triggers internal navigation via visit(); paths like "/foo" also fall back to page(:foo) if no URL route matches
- Support for `class MyApp < Shoes` inheritance pattern with URL routing
- Fixed background() with remote URLs (now properly wrapped in CSS url())
- Lacci: `animate`, `every`, `timer`, `hover`, `motion`, `keypress` and slot `click` blocks ran twice per event; now once
- Lacci: `prepend` kept its children in reverse; `list_box { }` dropped its block and `choose` never told the display; `link(click: proc)` never fired; `click` and `release` on shapes, text and images bound nothing
- Lacci: `"#abc"` expanded by 16 instead of 17, and `rgb()` now reads each component as Integer or Float on its own
- Lacci: clearing a slot of 2000 paras took 10 s of unsubscribing; it takes 0.05 s
- Lacci: a download that got an error response raised ArgumentError instead of logging the response code
- `scarpe package --dmg` builds running side by side no longer empty each other's staging folder (a fixed `dmg-staging` in the shared cache), and neither do PNG icons' iconsets
- `scarpe package` took scarpe-components for scarpe, and the webview packager set an environment variable nothing reads
- Lacci: a `stroke` or `fill` set inside a `shape` block never reached that shape
- Native: nothing on stdin (huge sizes, deep nesting, reparenting loops, lines that are not UTF-8) can crash the renderer or make it allocate without bound
- Lacci: an app routed with `url "/", :anything` shows that page at boot; it had to be named `:index`
- Lacci: art can be placed by `right:` and `bottom:` alone, and a rect or oval naming both edges runs between them
- Lacci: `line`, `arc`, `arrow`, `star` and `shape` take `stroke:` and `fill:` (and `shape` `strokewidth:`) as the manual lists; a border's `strokewidth` reads back as a number; slots answer `respond_to?` for their style methods
- Native packages read image sizes (`Image#size`, `imagesize`): FastImage is copied in; requiring Lacci no longer runs git
- Native: long Shoes-Spec `advance` runs no longer deadlock the headless pipes; `ask` while an app is still being built opens a small window of its own; closing a window answers the `ask` open in it; headless `--exit-after` closes cleanly; Enter clicks a focused check or radio; `variant: "smallcaps"` draws small capitals; error underlines keep inside their slot; rewritten image files show their new pixels
- Native: text in several windows is no longer shaped again on every change, clipped rows paint without a mask per clip, and scrolling moves the layout instead of laying the window out again
- Native: an app body that runs past 20 s no longer fails its start; a `window` whose block raises no longer counts as open; handlers that raise LoadError, SystemStackError or NotImplementedError no longer end the app; `ask` passes `secret:` and `title:` to the native dialog
- Native: Ctrl-C still quits after a second window opens, and a second Ctrl-C ends a stuck renderer; TERM, or a Ruby that dies, takes the renderer's process group with it
- Native: Shoes-Spec test code and `scarpe peek` steps start after the slots' `start` blocks, and `wait_frames` starts a slot made since
- Native: an installed gem never runs cargo, and downloaded images are cached in a private per-user directory that refuses planted links, stale junk and https-to-http redirects
- Native: a press on a label or icon with no click block goes on to the clickable shape beneath it, as Shoes 3 skips what has no click; before, the label swallowed it
- Native: a button, check, radio or list box the mouse pressed leaves Space, Return and the arrows to the app's `keypress`; only focus from the keyboard or `focus` takes them
- Native: `font: "bold 16px"` (and `italic`) on an edit line or edit box draws bold (or slanted), as it does on a para
- Lacci: `line.move` moves both ends of the line, not only its start; a border's `strokewidth` is its own, 1 unless given, and no longer the pen's
- Lacci: `style` on an animated shape costs about half what it did: a class's style names are worked out once
- Native: a packaged app whose name or folder holds a space or a parenthesis ("ZARKING (Rust)", "For Noah") starts when double-clicked; Ruby passed the renderer's path alone to /bin/sh, which only a start with no flags does. Opened from Finder, the Dock or `open`, a native package writes its output to `~/Library/Logs/<name>/launcher.log`
- Native: `timer(0)` runs on the next turn of the loop, and `every(0)` every millisecond, as in Shoes 3; both waited a whole second
- Lacci: `style(scale:)`, `style(skew:)`, `style(translate:)` and `style(transform:)` reach the display, as `style(rotate:)` does; they only set an instance variable
- Lacci: an app may name its own instance variables `@slots`, `@pages`, `@routes`, `@started` or `@location`; they had replaced the App's own, and the next `stack` died with NoMethodError. The App keeps its bookkeeping in `@_` names
- Native: text whose stroke has no alpha prints nothing, so a fade ends clear; it was drawn in solid black
- Native: a slot's `click` runs before the click of a shape drawn under it, as in Shoes 3, so a backdrop that closes a card no longer swallows the card's own click; `click_on` and `peek --click` go through an empty slot on top, as a real press does, and name the drawable whose block ran
- Native: turned, scaled or skewed art repaints only its own corner of the window; any transform had repainted the whole window on every change to that shape
- Native: a dozen small things moving far apart (fireflies, confetti) repaint in a few small patches; past eight they were joined into one box across the window and repainted whole
- Native: a picture shown bigger or smaller than its pixels is resampled once for that size and kept, not on every paint; a 211 px glow stretched to 844 device pixels cost 15 ms a paint and now costs what the same glow drawn from an 844 px file does, 5.8 ms
- Lacci: `move` and `displace` tell the display in one message, not one for each coordinate
- Native packages: `font(path)` names and loads the font inside a packaged app; it answered nil there, since the bundled Ruby has no encoding transcoders, and the words fell back to the system face

- Lacci: a flow's `scroll_top` read nil until set; every slot has `scroll_top` and `scroll_top=` now. A text fragment's `parent` is the para or fragment holding it, as in Shoes 3, and spans keep `weight`, `family`, `emphasis` and `kerning`
- Native: a click block on an image is heard through an empty slot laid over it, once, on the press, as a shape's is; a negative `right` or `bottom` puts an element past its slot's edge, as in Shoes 3; a star or an arrow turns about the centre its `left` and `top` name
- Lacci: every drawable subscribed to its own hover, leave and motion as it was made; now only when given a block for one, so a text of a thousand spans remade on every key leaves nothing on the event bus

- Lacci: a closing window sends every slot in it its `finish`, the window's own slot first, as Shoes 3 does (ledger H8), so an app can save its work as it goes; closing Hackety Hack with its red button used to lose the child's program
- Lacci: the colon key reaches `keypress` as the String `":"`; it arrived as `:""`
- Lacci's turtle: `Turtle.draw` with no program draws an empty canvas instead of raising; step mode shows the next command again on Ruby 3.4 and later; `execute` and `draw all` sit at the right of their rows, as in Hackety Hack's turtle, so both rows of controls fit the window
- Lacci's turtle is Hackety Hack's little green PNG, which the native display draws (it was an SVG nothing drew), and `Turtle.start`'s pen swatch sits after its label instead of over it
- Lacci: a widget's options are its own, as in Shoes 3: the ones that are styles place it and the rest reach its `initialize` without an "Unexpected non-style keyword" warning (Hackety Hack's `glossb "OK", :color => "dark"`)
- Native: a sized or trimmed text too wide as a box for the rest of a line, whose text fits there on one line, sits on that line, as Shoes 3 draws it (ledger C7): Hackety Hack's lists put each name beside its icon
- Native packages carry `docs/static/manual.md`, so `Shoes.show_manual` opens the manual in a packaged app too
- The manual window shows the manual's pictures, draws its Colors List as named swatches with their numbers and its Classes List as the tree of drawables, as Shoes 3's did; it printed `{COLORS}` and `{INDEX}`. Native packages carry the pictures
- Native packages read files as UTF-8 when started with no `LANG`, as Finder, the Dock and `open` start them, and the manual reads as UTF-8 anywhere: in a packaged app Help raised "invalid byte sequence in US-ASCII", and a saved program with an accented letter could not be read back
- Lacci: `para.cursor = :marker` drops the selection as Shoes 3.1 does (the caret goes to its start and the marker is cleared), and `cursor = nil` clears the marker too; it jumped to the marker and kept it, so in Hackety Hack's editor typing after Backspace or select-all came out backwards
- Native: text that ends in a newline keeps the empty line under it, as Pango does: the caret after Return at the end of a program sits at the start of that line, where the next letter goes, instead of at the end of the line above, and the line counts in the text's height
- `Shoes.text_mode = :shoes3` sets a program's text as Shoes 3 did: sizes are points at 96 dpi, so a para is 16 px tall, and text that names no face is Arial (ledger M14); the default stays pixels. For programs laid out for Shoes 3, such as Hackety Hack
- Native: a slot with no height placed in a flow beside something taller reaches down to the bottom of that row, as Shoes 3 grows it (ledger C16), so its background fills the row
- Native: a slot with no height placed by `bottom` is measured by its margins alone, as Shoes 3 places it, so its contents sit just above the slot's foot (Hackety Hack's Prefs and Quit tabs)
- Native: a `timer(0)` runs once what was made before it is laid out, as in Shoes 3, so it can measure it: Hackety Hack's tooltips size their background in one, and raised a TypeError on a width still nil
- Native: each window's `mouse` is the pointer as it was last over that window, [0, 0, 0] before it ever was, as in Shoes 3; a window just opened read the pointer over another (Hackety Hack's Pong started its paddle off the window)
### Incompatibilities
- A background or border given a size and placed by `right` or `bottom` is measured from that edge by its pattern's own size, 1 px for a colour or a gradient, as Shoes 3 places it (ledger M19): `background black, width: 50, right: 50` is the manual's column on the right-side, and `height: 150, bottom: 150` a band along the foot. Without a size, `right` and `bottom` still inset it
- An app with no size opens at 600x500 titled "Shoes", as in Shoes 3 and Shoes 4 (it was 480x420 "Shoes!")
- `oval(left, top, n)`: `n` is a diameter, as the manual says, not a radius
- `rotate` adds to the slot's running turn, as in Shoes 3 (it set the angle outright); `scale` and `skew` still set theirs
- `left`, `top`, `width` and `height` include the element's margins, as Shoes 3 reports them
- `ins` is an underline fragment, no longer another name for `inscription`
- Slot blocks (`stack`, `flow`, `append`, `clear`...) keep the self they were written with, as the manual and Shoes 3 have it (ledger B1); only the app block, `window`, `dialog` and `app { }` run on the App. Code that calls Shoes methods bare inside a slot block from a plain object needs a way to the app, its own `method_missing` or `app { }`, as in Shoes 3. A widget's calls inside its own slots land in them, and what a widget lacks it asks its app for
- Gradients run top to bottom (angle 0) unless given an angle; they used to default to 45
- `clear` keeps the slot's event handlers and the timers it started, as Shoes 3 does
- A slot keeps one block per event: a second `click`, `keypress`, `hover`, `leave`, `motion`, `release` or `wheel` given to the same slot replaces the first, as in Shoes 3 (ledger H6); they used to add up
- A `list_box` starts with nothing chosen unless `choose:` names an item
- The draw context's `fill`, `stroke` and `strokewidth` no longer reach text and controls
- Native: a `width` or `height` the app gives includes the element's margins, as in Shoes 3 (`stack width: 100, margin: 10` is an 80 px box); before, margins went outside a px size
- Native: a negative `left` or `top` on art is a plain coordinate, as in Shoes 3, so art moves off the left and top edges instead of jumping to the far side
- Native: any number on art is pixels, as the manual and Shoes 3 say: `oval 0.5, 0.5, 12` sits in the corner and `rect 10, 10, 0.8` is under a pixel wide, where a Float up to 1 was a share of the slot; a percentage (`"50%"`) still is
- `close` closes only its own window while another is open, as the manual says (it closed every window); the last window's `close` still ends the app
- Native: downloaded images are cached in `~/Library/Caches/scarpe-native` (or `XDG_CACHE_HOME`, or `%LOCALAPPDATA%`), no longer under `$TMPDIR`
- Native: in a checkout, a `scarpe-native` on PATH wins over the dev build; the order is `SCARPE_NATIVE_BIN`, the packaged binary, PATH, then the dev build

## [0.4.0] - 2024-05-06 - Strangers

Core Scarpe has been relatively stable for awhile. A lot of this release is bugfixes and refactors.

## [0.3.1] - 2023-??-?? - Up

Lots of bug fixes. We're also still implementing major Shoes3 features.
Testing is finally improving at a reasonable rate, but we have a long
way to go.

The Scarpe architecture is still early. We've improved the internal APIs
for creating drawables significantly, added an asset server and are
still making big changes.

### Enhancements

- Ovals!
- Lots more text methods: del, sub, sup; lots more text styles: underline, strikethrough, strikecolor, align
- Features! Shoes.app(feature: [:html, :scarpe]) lets apps declare dependencies on non-classic Shoes!
- Better handling of :left, :top, :width and :height, :margin and :padding on more drawables
- The html_class style is a feature to make it easier to do Bootstrap styling on your drawables
- Directly run Shoes Specs, including with Niente
- We use Minitest assertion DSL rather than our own everywhere now

### Bugs Fixed

- We've changed "module Shoes" to "class Shoes" for Shoes3 compatibility.
- Several style and method names, including on Para and ListBox, changed to Shoes3 standard.

### Incompatibilities

TextDrawables now draw with very different Calzini (HTML renderer) properties
We're deprecating the CatsCradle test DSL in favour of Shoes-Spec.
Some error names have changed, with more to come.
We've changed the Lacci drawable-create event to include the parent ID.

## [0.3.0] - 2023-11-24 - You

- Progress bars
- Various new APIs and many bug fixes
- Added Tiranti, a Bootstrap-based Calzini HTML renderer replacement
- Added Calzini, a Drawable-to-HTML renderer
- Rename of Widget to Drawable
- Extremely early Shoes-Spec testing support
- Niente, a "no-op" testing display service

## [0.2.1] - 2023-07-02 - Give

- Bugfix release

## [0.2.0] - 2023-07-02 - Gonna

- First batch of functionality. Will aggressively track to changelog from here on out.

## [0.1.0] - 2023-02-09 - Never

- Initial release
