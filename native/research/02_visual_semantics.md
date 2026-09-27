# 02 — Visual semantics of the Webview display service

Lane: how every drawable's properties become pixels in `lib/scarpe/wv/*` + `scarpe-components/lib/scarpe/components/calzini*`, so a native (Rust) renderer can reproduce them, and where it should *not* reproduce them.

Repo: `<repo>` @ `fdcee7a` (master). All paths below are relative to it unless absolute.

## 0. How this was verified, and how to read it

- Read every file in `lib/scarpe/wv/` and `scarpe-components/lib/scarpe/components/{calzini.rb,calzini/*.rb,tiranti.rb,html.rb}`, plus the Lacci drawables that produce the props.
- Rendered real Calzini output through a harness (`scratchpad/research/vs02/harness.rb`, `t1.rb`–`t3.rb`) and composed full pages (`vs02/p1.rb`–`p4.rb` → `p*.html`) that mimic the Webview DOM tree, then measured them in Chrome 153 (Blink) at a forced 480x420 viewport. The real app runs in WKWebView (WebKit) on macOS, so widget pixel sizes below are Chrome UA defaults and will differ by a pixel or two in WebKit; layout rules (flex/block/absolute) are identical.
- Three columns of truth appear throughout: **WV** = what Webview does today; **Manual** = `docs/static/manual.md` (declared source of truth); **Native rec.** = what I recommend the Rust renderer does. Where WV is visibly broken I say so and cite the measurement. Do not port WV bugs.

The big picture: WV's *layout of widgets and text* is mostly sane CSS (flex row for flow, block/flex column for stack). WV's *art* (rect, oval, line, star, arc, arrow, shape) is largely broken geometrically, and its *color* handling is inconsistent per drawable. A native renderer should take layout rules from WV (with the fixes noted) and geometry/color rules from the manual.

---

## 1. Render pipeline (what a display drawable is)

- `Scarpe::Webview::Drawable` (`lib/scarpe/wv/drawable.rb`) receives `properties` (Hash, string keys, = Lacci `shoes_style_values` incl. `"shoes_linkable_id"`), stores each as an ivar (`drawable.rb:51-55`), and `shoes_styles` rebuilds the hash from ivars (`:82-88`).
- `to_html` = `element { children.map(&:to_html).join }` (`drawable.rb:184-188`). Each subclass's `element` calls Calzini `render(name, props=shoes_styles, &block)` which dispatches to `"#{name}_element"` (`calzini.rb:45-47`).
- DOM id of every drawable = `linkable_id.to_s` (`drawable.rb:176-178`). Exception: TextDrawables use `class="id_<linkable_id>"` and are addressed by class (`text_drawable.rb:57-59`).
- HTML DSL: `Scarpe::Components::HTML` (`html.rb`). Attributes with `nil` are dropped, but **`false` is rendered as the string `"false"`** (`html.rb:120-126`). Content strings are inserted raw (no escaping).
- Initial draw and any `full_redraw_request`: `wrangler.replace(doc_root.to_html)` sets `#wrapper-wvroot.innerHTML` (`app.rb:377-383`, `web_wrangler.rb:629-631`).
- Incremental updates (`properties_changed`, `drawable.rb:97-117`): `hidden:true` → `style.display="none"`; `hidden:false` → full re-render of that drawable; `tooltip` → `setAttribute("title", ...)`; anything unhandled → `needs_update!` = `outerHTML = to_html` (`drawable.rb:228-230`). Per-class handled props in §10.

Renderer selection: `ENV["SCARPE_HTML_RENDERER"] || "calzini"` (`lib/scarpe/wv.rb:36-44`); `tiranti` = Bootstrap variant (§11). Webview also pushes 15 web fonts into `Shoes::FONTS` and `:html` into `Shoes::FEATURES` (`wv.rb:62-80`).

---

## 2. Window and page shell

App defaults (Lacci `lacci/lib/shoes/app.rb:42-46`): `title: 'Shoes!'`, `width: 480`, `height: 420`, `resizable: true`.

- `WebWrangler#run` (`web_wrangler.rb:407-432`): `set_title(title)`, `set_size(width, height, hint)` with `hint = resizable ? 0 : 3` (0 = default size, user-resizable; 3 = fixed). Width/height are the content area.
- Empty page (`calzini.rb:56-87`): `body { font-family: arial, Helvetica, sans-serif; margin: 0; height: 100%; overflow: hidden; }`, `p { margin: 0 }`, `#wrapper-wvroot { height:100%; width:100% }`, plus `@keyframes shoesBlink`. Body background = UA default white. Default text color black.
- **`body overflow: hidden` ⇒ the app window never scrolls in WV.** Content past 420px is clipped unless inside a `scroll: true` slot. Manual/Shoes3: the main window scrolls (see `gutter()` = 28 in `app.rb:551-553`). Native rec.: make the root scrollable vertically.
- Root drawable: `DocumentRoot < Flow` with default `width: "100%"`, `height: "100%"` (`lacci/lib/shoes/drawables/document_root.rb:7-8`). Rendered as a flow (`calzini/slots.rb:38-40`) whose last two children are `<div id="root-fonts">` and `<div id="root-alerts"> </div>` (`wv/document_root.rb:55-67`).
- App prop changes (`wv/app.rb:313-331`): `title` → `set_title`; `opacity` → `document.body.style.opacity` (clamped 0..1); `cursor` → `document.body.style.cursor` via `SHOES_CURSOR_MAP` (`app.rb:334-344`).
- Built-in `font(path)` (`document_root.rb:85-100`): appends `@font-face { font-family: <basename without ext>; src: url(data:font/truetype;base64,...) }`. So `font "fonts/Pacifico.ttf"` makes family `Pacifico` available.
- `alert(text)` (`document_root.rb:23-27,102-106`, `calzini/alert.rb`): full-window overlay `position:fixed; background:rgba(0,0,0,0.4)`, centered modal `min-width:200px; min-height:50px; padding:10px; background:#fefefe; border-radius:9px; flex column space-between`, text div then `<button>OK</button>`; OK fires `"<docroot_id>-OK"`, which clears all alerts. `ask`, `confirm`, `ask_color`, `ask_open_file`, `ask_save_file`, `ask_open_folder`, `ask_save_folder` are native macOS `osascript` dialogs (`document_root.rb:28-48,113-183`), response via `Shoes::DisplayService.set_builtin_response`.

---

## 3. Units and numeric rules

### 3.1 `dimensions_length(value)` (`calzini.rb:102-115`) — used for width/height/top/left/margins/padding

| Input | CSS | Notes |
|---|---|---|
| Integer ≥ 0 | `"Npx"` | |
| Integer < 0 | `"calc(100% - |N|px)"` | measured: `width: -400` in 480 → 80px |
| Float | `"#{v*100}%"` e.g. `0.5` → `"50.0%"` | `0.3` in 480 → 144px. Negative float → `"-30.0%"` = invalid CSS, ignored. |
| String | passed through | `"50%"` fine; `"10"` → `margin-left:10` **invalid (unitless), ignored** |
| nil | not emitted | |

