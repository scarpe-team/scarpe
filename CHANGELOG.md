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
- The Shoes spec suite (`spec/run`): 983 cases from the manual and Noah Gibbs' Shoes-Spec corpus, runnable on Niente and native, with `spec/LEDGER.md` ruling on every place the manual, Shoes 3, Shoes 4 and Lacci disagree
- Lacci: `animate`, `every` and `timer` return `Shoes::Animation`, `Shoes::Every` and `Shoes::Timer`; `Shoes.app`, `window` and `dialog` return the App; methods the manual marks "» self" return self
- Lacci: `left`, `top`, `width` and `height` read laid-out pixels when the display reports them; slots gain `before`, `after`, `scroll_height`, `scroll_max` and `gutter`; `font(path)` returns the family names in the file
- Native text fields undo and redo (Cmd-Z or Control-Z, Cmd-Shift-Z or Control-Y) and take an input method's commit as one edit
- Ghost windows (`--ghost`, or `SCARPE_NATIVE_GHOST=1`): real windows that present frames nobody can see or click; every automated windowed run opens them
- `scarpe peek --drag X,Y,X,Y...`, and `drag` in Shoes-Spec test code
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
- `scarpe package` took scarpe-components for scarpe, and the webview packager set an environment variable nothing reads
- Lacci: a `stroke` or `fill` set inside a `shape` block never reached that shape
- Native: nothing on stdin (huge sizes, deep nesting, reparenting loops, lines that are not UTF-8) can crash the renderer or make it allocate without bound

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
