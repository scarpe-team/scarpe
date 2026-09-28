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
- The Shoes spec suite (`spec/run`): 1019 cases from the manual and Noah Gibbs' Shoes-Spec corpus, runnable on Niente and native, with `spec/LEDGER.md` ruling on every place the manual, Shoes 3, Shoes 4 and Lacci disagree
- Lacci: `animate`, `every` and `timer` return `Shoes::Animation`, `Shoes::Every` and `Shoes::Timer`; `Shoes.app`, `window` and `dialog` return the App; methods the manual marks "» self" return self
- Lacci: `left`, `top`, `width` and `height` read laid-out pixels when the display reports them; slots gain `before`, `after`, `scroll_height`, `scroll_max` and `gutter`; `font(path)` returns the family names in the file
- Native text fields undo and redo (Cmd-Z or Control-Z, Cmd-Shift-Z or Control-Y) and take an input method's commit as one edit
- Native windows describe themselves to screen readers through AccessKit: VoiceOver reads and works buttons, checks, radios, fields, list boxes, text, headings, links, progress bars and images. `image(path, alt: "...")` names a picture, and Shoes-Spec gains `a11y_tree`, `a11y_nodes` and `a11y_action`
- Ghost windows (`--ghost`, or `SCARPE_NATIVE_GHOST=1`): real windows that present frames nobody can see or click; every automated windowed run opens them
- `scarpe peek --drag X,Y,X,Y...`, and `drag` in Shoes-Spec test code
- `scarpe package --include PATH` carries any other file or folder an app reads (repeatable); a native package keeps its `--name` as written, spaces and all
- Lacci: `download` takes `start:`, `progress:`, `finish:`, `headers:` and `body:` and no longer needs nokogiri; `Image#path`, `full_width` and `full_height` and the `imagesize` built-in; the `error` built-in; `rgb`, `gray` and the named colours return a `Shoes::Color`, an Array with `red`, `green`, `blue` and `alpha`; `banner`, `title` and the rest of that family are `Shoes::Para` subclasses

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

### Incompatibilities
- An app with no size opens at 600x500 titled "Shoes", as in Shoes 3 and Shoes 4 (it was 480x420 "Shoes!")
- `oval(left, top, n)`: `n` is a diameter, as the manual says, not a radius
- `rotate` adds to the slot's running turn, as in Shoes 3 (it set the angle outright); `scale` and `skew` still set theirs
- `left`, `top`, `width` and `height` include the element's margins, as Shoes 3 reports them
- `ins` is an underline fragment, no longer another name for `inscription`
- Gradients run top to bottom (angle 0) unless given an angle; they used to default to 45
- `clear` keeps the slot's event handlers and the timers it started, as Shoes 3 does
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