Native rec. (matches Noah's GTK `req_to_size`, `ref/gtk-scarpe/lib/scarpe/gtk-scarpe/positioning.rb:246-270`): Integer n → n px; negative Integer → parent − |n|; Float f → parent × f, negative Float → parent × (1+f); `"N%"` → parent × N/100; numeric strings (`"10"`, `"10px"`) → px.

### 3.2 Integer coercion in Lacci

`Drawable.convert_to_integer` (`lacci/lib/shoes/drawable.rb:845-854`) = `Integer(v)` (truncates floats) **then clamps negatives to 0**. Used for Oval `left/top/radius/width/height/strokewidth`, Arc `left/top/width/height`, Arrow `left/top/width`, Border `strokewidth/curve`, Background `curve`, Star `points`. `convert_to_float` (Star `outer/inner`) clamps too. So ovals/arcs can never have negative left/top.

### 3.3 Font size names (`calzini.rb:24-33`, duplicated `wv/para.rb:10-19`)

| Name | px |
|---|---|
| `banner` | 48 |
| `title` | 34 |
| `subtitle` | 26 |
| `tagline` | 18 |
| `caption` | 14 |
| `para` | 12 |
| `inscription`, `ins` | 10 |

`para_font_size` (`calzini/para.rb:176-183`): `SIZES[size.to_s.to_sym] || size.to_s.to_i` then px. So `"20"` → 20px, `"20px"` → 20px, **Float `0.5` → `0px`**, `12.7` → 12px. `text_size` (used by Button, `calzini.rb:89-100`) behaves the same for symbols/strings/numerics (Numeric kept as-is, so Float size on a button → `"12.7px"`).

### 3.4 Margin (Lacci `lacci/lib/shoes/margin_helper.rb`, applied only in `Drawable#initialize`, `drawable.rb:293`)

- `margin: n` (Numeric) → `margin_top/bottom/left/right = n` (unless already given).
- `margin: {left:, top:, ...}` → `margin_<key>`.
- `margin: [a]` or `"a"` → all four = a.
- `margin: [l, t, r, b]` or `"l t r b"` (split on whitespace, `,` or `-`) → **left=0, top=1, right=2, bottom=3** (Shoes order). 2 or 3 values raise `InvalidAttributeValueError`.
- String form produces **string** values (`"10"`) → unitless CSS → ignored by the browser. Only Integer margins work in WV.
- `kwargs[:margin]` is then set to nil. Calzini never reads `"margin"`; it reads `margin_left/right/top/bottom` (`calzini.rb:148-151`). Consequence: **`drawable.style(margin: 10)` after creation does nothing in WV** (`style()` at `drawable.rb:537-565` bypasses `margin_parse`). Native rec.: normalise `margin` in the renderer too (accept number / 4-array / hash on every update).
- CSS is `content-box`: a flow with `width:100%` + `margin_left:10` overflows its parent by 10px (measured).

### 3.5 Padding (Scarpe extension, `calzini.rb:155,174-209`)

`padding` may be Hash (`{dir => v}`), **Array in order `[left, right, top, bottom]`** (`SPACING_DIRECTIONS`, `calzini.rb:160`; note: differs from margin's `[l,t,r,b]`), or scalar (CSS `padding: v`). `padding_left/right/top/bottom` override. If none present, falls back to `props["options"]["padding..."]`. Button overwrites `padding-top/-bottom` with the raw value (`calzini/button.rb:63-64`) ⇒ `padding_top: 10` on a button becomes `padding-top:10` (unitless, **ignored**).

---

## 4. Layout model

### 4.1 Slot DOM (`calzini/slots.rb`)

```
Flow:   <div id=ID style="display:flex;flex-direction:row;flex-wrap:wrap;align-content:flex-start;justify-content:flex-start;align-items:flex-start;[overflow:auto];...slot_style">
          <div style="height:100%;width:100%;position:relative;display:contents"> children </div></div>
Stack:  <div id=ID style="display:flex;flex-direction:column;align-content:flex-start;justify-content:flex-start;align-items:flex-start;[overflow:auto];...slot_style">
          <div style="height:100%;width:100%;position:relative"> children </div></div>
```

`slot_style` (`slots.rb:60-92`) = `drawable_style` + `background_style` + `border_style` + width/height + attach, then `position: relative` unless already absolute. `html_attributes` (event handlers from subscriptions, `wv/slot.rb:62-70`) are merged onto the outer div.

Consequences (all measured in Chrome):

- **Flow**: inner div is `display:contents`, so every child is a flex item of a row-wrap container. Each child is shrink-to-fit (max-content, capped at the line), packed left-to-right, wraps when the next item doesn't fit, rows top-aligned (`align-items:flex-start`), no vertical stretching. Two `para`s in a flow sit **side by side** (p1: `Para after background` at x=0 w=196, next para at x=196).
- **Stack**: outer is a flex column with exactly one flex item (the inner div, `width:100%`). Children therefore live in an ordinary **block formatting context**: block elements (`p`, nested slot divs) take the full stack width and stack vertically; **inline-level widgets (button, input, textarea, select, progress, img, checkbox, radio) sit side by side on a line box and wrap like words** (p3: B1 at x=10, B2 at x=42 on the same line). Line boxes use the inner div's 16px Arial strut, so a 13px checkbox row is ~19px tall (p4: checks at y=17, next para at y=33).
- Stack without `width`: **no default width in Lacci** (`stack.rb` sets none). In a flow (incl. the app root) it is a flex item ⇒ shrink-to-fit (p2: 65px for "stack in flow"). Inside another stack it is block-level ⇒ fills the parent width (p4: nested stack 300 = parent). Flow without width: default `"100%"` (`lacci/lib/shoes/drawables/flow.rb:9`).
- Slot height without `height`: content height; absolutely positioned children (all shapes, anything with top/left) contribute nothing (p3: stack containing only a 30x30 rect + para is 14px tall).
- Lacci's own getter claims Shoes3 slots fill their parent width (`drawable.rb:649-655` "Slots without explicit width should fill their parent (Shoes3 behavior)"). WV disagrees for stacks in flows.

Native rec.: implement Shoes3 semantics explicitly: flow = left-to-right packing with wrap, stack = vertical list; a slot or text block with no width takes the **remaining width of the current line** (Shoes3), which makes consecutive paras/stacks in a flow each start a new line; widgets use intrinsic size. If exact WV parity is wanted instead, use the rules in the bullets above (they are what current screenshots/tests reflect). Flag this choice to the spec lane: it is the single biggest layout divergence.

### 4.2 Common style mapping `drawable_style(props)` (`calzini.rb:117-158`)

| Prop | CSS |
|---|---|
| `hidden` truthy | `display:none` (overrides slot `display:flex` because slot styles are merged after) |
| `top` or `left` present | `position:absolute` + `top`/`left` via `dimensions_length` |
| `width`, `height` | via `dimensions_length` |
| `displace_left`/`displace_top` | `transform: translate(dxpx, dypx)` + `position:relative` if not absolute (raw numbers + "px") |
| `cursor` | `SHOES_CURSOR_MAP` (`calzini.rb:258-282`): `arrow_cursor/arrow→default`, `text_cursor/text→text`, `watch_cursor/wait→wait`, `hand_cursor/hand→pointer`, `crosshair`, `move`, `help`, `not_allowed→not-allowed`; other symbols `_`→`-` |
| `margin_left/right/top/bottom` | `margin-*` |
| padding family | §3.5 |
| `right`, `bottom` | **ignored** (declared as Shoes styles, `drawable.rb:264`, never rendered). Manual: right/bottom edge relative to container. Native rec.: implement. |
| `tooltip` | not in drawable_style; emitted as `title=` only by button/edit_line/edit_box/list_box; any later change sets `title` on any drawable |

Absolute positioning context: slots are `position:relative`, so `top/left` are relative to the **nearest enclosing slot's box** (flow: outer div; stack: inner div = content box). Absolute items leave the flow (siblings close the gap), matching the manual's `move()`. `displace` does not affect layout (manual agrees).

### 4.3 `scroll`, `attach`, `scroll_top`

- `scroll: true` → `overflow:auto` on the slot (`slots.rb:102,113`). Scrollbar appears inside the fixed width (manual agrees). Only meaningful with a height.
- `scroll_top` (`wv/flow.rb`, `wv/stack.rb`): `bind_shoes_event(event_name: "scroll_top")` **with no target**, so every Flow/Stack sets its own `scrollTop` when *any* slot sends `scroll_top`. Native rec.: target the event.
- `attach` (`slots.rb:71-85`): value matched by `to_s`: `/window/i` or `"Shoes::Window"` → `position:absolute`; `"center"`/`":center"` → absolute, `left:50%;top:50%;transform:translate(-50%,-50%)`. But in Lacci `Window = Shoes::App` (`lacci/lib/shoes.rb:52`), so `attach: Window` stringifies to `"Shoes::App"` and **does nothing**. Manual: `attach: Window` → position in window coordinates. Native rec.: treat `Shoes::App` class / `"Shoes::App"` as window attach.

### 4.4 Paint order (z-order) — WV defect

`background` and `border` are `position:absolute` divs with no z-index (`calzini/background.rb:12-21`, `calzini/border.rb:10-18`); shapes are `position:absolute` too. CSS paints positioned boxes after all non-positioned in-flow boxes, so **a background covers every non-positioned sibling (paras, buttons, inputs) regardless of order** (screenshot p1 and p3: all paras/buttons under a `background` vanished; only `position:relative` stacks drew on top). Shapes likewise draw over text. Manual: backgrounds/borders are layered elements in creation order ("Shoes layers background elements").

Native rec.: paint each slot's children strictly in child order (creation order; `prepend` puts children first), backgrounds included, then children-of-children recursively. Backgrounds are normally declared first, so they end up at the bottom.

### 4.5 `hidden`

`display:none` removes from layout. Children hidden with parent. Native: skip layout + paint + hit-testing.

---

## 5. Colors

### 5.1 What arrives in props

Lacci color helpers (`lacci/lib/shoes/colors.rb`):
- `rgb(r,g,b,a=nil)` (`:168-178`): Integers → `[r,g,b,a||255]`; Floats → `[r,g,b,a||1.0]` (float channel 0..1).
- `gray(d=128, a=nil)` (`:162-165`) → `[d,d,d, a || (Integer ? 255 : 1.0)]`.
- Named color methods (`red`, `blue`, … 140 X11 names, `:7-148`): `red(alpha=255)` → `[255,0,0,alpha]`; `red(0.5)` → `[255,0,0,0.5]` (**mixed int channels with float alpha**).
- `gradient(c1, c2, angle: nil)` (`:181-189`) → `Shoes::Colors::Gradient` with `color1`/`color2` CSS strings like `"rgb(255,0,0)"` and `angle` default **45** (`:198`). `first`/`last` return the strings.
- `to_rgb` (`:216-253`): `"#rrggbb"`; `"#rgb"` → **`16*x`, not `17*x`** (`:234`; `#f00` → 240,0,0); named strings/symbols via COLORS; arrays passed through.
- `nofill`/`nostroke` → `rgb(0,0,0,0)` = `[0,0,0,0]` into the draw context (`slot.rb:131-158`).
- Ranges (`"#f00".."#00f"`) are also accepted as gradients by Calzini.
- Strings may also be image paths (`fill "static/avatar.png"`), CSS strings (`"rgba(255,200,0,255)"`), URLs.

Wire note: in-process (`wv_local`) these are Ruby objects. Over the relay they are `JSON.dump`ed (`webview_relay_util.rb:35`): `Gradient` → `"rgb(240,0,0)-rgb(0,0,255)"` (its `to_s`), Range → `"#f00..#00f"`, Symbol → `"black"`, Class → `"Shoes::App"`, arrays stay arrays (verified). A Rust backend needs an explicit serializer for gradients or it loses them.

### 5.2 Conversion functions in Calzini

- `rgb_to_hex(color)` (`calzini.rb:219-255`): nil → nil; `""` → `#000000`; String → unchanged; Range → first; Gradient → `first`; Array → **alpha premultiplied into RGB and dropped**: ints `c*a/255`, floats `c*a`, output `#RRGGBB`. So `[255,0,0,128]` → `#800000` (opaque dark red), **`[0,0,0,0]` (nofill/nostroke) → `#000000` opaque black**.
- `first_color_of(*colors)` (`:211-215`): first non-nil, non-empty, then `rgb_to_hex`.
- Background/border/slot arrays: `"rgba(#{a.join(', ')})"` raw (`background.rb:33-35`, `border.rb:25-26`, `slots.rb:129-130,146-147`): `[255,0,0,128]` → `rgba(255, 0, 0, 128)` → alpha clamps to 1 → **opaque**; floats `[0.0,0.0,1.0,0.5]` → `rgba(0.0,0.0,1.0,0.5)` → **near-black at 50%** (measured `rgba(0,0,1,0.5)`).
- Para `stroke`/`fill` are converted by Lacci to arrays first (`lacci/lib/shoes/drawables/para.rb:7-8`), then `rgb_to_hex`. TextDrawable (em/strong/span/link…) `stroke`/`fill` are raw and pass through `rgb_to_hex` (strings unchanged).

### 5.3 Per-drawable color path (WV)

| Drawable | fill source | stroke source | alpha kept? | gradient |
|---|---|---|---|---|
| rect | `props.fill` \|\| `dc.fill` → `first_color_of` | `props.stroke` \|\| `dc.stroke` | no (premultiplied hex) | first color only |
| oval | `props.fill` (default `"black"`) \|\| `dc.fill` | `props.stroke` (default `"black"`) \|\| `dc.stroke` | no | first color only |
| star | `props.fill` \|\| `dc.fill` \|\| black | `props.stroke` \|\| `dc.stroke` \|\| black | no | first color only |
| line | — | `props.stroke` \|\| `dc.stroke` \|\| black | no | first |
| arrow | `props.fill` \|\| `dc.fill` \|\| black | same | no | first |
| arc | **none emitted** (SVG default black fill, no stroke) | none | — | — |
| shape | `dc.fill` \|\| `"black"` raw into style (array → Ruby `inspect` string, invalid) | none | — | — |
| background | `fill` | — | array: raw rgba (0-255 alpha clamps) | Range/Gradient → `linear-gradient(<angle>deg, c1, c2)` |
| border | — | `stroke` (default `:black`) | array raw rgba | Range → `border-image: linear-gradient(45deg,…)`; Gradient object → treated as string (broken) |
| para | `fill` → background-color | `stroke` → color | no | — |
| text drawables | `fill` | `stroke` | no | — |

Image-path fills: rect/oval/star detect `fill` strings ending in `.png .jpg .jpeg .gif .svg .webp .bmp` (not starting `#`/`rgb`) and use an SVG `<pattern patternUnits="userSpaceOnUse">` with `<image preserveAspectRatio="xMidYMid slice">` sized to the shape's SVG box (`art_drawables.rb:138-148`). Background with an image path renders nothing (`background-color: path.png`, invalid) — regression; only the unused slot `background_color` style handles files (base64 data URI) and URLs.

### 5.4 Native rec. (canonical color model)

Normalise every color prop in the Ruby→Rust serializer to `{"rgba":[r,g,b,a]}` floats 0..1 or `{"gradient":{"from":rgba,"to":rgba,"angle":deg}}` or `{"image":path}`:
- Integer arrays: channels /255, alpha /255 (default 255). Float arrays: as is (alpha default 1.0). Mixed int channels + float alpha (`red(0.5)`): treat alpha ≤ 1.0 Float as 0..1.
- `#rgb` → `x*17`. Named colors from `Shoes::COLORS`. CSS `rgb()/rgba()` strings: parse.
- `[0,0,0,0]` = fully transparent (nofill/nostroke must mean "don't paint").
- Gradient angle (manual `:angle`, `manual.md:1073-1079`): angle 0 = top→bottom, 90 = left→right (rotating counter-clockwise). CSS equivalent is `(180 − angle)deg`; WV passes the Shoes angle straight into CSS (so WV's default 45deg runs bottom-left→top-right). Manual default (no angle): top→bottom.

---

## 6. Art drawables (shapes)

Every WV shape is an absolutely positioned `<div>` (because Lacci always supplies `left`/`top`) wrapping an inline `<svg>`. SVG root clips to its width/height. **Geometry is buggy for most shapes**; measured in p1 (screenshot at 480x420).

Draw context (`lacci/lib/shoes/drawables/slot.rb:24-33,124-204`): per-slot hash with string keys `fill`, `stroke`, `strokewidth`, `rotate`, `scale` (`[x,y]`), `skew` (`[x,y]`), inherited from parents (`current_draw_context`). Passed to shapes as prop `"draw_context"` (only non-nil keys). Lacci also copies `fill/stroke/strokewidth/rotate/transform/translate` from the context into the drawable's own props **if** the drawable declares that style (`DRAW_CONTEXT_STYLES`, `drawable.rb:288,349-362`): rect & oval declare `fill`/`stroke`; oval `strokewidth`; star/line/arc/arrow declare none, so they read `draw_context`. `translate(x,y)` and `cap(style)` are no-op stubs (`app.rb:557-575`). `transform(:center)` on shapes doesn't exist (only on Image).

### 6.1 rect — `rect(left, top, width, height, curve=0)`

Lacci (`rect.rb`): 3 args → height=width; 2 args → `(0,0,w,h)`; 1 arg → `(0,0,s,s)`; kwargs-only defaults left/top 0 and height=width. Styles: `left top width height curve fill stroke draw_context`.
WV (`art_drawables.rb:17-48,189-202`):
```
<div id style="position:absolute;top:Tpx;left:Lpx;width:Wpx;height:Hpx">
  <svg width=W(+2*curve) height=H(+2*curve)>
    <rect x=L y=T width=W height=H style="stroke:S;fill:F" [rx=curve] transform="rotate(DC_ROTATE W'/2 H'/2)"/>
```
- **Bug: `x=left, y=top` inside a div already at (left, top)** ⇒ drawn at (2L, 2T) and clipped to the div's W×H SVG. Measured: `rect(10,40,100,50)` shows only a 90×10 sliver at (20..110, 80..90).
- No stroke-width (SVG default 1). No default fill/stroke given ⇒ SVG default: black fill, no stroke. `rx` only (ry defaults to rx). Rotation around the SVG box center; missing rotate yields `rotate( cx cy)` (invalid, ignored).
Manual (`manual.md:1749-1781`): rect at (left, top) size W×H, `curve` = corner radius, optional `center: true`. Native rec.: rect at (L,T) W×H in slot coords, `curve` corner radius, fill/stroke/strokewidth from props→draw context, default stroke width 1, rotate about the corner (Shoes default `transform :corner`) unless center.

### 6.2 oval — `oval(left, top, radius)` / `oval(left, top, width, height)` / styles

Lacci (`oval.rb:20-45`): requires left, top and one of width/height/radius; `width ||= radius*2`; `width ||= height; height ||= width`; `radius ||= width/2`; defaults `fill "black"`, `stroke "black"`; `center` style (default nil).
WV (`art_drawables.rb:93-134,211-216`):
```
<div style="position:absolute;top:T;left:L;width:W;height:H"><svg width=radius*2 height=(height||radius*2)>
  <ellipse cx=(center ? radius : 0) cy=(center ? svgH/2 : 0) rx=svgW/2 ry=svgH/2 style="fill:F;stroke:S;stroke-width:SW;"/>
```
stroke-width = `props.strokewidth || dc.strokewidth || "2"`.
- **Bug: without `center: true` the ellipse is centred on the SVG's top-left corner ⇒ only the bottom-right quadrant shows** (measured quarter circle at 150..180, 40..70). With `center: true` the ellipse fills the box whose top-left is (left, top) — i.e. WV's `center:true` gives what the manual calls the *default*. `examples/oval.rb` passes `center: true` everywhere to look right.
Manual (`manual.md:1716-1747`): default (left, top) is the top-left of the bounding box; `center: true` makes (left, top) the center. `radius` is half the width (styles list `manual.md:1348-1354`; note the Art intro `manual.md:1639-1645` contradicts itself with "radius: 100 … one-hundred pixels wide"). Native rec.: ellipse in box (L, T, W, H), or centred on (L, T) when `center`.

### 6.3 line — `line(left, top, x2, y2)`

WV (`art_drawables.rb:50-58,174-187`): `<div style="position:absolute;top:T;left:L"><svg width=x2 height=y2><line x1=L y1=T x2=x2 y2=y2 style="stroke:S;stroke-width:4"/>`.
- **Bug: double offset** (start at (2L, 2T), end at (L+x2, T+y2)) and SVG sized x2×y2 so lines going up/left of the start are clipped away. Measured `line(10,150,200,150)` drawn from (20,300) to (210,300).
- **stroke-width fixed at 4; `strokewidth` ignored.**
Manual (`manual.md:1711-1714`): from (left, top) to (x2, y2), current stroke. Native rec.: exactly that, width = strokewidth (dc) default 1, cap per `cap` (default `:rect` = butt).

### 6.4 star — `star(left, top, points=10, outer=100.0, inner=50.0)`

Lacci defaults `points 10, outer 100, inner 50` (`star.rb:11-13`).
WV (`art_drawables.rb:60-91,204-240`): div at (L, T), `<svg width=outer height=outer>`, `<polygon points=… style="fill:F;stroke:S;stroke-width:2" transform=build_svg_transform(dc, outer/2, outer/2)>`. Vertex i (0..points-1): outer vertex at angle `i*2π/points`, inner at `+π/points`, positions `outer/2 + cos(a)*R/2`, `outer/2 + sin(a)*R/2` with R = outer or inner. So first point is at angle 0 (pointing **right**), going clockwise on screen; **`outer` and `inner` are treated as diameters**; bounding box top-left at (L, T).
Manual (`manual.md:1826-1831`, `:1254-1259`, `:1335-1339`): star **centred** at (left, top); `outer` = full radius, `inner` = inner radius. Native rec.: centre (L,T), radii outer/inner, stroke width from strokewidth (default 1), pick a fixed start angle (document it; Shoes3's first point conventionally points up — verify against a Shoes3 screenshot before committing).

### 6.5 arc — `arc(left, top, width, height, angle1, angle2)` (radians, Floats)

WV (`art_drawables.rb:4-15,150-172`): div `position:absolute; left/top/width/height`, `<svg width=W height=H><path d="M cx cy L W cy A rx ry 0 large 0 x2 y2 Z" transform="rotate(DC, cx, cy)"/>`, where x2,y2 = point at angle2; `large = ((a2−a1) mod 360) > 180`. **angle1 is only used for the large-arc flag; the path always starts at angle 0; sweep flag 0 (counter-clockwise) while end point is computed clockwise** ⇒ measured result is a concave sliver, not a wedge. No fill/stroke attributes (SVG default black fill). Lacci clamps negative left/top to 0.
Manual (`manual.md:1665-1670`): section of an oval from angle1 to angle2; `angle1=0, angle2=TWO_PI` ≈ oval. Native rec.: elliptical arc inscribed in (L,T,W,H) from angle1 to angle2, clockwise on screen (cairo convention, y down, 0 = 3 o'clock), filled with fill (pie or chord: decide in spec; Shoes3/cairo draws the arc path and fill closes it with a chord), stroked with stroke.

### 6.6 arrow — `arrow(left, top, width)`

WV (`art_drawables.rb:242-294`): div `position:absolute;left;top` containing `<svg>` **with no size (default 300×150)**, a `<marker id="head">` (same id for every arrow on the page), and `<line x1=L+W y1=T x2=L y2=T stroke-width=W/4 marker-end=url(#head) transform=rotate(DC, L+W/2, T)>`. Head at (L, T) pointing **left**; double offset again; anything with `top ≥ 150` is clipped away entirely (p1: `arrow(10,200,40)` invisible).
Manual (`manual.md:1672-1674`): "Draws an arrow at coordinates (left, top) with a pixel width." Native rec.: shaft from (L, T+W/2·k) to (L+W, …) pointing right, head proportional to width; fill/stroke from context. Decide exact geometry in spec.

### 6.7 shape — `shape(left=nil, top=nil) { move_to/line_to/curve_to/arc_to }`

Lacci: Shape is a Slot (`shape.rb`), `shape_commands` = array of `["move_to",x,y]`, `["line_to",x,y]`, `["curve_to",cx1,cy1,cx2,cy2,x,y]`, `["arc_to",cx,cy,w,h,a1,a2]`. Ovals/rects created inside a shape block become *children* (not path segments).
WV (`wv/shape.rb`): `<div style="width:400;height:900"><svg width=400 height=500><path d=… style="fill:DCFILL;stroke-width:2"/>`. Unitless div size (ignored), **not absolutely positioned (takes layout space, left/top ignored)**, fixed 400×500 canvas, no stroke color, children rendered *before* the shape div. `arc_to` computes points with **y-up** math (`cy - ry*sin`) and starts a new subpath with `M` (`shape.rb:54-70`), unlike arc.
Manual (`manual.md:1799-1824`): path starts at (left, top), cairo semantics (`arc_to` continues the path). Native rec.: build one path in slot coordinates offset by (left, top), fill + stroke from context; child shapes drawn as a group.

### 6.8 Transforms (draw context)

- `rotate(deg)`: rect/arc/arrow/star apply SVG rotate about the SVG box centre (arrow: line midpoint); oval, line, shape ignore rotate. Manual (`manual.md:1783-1797`, `:1857-1860`): rotation of the pen, default origin `:corner`.
- `scale(x, y=x)` and `skew(x, y=0)` (degrees): only star (`build_svg_transform`, `calzini.rb:299-324`) applies them (scale about centre).
- Image: `image.rotate(deg)` → `rotate_angle` → CSS `transform: rotate(Ndeg)`; `image.transform(:center|:corner)` → `transform_origin` `"center"`/`"top left"` (`calzini/misc.rb:39-63`, `lacci/.../image.rb`).

---

## 7. background and border

### 7.1 background — `background(pattern, curve: 0, width:, height:, …)`

Lacci: `HasBackground#background(color, options={})` → `Shoes::Background.new(fill: color, **options)`, a child drawable of the current slot (`lacci/lib/shoes/background.rb:23-32`); default `curve 0`. App-level `background` forwards to current slot.
WV (`calzini/background.rb`): `<div id style="height:inherit;width:inherit;position:absolute;top:0;left:0;box-sizing:border-box;pointer-events:none;background…;[border-radius:Cpx];[height/width override]">`. `inherit` resolves to the slot inner div's `100%`, i.e. **covers the whole slot box** (padding box). `width: 50` → 50px stripe on the left; `height` likewise from the top. Fill: Range → `linear-gradient(45deg, first, last)`; Gradient → `linear-gradient(<angle>deg, c1, c2)`; Array → raw rgba; else `background-color: <string>` (CSS names/hex/rgba strings OK; image paths broken). z-order bug §4.4.
Manual (`manual.md:1899-1919`, `:2752-2803`): colors and images **tile**, gradients stretch; multiple backgrounds layer; `background white, width: 50` = 50px stripe on the left. Native rec.: rectangle (0,0,w||slotW,h||slotH) in slot coords, rounded by `curve`, painted in child order; image patterns tiled.

### 7.2 border — `border(pattern, strokewidth: 1, curve: 0)`

Lacci `Shoes::Border` (`border.rb`): positional `stroke, strokewidth, curve`; defaults `stroke :black`, `strokewidth 1`, `curve 0`. (The `Shoes::Border` *module* with `border_color`/`options` in `lacci/lib/shoes/border.rb` is never required; the Calzini slot `border_style` path is dead code.)
WV (`calzini/border.rb`): same absolute full-slot div, `box-sizing:border-box; border-style:solid; border-width:SWpx; border-radius:Cpx; border-color:S` (Range → `border-image` gradient, Array → raw rgba). Stroke drawn **inside** the slot box. Paints over non-positioned content (harmless, it's hollow).
Native rec.: stroke a rounded rect inset by strokewidth/2 inside the slot box.

---

## 8. Text

### 8.1 Para and the text-block family

Lacci (`lacci/lib/shoes/drawables/para.rb`): `banner/title/subtitle/tagline/caption/inscription(ins)` = `para(size: :<name>)` (`:246-306`); default `size :para` (`:38`). Styles: `text_items size family font_weight font font_variant emphasis kerning weight wrap stroke fill underline strikethrough align text_cursor text_marker` + common. `stroke`/`fill` converted to RGB arrays; `underline ∈ [nil,none,single,double,low,error]`; `strikethrough ∈ [nil,none,single]`; `align ∈ [left,center,right]`. `font:` string is parsed by `FontHelper#parse_font` (`font_helper.rb`) into `emphasis` (italic/oblique), `font_variant` (small-caps/initial/inherit), `font_weight` (bold/bolder/lighter/100..900), `size` (any token containing a digit, e.g. `"14"`, `"20px"`), `family` (remaining words joined by spaces).
`text_items`: array of Strings and TextDrawable linkable_ids (`para.rb:128-130,245-249`).

WV DOM (`calzini/para.rb:4-24,28-105`, `wv/para.rb:77-100`):
```
<p id style="color;background-color;font-size;font-family;text-decoration-line:line-through;font-weight;font-style;letter-spacing;font-variant;[position/top/left/width/margins…]">…</p>
```
If `align`, `wrap`, or `underline` is set, the `p` (without id) is wrapped: `<div id style="text-align;white-space/overflow/text-overflow|word-break;text-decoration-line:underline;text-decoration-style;text-underline-offset;text-decoration-color;width:100%">`.

| Prop | CSS |
|---|---|
| `size` | `font-size` px (§3.3) |
| `stroke` | `color: #RRGGBB` |
| `fill` | `background-color` (highlighter) |
| `family` | `font-family` (raw) |
| `font_weight` | `font-weight` (**`weight` is ignored**, also on link) |
| `emphasis` | `font-style` normal/oblique/italic |
| `kerning` | `letter-spacing: Npx` |
| `font_variant` | `font-variant` |
| `strikethrough: "single"` | `text-decoration-line: line-through`; `strikecolor` → `text-decoration-color` (not a declared Para style) |
| `underline` single/double/error/low | wrapper `text-decoration-line: underline` + style `double`/`wavy`/offset `0.3rem`; `undercolor` → `text-decoration-color` |
| `align` | wrapper `text-align` |
| `wrap: "trim"` | wrapper `white-space:nowrap; overflow:hidden; text-overflow:ellipsis` (ellipsis doesn't show because the text lives in the child p; text is just clipped) |
| `wrap: "char"` | wrapper `word-break: break-all` |
| `rise` | `vertical-align: Npx` (not a declared style on Para or TextDrawable, so unreachable) |
| `leading`, `justify`, `stretch`, `variant`, `strokewidth` | not implemented |

Metrics (Chrome, Arial, `line-height: normal` ≈ 1.15×): box heights banner 48px→55, title 34→39, subtitle 26→30, tagline 18→21, caption 14→16, para 12→14, inscription 10→12. Paragraph margins 0; no extra spacing between paras. Manual: `:leading` defaults to 4px between lines (`manual.md:1282-1286`). Native rec.: line height = font ascent+descent (~1.15×size) + leading (default 4 → consider whether to honour; WV uses 0).

Content: String items have `"\n"` → `<br>` and are **not HTML-escaped** (`wv/para.rb:97`); native must render literally. Width: in a stack the p is full width; in a flow it is shrink-to-fit up to the line (§4.1) and wraps at word boundaries.

Para cursor/selection (`wv/para.rb:22-63`, JS module `wv/app.rb:94-285`): `text_cursor` (char index or nil) draws a 1px black caret `animation: shoesBlink 1s step-end infinite`; `text_marker` + cursor highlights the range with `rgba(51,153,255,0.3)` rects. Mouse moves report `scarpeParaHitReport(para_id, char_index)` (hit-test cache for `Para#hit`) and caret top `scarpeParaCursorTopReport(para_id, y)` (for `cursor_top`).

`text_items` change → `innerHTML = to_html` of the p itself (`wv/para.rb:27-28`), which nests a second `<p id=…>` inside the first. Cosmetic only.

### 8.2 TextDrawables (inline spans)

Lacci (`text_drawable.rb`): classes `Code Del Em Strong Span Sub Sup Ins` (+ `Link`). Declared styles: `text_items size stroke strokewidth fill undercolor font strikethrough underline` + common. `Ins` default `underline: "single"` (`:131`). Link adds `text click has_block weight`.
WV (`wv/text_drawable.rb:62-90`, `calzini/para.rb:191-261`): element `<TAG class="id_ID" style=…>` with TAG: `code→code`, `del→del`, `em→em`, `strong→strong`, `span→span`, `sub→sub`, `sup→sup`, `ins→span`, `link→a`. Uses the same `text_specific_styles` as para (so `stroke`, `fill`, `size`, `strikethrough`, `underline` work; `font` is declared but **ignored**; `family`, `emphasis`, `kerning`, `weight` are not declared). An underline wraps the tag in an extra `<span class="id_ID" style="text-decoration…">`. Nested TextDrawables nest recursively; strings get `"\n"` → `<br/>`.

Browser defaults that WV relies on (measured, para 12px parent): `code` monospace 12px; `del` line-through; `em` italic; `strong` bold (700); `sub`/`sup` font-size 10px (`smaller`) with `vertical-align: sub/super`; link `<a>` color `#0000EE` (UA), underline, visited `#551A8B`, pointer cursor, **no hover style**.
Manual: link = single underline, stroke `#06E`; LinkHover = underline, stroke `#039` (`manual.md:2034-2039`); sub/sup: rise −10/+10 px and x-small (`manual.md:2093-2106`, `:1366-1372`); ins = single underline; code = monospace. Native rec.: follow manual colors (`#0066EE`, hover `#003399`), sub/sup rise ±10px at `x-small` (64% of current size per `manual.md:1399-1408`).

Link click (`calzini/para.rb:232-253`, `lacci/.../link.rb`): `click: "http…"` → `href` (clicking navigates the whole webview away: WV bug); `click: "/route"` → `has_block=true`, `onclick` handler, Lacci calls `app.visit`; block given → `href="#"` + `onclick`. Native rec.: URL → open in system browser; `/route` or block → fire `click`.

### 8.3 Font string on widgets (`parse_font`, `calzini/para.rb:108-174`)

edit_line / edit_box / list_box `font:` → CSS shorthand `"<style> <variant> <weight> <size> <family>"` with defaults `normal normal normal medium Arial`; bare-number size gets `px`. E.g. `"Monospace 14"` → `font: normal normal normal 14px Monospace`. Button `font` → `font-family` only.

---

## 9. Widgets (native controls)

Measured default sizes are Chrome UA (13.333px Arial control font). WKWebView on macOS uses Aqua controls with the system font; expect ±2px.

| Widget | WV element | Props → CSS/attrs | Default size (Chrome) |
|---|---|---|---|
| button | `<button id onclick onmouseover title class>` text (`calzini/button.rb`) | `width/height/top/left` (px), `color`→background-color (raw; arrays break), `text_color`/`stroke`→color, `size`→font-size (§3.3), `font_size` raw (Integer → unitless, ignored), `font`→font-family, `padding_top/bottom` raw (ignored when Integer), `tooltip`→title, `icon` (img URL) + `icon_pos` left/right/top/bottom (img `max-height:1.2em` side / `1.5em` stacked), `html_class` (feature `:html`) | "Button": 55×22; padding 1px 6px, border 2px outset, bg #EFEFEF |
| check | `<input type=checkbox id onclick value=text checked=…>` | `checked` → attribute; **`checked: false` renders `checked="false"` = checked** (verified). Later changes via `.checked = bool` | 13×13, margin 3px 3px 3px 4px |
| radio | `<input type=radio name=GROUP …>` | `group` or parent slot's linkable_id (`wv/radio.rb:23-31`); same `checked` bug | 13×13, margin 3px 3px 0 5px |
| edit_line | `<input type=text\|password value oninput onmouseover title>` | `secret`→password, `width`, `font` (§8.3), `stroke`→color. No `height` style. | 147×22 (size=20 chars) |
| edit_box | `<textarea oninput onmouseover title>text</textarea>` | `width`, `height`, `font` | 183×37 (cols 20, rows 2), UA monospace font, resizable grip |
| list_box | `<select onchange title><option value=item>…` | `items`, `width`, `height`, `font`, `stroke`→color. **Initial selection ignores `chosen`**: Calzini checks `props["choose"]` but Lacci sends `"chosen"` (`misc.rb:77` vs `list_box.rb:10,19`), so the first item always shows until a later `chosen` prop_change sets `.value`. `ListBox#choose` sets `@chosen` without a prop_change (`list_box.rb:40`), so it never updates the display either. | "alpha": 55×19 |
| progress | `<progress max=1 value=fraction role=progressbar aria-*>` | `fraction` 0..1; nil → indeterminate | 160×16 |
| image | `<img id src style onclick onmouseover onmouseout>` | `url` (http(s)/data URLs used directly; file paths served via the local asset server, `wv/image.rb:24-30`; empty → transparent 1×1 PNG spacer), `width`/`height` (one given → other auto keeps aspect), `top/left`, `click` truthy → `cursor:pointer`, `rotate_angle`, `transform_origin`. Lacci: `image(w, h)` numeric form sets width/height with blank url. | natural image size |
| video | `<video controls><source src type>` | `url`; type from extension: `.mp4 video/mp4`, `.webp video/webp`, `.mov video/quicktime`, `.mkv video/x-matroska` (`wv/video.rb:5-22`) | 300×150 until loaded |
| slider | not implemented anywhere (no Lacci class) | | |

`state` ("readonly"/"disabled", `manual.md:1410-1421`), `autoplay`, `focus` for button/check/radio are absent in WV. `focus()` exists for edit_line, edit_box, list_box via `bind_shoes_event("focus")` → `element.focus()`.

Mask (`wv/mask.rb`, `calzini/slots.rb:30-58`): a Mask slot renders its children in an invisible container (`opacity:0; pointer-events:none; z-index:-1; overflow:hidden`, width/height 100%; the intended `position:absolute` is overwritten to `relative` by `slot_style`, so the mask takes layout space until JS hides it). A hidden `<img onerror=…>` then: collects each child `<svg>` (inner markup with every fill/stroke recolored white, translated by the svg's parent div `left/top`) and each text element (`p, h1-h6, span`) as SVG `<text>` in white at its layout position; builds an SVG data URI of the parent inner div's size (fallback 500×500); sets it as `mask-image`/`-webkit-mask-image` (`no-repeat`, exact size) **on the mask's parent slot inner div**; then `display:none` on the mask. Net effect: the parent slot's other content is visible only where the mask's shapes/text are. Native rec.: render mask children to an alpha mask (union of shapes/glyphs), clip the parent slot's other children to it.

Tooltip: `title` attribute ⇒ native OS tooltip after hover delay.

---

## 10. Events (JS → Ruby) and prop updates (Ruby → DOM)

### 10.1 Mechanism

- JS calls the bound function `scarpeHandler(name, ...args)` (`wv/app.rb:48-50`). `name = "#{linkable_id}-#{event}"` built by `handler_js_code(event, *js_arg_exprs)` (`drawable.rb:237-242`). `App#handle_callback` looks up `@callbacks[name]` (registered by `Drawable#bind(event)`, `drawable.rb:194-198`) and the display drawable calls `send_self_event(*args, event_name:)`, which Lacci receives via `bind_self_event`.
- Other bound JS functions: `scarpeInit` (first redraw), `scarpeExit` (destroy), `scarpeHeartbeat` (every 0.1 s, `web_wrangler.rb:114-122`), `scarpeMouseTracker(button, pageX, pageY)` on document mousemove/mousedown/mouseup (button 1 while left held, else 0) → `Shoes::DisplayService.mouse_state = [b, x, y]` (`app.rb:58-60,76-92`), `scarpeParaHitReport`, `scarpeParaCursorTopReport`, `dynamicRubyCallback(id)` (post-start timers), `puts` (console forwarding).

### 10.2 Per-drawable events (display → Lacci)

| Drawable | DOM hook | Event name | Args sent | Lacci reaction |
|---|---|---|---|---|
| button | `onclick` | `click` | none | calls block |
| button | `onmouseover` (fires repeatedly across children) | `hover` | none | `@hover&.call` |
| check | `onclick` | `click` | none | `checked = !checked?`, block(self) |
| radio | `onclick` | `click` | none | uncheck others in group, `checked = true`, block(self) |
| edit_line | `oninput` (every keystroke) | `change` | `this.value` | `text = v`, block(v) |
| edit_box | `oninput` | `change` | `this.value` | `text = v`, block(self) |
| edit_line/edit_box | `onmouseover` | `hover` | none | |
| list_box | `onchange` | `change` | selected option value | `chosen = v`, block(self) |
| image | `onclick` / `onmouseover` / `onmouseout` | `click` / `hover` / `leave` | none | handlers |
| link | `onclick` (only when has_block) | `click` | none | route visit / block(self) |
| alert OK | button `onclick` | `OK` on DocumentRoot id | none | alerts cleared |

Para, shapes, background etc. have **no** click/hover wiring in WV even though Lacci exposes `click`/`hover`/`release` on every drawable (`drawable.rb:758-803`).

### 10.3 Slot/app subscriptions (`SubscriptionItem`, `wv/subscription_item.rb`)

Created by `motion hover leave click release keypress wheel animate every timer` on App or Slot (`lacci/lib/shoes/app.rb:414-421`). Parent = current slot. Webview attaches attribute handlers on the parent slot's **outer** div via `set_event_callback` (multiple handlers joined with `;`):

| API | DOM | JS args → Ruby | Lacci block args |
|---|---|---|---|
| `motion` | `onmousemove` | x, y relative to slot bounding rect (`clientX - rect.left`), `ctrlKey`, `shiftKey` | `(x, y, mods)` mods ∈ `""`, `"control"`, `"shift"`, `"control_shift"` |
| `hover` | `onmouseenter` | — | `(slot_subscription)` |
| `leave` | `onmouseleave` | — | same |
| `click` | `onclick` | `event.button` (**JS numbering: 0=left, 1=middle, 2=right**; Shoes3 uses 1=left), x, y slot-relative | `(button, x, y)` |
| `release` | `onmouseup` | same | `(button, x, y)` |
| `keypress` | document `keydown` listener (global) | key string (below) | `:sym` for `":name"` strings, else String |
| `wheel` | `onwheel` + `stopPropagation()` | `-deltaY` (positive = up), `clientX`, `clientY` (**window-relative**) | `(delta, x, y)` |
| `animate(fps=10)` | `setInterval(1000/fps)` | counter starting at 1 | `(frame)` |
| `every(sec)` | `setInterval` | counter starting at 1 | `(count)` |
| `timer(sec=1)` | `setTimeout` (one shot) | — | `()` |

`stop/start/toggle` set the `stopped` prop; WV checks `@stopped` before sending (`subscription_item.rb:7-18`).

Keypress mapping (`subscription_item.rb:115-162`): `ArrowLeft/Right/Up/Down → :left/:right/:up/:down`, `Home :home`, `End :end`, `PageUp :page_up`, `PageDown :page_down`, `Escape :escape`, `Backspace :backspace`, `Tab :tab`, `Enter :return`, `Delete :delete`, `Insert :insert`, `F1..F12 :f1..:f12`, `" "` → `" "`; bare Control/Shift/Alt/Meta ignored; other single chars as-is (shift is implicit in the char); other named keys → `":" + key.downcase`. Modifiers: characters get `alt_` then `control_` prefixes (`"control_c"`); special keys get `alt_`, `control_`, `shift_` prefixes and lose the colon (`"shift_left"` is sent as a plain string, **not** a symbol).

**Lacci double-fire (verified under Niente):** `SubscriptionItem#initialize` binds a per-type handler and then unconditionally a second generic `bind_self_event(shoes_api_name) { |*args| @callback&.call(*args) }` (`lacci/lib/shoes/drawables/subscription_item.rb:89-91`). Every event calls the user block twice: `keypress` got `[:left, ":left"]`, `animate(3)` ran twice. Any native backend test that counts callbacks will see this.

### 10.4 Ruby → DOM incremental updates

| Class | Prop | DOM op |
|---|---|---|
| any | `hidden` true / false | `style.display="none"` / full re-render |
| any | `tooltip` | `setAttribute("title", v)` |
| Check, Radio | `checked` | `.checked = true/false` |
| EditLine, EditBox | `text` | `.value = \`…\`` |
| ListBox | `chosen` | `.value = \`…\`` |
| Para | `text_items` | `innerHTML = to_html` |
| Para | `text_cursor`, `text_marker` | `scarpeParaCursor.updateCursor/removeCursor` |
| App | `title`, `opacity`, `cursor` | window title / body style |
| Slot | event `full_redraw_request` (after `clear { }`) | whole-page replace |
| Flow/Stack | event `scroll_top` | `.scrollTop = v` |
| everything else | any | `outerHTML = to_html` |

---

## 11. Tiranti (Bootstrap) variant

`SCARPE_HTML_RENDERER=tiranti` (`tiranti.rb`): Bootswatch theme CSS (default `sketchy`, env `SCARPE_BOOTSTRAP_THEME`), body `height:100%; overflow:hidden` (no font reset). Overrides: button → `class="btn btn-primary"` (or `btn <html_class>`), no hover handler; alert → Bootstrap modal markup; check → wrapped in `div.form-check`; progress → striped animated `div.progress` at `width:90%`; para → tag by size: `≥48px h1`, `≥34 h2`, `≥26 h3`, `%`/calc sizes `h2`, else `p`. Everything else = Calzini. Not the default; not worth porting.

---

## 12. Spec coupling to HTML (heads-up for the backend and spec lanes)

142 of 805 cases in Noah's Shoes-Spec (`ref/shoes-spec/cases/**/*.sspec`) call `dom_html` and assert substrings. HTML/CSS-specific ones found: `svg` (9), `path` (6), `style` (4), `#FF0000` (4), `#00FF00` (3), `button` (3), `rect`/`polygon`/`img`/`font-family`/`<strong` (2 each), `#ff0000`, `#008000`, `ellipse`, `line`, `textarea`, `select`, `progress`, `rgba`, `underline`, `font-weight`, `<a`, `50px`, `100% - 80px`, `20px margin-left`. A native backend must either provide a `dom_html`-like serialization that emits these tokens (e.g. an HTML-ish dump of its display tree using Calzini tag names and `#RRGGBB` uppercase hex) or those cases must be rewritten against drawable queries.

---

## 13. Drawable → props → visual rule (implementable table)

Coordinates: slot-local, origin = slot top-left; y down; px. "Ctx" = draw_context inheritance (own prop wins, then nearest slot's `fill/stroke/strokewidth/rotate/scale/skew`). Colors per §5.4. "WV" notes the current behaviour only where it differs from the rule.

| Drawable | Props (wire names) | Visual rule for native renderer | WV today |
|---|---|---|---|
| App | `title="Shoes!"`, `width=480`, `height=420`, `resizable=true`, `opacity`, `cursor` | Window content W×H, title; fixed size if `resizable:false`; white bg; default font Arial/Helvetica/sans-serif, black; root is a flow filling the window, vertically scrollable | never scrolls (`overflow:hidden`) |
| DocumentRoot | `width="100%"`, `height="100%"` | Flow (below) | |
| Flow | `width` (default `"100%"`), `height`, `margin_*`, `padding*`, `scroll`, `scroll_top`, `attach`, `top/left`, `hidden`, `displace_*` | Pack in-flow children left→right, wrap to next row when the next child's outer width exceeds remaining width; row height = tallest child; children top-aligned; height = content unless set; `scroll:true` + height → clip & vertical scrollbar inside width; `top/left` → absolute in parent slot | as rule |
| Stack | same, no default width | Children top→bottom, each on its own row, left-aligned; width = remaining line width (Shoes3) | block flow: inline widgets share lines; shrink-to-fit in flows, full width in stacks |
| (any slot child) with `top`/`left` | | Out of flow, placed at (left, top) in the slot's box, no effect on siblings or slot height | as rule |
| Widget (Shoes::Widget subclass) | | render as Flow | Flow |
| Mask | children | Children form an alpha mask over the parent slot's other content | JS + CSS mask-image |
| Background | `fill`, `curve=0`, `width`, `height` | Filled rect (0,0,width‖slotW,height‖slotH), radius `curve`; colors/images tile, gradients stretch; painted in child order | covers later non-positioned siblings; image paths ignored; array alpha 0–255 clamps to opaque; float arrays near-black |
| Border | `stroke=:black`, `strokewidth=1`, `curve=0` | Stroke rounded rect around the slot box, inside it | as rule (paints above content) |
| Para (+banner…inscription) | `text_items`, `size` (banner 48/title 34/subtitle 26/tagline 18/caption 14/para 12/inscription 10), `stroke`, `fill`, `family`, `font`, `font_weight`, `emphasis`, `font_variant`, `kerning`, `underline`, `strikethrough`, `align`, `wrap`, `text_cursor`, `text_marker` | Wrapped text block; line height ≈1.15×size (+leading, manual default 4); color stroke (default black); fill = highlight behind glyphs; underline single/double/low/error(wavy); strike single; align left/center/right; wrap word/char/trim(clip); `"\n"` = line break; text literal (no HTML) | `weight` ignored; Float size → 0px; siblings in a flow sit side by side |
| code / del / em / strong / span / sub / sup / ins | `text_items`, `size`, `stroke`, `fill`, `underline`, `strikethrough`, `undercolor` | Inline run inheriting para style; code = monospace; del = strike; em = italic; strong = bold 700; sub/sup = x-small, baseline −10/+10px; ins = underline | `font` ignored; sub/sup use UA sizes |
| link | `text_items`, `click` (URL or `/route`), `has_block` | Inline run, color `#0066EE`, underline; hover `#003399`; pointer cursor; click → `click` event (URL → system browser) | UA `#0000EE`, no hover; URL navigates the webview |
| rect | `left`, `top`, `width`, `height` (=width if missing), `curve`, `fill`, `stroke`, Ctx | Rect (L,T,W,H) radius curve; fill; stroke width Ctx strokewidth (default 1); rotate about corner | double offset + clipped; no stroke-width |
| oval | `left`, `top`, `radius`, `width`(=2r), `height`(=width), `center`, `fill="black"`, `stroke="black"`, `strokewidth`, Ctx | Ellipse in box (L,T,W,H); `center:true` → centred on (L,T) | quarter-circle unless `center:true`; default stroke width 2 |
| line | `left`, `top`, `x2`, `y2`, Ctx | Segment (L,T)→(x2,y2), Ctx stroke & strokewidth (default 1), cap | double offset, width fixed 4, clipped |
| star | `left`, `top`, `points=10`, `outer=100`, `inner=50`, Ctx | Star centred at (L,T), outer/inner radii, 2·points vertices alternating; fill+stroke | top-left at (L,T), outer/inner used as diameters, stroke width 2, starts pointing right |
| arc | `left`, `top`, `width`, `height`, `angle1`, `angle2` (radians), Ctx | Elliptical arc inscribed in (L,T,W,H), angle1→angle2 clockwise from 3 o'clock; fill + stroke | broken path, always starts at angle 0, no colors |
| arrow | `left`, `top`, `width`, Ctx | Arrow of length `width` at (L,T); fill+stroke from Ctx | head at (L,T) pointing left, double offset, invisible if top ≥ 150 |
| shape | `left`, `top`, `shape_commands` (`move_to x y`, `line_to x y`, `curve_to cx1 cy1 cx2 cy2 x y`, `arc_to cx cy w h a1 a2`), Ctx | Single path offset by (L,T), cairo semantics (arc_to continues path, clockwise), fill+stroke | fixed 400×500, not positioned, fill only, y-up arc_to |
| button | `text`, `width`, `height`, `top`, `left`, `color`, `text_color`, `stroke`, `size`, `font_size`, `font`, `padding_top/bottom`, `tooltip`, `icon`, `icon_pos` | Native push button, intrinsic size (≈55×22 for "Button") unless width/height; click → `click` | Integer `font_size`/`padding_*` ignored |
| check | `checked` | Native checkbox ≈13×13 (+3px margins); click toggles, fires `click` | `checked:false` renders checked |
| radio | `group` (default: parent slot id), `checked` | Native radio; one per group checked | same `false` bug |
| edit_line | `text`, `width` (default ≈147), `secret`, `font`, `stroke`, `tooltip` | Single-line field ≈22 high; `secret` masks; every edit fires `change(text)` | |
| edit_box | `text`, `width`, `height` (default ≈183×37), `font`, `tooltip` | Multi-line text area; `change(text)` per edit | |
| list_box | `items`, `chosen` (initial = `choose:` or first), `width`, `height`, `font`, `stroke` | Popup menu showing `chosen`; selection fires `change(item)` | initial selection ignored (always first) |
| progress | `fraction` 0..1 (nil = indeterminate) | Native progress bar ≈160×16 | |
| image | `url` (path/URL/data), `width`, `height`, `top`, `left`, `click`, `rotate_angle`, `transform_origin` | Natural size, or scaled with aspect when one side given; click/hover/leave events | |
| video | `url` | Player with controls (≈300×150 before load) | |
| alert / ask / confirm / ask_color / ask_*_file / ask_*_folder | text | Modal dialogs; alert returns on OK | alert is in-page overlay; others osascript |
| SubscriptionItem | `shoes_api_name`, `args`, `stopped` | Events per §10.3 on the parent slot's box | JS button numbering; wheel window-relative |
