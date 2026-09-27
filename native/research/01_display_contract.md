# 01: The Lacci <-> display service contract (protocol level)

Repo: `<repo>` @ `fdcee7a` (master). Line numbers are from that tree.
Everything marked **(probed)** was observed by running Lacci + Niente with an event logger.
The probe scripts are in `research/probe/` (`probe_lib.rb`, `p1_lifecycle.rb`, `p2_events.rb`, `p3_classes.rb`, `p4_serialize.rb`, `p5_tree.rb`).
To run one: `cd scarpe-native && NIENTE_LOG_LEVEL=warn bundle exec ruby <probe>`.

---

## 0. The whole contract in one screen

A display service is **one Ruby class** that Lacci instantiates lazily and then talks to through **one method plus a synchronous pub/sub bus**.

1. **Selection.** `lib/scarpe.rb:11-14` does `require "scarpe/#{ENV["SCARPE_DISPLAY_SERVICE"] || "wv_local"}"`. The required file must call `Shoes::DisplayService.set_display_service_class(Klass)` (`lacci/lib/shoes/display_service.rb:192`, which can only be called once). A new service named `native` would live at `lib/scarpe/native.rb`.
2. **Instantiation.** `Shoes::DisplayService.display_service` (`display_service.rb:200-206`) calls `Klass.new` with no arguments. This happens the first time a drawable is created, which is the first app's DocumentRoot. That makes it a good moment to spawn a child process. The subclass must call `super()`, which sets `@display_drawable_for = {}` (`:209-211`).
3. **The only direct call** is `create_display_drawable_for(drawable_class_name, drawable_id, properties, parent_id:, is_widget:)` (`display_service.rb:215`). It is called from `Shoes::Drawable#create_display_drawable` (`drawable.rb:577-586`). Its return value is ignored by Lacci. The service **should** call `set_drawable_pairing(id, obj)` (`:219-231`), because Shoes-Spec proxies call `query_display_drawable_for(obj.linkable_id)` and raise if it returns nil (`lib/scarpe/shoes_spec.rb:218-222`, `lacci/lib/scarpe/niente/shoes_spec.rb:156`).
4. **Everything else is events** on the class-level bus:
   - `Shoes::DisplayService.dispatch_event(event_name, event_target, *args, **kwargs)` (`:87-124`)
   - `subscribe_to_event(name, target, &blk) -> unsub_id` (`:137-158`)
   - `unsub_from_events(id)` (`:164-172`)
   - Convenience wrappers on `Shoes::Linkable`: `send_self_event` (`:263`), `send_shoes_event(*args, event_name:, target: nil, **kw)` (`:267`), `bind_shoes_event(event_name:, target: nil)` (`:271`), `unsub_all_shoes_events` (`:285`).
   - **Both directions use the same bus.** Lacci -> display events and display -> Lacci events are just different event names.
5. **Class-level side channels** that the display writes and Lacci reads. These are not events:
   - `Shoes::DisplayService.mouse_state=` `[button, x, y]` (`:38-42`)
   - `para_hit_cache[id]` (`:46-48`)
   - `para_cursor_top_cache[id]` (`:50-52`)
   - `set_builtin_response(value)` (`:58-61`), consumed synchronously by `Shoes::Builtins#shoes_builtin` (`builtins.rb:66-75`).
6. **Globals the service populates at require time:**
   - `Shoes::FEATURES` (only `:html` and `:multi_app` are known, `constants.rb:55-58`). Push `:multi_app` or `window()` raises `TooManyInstancesError` (`app.rb:53-58`). Niente pushes it (`niente.rb:33`). Webview does not.
   - `Shoes::EXTENSIONS`
   - `Shoes::FONTS` (webview pushes 15 web font names, `wv.rb:62-78`)
   - `Shoes::Spec.instance` (`lacci/lib/shoes-spec.rb:13`)
   - optionally `Shoes.add_file_loader` (the segmented-file loader, `wv.rb:56-58`)

### Dispatch semantics (`display_service.rb:87-124`)

- Dispatch is **synchronous and re-entrant**. Handlers run inline, in this order: `[name][:any]`, then `[name][target]`, then `[:any][:any]`, then `[:any][target]` (`:114-119`).
- **A `nil` target is a real key.** A subscription with `target: nil` only receives events dispatched with `nil`, and a subscription with an id only receives that id (`:111-113`). Several existing webview bugs come from this rule (see §9).
- Handlers are called as `h.call(*args, **kwargs)` with `kwargs[:event_name]` and `kwargs[:event_target]` injected (`:120-122`). A `do |*args|` block therefore receives a trailing Hash `{event_name:, event_target:}`. **Display -> Lacci events must carry exactly the positional args listed below.** Any extra kwargs leak into splat handlers.
- With `SCARPE_DEBUG` set, args and kwargs go through a `JSON.parse(JSON.dump(...))` round trip (`:99-106`). This turns Symbols into Strings and Ranges and Gradients into Strings.
- Unknown event names or targets are dropped silently. Dispatch does not validate. Validation happens only when Lacci binds (`drawable.rb:474-479`).

---

## 1. Drawable classes the service can be asked to create

Unless noted, the class-name string sent is `self.class.name` with `Scarpe::` and `Shoes::` stripped (`drawable.rb:578`).

**Base properties for every drawable** (`drawable.rb:264-282`):
`top left width height right bottom margin margin_top margin_bottom margin_left margin_right padding padding_top padding_bottom padding_left padding_right hidden displace_left displace_top cursor tooltip`

- The properties hash is `shoes_style_values` (`drawable.rb:505-514`): **every** style name maps to its value, **nil included**, plus `"shoes_linkable_id" => Integer`. Keys are Strings. Values are raw Ruby objects (see §1b).
- Styles that are feature-gated only appear if the app requested the feature. Today the only one is `Button :html_class` with feature `:html`, added by webview (`wv/scarpe_extensions.rb:5`).

**Base events for every drawable** (`drawable.rb:18`): `parent destroy prop_change hover leave motion`.

Lacci binds these on **every** drawable (`drawable.rb:416-426`):
- `hover` with no args, calls `@hover`
- `leave` with no args, calls `@leave`
- `motion` with args `(x, y)`, calls `@motion`

These fire only if the display sends them. `Drawable#click` and `#release` (`:789-802`) **store a block but bind nothing**. That makes `rect.click {}`, `para.click {}`, `oval.click {}` no-ops for every display service.

