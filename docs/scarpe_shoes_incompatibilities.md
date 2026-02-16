---
layout: default
title: scarpe shoes incompatibilities
---

# Scarpe/Shoes Incompatibilities

This document outlines known incompatibilities between Scarpe and classic Shoes3 (the original _why implementation and its successors).

## Unsupported Shoes3 Widgets

These widgets exist only in Shoes3 and have no Scarpe equivalent:

- **`plot`** - Graphing/charting widget
- **`terminal`** - Embedded terminal emulator
- **`systray`** - System tray icon
- **`spinner`** - Loading spinner widget
- **`switch`** - Toggle switch widget (use `check` instead)
- **`video`** - Video player (VLC-based in Shoes3)
- **`svghandle`** - SVG rendering (Scarpe uses `image` with SVG data URIs)

## Unsupported Shoes3 APIs

### Global App Settings (`Shoes.` methods)
- `Shoes.settings` - Application preferences
- `Shoes.monitor` - Display/monitor detection
- `Shoes.show_manual` - Built-in manual viewer (stub only in Scarpe)
- `RELEASE_*` constants - Version/release info

### Event System
- `shoesevent` - Programmatic event creation
- `event` block - Global event capture/replay
- Event capture/replay system

### Decoration & Theming
- `decoration` - Window decoration control
- `cache` - Asset caching system

### Native Menus
- `menu`, `menubar` - Native OS menus

## Behavioral Differences

### Scripts Without `Shoes.app`

Classic Shoes allowed calling `ask()`, `alert()`, and other builtins at the top level without wrapping in `Shoes.app`:

```ruby
# This works in classic Shoes, NOT in Scarpe
guess = ask "What's your name?"
alert "Hello, #{guess}!"
```

**Scarpe requires `Shoes.app`** because builtins need a WebView context:

```ruby
# Scarpe-compatible version
Shoes.app do
  guess = ask "What's your name?"
  alert "Hello, #{guess}!"
end
```

### Method Definition Order

Methods defined AFTER `Shoes.app` are not available inside the block:

```ruby
# This will FAIL - to_radians doesn't exist when Shoes.app runs
Shoes.app do
  angle = to_radians(45)  # NoMethodError!
end

def to_radians(deg)
  deg * Math::PI / 180
end
```

**Solution:** Define helper methods BEFORE `Shoes.app`:

```ruby
# This WORKS
def to_radians(deg)
  deg * Math::PI / 180
end

Shoes.app do
  angle = to_radians(45)  # Works!
end
```

### Widget Positioning

In classic Shoes, widgets knew their position after layout. In Scarpe, `self.left` and `self.top` inside `Widget#initialize` return `nil` because browser layout hasn't occurred yet.

```ruby
class MyWidget < Shoes::Widget
  def initialize
    @x = self.left  # nil in Scarpe, had value in classic Shoes
  end
end
```

### `ask()` Cancel Behavior

- **Classic Shoes:** `ask()` returned `nil` on cancel
- **Scarpe:** `ask()` returns empty string `""` on cancel (more predictable for string operations)

### Pre-app Dialogs

Calling `confirm()`, `ask()`, or `alert()` before `Shoes.app` exists doesn't work in Scarpe:

```ruby
# Works in classic Shoes, fails in Scarpe
if confirm("Continue?")
  Shoes.app { ... }
end
```

## External Dependencies

Some Shoes3 examples require gems that are dead or incompatible with modern Ruby:

- **hpricot** - Dead HTML parser (use Nokogiri)
- **bluecloth** - Markdown renderer (use kramdown or redcarpet)
- **observer** - Removed from Ruby 3.4 stdlib

## Migration Tips

1. **Wrap all code in `Shoes.app`** - Don't rely on top-level builtins
2. **Define helpers before `Shoes.app`** - Method order matters in Ruby
3. **Use `check` instead of `switch`** - Similar functionality
4. **Replace `svghandle` with `image`** - SVG data URIs work well
5. **Use Nokogiri instead of hpricot** - For HTML/XML parsing
6. **Test `ask()` cancel handling** - Now returns `""` not `nil`

## What Works Well

Scarpe has excellent compatibility with core Shoes features:

- Layout: `stack`, `flow`, `background`
- Drawing: `rect`, `oval`, `line`, `arc`, `star`, `shape`, `mask`
- Text: `para`, `title`, `subtitle`, `tagline`, `caption`, `inscription`, `banner`
- Styles: `span`, `strong`, `em`, `link`, `code`, `ins`, `del`, `sub`, `sup`
- Interaction: `button`, `click`, `hover`, `leave`, `keypress`, `motion`
- Input: `edit_line`, `edit_box`, `list_box`, `check`, `radio`
- Timing: `animate`, `timer`, `every`
- Dialogs: `alert`, `confirm`, `ask`, `ask_color`, `ask_open_file`, `ask_save_file`
- Graphics: `fill`, `stroke`, `strokewidth`, `nofill`, `nostroke`, `rotate`
- Custom: `Shoes::Widget` subclasses
- Navigation: URL routing with `url` and `visit`
- Turtle graphics: Full `Turtle.draw` / `Turtle.start` support

The Hackety Hack samples are a good test suite - 9 of 12 run unmodified on Scarpe.