### 1a. The class table **(probed via p3_classes.rb)**

"Setters" means `prop_change` can arrive later for any style via the auto setter (`drawable.rb:805-834`) or `style(...)` (`:537-573`). So **any listed style can change later.**

| Sent name | Lacci file | Extra styles (beyond base) | Defaults | Positional init args | Lacci -> display events it sends | Display -> Lacci events it expects (target = own id) |
|---|---|---|---|---|---|---|
| `App` | `app.rb` | `title resizable features opacity owner` (width/height come from base) | constructor defaults: `title 'Shoes!'`, `width 480`, `height 420`, `resizable true`, `features []`, `owner nil` (`app.rb:42-50`) | none | `init`, `run`, `destroy` (all **nil target**, see §2); `prop_change` target app id (e.g. `title=` at `app.rb:497`) | `destroy` (nil target) = quit; `custom_event_loop` (nil target, arg `"displaylib"`/`"return"`/`"wait"`) |
| `DocumentRoot` | `document_root.rb` (a Flow) | `attach background_color scroll scroll_top` | `width "100%"`, `height "100%"` | none | as Flow | none |
| `Stack` | `stack.rb` | `attach background_color scroll scroll_top` | none | none | `full_redraw_request` (**nil target**, bug), `scroll_top` event (target id, arg Integer, `stack.rb:27-30`) | none |
| `Flow` | `flow.rb` | same as Stack | `width "100%"` (`flow.rb:9`) | none | `full_redraw_request` (nil target). `flow.scroll_top=` goes through method_missing and sends **`prop_change {"scroll_top"=>v}`** instead of the `scroll_top` event | none |
| `Mask` | `mask.rb` | `attach` | none | none | `full_redraw_request` | none |
| *Widget subclass*, e.g. `"Glossb"`, `"TurtleCanvas"` | `widget.rb` | `attach background_color` + subclass styles | none (the Flow's 100% width is **not** inherited) | `:any` | as slot | none. Sent with **`is_widget: true`**. Webview renders it as a Flow (`webview_local_display.rb:81-82`) |
| `Shape` (a Slot) | `shape.rb` | `attach shape_commands draw_context` (+ `left top`) | none | `shape(left, top)` numeric | none of its own | none |
| `Arc` | `arc.rb` | `draw_context angle1 angle2` (left/top/width/height validated as Integer) | none | `left top width height angle1 angle2` | none | none |
| `Arrow` | `arrow.rb` | `draw_context` | none | `left top width` | none | none |
| `Line` | `line.rb` | `x2 y2 draw_context` | none | `left top x2 y2` | none | none |
| `Oval` | `oval.rb` | `center draw_context stroke fill radius strokewidth` | `fill "black"`, `stroke "black"` | `left top [radius height]`. Also computes `width ||= radius*2`, `height ||= width`, `radius ||= width/2` (`oval.rb:33-42`) | none | none |
| `Rect` | `rect.rb` | `draw_context curve stroke fill` | none | `left top width height [curve]`. 1-3 args are normalised (`rect.rb:17-30`) | none | none |
| `Star` | `star.rb` | `draw_context points outer inner` | `points 10`, `outer 100.0`, `inner 50.0` | `left top [points outer inner]` | none | none |
| `Background` | `drawables/background.rb` | `fill curve` | `curve 0` | `[fill curve]` | none | none. Created by `slot.background(color, opts)` (`lacci/lib/shoes/background.rb:22-33`) |
| `Border` | `drawables/border.rb` | `stroke strokewidth curve` | `stroke :black`, `strokewidth 1`, `curve 0` | `[stroke strokewidth curve]` | none | none |
| `Button` | `button.rb` | `text color text_color size font_size icon icon_pos font stroke` (+`html_class` with :html) | none | `[text]` | none | **`click`** with no args (`button.rb:42-45`) |
| `Check` | `check.rb` | `checked` | none | `[checked]` | `prop_change {"checked"=>bool}` echoed after each click | **`click`** with no args. Lacci toggles `checked` itself and echoes it back (`check.rb:14-17`) |
| `Radio` | `radio.rb` | `group checked` | none | `[group]` | `prop_change {"checked"=>false}` to siblings, then `{"checked"=>true}` to self | **`click`** with no args. Lacci handles group exclusivity (`radio.rb:27-36`). The group key is `@group` or the parent id or `"default"` |
| `EditLine` | `edit_line.rb` | `text font stroke secret` | none | `[text]` | `prop_change {"text"=>…}` (echoed after each change); `focus` event (target id, arg `{}`) | **`change`** with args `(new_text: String)`. Lacci sets text (with echo) and calls `block.call(new_text)` |
| `EditBox` | `edit_box.rb` | `text font stroke` | none | `[text]` | `prop_change {"text"}` (echo); `focus` | **`change`** with args `(new_text)`. Calls `block.call(self)` |
| `ListBox` | `list_box.rb` | `items font stroke chosen` | `chosen = items.first` | kwargs only: `items:`, `choose:` (these two are removed before super, `list_box.rb:18-19`) | `prop_change {"chosen"}` (echo); `focus`. **`choose(item)` sets `@chosen` and sends nothing** (`:35-41`, bug) | **`change`** with args `(new_item: String)` |
| `Image` | `image.rb` | `url click rotate_angle transform_origin` | none | `url`, or `image(w, h)` which becomes url `""` (`image.rb:14-20`) | none (`replace(url)` becomes `prop_change {"url"}`) | **`click`**, `hover`, `leave`, all with no args |
| `Progress` | `progress.rb` | `fraction` | none | none | none | none |
| `Video` | `video.rb` | `url` | none | `url` | none | none |
| `Para` | `para.rb` | `text_items size family font_weight font font_variant emphasis kerning weight wrap stroke fill text_cursor text_marker underline strikethrough align` | `size :para` (a Symbol) | text children (all positional) | `prop_change {"text_items"=>[…]}` is sent **before** its own create (§3) | optional `hover`/`leave`/`motion` via the base bindings. **No click.** |
| `TextDrawable` (base, from DSL `text(...)`) | `text_drawable.rb` | `text_items size stroke strokewidth fill undercolor font strikethrough underline` | none | children | as Para | none. **Created with a parent** (`parent_id` = slot), unlike its subclasses (§3) |
| `Code` `Del` `Em` `Strong` `Span` `Sub` `Sup` `Ins` | built by `Shoes.default_text_drawable_with` (`text_drawable.rb:106-127`) | same as TextDrawable | `Ins`: `underline "single"` (`:131`) | children | `prop_change {"text_items"}` | none. `parent_id: nil` |
| `Link` | `link.rb` | TextDrawable styles + `text click has_block weight` | none | children | `prop_change {"text_items"}` | **`click`** with no args (`link.rb:24-31`). If `click` is a String starting with `/`, Lacci calls `app.visit(click)` and then the block |
| `SubscriptionItem` | `subscription_item.rb` | `shoes_api_name args stopped` | none | kwargs `args: [...]`, `shoes_api_name:` | `prop_change {"stopped"=>bool}` (`stop`/`start`/`toggle`, `:101-113`) | depends on api name (§4, §5) |
| `LinkHover` | `link.rb:37-41` | | | | **never instantiated** (raises) | |

Not creatable:
- `Shoes::Slot` and bare `Shoes::Widget` never send a create. They are pre-declared in `shoes.rb:31-33` before the `inherited` hook exists, so they are absent from `drawable_classes`.
- `ins(...)` is `alias_method :ins, :inscription` (`para.rb:315`), so it makes a **Para** with `size :inscription`, **not** a `Shoes::Ins` **(probed)**.

Styles set through `style(...)` skip the validators (`drawable.rb:549-562`):
- Values arrive raw. For example `para.style(stroke: "#abc")` sends the String, while at creation Para's validator would have turned it into an rgb Array (`para.rb:7`).
- `style()` also sends `fill stroke strokewidth rotate` for classes that do not declare them (`:546,554-557`). **The display must accept `prop_change` keys that were absent from create props.**

### 1b. Property value types the display must parse **(probed via p4_serialize.rb)**

- **Colors** (`fill`, `stroke`, `border_color`, `background_color`, `undercolor`, `color`, `text_color`) can be any of:
  - `[r,g,b,a]` Integers 0-255, e.g. `red` gives `[255,0,0,255]`, from `colors.rb:151-158`
  - `[r,g,b,a]` Floats 0.0-1.0 (`rgb(0.5,…)` gives `[0.5,0.2,0.1,1.0]`; `gray(0.5)` gives `[0.5,0.5,0.5,1.0]`)
  - a String: `"#rgb"`, `"#rrggbb"`, a named color, an image path or URL (e.g. `background "bg.png"`)
  - a Symbol (Border default `:black`)
  - a **Ruby Range** of two colors (`"#fff".."#000"`), which `JSON.generate` turns into `"#fff..#000"`
  - a **`Shoes::Colors::Gradient`** (`colors.rb:193-214`, fields `color1 color2 angle(default 45)`), which JSON turns into `"rgb(255,0,0)-rgb(0,0,255)"`
  - `nofill`/`nostroke` give `[0,0,0,0]` (alpha 0 means none)
  - Lacci's 3-digit hex is wrong: `to_rgb("#abc")` returns `[160,176,192,255]` (16×nibble) instead of `[170,187,204,255]` (`colors.rb:228-232`).
- **`draw_context`** (Arc/Arrow/Line/Oval/Rect/Star/Shape): a Hash of the non-nil entries among `"fill" "stroke" "strokewidth" "rotate" "scale"([x,y]) "skew"([x,y])`, inherited through parent slots (`slot.rb:24-33,198-203`). Classes that also declare `fill`/`stroke`/`strokewidth` receive them as top-level props too (`drawable.rb:288,353-363`).
  - **Para, Button, EditLine and ListBox also inherit the draw-context `stroke`/`fill`** as top-level props. After `fill red` at app level, later paras arrive with `"fill"=>[255,0,0,255]` **(probed)**. Webview paints that as the text background.
- **Dimensions** (`width height left top …`):
  - Integer px
  - a negative Integer means parent minus |v|
  - a String `"50%"`
  - a Float, which Calzini reads as a fraction (`calzini.rb:102-115`, `0.5` = 50%) but Lacci's getter reads as px (`drawable.rb:683`)
- **Margin.** `margin:` is expanded **only at creation** into `margin_top/bottom/left/right` (`margin_helper.rb`; array order `[left, top, right, bottom]`; strings are split and **stay Strings**), and `"margin"` is set to nil. A later `style(margin: 10)` sends the raw `"margin"` key. `padding` is never expanded.
- **Text `size`:**
  - a Symbol `:inscription :para :caption :tagline :subtitle :title :banner`, which is a String after JSON
  - an Integer
  - or a String like `"18px"` from font parsing (`para.rb:66-99`)
  - Table (Calzini `calzini.rb:23-32`): inscription 10, ins 10, para 12, caption 14, tagline 18, subtitle 26, title 34, banner 48.
- **Values that are not data:**
  - `App "owner"` is a `Shoes::App` **object**
  - `attach: Window` is the **class** `Shoes::App` (JSON gives `"Shoes::App"`); `attach:` can also be a drawable object
  - `Link click:` can be a **Proc** (and a Proc click is silently dead, §9)
  - `features` is an Array of Symbols
  - `ListBox items` can be any objects; the display returns the chosen item as a String
- **Shape commands.** `shape_commands` is `[["move_to",x,y], ["line_to",x,y], ["curve_to",cx1,cy1,cx2,cy2,x,y], ["arc_to",cx,cy,w,h,a1,a2]]`, built by `App#move_to/line_to/curve_to/arc_to` (`app.rb:509-568`).
  - **It is sent as `[]` at create time and filled afterwards by mutating the same Array object, with no `prop_change`** (`shape.rb:25-32`) **(probed)**. That only works in-process by aliasing.
- **File paths** (`Image url`, `Video url`, a background image, the `font` builtin arg) are relative to the Ruby process cwd. `Shoes.run_app` does `Dir.chdir(app_dir)` at `shoes.rb:210`. Webview resolves them with `File.expand_path` (`wv/image.rb:29`). **A separate process must receive absolute paths.**

---

## 2. Lifecycle

### 2a. App start. Exact order **(probed, p1)**

```
Shoes.app(...)                               shoes.rb:138-195
  Shoes::App.new                             app.rb:42
    Drawable#initialize allocates App id N (ids are global Integers from 1, drawable.rb:141-145)
    CREATE DocumentRoot id=N+1 parent=nil    app.rb:88-90  (DocumentRoot is created BEFORE App)
    CREATE App          id=N   parent=nil    app.rb:93     props: width height title resizable features (+owner)
    [SHOES_SPEC_TEST env: test code evaluated here, app.rb:97-103]
    App subscribes to 'destroy'(nil) and 'custom_event_loop'(nil); traps INT -> destroy (app.rb:109-128)
  app.init                                   shoes.rb:192 -> app.rb:131
    EVENT init        target=nil args=[]
    app body runs with DocumentRoot as current slot: creates (parent-first, children in source order)
    render_index_if_defined_on_first_boot -> visit('/') if url '/', :index
    App#start callbacks (Lacci-local, app.rb:146-159)
  app.run                                    shoes.rb:193 -> app.rb:254-278
    EVENT run         target=nil args=[]
      (display may send  EVENT custom_event_loop target=nil args=["displaylib"|"return"|"wait"]  BEFORE run returns)
    after run returns:
      'displaylib' (default) -> app.destroy -> EVENT destroy target=nil
      'return'               -> Shoes.app returns nil; nothing else
      'wait'                 -> Lacci busy loops dispatch_event('heartbeat', nil) until @do_shutdown (no sleep, a tight loop)
```

How the existing services pick a loop type:
- **Webview** blocks inside the `run` handler (`wv/app.rb:289-299`), so it is `displaylib` (single app only).
- **Niente** sends `custom_event_loop "return"` and installs an `at_exit` loop dispatching `heartbeat` until a `destroy` (`niente/app.rb:16-29`).
- **space_shoes** also uses `return`.
- The code comment at `app.rb:24-34` says **only `return` supports multiple apps.**

`heartbeat` (nil target, no args) is dispatched only by Lacci's `wait` loop and Niente's at_exit loop. Webview never dispatches a Shoes `heartbeat`; its heartbeat is internal (`web_wrangler.rb:114-122`). Niente's Shoes-Spec runner runs the tests on the first `heartbeat` (`niente/shoes_spec.rb:21-27`).

### 2b. Create, reparent, destroy **(probed)**

- **Create order is parent-first.** A slot calls `create_display_drawable` *before* evaluating its block (`stack.rb:14-18`, `flow.rb:17-19`), so `parent_id` always refers to an already-created id.
- **Text drawables are created before the Para that references them**, because they are argument expressions (§3).
- **Position is not sent.** The Lacci child list can differ from append order (prepend), but `create` carries only `parent_id`. Webview and Niente `add_child` always append (`wv/drawable.rb:144-150`, `niente/drawable.rb:53-56`).
- **Reparent.** `set_parent(new, notify: true)` sends `EVENT parent target=id args=[new_parent_id_or_nil]` (`drawable.rb:597-604`). **Current Lacci never calls it with notify: true**; every creation uses `notify: false` (`:397`). The event is part of the contract (Niente and webview both handle it) but is never emitted today.
- **Destroy.** `Drawable#destroy` sends `EVENT destroy target=id args=[]`, unsubscribes all of that drawable's handlers, and unregisters the id (`drawable.rb:607-614`).
  - `Slot#destroy` (`slot.rb:231-235`) fires the `finish` callbacks, then **destroys children first (depth-first)**, then itself. The display sees leaf destroys before parent destroys.
  - **`remove` is `alias_method :remove, :destroy` on Drawable** (`drawable.rb:615`), so **`slot.remove` calls `Drawable#destroy`. There is no cascade and no finish callbacks: only the slot's own destroy is sent** **(probed: `$st.remove` sent only `destroy target=3` while child 28 lived)**.
  - A display must therefore handle both a destroy of a node whose children are already gone and a destroy of a node with live children (tear down the subtree itself).
  - Text drawables are **never** destroyed when their Para is replaced or removed. They are orphaned.
- **App destroy.** `App#destroy` sends `EVENT destroy target=nil` (`app.rb:280-283`), **not** the app id. Every App subscribes to nil-target `destroy`, so a single nil `destroy` shuts down **all** apps (`app.rb:109-113`). `Shoes.quit` calls `APPS.each(&:destroy)` (`shoes.rb:258-260`), which sends one nil `destroy` per app **(probed)**.

### 2c. clear, append, prepend, before and after **(probed, p2 and p5)**

- **`slot.clear`**: each child's `destroy` in Lacci child order (cascading). No event for the slot itself.
- **`slot.clear { … }`** (`slot.rb:259-270`): the destroys, then creates of the new children (parent = slot), then **`EVENT full_redraw_request target=nil`**.
  - The nil target is a bug. Webview subscribes with the slot id (`wv/slot.rb:14-16`), so webview **never** receives it.
  - `refresh_slot` (`:242-244`) has the same problem.
- **`slot.append { … }`**: plain creates with parent = slot, appended.
- **`slot.prepend { … }`** (`slot.rb:322-352`): creates with parent = slot. On the Lacci side each child is `unshift`ed (`slot.rb:48-55`), which **reverses the order** of multiple prepended children. The display is not told the position.
  - Probed after `prepend { para "pre1"; para "pre2" }`: Lacci children `[27, 26, 4, 5, 25]`, Niente display children `[4, 5, 25, 26, 27]`.
- **`before(el)` / `after(el)`**: **not implemented** in Lacci. No `Slot#before`/`#after` exists, even though the manual documents them at `manual.md:2315-2320`.
- **`visit(path)`** (`app.rb:364-399`) is `@document_root.clear { … }`, so it produces destroys, creates and a nil `full_redraw_request`.

### 2d. hide, show, style, move

- `hide`/`show`/`toggle` (`drawable.rb:739-751`) send `prop_change {"hidden"=>true|false}`. A create can also carry `hidden: true`.
- `SubscriptionItem#toggle` **overrides** this to toggle `stopped` (`subscription_item.rb:111-113`).
- `move(l, t)` sends two events: `prop_change {"left"=>l}` then `{"top"=>t}` (`drawable.rb:624-628`).
- `displace(l, t)` does the same with `displace_left`/`displace_top`.
- `width=`/`height=` (`:724-736`) send `prop_change {"width"=>v}`.
- `style(k: v, …)` sends **one** `prop_change` with several keys (`:564`).
- `style(Shoes::Button, k: v)` only changes class defaults on the Lacci side. Nothing is sent.

### 2e. Multiple apps, window(), dialog() **(probed)**

- `App#window(**opts)` and `App#dialog(**opts)` are both `Shoes.app(**opts.merge(owner: self))` (`app.rb:577-585`). Kernel-level `window`/`dialog` are `Shoes.app(**opts)` with no owner (`builtins.rb:114-122`). **dialog carries no flag distinguishing it from window.**
- A new app replays §2a inside whatever handler called it: create DocumentRoot, create App (props include **`"owner" => <Shoes::App object>`**), `init`, body, `run`.
- Because `init`, `run` and `custom_event_loop` are nil-target, **every live display App receives every other app's `init`/`run`**. Niente's first App re-ran its `run` logic when the second window opened.
- **How to tell which window an event means:**
  - a drawable belongs to the window whose DocumentRoot is reached by following `parent_id`
  - the DocumentRoot id is always the App id + 1 (App allocates its id in `super` before `DocumentRoot.new`, `app.rb:85-90`)
  - at `init`/`run` dispatch time, `Shoes.APPS.last` is the app being started (`shoes.rb:150,192-193`)
- The return value of `window` is nil, because `Shoes.app` returns nil.

---

## 3. Text

- **Para and text drawables hold `text_items`**, an Array mixing **Strings** and **Integer linkable ids** of TextDrawables (`para.rb:115-117`, `text_drawable.rb:46-48`).
  - Non-TextDrawable args are converted with `to_s`, so **every Integer in `text_items` is an id and never literal text.**
  - Nesting is recursive: `strong("a", em("b"))` gives Strong `text_items ["a", <em_id>]`.
- **Ordering quirk (probed):** `update_text_children` calls the `text_items=` setter **before** `create_display_drawable` (`para.rb:106-108`, `text_drawable.rb:41-43`). The wire sequence for `para "Hello ", strong("bold")` is:
  ```
  EVENT prop_change target=5 [{"text_items"=>["bold"]}]
  CREATE Strong id=5 parent=nil {"text_items"=>["bold"]}
  EVENT prop_change target=7 [{"text_items"=>["Hello ", 5]}]
  CREATE Para id=7 parent=3 {"text_items"=>["Hello ", 5], "size"=>:para}
  ```
  **A remote display receives `prop_change` for an id it has not seen yet and must drop it** (the create carries the same data).
- **`parent_id` is nil for `Code Del Em Strong Span Sub Sup Ins Link`**, because `expects_parent?` is false for strict subclasses of TextDrawable (`drawable.rb:429-434`). The bare `TextDrawable` from `text("...")` **does** get a slot parent **(probed: `TextDrawable id=13 parent=2`)**, so it must be renderable as a standalone slot child.
- **Updates:**
  - `para.replace(*children)` and `para.text = …` (`para.rb:126-137`) send `prop_change {"text_items"=>[…]}` on the Para, after creating any new text drawables.
  - Changing a nested span (`strong.replace("B2")`) sends `prop_change {"text_items"}` **on the span's id only**. The display must re-render every Para that references that span, so it needs a reverse index from text drawable to para.
  - Styles on spans travel as that span's own create props or `prop_change` (e.g. `strong("x", stroke: red)`). Nothing propagates up to the Para.
- **Visual meaning** is display-defined. Webview uses tags `code del em strong span sub sup`, and `ins` renders as a span with `underline "single"` (`wv/text_drawable.rb:83-90`). Link is `<a>` (`wv/link.rb`).
- **Link click flow:**
  - If `has_block` is true (a block was given, **or** `click` starts with `"/"`), the display sends `EVENT click target=<link id> args=[]`. Lacci then does `app.visit(click)` for internal routes and `block.call(link)` (`link.rb:24-31`).
  - If `has_block` is false and `click` is a URL String, **the display must open the URL itself**. Lacci does nothing. Webview relies on `href`, `calzini/para.rb:232-253`.
  - A Link has no parent. The display must hit-test link runs inside the Para's text layout and map them back to the link id.
- **Para text cursor.**
  - Lacci -> display: `prop_change` of `text_cursor` (Integer char index or nil) and `text_marker` (Integer or nil) (`para.rb:182-211`).
  - Non-Integer `cursor=` sends `prop_change {"cursor"=>String}` (a CSS cursor name).
  - Display -> Lacci goes through the caches only:
    - `para_hit_cache[para_id] = Integer|nil`, read by `Para#hit(x, y)`, which **ignores x and y** and returns the cached value (`para.rb:232-234`)
    - `para_cursor_top_cache[para_id] = Integer`, read by `Para#cursor_top` (`:240-242`)
  - Keys must be the **Integer** linkable id. Webview writes String keys from JS (`wv/app.rb:63-74`), so `hit` always returns nil there (bug).

---

## 4. Timers and animation

Timers are `SubscriptionItem`s:
- `animate(fps)`, `every(secs)` and `timer(secs)` become `subscription_item(args: [...], shoes_api_name: "animate"|"every"|"timer")` (`app.rb:414-422`, and the same on Slot).
- Create props: `{"shoes_api_name"=>"animate", "args"=>[5]}` (`args` is `[]` if none), `parent_id` = the current slot **(probed)**.

**Lacci does not tick anything.** The display (or the shim) must produce the events. Niente never fires them.

| API | Display -> Lacci event | Args | Webview behaviour (`wv/subscription_item.rb:22-45`) | Manual |
|---|---|---|---|---|
| `animate(fps=10)` | `animate`, target = item id | `(frame)` | `periodic_code` every `1/fps` s, counter pre-incremented, so **the first frame sent is 1** | frame **starts at 0**; fps defaults to 10 (`manual.md:1877-1896`) |
| `every(secs)` | `every` | `(count)` | every `secs` s, first count 1 | `every(seconds) { \|count\| }` (`:1989`) |
| `timer(secs=1)` | `timer` | `()` | one shot after `secs` s (`one_shot_code`) | one shot (`:2111`) |

- **Stop, start, toggle:** `prop_change {"stopped"=>true|false}` targeted at the item. Webview checks `@stopped` before sending, and the base `prop_change` handler sets the ivar.
- **Destroy** stops it. Destroy events arrive when the parent slot is cleared.
- **Webview limitation:** `periodic_code` **raises `PeriodicHandlerSetupError` if the app is already running** (`web_wrangler.rb:174-193`), so an `animate`/`every` created inside a click handler crashes webview. A new service must allow timers to be created at any time.
- **LACCI BUG: every SubscriptionItem callback fires twice** **(probed)**.
  - `subscription_item.rb:24-87` binds a handler per api name, and **then** `:89-91` binds a second generic `bind_self_event(shoes_api_name) { |*args| @callback&.call(*args) }`.
  - Each display event therefore calls the user block twice. The second call gets the **raw args plus a trailing `{event_name:, event_target:}` Hash**. Observed:
    - `timer` block called with `[]` then `[{event_name: "timer", event_target: 8}]`
    - `every` count 1 twice
    - `keypress` called with `:left` then `":left"`
    - `motion` called with `[5, 6, "control"]` then `[5, 6, true]`
    - `hover` called with the item, then a Hash
  - This affects webview today as well. The fix is to delete lines 89-91. It is a Lacci change for the builders to make, not something to work around in the display.

---

## 5. Input events

### 5a. Widget-level (display -> Lacci, target = the widget's id)

| Event | Sent to | Args | Notes |
|---|---|---|---|
| `click` | Button, Check, Radio, Link, Image | none | Check and Radio: Lacci changes `checked` and echoes it with `prop_change` in the same dispatch |
| `change` | EditLine, EditBox | `(new_text)` | webview sends it on every `oninput` (per keystroke). Lacci echoes `prop_change {"text"=>new_text}`, which the display must apply idempotently to keep the caret |
| `change` | ListBox | `(item_string)` | echoes `prop_change {"chosen"}` |
| `hover` / `leave` | **any drawable** (base binding) | none | webview only sends `hover` from Button, EditBox and EditLine (`onmouseover`), and `hover`/`leave` from Image |
| `motion` | any drawable (base binding) | `(x, y)` | webview never sends it for plain drawables |

### 5b. Slot-level and app-level (`motion hover leave click release keypress wheel`)

These are `SubscriptionItem`s parented to the **slot they were declared in**. At app level that is the DocumentRoot or current slot. They are created with `shoes_api_name` and no args.

The display attaches the listener to the **parent slot's area** and sends to the **item's id**:

| api | Display -> Lacci args | What Lacci passes to the user block | Webview source |
|---|---|---|---|
| `click` | `(button, x, y)` | `(button, x, y)` | `onclick` on parent; `button` = JS `e.button` (**0 = left**, manual/Shoes numbering is 1-based); x and y **relative to the parent's bounding rect** (`wv/subscription_item.rb:81-91`) |
| `release` | `(button, x, y)` | same | `onmouseup` |
| `motion` | `(x, y, ctrl_key, shift_key)` | `(x, y, mods)`, mods one of `""`, `"control"`, `"shift"`, `"control_shift"` (`subscription_item.rb:51-54`) | `onmousemove`, parent-relative |
| `hover` / `leave` | `()` | `(item)`. The manual says it should be the slot (`manual.md:2200,2251`) | `onmouseenter` / `onmouseleave` |
| `keypress` | `(key_string)`. A leading `":"` means a Symbol: `":left"` becomes `:left` (`subscription_item.rb:71-77`) | String or Symbol | **document-level** `keydown`, regardless of parent (`wv/subscription_item.rb:103-163`) |
| `wheel` | `(delta, x, y)`, delta > 0 = up/away | same | `onwheel`: `-deltaY` (float pixels), and **window-relative** `clientX`/`clientY` |

- **Key names (webview):**
  - Special keys: `:left :right :up :down :home :end :page_up :page_down :escape :backspace :tab :return :delete :insert :f1..:f12`, space is `" "`, bare modifier keys are ignored, other named keys become `":" + key.downcase`.
  - Prefix order is `alt_`, `control_`, `shift_` (shift only for special keys).
  - The manual (`manual.md:2207-2249`) disagrees in three places:
    - order is `control`, `shift`, `alt`
    - Return is the String `"\n"`, and only modified Return becomes a Symbol (`:control_enter`)
    - modified printable keys are **Symbols** (`:alt_&`), but webview sends Strings (`"alt_a"`)
  - Scarpe has no `keydown`/`keyup`/`keyrelease` at all.
- **`start` and `finish`:**
  - `App#start {}` runs on the Lacci side after the body (`app.rb:146-159`).
  - `Slot#finish {}` runs on destroy (`slot.rb:209-235`).
  - `SubscriptionItem#start` restarts a timer.
  - **Slot `start {}` does not exist** (it hits method_missing and raises NoMethodError), although the manual lists it at `:2286`.
  - None of these need display events.
- **`mouse_state`.** The display writes `Shoes::DisplayService.mouse_state = [button(1 while left is held, else 0), x, y]` in window/page coordinates on every mousemove, mousedown and mouseup (`wv/app.rb:58-60,76-92`). It is read by `App#mouse` (`app.rb:465-467`). Before any write it is `[0,0,0]`.
- **Clipboard** is not a display concern. `App#clipboard` and `clipboard=` shell out to `pbpaste`/`pbcopy`/`xclip` on the Lacci side (`app.rb:471-493`).

---

## 6. Builtins

`Shoes::Builtins` is mixed into Kernel (`builtins.rb:108-110`).

- **Lacci -> display:** `dispatch_event("builtin", nil, cmd_name, args_array)`. The handler signature is `|cmd_name, args|` and **the target is always nil**.
- **Response:** the handler must call `Shoes::DisplayService.set_builtin_response(value)` **synchronously, before its handler returns** (`builtins.rb:66-75`).
- **If the value consumed is `nil`, Lacci treats it as unhandled** and runs a macOS `osascript` fallback (`:79-98`). The fallback covers only `ask_open_file ask_save_file ask_open_folder ask_save_folder ask confirm`.
  - Consequence: a display that answers `nil` for a **cancelled** file dialog makes a **second native dialog** appear.
  - Webview does exactly that (`wv/document_root.rb:37-48` returns nil on cancel).

| cmd | args | Return expected | Webview behaviour |
|---|---|---|---|
| `alert` | `[message]` | nil; blocking (modal) in Shoes | in-page overlay, **non-blocking**, no response (`document_root.rb:23-27`) |
| `ask` | `[message]` | String; `""` on cancel for Shoes3 compatibility | osascript |
| `confirm` | `[question]` | true/false | osascript |
| `ask_color` | `[title]` | color | calls **`Shoes.rgb`, which does not exist** (probed `Shoes.respond_to?(:rgb) => false`). The error is rescued, returns nil, and ask_color is **broken** |
| `ask_open_file` / `ask_save_file` / `ask_open_folder` / `ask_save_folder` | `[]` | path String or nil | osascript; save_folder reuses the open-folder dialog |
| `font` | `[path_or_url]` | nothing | Lacci also appends `File.basename(path, ".*")` to `Shoes::FONTS` (`builtins.rb:13-18`); the display must register the font file |

Other points:
- `debug`/`info` only `puts` (`builtins.rb:54-60`). `App#info`/`debug` alias `puts` (`app.rb:546-547`).
- In multi-app, **every** display App/DocumentRoot that subscribes to `builtin` handles it: webview binds it per DocumentRoot, Niente not at all. A remote service should handle `builtin` once, in the service, and choose the focused window as the dialog parent (there is no app id).
- Test stubs: `Scarpe::DialogStubsInterceptor` is **prepended to `Shoes::Builtins`** (`lib/scarpe/shoes_spec.rb:80-146,198-206`), so a stubbed dialog never reaches the display.

---

## 7. Layout facts reported back to Shoes

**None exist.** No display -> Lacci message carries a size, a position, a scroll offset or a window size. Every getter is answered from Lacci-side data:

| Getter | How it is answered today | File |
|---|---|---|
| `drawable.width` / `height` | Lacci-stored style. `"N%"` and negatives are resolved against the parent's getter, recursing to `App#width`/`height`, which are the **constructor values** (default 480x420). Unset on a Slot: the parent's value. Unset on a non-slot: **nil**. Float values are returned as-is (0.5 means 0.5) | `drawable.rb:649-716` |
| `slot.left` / `top` | the stored value, or 0 | `slot.rb:65-73` |
| `app.width` / `height` after a user resize | stale constructor value | n/a |
| `stack.scroll_top` | the last value Lacci set, or 0. User scrolling is never reported | `stack.rb:23-25` |
| `app.gutter` | the constant 28 | `app.rb:551-553` |
| `app.mouse` | `mouse_state` (§5) | `app.rb:465` |
| `para.hit`, `para.cursor_top` | caches (§3) | `para.rb:232-242` |
| `image.size` | `FastImage.size(@url)` on the Lacci side | `image.rb:85-90` |
| `scroll_height`, `scroll_max`, `full_width`, `full_height`, `imagesize`, `location`, `started?` | **not implemented** (manual `:2440-2455,3143-3153,2017,980,1006`) | n/a |
| `contents` / `children` | the Lacci tree | `slot.rb:58-61` |

Anything that needs real measured layout (auto-sized stacks, para widths, a resized window) currently gets stale or nil values. A native backend that sends a layout report (see §8, messages `resize`/`scroll`/`layout`) would be **new** behaviour. The Ruby shim would have to write ivars directly (`@width`, `@scroll_top`) to avoid a `prop_change` echo.

---

## 8. Proposed minimal message set for a display in another process

This is derived only from §1-7. Proposed design: a **Ruby shim display service** (`Shoes::DisplayService` subclass, in the Lacci process) talks to a **Rust process** over newline-delimited JSON on the child's stdin/stdout, or a Unix socket.

**Why the shim.** Several contract pieces are in-process only and must stay in Ruby:
- `set_drawable_pairing` for Shoes-Spec
- `mouse_state`, `para_*_cache` and `set_builtin_response`
- normalising Ruby values
- Procs

**Precedent.** `Scarpe::Webview::RelayDisplayService` (`webview_relay_display.rb`, `webview_relay_util.rb`, `wv_display_worker.rb`) already does cross-process relay, but it **is bit-rotted**:
- its `create_display_drawable_for(klass, id, props)` (`webview_relay_display.rb:70`) lacks the required `parent_id:`/`is_widget:` kwargs, so it raises ArgumentError
- framing uses `str_data.length` (characters) as a byte count (`webview_relay_util.rb:36`), which breaks on non-ASCII text
- builtins cannot return a value across the boundary
- it never registers pairings, so Shoes-Spec proxies raise

Copy its shape (subscribe `:any/:any`, relay everything) but not its code.

### Ruby shim -> Rust

| msg | fields | Source |
|---|---|---|
| `create` | `id, class, parent (id or null), widget (bool), index (int, the position in the Lacci parent's children computed with `parent.children.index(drawable)` at create time, which fixes prepend), props {normalised}`. For `App` also add `doc_root: id+1`, `owner: id or null` | `create_display_drawable_for` |
| `props` | `id, changes {…}` | `prop_change` (**drop it if the id is unknown**; the pre-create text_items case) |
| `destroy` | `id` (Rust destroys the whole subtree) | `destroy` with a target |
| `reparent` | `id, parent` | `parent` (unused today) |
| `focus` | `id` | `focus` |
| `scroll_to` | `id, top` | `scroll_top` event, and `prop_change` `scroll_top` on Flow |
| `redraw` | `id or null` | `full_redraw_request`; can be a no-op for a retained-mode renderer |
| `init` / `run` | `app` (use `Shoes.APPS.last`) | nil-target `init`/`run` |
| `quit` | `app or null` | nil-target `destroy`; prepend `Shoes::App#destroy` to capture which app |
| `builtin` | `req, cmd, args` | `builtin`. **Blocking RPC**: the shim waits for `builtin_reply` inside the handler |
| `flush` | batch boundary | Proposed: buffer all messages emitted during one Lacci dispatch and flush once, so `clear {}` rebuilds apply atomically with one relayout |
| `query` | `req, what: "tree"\|"layout"\|"screenshot"` | new; for the look-and-click test harness |

### Rust -> Ruby shim

| msg | fields | Shim action |
|---|---|---|
| `event` | `name, target, args` | `DisplayService.dispatch_event(name, target, *args)`: click, change, hover, leave, motion, release, keypress, wheel, and optionally animate/every/timer |
| `builtin_reply` | `req, value, cancelled` | `set_builtin_response(value)`. For a cancel Lacci currently cannot tell "nil = cancelled" from "nil = unhandled" (§6). Either fix `shoes_builtin` to check the flag, or answer `""`/false |
| `mouse` | `button, x, y` | `Shoes::DisplayService.mouse_state = [b, x, y]` |
| `para_hit` / `para_cursor_top` | `id, value` | write the caches with **Integer** keys |
| `window_closed` | `app` | that app's `destroy(send_event: false)`, or `dispatch_event("destroy", nil)` to quit everything |
| `resize` / `scroll` / `layout` | `app,w,h` / `id,top` / `id,l,t,w,h` | **new**: set Lacci ivars directly (§7) |
| `reply` | `req, …` | answers `query` |
| `error` | `message` | raise or log |

### Event loop choice

- **Recommended: `return` plus an at_exit pump**, as Niente and space_shoes do:
  - the `run` handler sends `custom_event_loop "return"` before returning
  - an `at_exit` loop does `IO.select` on the socket with a ~16 ms timeout, dispatches incoming events, dispatches `heartbeat` (nil target, for Shoes-Spec), and flushes the batch
  - it exits when every window has closed
  - This is the only mode that supports `window()`. Its cost: `Shoes.app` returns, so code after it runs before the GUI.
- **Alternative:** `displaylib` with the pump inside the first app's `run` handler. This matches webview's "Shoes.app never returns". Nested apps then send `"return"`. Note that `custom_event_loop` is nil-target, so it overwrites every app's type.
- **Timers:** it is simpler and exact to tick `animate`/`every`/`timer` **inside the Ruby pump**, dispatching to the item ids directly and honouring `stopped` and destroy. This needs no round trip and gives the right frame numbering (start at 0 per the manual). Rust would then need no timer logic.

### Things that cannot cross the boundary as-is (the shim must normalise)

1. **Procs:** `Link click:` with a proc (also dead in Lacci, §9). Drop it or send `{"proc":true}`. Every user block stays in Ruby; only events cross.
2. **Ruby objects:**
   - `App owner`: send the id
   - `attach: Window` (a Class): send `"window"`
   - `attach: drawable`: send the id
   - `Shoes::Colors::Gradient`: send `{"gradient":[c1,c2],"angle":a}`
   - `Range` of colors: send `{"gradient":[first,last],"angle":45}`
   - Symbols: send Strings (JSON does this by default)
3. **Mutation by aliasing:** `Shape#shape_commands` is filled after create. The shim must send a `props {shape_commands}` after the shape block. Hook `Shape#initialize`, or fix Lacci to call `self.shape_commands = …` or send a prop_change.
4. **Synchronous returns:** builtins need a blocking request/response. While blocked, the shim must **queue** incoming events and must not dispatch them re-entrantly.
5. **Class-level state** (`mouse_state`, para caches) lives only in the Ruby process, so it needs explicit messages.
6. **Relative paths** (`url`, fonts, image backgrounds): expand against `Dir.pwd` in Ruby.
7. **Threads:** `download` runs its callback on a Ruby `Thread` (`download.rb:38-58`). Writes to the socket need a Mutex. Lacci itself is not thread-safe.

---

## 9. Existing bugs a new backend will hit (all verified in code or by probe)

1. **SubscriptionItem double-fires every callback** (`subscription_item.rb:89-91`), with wrong args on the second call. Probed.
2. **nil-target vs id-target mismatches.** These webview subscriptions never fire:
   - `full_redraw_request`: sent nil (`slot.rb:243,267`), bound to the id (`wv/slot.rb:14`)
   - `focus`: sent to the id (`edit_line.rb:45` etc.), bound nil (`wv/edit_line.rb:19`, `edit_box.rb:19`, `list_box.rb:15`)
   - `scroll_top`: sent to the id (`stack.rb:29`), bound nil (`wv/stack.rb:8`, `wv/flow.rb:8`)
3. **Prepend** reverses order on the Lacci side and sends no position to the display (§2c).
4. **`slot.remove` does not cascade** (the alias binds `Drawable#destroy`, `drawable.rb:615`).
5. **`ListBox#choose` sends no `prop_change`** (`list_box.rb:35-41`).
6. **Link `click:` proc is never called** (`link.rb:18-31`: `has_block` is false and `@block` is nil).
7. **`Drawable#click`/`#release` on non-widgets bind nothing** (`drawable.rb:789-802`).
8. **Builtin `nil` means "unhandled"**, so a cancelled dialog is shown twice; `ask_color` is broken (`Shoes.rgb`).
9. **Shape commands** are sent empty at create.
10. **The Para text_items `prop_change` precedes create** (not a bug in-process, but a hazard across processes).
11. **`init`/`run`/`destroy`/`custom_event_loop`/`builtin` are nil-target**, so multi-window services must infer the app.
12. **Webview para caches use String keys** while `Para#hit` reads Integer keys.
13. **The relay service is broken** (signature, framing, builtins).
14. **`animate` frame numbering starts at 1** in webview (the manual says 0); mouse `button` is 0-based (Shoes is 1-based); the webview keypress naming differs from the manual (§5b).
15. **Dimension semantics** for Floats differ between Lacci getters (px) and Calzini (fraction).

## 10. Shoes-Spec hooks a new service must provide

- **Env contract** (used by `shoes-spec/lib/tasks/scarpe.rake:286-291` and `implementations/gtk-scarpe/gtk_scarpe_runner.rb:27-31`): `SHOES_SPEC_TEST` (file whose code is evaluated in `App#initialize`, `app.rb:97-103`), `SCARPE_DISPLAY_SERVICE`, `SHOES_MINITEST_EXPORT_FILE`, `SHOES_MINITEST_CLASS_NAME`, `SHOES_MINITEST_METHOD_NAME`.
- **Service side:**
  - set `Shoes::Spec.instance` to an object with `run_shoes_spec_test_code(code, class_name:, test_name:, filename:, line:)` (`shoes-spec.rb:49`)
  - run the tests on the first `heartbeat` (Niente pattern)
  - give finder proxies `trigger_click`/`trigger_hover`/`trigger_leave`/`trigger_change`, implemented as `dispatch_event(name, id, *args)` (`niente/shoes_spec.rb:170-175`)
- **Usage in the 805 reference `.sspec` cases:** `trigger_click` ×63, `trigger_hover` ×1, `dom_html` ×73 (webview-specific HTML assertions; a native service has no equivalent), `stub_alert`/`stub_ask`/`stub_confirm` ×1 each, `wait` ×6.
