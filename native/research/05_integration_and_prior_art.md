# 05: CLI, display-service loading, packaging, prior art for non-webview backends

Lane: integration. Repo: `<repo>` (the checked-out branch is **`main`**, not `master`; `origin/HEAD -> origin/main`, HEAD `fdcee7a`). All line numbers are from that checkout. The refs `gtk-scarpe`, `space_shoes` and `shoes-spec` are under `.../scratchpad/ref/`.

Spike artifacts I produced live in `.../scratchpad/research/spike_relay/` (patched relay, captured datagrams, double-fire repro) and `.../scratchpad/research/pkg_out*` (packager output).

---

## 0. TL;DR for builders

1. **Registering a service is one file.** `SCARPE_DISPLAY_SERVICE=native` makes `lib/scarpe.rb:14` run `require "scarpe/native"`, so you create `lib/scarpe/native.rb`. It must set `Shoes::Log.instance` (only once), add the segmented file loader, set `Shoes::Spec.instance`, and call `Shoes::DisplayService.set_display_service_class(...)`. Skeleton in §1.4.
2. **Env var mismatch is real.** `exe/scarpe:30` sets `SCARPE_DISPLAY`, which nothing reads. The live var is `SCARPE_DISPLAY_SERVICE` (`lib/scarpe.rb:11`, default `"wv_local"`). The packager's boot scripts and launchers also set the dead `SCARPE_DISPLAY` (package.rb:953, 1009, 1899, 2495).
3. **wv_relay is broken today.** It dies at the first drawable with `NoMethodError: undefined method 'bind_shoes_event' for an instance of Scarpe::Webview::RelayDisplayService` (webview_relay_display.rb:39). I found 6 bugs in total (§5.2). With 4 small monkeypatches (in my spike dir, repo untouched) it **works end to end**: a timer fires in the child, the Ruby handler runs in the parent, `prop_change` goes back to the child, `Shoes.quit` exits 0 with no orphan process. Its message shapes (`create` / `event` / `destroy`) are a proven template for a Rust child process. Its framing is not (it counts chars instead of bytes, and `.encode(BINARY)` raises on any non-ASCII text).
4. **Packaging is broken on this machine today.** `scarpe package --dev` builds a 26 MB `.app` (8.9 MB `--minimal`, 2.8 MB `.dmg`), but the app dies with `cannot load such file -- scarpe (LoadError)`. Causes are in §2.3: the `scarpe`, `lacci` and `webview_ruby` gems are missing, and `find_gem_dir` has a prefix bug. The Ruby runtime itself strips to **23 MB (full) / 8.0 MB (minimal)**. A native-backend app should land around 10 to 15 MB.
5. **The Traveling Ruby used for packaging is 3.4.7, and CI Ruby is 3.2.0** (`.ruby-version`). Local Ruby is 4.0.1. Any new Ruby must parse on 3.2 (no `it` block param).
6. **gtk-scarpe (Noah, Jan to May 2024)** is the only prior non-HTML backend. It ran in-process on Ruby-GNOME GTK4, did Shoes layout in Ruby (`Scarpe::Positioning`: Stack/Flow/Drawable), placed native widgets absolutely in a `Gtk::Fixed`, and never re-laid-out after a property change. It passed 6 Shoes-Spec cases. Details and lessons in §3.
7. **Lacci bug found while doing this, which affects every backend.** `Shoes::SubscriptionItem` binds each event twice (lacci/lib/shoes/drawables/subscription_item.rb:24-87 and again at :89-91). Every `timer`/`animate`/`every`/`hover`/`leave`/`motion`/`keypress`/`wheel`/slot-`click` callback runs **twice** per event. Reproduced under Niente: `{timer: 2, animate: 2, click: 1}` for one dispatch each (§7.1).
8. **Tests write into the repo.** `rake lacci_test` creates `lacci/test/niente_test.json` (gitignored; I deleted the one my run made). `rake test` writes `test/sspec.json` and `logger/*.log`. Never run `rake ci_test`: it runs `brew install`, `git checkout main` and `bundle install` (Rakefile:13-23).
9. **Always use `bundle exec`.** Bare `ruby` picks minitest 6.0.6, and the Shoes-Spec JSON export silently never gets written (§6.4). The lock pins minitest 5.27.0.
10. **Baselines:** `bundle exec rake lacci_test` gives 105 tests, 193 assertions, 0 failures in 32 s. A trivial Niente run of `exe/scarpe` takes 0.67 to 1.1 s wall. Rust 1.93.1 (`~/.cargo/bin`) is available, on macOS 26.2 with Xcode.

---

## 1. CLI and display-service loading

### 1.1 `exe/scarpe` control flow

- **:6-14:** `package` is handled early. It prepends `../lib`, runs `require_relative "../lib/scarpe/package"`, then `Scarpe::Package.run(ARGV[1..])` and `exit`. It never loads Shoes or Lacci.
- **:17-23:** `extension` is handled the same way, through `Scarpe::Extension.run(ARGV[1..])`.
- **:26-27:** `--dev` and `--debug` are removed from ARGV wherever they appear. `--debug` sets `ENV['SCARPE_DEBUG']='true'` (:32-34).
- **:30:** `ENV['SCARPE_DISPLAY'] ||= 'wv_local'`. **This is dead: nothing reads `SCARPE_DISPLAY`.**
- **:35-43:** with `--dev`, it prepends `../lib` to `$LOAD_PATH`, then runs `require 'bundler/setup'` and `Bundler.require(:default)`.
  - `Bundler.require` loads the `scarpe` path gem from `gemspec`, plus `lacci` and `scarpe-components` from their `path:` entries in the Gemfile.
  - That means **`require "scarpe"`, and therefore the display service, actually load inside `Bundler.require`**, before line 44.
  - Bundler also puts `lacci/lib` and `scarpe-components/lib` on the load path.
- **:44-45:** `require "scarpe"`, then `require "lacci/scarpe_cli"`, then `include Scarpe::CLI`.
- **:51:** `version_check` requires Ruby 3.2 or later (scarpe_cli.rb:21-25).
- **:67-91:** verbs.
  - `-v` prints versions. `env` prints `print_env`.
  - `run FILE` (exactly 2 args), or a bare `FILE` (exactly 1 arg).
  - Anything else prints usage and exits -1.
- **:100:** `Shoes.run_app verb_target`.
- **There is no CLI flag to choose a backend.** The only switch is the env var. To add a `--native` flag, set `ENV["SCARPE_DISPLAY_SERVICE"]` before line 41. It must happen before `Bundler.require`, because that is where `require "scarpe"` really runs under `--dev`.

### 1.2 Resolution (`lib/scarpe.rb`, the whole file)

```ruby
require "shoes"                 # lacci/lib/shoes.rb
require "lacci/scarpe_core"     # defines Scarpe, Shoes::Error, Scarpe::Error; requires lacci/version + scarpe/components/version
d_s = ENV["SCARPE_DISPLAY_SERVICE"] || "wv_local"   # :11
require "scarpe/errors"         # lib/scarpe/errors.rb: Scarpe::*Error classes only
require "scarpe/#{d_s}"         # :14  (plain require, so another gem can supply the file)
```

- `wv_local` resolves to `lib/scarpe/wv_local.rb`. It runs `require_relative "wv"` (the whole webview stack), then `require_relative "wv/webview_local_display"`, then `Shoes::DisplayService.set_display_service_class(Scarpe::Webview::DisplayService)`.
- `wv_relay` resolves to `lib/scarpe/wv_relay.rb`. It loads the same `wv` stack plus `wv/webview_relay_display`, then `set_display_service_class(Scarpe::Webview::RelayDisplayService)`.
- `niente` resolves to **`lacci/lib/scarpe/niente.rb`**. It is found because `lacci/lib` is on the load path, which shows a service file can live in any gem.
- The value is a path fragment, so names with hyphens work: gtk used `"gtk-scarpe"`.
- **`native` would resolve to `lib/scarpe/native.rb`.** Nothing by that name exists yet.

### 1.3 Env var mismatch

| Location | Sets / reads | Effect |
|---|---|---|
| exe/scarpe:30 | sets `SCARPE_DISPLAY` | dead |
| lib/scarpe.rb:11 | reads `SCARPE_DISPLAY_SERVICE`, default `wv_local` | **the real switch** |
| lib/scarpe/wv/wv_display_worker.rb:10 | sets `SCARPE_DISPLAY_SERVICE="wv_local"` | real (relay child) |
| lacci/lib/lacci/scarpe_cli.rb:35 | prints `SCARPE_DISPLAY_SERVICE` in `scarpe env` | real |
| package.rb:953 (macOS boot.rb), :1009 (macOS launcher), :1899 (Linux boot.rb), :2495 (Windows boot.rb) | set `SCARPE_DISPLAY` | dead. The packaged app only gets wv_local through the default in lib/scarpe.rb:11 |
| HelloScarpe.AppDir/usr/share/helloscarpe/boot.rb:18 | sets `SCARPE_DISPLAY` | dead (a committed build artifact) |
| ref gtk-scarpe exe/gtk-scarpe:10 | sets `SCARPE_DISPLAY` | dead. gtk's real selection is `lib/scarpe/gtk-scarpe.rb:3` |
| README.md:162-166, CLAUDE.md:209, test helpers | document or use `SCARPE_DISPLAY_SERVICE` | correct |

### 1.4 What `lib/scarpe/native.rb` must do (contract, derived from wv.rb, niente.rb and gtk-scarpe.rb)

These are the requirements, in load order.

1. **Set exactly one logger.**
   - Call `Shoes::Log.instance = <impl>`. It raises `Shoes::Errors::TooManyInstancesError` if set twice (lacci/lib/shoes/log.rb:30-34).
   - Then call `Shoes::Log.configure_logger(cfg)`.
   - Without a logger, the first `log_init` blows up on `nil` (log.rb:45-47).
   - Implementations:
     - `Scarpe::Components::PrintLogImpl.new`: `require "scarpe/components/print_logger"`, no gem deps. Niente uses it.
     - `Scarpe::Components::SimpleLogImpl.new`: `require "scarpe/components/simple_logger"`, stdlib Logger. Packaged wv uses it.
     - `Scarpe::Components::ModularLogImpl.new`: `require "scarpe/components/modular_logger"`, needs the `logging` gem. This is the one that honours the `SCARPE_LOG_CONFIG` JSON file.
   - Config: `ENV["SCARPE_LOG_CONFIG"] ? JSON.load_file(...) : (ENV["SCARPE_DEBUG"] ? Shoes::Log::DEFAULT_DEBUG_LOG_CONFIG : Shoes::Log::DEFAULT_LOG_CONFIG)` (the same logic as wv.rb:47-54).
2. **Add the segmented file loader** so `.sspec` and `.scas` files run:
   ```ruby
   require "scarpe/components/segmented_file_loader"
   Shoes.add_file_loader Scarpe::Components::SegmentedFileLoader.new
   ```
3. **Declare capabilities.**
   - `Shoes::FONTS.push(...)`. The array is empty by default (constants.rb:40).
   - `Shoes::FEATURES.push(:multi_app)`, only if the service can create more than one `Shoes::App`. Without it, a second `Shoes.app`/`window` raises `TooManyInstancesError` (app.rb:53-58). `KNOWN_FEATURES = [:html, :multi_app]` (constants.rb:55-58).
   - `Shoes::EXTENSIONS.push(...)` for anything non-standard.
   - Do **not** push `:html`.
4. **Set the Shoes-Spec implementation.**
   - `Shoes::Spec.instance = <class or module>`.
   - It must respond to `run_shoes_spec_test_code(code, class_name: nil, test_name: nil, filename: "(eval)", line: 1)`. Lacci calls it with `filename:, line: 1` (app.rb:101). gtk-scarpe's old signature, which lacked `filename:`/`line:`, would now raise ArgumentError.
   - Setting it twice with a different object raises (lacci/lib/shoes-spec.rb:13-19).
   - wv.rb:85-92 sets it to `Scarpe::Test`, so **the native service must never be loaded in the same process as `scarpe/wv`**. That also covers the packager's boot script, which does `require 'scarpe/wv'` (package.rb:973).
5. **`Shoes::DisplayService.set_display_service_class(Scarpe::Native::DisplayService)`.**
   - It can only be set once (display_service.rb:192-196).
   - Lacci instantiates it **lazily, with no arguments**, the first time a drawable calls `Shoes::DisplayService.display_service` (display_service.rb:200-206). That first caller is the `DocumentRoot` inside `Shoes::App#initialize` (app.rb:88-90).
   - So a Rust child process spawned in `initialize` starts when `Shoes.app` is first called, not at require time.

Minimal skeleton, using the names Lacci actually calls:

```ruby
# lib/scarpe/native.rb
require "json"
require "scarpe/components/print_logger"
Shoes::Log.instance = Scarpe::Components::PrintLogImpl.new
Shoes::Log.configure_logger(ENV["SCARPE_DEBUG"] ? Shoes::Log::DEFAULT_DEBUG_LOG_CONFIG : Shoes::Log::DEFAULT_LOG_CONFIG)
require "scarpe/components/segmented_file_loader"
Shoes.add_file_loader Scarpe::Components::SegmentedFileLoader.new
Shoes::FONTS.push("Helvetica", "Arial")          # whatever the Rust side can really draw
module Scarpe::Native; end
require_relative "native/shoes_spec"             # defines Scarpe::Native::Test
Shoes::Spec.instance = Scarpe::Native::Test
require_relative "native/display_service"
Shoes::DisplayService.set_display_service_class(Scarpe::Native::DisplayService)
```

### 1.5 The DisplayService interface Lacci calls

Class-level methods live on `Shoes::DisplayService` (lacci/lib/shoes/display_service.rb). They are the event bus, shared by everyone:

- `dispatch_event(event_name, event_target, *args, **kwargs)` (:87).
  - It adds `kwargs[:event_name]` and `kwargs[:event_target]` (the latter only if non-nil) before calling handlers (:120-121).
  - Handler lookup is `[same_name[:any], same_name[target], any_name[:any], any_name[target]]` (:114-119).
  - A `nil` target only matches a `nil` subscription.
  - With `SCARPE_DEBUG`, args get a JSON round-trip (:99-106). This is a cheap way to prove everything is serialisable.
- `subscribe_to_event(event_name, event_target, &handler)` returns an unsub id (:137). `unsub_from_events(id)` (:164). `full_reset!` (:178).
- `set_builtin_response(value)`, `consume_builtin_response`, `clear_builtin_response` (:58-77).
  - These handle **synchronous** answers to `ask`, `confirm`, `ask_color`, the file dialogs and so on.
  - `Shoes::Builtins#shoes_builtin` does `clear`, then `dispatch_event("builtin", nil, cmd_name, args)`, then `consume` (builtins.rb:66-75).
  - If the result is `nil`, it falls back to `osascript` on macOS for `ask_open_file`/`ask_save_file`/folders/`ask`/`confirm` (builtins.rb:79-97).
  - **A child-process design must block inside the `"builtin"` handler until the Rust side answers, then call `set_builtin_response`.** A fire-and-forget design like the relay cannot return values.
- `mouse_state` / `mouse_state=` (`[button, x, y]`), `para_hit_cache` and `para_cursor_top_cache` (:38-52). The display service updates these. `App#mouse` and `Para#hit` read them.

Instance methods: subclass `Shoes::DisplayService` and call `super()`, which sets `@display_drawable_for = {}` (:209-211).

- **`create_display_drawable_for(drawable_class_name, drawable_id, properties, parent_id:, is_widget:)`** (:215). This is the only required override.
  - It is called from `Shoes::Drawable#create_display_drawable` (drawable.rb:577-586) as `create_display_drawable_for(klass_name, self.linkable_id, shoes_style_values, parent_id:, is_widget:)`.
  - `klass_name` has `Scarpe::` and `Shoes::` stripped, e.g. `"Button"`, `"DocumentRoot"`, `"App"`, `"SubscriptionItem"`, `"Para"`, `"Em"`. For user widgets it is the widget class name, which is why `is_widget` is passed.
  - `properties` is an `IndifferentHash` of **every** style name plus `"shoes_linkable_id"`, with nil values included. In my captures that meant 25 to 39 keys.
  - The return value is used by Webview and Niente but ignored by the relay.
- `set_drawable_pairing(id, display_drawable)` (:219) and `query_display_drawable_for(id, nil_ok: false)` (:233).
- `destroy` (:243). Override it.

**IDs:** `linkable_id` defaults to `object_id` (display_service.rb:258). On Ruby 3.4 and 4.0 that is a small sequential **Integer**. The captures show `DocumentRoot` = 2, `App` = 1, then 3, 4, 5... The JSON wire therefore carries numbers, even though Niente's comments call them strings. **The Rust side should accept either type as the key.**

**Creation order observed on the wire** (from the §5 spike):
- `DocumentRoot` comes first (`parent_id: nil`), then `App` (`parent_id: nil`), then the `init` event.
- Next come the children with `parent_id: 2`, then the `run` event.
- **`Para` emits `prop_change {"text_items":[...]}` BEFORE its own `create`.** The cause is `update_text_children` running before `create_display_drawable` (lacci/lib/shoes/drawables/para.rb:104-108, 251). The backend must ignore `prop_change` for unknown targets. The later `create` carries the same `text_items` anyway.

Sample `create` properties with nils removed:
- App: `{"width"=>300,"height"=>200,"title"=>"relay spike","resizable"=>true,"features"=>[],"shoes_linkable_id"=>1}`
- DocumentRoot: `{"width"=>"100%","height"=>"100%","shoes_linkable_id"=>2}`
- Para: `{"text_items"=>["before"],"size"=>"para","shoes_linkable_id"=>3}`
- Button: `"text":"Push me"`, 31 keys in total.
- SubscriptionItem (timer): `{"shoes_api_name"=>"timer","args"=>[1],"shoes_linkable_id"=>5}`

Events every display drawable should bind (Niente's `Drawable`, lacci/lib/scarpe/niente/drawable.rb:16-33, is the minimal model):
- `"parent"` (target = own id, arg `new_parent_id`), for reparenting after creation.
- `"prop_change"` (target = own id, arg `{name => value}`).
- `"destroy"` (target = own id).

The App display drawable binds the untargeted `"init"`, `"run"` and `"destroy"` (niente/app.rb:8-10) and `"builtin"` (gtk app.rb:33).

**Timers are the display service's job.** Lacci's `SubscriptionItem` only binds to `animate`/`every`/`timer` events. The Webview side runs `periodic_code`/`one_shot_code` and emits `send_self_event(counter, event_name: "animate")` and the like (lib/scarpe/wv/subscription_item.rb:21-44). It must also honour the `stopped` prop.

### 1.6 App lifecycle, event-loop types, process exit

- `Shoes.app(...)` runs `Shoes::App.new`, then `app.init`, then `app.run` (lacci/lib/shoes.rb:138-195).
- `App#init` sends `init`, then runs the app block `with_slot(@document_root)`, then fires the `start` callbacks (app.rb:131-140).
- `App#run` (app.rb:254-278) sends `run`. **Before that event returns**, the display service can send `send_shoes_event("<type>", event_name: "custom_event_loop")` to change `@event_loop_type` (app.rb:115-122). `CUSTOM_EVENT_LOOP_TYPES = %w[displaylib return wait]` (app.rb:35).
  - `displaylib` is the default, and is what Webview and GTK use. The `run` handler blocks in the native loop. When it returns, Lacci calls `destroy`.
  - `wait`: Lacci spins `dispatch_event('heartbeat', nil) until @do_shutdown` (app.rb:267). **There is no sleep**, so the heartbeat handler must block (for example `IO.select` on the Rust socket with a ~16 ms timeout), or it burns 100% CPU.
  - `return`: `run` returns without destroying. Niente uses this and then loops heartbeats in `at_exit` until `destroy` (niente/app.rb:16-29). This also spins with no sleep. It is also how multiple apps and code after `Shoes.app` can work.
- `App#destroy` sets `@do_shutdown` and dispatches `destroy` (untargeted) (app.rb:280-283).
  - `Shoes.quit` / `Shoes.exit` run `Shoes.APPS.each(&:destroy)` (shoes.rb:258-261).
  - `Signal.trap('INT')` calls `destroy` (app.rb:124-128).
  - In the spike, `destroy` arrived **three times** on the wire. Make it idempotent.
- **Process exit.**
  - Normal: the native loop returns, Lacci destroys, `Shoes.app` returns, the script ends and the process exits 0.
  - Test mode: Webview's CatsCradle `shut_down_shoes_code` dispatches `destroy` on the first call and `exit 0` on the second (lib/scarpe/cats_cradle.rb:204-211). `exit_on_first_heartbeat` does `exit 0` (shoes_spec.rb:414-421).
  - **The exit code is 0 even when a Shoes-Spec test fails.** The verdict lives in the JSON export (§1.8).
  - An uncaught exception in app code gives a non-zero exit and no JSON. gtk's test asserted `expect_result: :no_file, process_success: false`.

### 1.7 How the app file is loaded

`Shoes.run_app(relative_path)` (lacci/lib/shoes.rb:205-226):
- expands the path, then `Dir.chdir(dirname)`. **The cwd becomes the app dir**, which matters for relative writes such as `sspec.json`.
- does `$LOAD_PATH.unshift(dir)`.
- tries `file_loaders` in order. The first `loader.call(path)` that returns truthy wins, otherwise it raises `"Could not find a file loader"`.
- the default loader is `proc { |path| load path; true }` (shoes.rb:228-236). `add_file_loader` prepends (:242-244).

`Scarpe::Components::SegmentedFileLoader#call(path)` (scarpe-components/lib/scarpe/components/segmented_file_loader.rb:52-57) only claims `.scas` and `.sspec` files.
- The format: optional YAML front matter (`---`), then segments split on `/\n-{5,}/` with an optional name after the dashes (`----------- app code`).
- The default segment types are `["shoes"]`, or `["shoes","app_test"]` when there are two segments (:128-139). More than 2 segments requires `front_matter[:segments]`.
- Handlers (:175-181):
  - `"shoes"` does `after_load { load seg_file }`.
  - `"app_test"` sets `ENV["SHOES_SPEC_TEST"] = seg_file` and `ENV["SHOES_MINITEST_EXPORT_FILE"] ||= "sspec.json"`. That default is **relative to the cwd = app dir**.
  - Custom types can be added with `add_segment_type(type, handler)`.

### 1.8 The Shoes-Spec process contract (every backend must honour it)

Env vars the harnesses set (test/test_helper.rb:64-74 and 132-140; lacci/test/test_helper.rb:53-61; shoes-spec runners):

| Var | Meaning |
|---|---|
| `SCARPE_DISPLAY_SERVICE` | backend |
| `SHOES_SPEC_TEST` | path to the test-code file. `App#initialize` reads it (app.rb:97-103) and calls `Shoes::Spec.instance.run_shoes_spec_test_code(code, filename:, line: 1)` **after** the DocumentRoot and App display drawables exist, but **before** the app block runs |
| `SHOES_MINITEST_EXPORT_FILE` | where `Minitest::Reporters::ShoesExportReporter` writes JSON: `[{name, klass, assertions, failures:[["unexpected"|"exception", json...]], time, metadata, exporter_metadata, source_location}]` (minitest_export_reporter.rb:56-80). `activate!` raises if it is unset (:33-36) |
| `SHOES_MINITEST_CLASS_NAME` / `SHOES_MINITEST_METHOD_NAME` | names for the generated Minitest class and method |
| `SCARPE_SSPEC_TIMEOUT` (default "30", `"none"`), `SCARPE_SSPEC_TIMEOUT_WAIT_AFTER_TEST` | Webview-only timeout knobs (lib/scarpe/shoes_spec.rb:174-183) |
| `SCARPE_LOG_CONFIG`, `SCARPE_DEBUG`, `LOCALAPPDATA`, `NIENTE_LOG_LEVEL` | logging and temp dirs |

The reference implementation to copy is **Niente::Test** (lacci/lib/scarpe/niente/shoes_spec.rb:9-35):
- activate the export reporter.
- define a `Minitest::Test` subclass whose single test method `eval(code, nil, filename, line)`s.
- subscribe to `"heartbeat"`. On the first heartbeat, call `Minitest.run []` and then `Shoes.APPS.each(&:destroy)`.

Finders are generated from `Shoes::Drawable.drawable_classes` (`button`, `buttons`, `para`, `title`/`banner`/..., `drawable`, `drawables`, `find_all`, `find_button`). The proxy's `trigger_click`/`trigger_hover`/`trigger_leave` do `Shoes::DisplayService.dispatch_event(event, linkable_id, ...)` (niente/shoes_spec.rb:170-175). Webview's proxy adds `trigger_change` and goes through `app.handle_callback("#{id}-#{event}")` (lib/scarpe/shoes_spec.rb:213-245).

**Better for a native backend:** make `trigger_click` ask the Rust side to hit-test and emit the real click, so the whole wire is exercised. Keep the Niente-style direct dispatch as a fallback.

---

## 2. Packaging (`lib/scarpe/package.rb`, 2,902 lines; `lib/scarpe/extension.rb`, 351 lines)

### 2.1 Shape

- CLI: `scarpe package <app.rb> [opts]`. `Scarpe::Package.run(args)` (:2739) calls `parse_args` (:2769-2832).
- Flags: `--name/-n`, `--icon/-i`, `--arch/-a` (x86_64|arm64|aarch64), `--output/-o`, `--verbose/-V`, `--dev`, `--sign/-s`, `--dmg`, `--universal/-u`, `--minimal/-m`, `--target/-t`, `--linux`, `--linux-musl`, `--windows`, `--skip-webview-check`, `--help`.
- The app file must end in `.rb` (:160). **There is no backend flag.**
- Runtime: **Traveling Ruby 3.4.7**, release `20251122` (:18-23). It downloads `traveling-ruby-20251122-3.4.7-<os>-<arch>-full.tar.gz` (~56 MB) with `curl` into `~/.scarpe/packager-cache/` (:492-537) and extracts it (228 MB for macOS arm64, already cached on this machine).
- `--dev`: `find_scarpe_root` (:394-405) walks up from package.rb, or tries `~/Progrumms/scarpe` or `../scarpe`. `overlay_dev_sources` (:702-721) replaces `lib/` inside **already-copied** gem dirs for `scarpe`, `lacci` and `scarpe-components` (the `SCARPE_DEV_GEMS` map, :109-113).

**macOS** `build_macos!` (:219-257), producing `<Name>.app`:

| Step | Lines | Note |
|---|---|---|
| `ensure_runtime_cached` | :506 | |
| `create_bundle_structure` | :541-547 | `Contents/{MacOS,Resources/app,Resources/runtime/ruby,Resources/runtime/gems/{gems,specifications,extensions}}` |
| `copy_ruby_runtime` | :549-580 | bin, bin.real, lib/*.dylib, *.crt, stdlib 3.4.0, site_ruby, vendor_ruby |
| `copy_gems` | :582-623 | `REQUIRED_GEMS` :73-90 + `PLATFORM_GEMS` :94-103: scarpe, lacci, scarpe-components, webview_ruby 0.1.2, ffi 1.17.2, ffi-compiler, webrick, fastimage, logging, little-plugger, multi_json, base64, minitest, rake, racc, syslog, nokogiri, sqlite3 |
| `copy_native_extensions` | :749-766 | ffi, racc, syslog, webview_ruby from TR `extensions/<plat>/3.4.0-static` |
| `copy_webview_extension` | :768-786 | compiles `webview.cpp` with `xcrun clang++ -framework WebKit`, caches at `~/.scarpe/packager-cache/webview-ext/libwebview-ext-<arch>.bundle` (:820-863), `lipo` for universal (:865-882) |
| `copy_user_app` | :917-948 | the `.rb`, plus same-dir assets if the dir isn't `/`, `/tmp`, or HOME, plus `images/ assets/ fonts/ sounds/` |
| `write_boot_script` | :950-980 | `Contents/Resources/boot.rb`: dead `SCARPE_DISPLAY`, `SCARPE_PACKAGED=1`, relaxed `Gem::Specification#activate_dependencies`, `require 'scarpe'`, **`require 'scarpe/wv'`**, `Shoes.run_app(ARGV[0])` |
| `write_launcher` | :982-1029 | `Contents/MacOS/scarpe-launcher` (bash): sets TR env (`RUBYOPT=-rtraveling_ruby_restore_environment`, `GEM_HOME`, `GEM_PATH`, `RUBYLIB`), dead `SCARPE_DISPLAY`, finds the first `app/*.rb`, `cd "$DIR/app"`, `exec "$RUBY_ROOT/bin.real/ruby" "$DIR/boot.rb" "$APP_FILE"` |
| `write_info_plist` | :1031-1067 | `CFBundleExecutable=scarpe-launcher`, `CFBundleIdentifier=com.scarpe.<name>`, `LSMinimumSystemVersion 10.15`, `NSHighResolutionCapable` |
| `copy_icon` | :1079-1111 | `.icns`, or `.png` converted via `sips` + `iconutil` |
| `strip_unnecessary_files` | :1113-1277 | removes test/spec/examples/docs dirs in gems; `*.o *.c *.h *.cpp` in gems; README/LICENSE/etc.; FFI ext and other-platform dirs; all Bootstrap themes but one; stdlib rdoc/irb/...; terminal dylibs; encodings; `dedup_dylibs` (:1518, saved 9.1 MB); bundler |
| `strip_minimal` | :1279-1491 | when `--minimal`: `OPTIONAL_GEMS` (:128), SSL/crypto/lzma/yaml dylibs, `MINIMAL_STRIP_STDLIB`/`FILES`, rubygems internals, date/digest/cgi/erb exts |
| `sign_bundle` | :1552-1606 | ad-hoc `codesign --sign -` on every `**/*.bundle` and `**/*.dylib`, then **explicitly** `bin.real/ruby` with entitlements (:1574-1581), then `--deep` on the `.app` |
| `write_entitlements` | :1608-1627 | `allow-unsigned-executable-memory`, `allow-jit` (WebKit reasons) |
| `create_dmg` | :1631-1670 | `hdiutil create -format UDZO -imagekey zlib-level=9` with an `/Applications` symlink |

**Linux** `build_linux!` (:259-286), producing an AppImage, or a self-extracting `.run` if `appimagetool` is missing (:2094-2229):
- AppDir layout: `usr/bin/ruby`, `usr/lib/ruby/...`, `usr/share/<name>/{main.rb,boot.rb}`.
- `copy_webview_extension_linux` (:1822-1859) **raises** unless a prebuilt `~/.scarpe/packager-cache/webview-ext/libwebview-ext-linux-<arch>.so` exists or `--skip-webview-check` is passed. It hardcodes the `webview_ruby-0.1.2` dir.
- `write_boot_script_linux` (:1878-1909) sets the dead `SCARPE_DISPLAY`, `require "scarpe"; require "scarpe/wv"`, then **`load File.join(__dir__, "main.rb")`**. That bypasses `Shoes.run_app`, so there is no chdir, no `$LOAD_PATH` push and no segmented loader.
- `write_apprun_script` (:1911-1954) **checks for WebKitGTK via ldconfig and `exit 1`** if it is missing (:1922-1935).
- `.desktop` and icon (:1956-1994).

**Windows** `build_windows!` (:288-316) produces the folder `<Name>/{<Name>.bat, ruby/, app/{main.rb,boot.rb}}` plus `<Name>-<arch>-windows.zip`:
- `copy_webview_extension_windows` (:2408-2447) needs a prebuilt `webview-<plat>.dll`.
- The boot script (:2474-2505) has the same dead env and the same `load`.
- The `.bat` launcher (:2507-2562) **checks the WebView2 registry key and exits** (:2529-2547).

### 2.2 What gets bundled, with measured sizes (this machine, arm64, `--dev`, `examples/button.rb`)

I ran the packager with `HOME` pointed at a sandbox so nothing was written to the real `~/.scarpe`. Command:

```
HOME=<research>/fakehome ruby exe/scarpe package <app>.rb --dev --verbose --output <research>/pkg_out
```

`fakehome/.scarpe/packager-cache/traveling-ruby-3.4.7-macos-arm64-full` and `fakehome/.local/share/mise` are symlinks to the real dirs.

| Build | .app | Ruby runtime | gems | .dmg | Time |
|---|---|---|---|---|---|
| full | **26 MB** | 23 MB | 3.0 MB | none | 1.9 s (runtime cached) |
| `--minimal --sign --dmg` | **8.9 MB** | 8.0 MB | small | **2.8 MB** | a few s |

These numbers **exclude** `scarpe`, `lacci` and `webview_ruby`, which never got copied (§2.3). Real source sizes: `lacci/lib` 320 KB, `scarpe-components/lib` 188 KB, `lib` 396 KB, `scarpe-components/assets` 7.0 MB (Bootstrap themes, mostly stripped), `libwebview-ext.bundle` 68 KB.

For comparison, the committed `HelloScarpe.AppDir` (a Linux build artifact from 2026-02-06, 3,061 files, **58 MB**) is inside `git ls-files`. **`scarpe.gemspec:24-28` packs every git-tracked file, so this AppDir ships inside the gem.**

**Estimate for a native backend:** minimal Ruby (8 MB) + lacci/components/service (~1 MB) + a stripped Rust GUI binary (typically 3 to 10 MB) gives roughly **12 to 20 MB .app, ~5 to 8 MB .dmg**, with no WebKit dependency on Linux or Windows. This is an estimate, not a measurement.

### 2.3 The packager is broken on this machine today (reproduced)

Launching the full build: `HelloButton.app/Contents/MacOS/scarpe-launcher` gives

```
boot.rb:21:in '<main>': ... 'Kernel#require': cannot load such file -- scarpe (LoadError)
```

(plus "Ignoring nokogiri/sqlite3 because its extensions are not built").

Root causes, all confirmed in the verbose log:
1. The TR 20251122 "full" gem set (237 gems) contains **no `scarpe`, `lacci`, `scarpe-components` or `webview_ruby`**. mise has none of `scarpe`, `lacci` or a current `scarpe-components` (only `scarpe-components-0.2.2`).
2. **Prefix bug in `find_gem_dir`** (:739). `Dir.children(gems_dir).select { |d| d.start_with?("#{name}-") }` for `name="scarpe"` matches `scarpe-components-0.2.2`. The log shows `✅ scarpe-components-0.2.2 (from system Ruby)` **twice**, once for `scarpe` and once for `scarpe-components`.
3. `overlay_dev_sources` (:702-721) only overwrites `lib/` in a gem dir that already exists (`next unless gem_dir`). With no `scarpe-*`/`lacci-*` dir it does nothing for lacci. For "scarpe" it globs `scarpe-*`, hits `scarpe-components-0.2.2` and overlays `lib/` there, then the scarpe-components overlay overwrites the same dir. **Result: no scarpe lib and no lacci in the bundle.**
4. `install_gem_from_system` (:665-700) skips any gem containing a `*.bundle`/`*.so`/`*.dll` (:683-684). So `webview_ruby`, which ships `ext/aarch64-darwin/libwebview-ext.bundle`, is never copied. The log says `⚠️ Gem not found in cache: webview_ruby`, then `webview_ruby gem directory not found in bundle`.

Conclusion: the packager only works when the `scarpe`, `lacci`, `scarpe-components` and `webview_ruby` gems are **installed** in a mise or rbenv Ruby. That is how `HelloScarpe.AppDir` was built: its `gems/3.4.0/gems/` holds `lacci-0.4.0` and `scarpe-0.5.0`.

**A native path should stop relying on "find the gem somewhere".** Copy `lib/`, `lacci/lib` and `scarpe-components/lib` straight from `@scarpe_root` into a known `RUBYLIB` dir, which is simpler and deterministic.

### 2.4 Exact hook points for a compiled Rust binary

These are ordered by what a `--backend native` (or auto-detected) path needs to change.

1. **Gem list:** `REQUIRED_GEMS` (:73-90). A native build needs only `scarpe`, `lacci` and `scarpe-components`, plus `minitest` if you want Shoes-Spec inside the app. Drop `webview_ruby`, `ffi`, `ffi-compiler`, `webrick`, `nokogiri`, `sqlite3` and `fastimage` (the last only matters for image auto-size). `NATIVE_EXTENSION_GEMS` (:106) is webview-motivated.
2. **Binary copy, a new step in `build_macos!`** (:219-257), in place of `copy_webview_extension` (:225).
   - Put the Rust executable in **`Contents/MacOS/`**, e.g. `Contents/MacOS/scarpe-native`.
   - Reason: `strip_unnecessary_files` never touches `Contents/MacOS`, and code in `Contents/MacOS` is where codesign and Gatekeeper expect executables. Executables in `Contents/Resources` are a known source of "code object is not signed at all (subcomponent)" errors.
   - On macOS, an executable inside `X.app/Contents/MacOS/` normally resolves `NSBundle.mainBundle` to `X.app`, so the Rust window should pick up the app name and icon from `Info.plist`. This is likely but unverified; check it in a spike.
3. **Boot script** `write_boot_script` (:950-980). Replace the dead `ENV['SCARPE_DISPLAY'] ||= 'wv_local'` with `ENV['SCARPE_DISPLAY_SERVICE'] ||= 'native'` **before** `require 'scarpe'`, and **delete `require 'scarpe/wv'`** (:973). Otherwise `Shoes::Log.instance` and `Shoes::Spec.instance` get set twice and raise (§1.4). Do the same at Linux :1899-1902 and Windows :2495-2498, and switch those two to `Shoes.run_app(File.join(__dir__, "main.rb"))` so segmented files and chdir behave.
4. **Launcher** `write_launcher` (:982-1029).
   - Replace `export SCARPE_DISPLAY=wv_local` (:1009) with `export SCARPE_DISPLAY_SERVICE=native` and `export SCARPE_NATIVE_BIN="$(cd "$(dirname "$0")"; pwd)/scarpe-native"`.
   - The Ruby service should resolve its binary in this order: `ENV["SCARPE_NATIVE_BIN"]`, then a path relative to its own file, then `target/release` in dev.
   - Alternative (a design choice for the orchestrator): make the Rust binary the `CFBundleExecutable` (:1039-1040) and have it spawn Ruby as its child. That gives the GUI process LaunchServices identity and keeps the main-thread rules simple.
5. **Signing** `sign_bundle` (:1552-1606).
   - Add an explicit `codesign --force --sign - --timestamp=none <app>/Contents/MacOS/scarpe-native`, as is done for `bin.real/ruby` (:1574-1581). Do it before the final `--deep` (:1584).
   - The JIT/unsigned-memory entitlements (:1618-1621) are only needed for WebKit.
   - Note: if the Rust side instead ships as a `.dylib` loaded via FFI or Fiddle, the existing `**/*.dylib` loop (:1562-1571) already covers it.
6. **Universal builds:** `--universal` currently lipos only the webview bundle (:865-882). For Rust, run `cargo build --target aarch64-apple-darwin` and `--target x86_64-apple-darwin`, then `lipo -create`.
7. **Linux and Windows:** skip `copy_webview_extension_linux` (:1822-1859, which raises) and the WebKitGTK check in AppRun (:1922-1935). Skip `copy_webview_extension_windows` (:2408-2447) and the WebView2 registry check (:2529-2547). Place the binary in `usr/bin/` (AppImage) or next to the `.bat`.
8. **Cache layout** to mirror: `~/.scarpe/packager-cache/webview-ext/<file>` via `Scarpe::Extension::CACHE_DIR` (extension.rb:15) with `EXTENSION_FILES` per platform (:19-29). A native equivalent would be `~/.scarpe/packager-cache/native/scarpe-native-<platform>`.
9. **Strip interplay:** `strip_unnecessary_files` deletes dirs named `test spec examples docs doc .git spikes experiments benchmark features yard` and files `*.c *.h *.cpp` **only under the gems dir** (:1121-1134). A Rust crate shipped inside the scarpe gem (e.g. `native/src/*.rs`) survives but is dead weight. Strip `native/` from gems if you copy source trees.

### 2.5 `scarpe extension`

`scarpe extension [status|list|build <target>|help]` (extension.rb:304-317).
- `status` prints the cache table (:49-77).
- `build` fetches the `webview_ruby-0.1.2.gem` source from rubygems.org, then compiles `webview.cpp` with GTK/WebKitGTK inside Docker (`ubuntu:22.04` for glibc, `alpine:3.19` for musl, QEMU for arm64) (:134-300). It prompts on stdin for arm64 in `build all` (:110-111).
- Wording bug: status claims `build linux` does "x86_64 glibc + musl", but `build("linux")` only builds glibc x86_64 (:82-83).

The same build matrix exists as CI in `.github/workflows/build-webview-extensions.yml` (manual `workflow_dispatch` plus pushes that touch that file): Linux x86_64/arm64 (QEMU), Alpine, macOS-13/14 with artifact upload. **This is the template for a Rust binary release matrix.** `scripts/build-linux-extensions.sh` (98 lines) is the shell equivalent.

---

## 3. gtk-scarpe (Noah Gibbs, 2024-01-09 to 2024-05-06, `ref/gtk-scarpe`, 1,978 Ruby lines)

### 3.1 Structure

- **A standalone gem with its own executable.** `exe/gtk-scarpe` is a near copy of `exe/scarpe`: `--dev`, `--dev-lacci` (prepends a sibling `../scarpe/{lacci,scarpe-components}/lib`), `--debug`. It prints `.sspec` results to stderr when `SHOES_MINITEST_EXPORT_FILE` is unset (:81-93).
- It depends on `gtk4`, `lacci ~>0.4.0`, `scarpe-components ~>0.4.0` and `logging`, **not on the scarpe gem**. So no webview, ffi or nokogiri.
- Entry file `lib/scarpe/gtk-scarpe.rb`:
  - `:3` `ENV['SCARPE_DISPLAY_SERVICE']="gtk-scarpe"`, then `require "shoes"; require "lacci/scarpe_core"`, then `require "gtk4"; require "gdk4"`.
  - `:13-19` overrides `GLib.exit_application` to re-raise `SystemExit`. Without it, `exit()` inside a GTK callback is swallowed. **Lesson: native loops eat exceptions and exit, so plan for that.**
  - `:24-30` ModularLogImpl. `:32-34` segmented loader. `:37` `FONTS.push("Helvetica","Arial")`. `:42-46` `Shoes::Spec.instance = Scarpe::GTK::Test`, then `set_display_service_class(Scarpe::GTK::DisplayService)`.
  - The requires for art drawables, subscription items, progress, image, edit_box, edit_line, list_box, shape and video are **commented out** (:61-69). So there were no timers or animation at all.
- `DisplayService#create_display_drawable_for(name, id, props, is_widget:, parent_id:)` (display_service.rb:37-79):
  - `App` builds `Scarpe::GTK::App`, which needs `@doc_root` first.
  - `is_widget` maps to `Scarpe::GTK::Flow`.
  - Otherwise `Drawable.display_class_for(name)` looks up `Scarpe::GTK.const_get(last segment)`.
  - Constructs with **`display_class.new(properties, parent: display_parent)`**, so the parent is known at construction, unlike Webview's later `set_parent`.
- `Drawable < Shoes::Linkable` (drawable.rb):
  - copies props to ivars (:56-61) and keeps `@shoes_style_names`.
  - binds `prop_change`, then `properties_changed(changes)`. Subclasses `delete` the keys they handle and call `super`. The base **raises** on leftover keys, and on any margin/position change, with `"How do we refresh this widget?"` (:124-147).
  - binds `destroy`, which calls `destroy_self`. That removes the drawable from its parent but never removes the GTK widget ("TODO: remove properly", :156-160).
- `Slot < Drawable` has `children` and `put_to_canvas` recursion (slot.rb:42-49). `Flow`/`Stack` are empty subclasses. `DocumentRoot` does `position_as("Flow")` with a `Gtk::Fixed` (:59-65).

### 3.2 Layout (`positioning.rb`, 290 lines, pure Ruby and unit tested)

- Three positioning kinds: `SC_POS_DRAWABLE_TYPES = ["Stack","Flow","Drawable"]`. Aliases `DocumentRoot→Flow`, `Widget→Flow`, `Button→Drawable`, `Para→Drawable` (:30-42).
- An includer implements `pos_properties`/`pos_property(name)`, `pos_children` and **`pos_minimum_size` returning `[w, h]` from the toolkit**. GTK used `@gtk_obj.preferred_size`, the natural size (drawable.rb:170-174).
- `calculate_layout(ctx)` returns `{"top","left","width","height","children"=>[...],"display"=>"in"|"out"}` (:142-240). `ctx` holds the parent's width/height and a running top/left.
  - An explicit `top` or `left` makes the drawable **out of flow** (`"display"=>"out"`). It doesn't push siblings or grow the slot (:124, :189-192, :210-213).
  - Stack stacks vertically. Its width is the max child width, its height the bottom of the last in-flow child.
  - Flow places children left to right and wraps when `left+width > max_width && next_left != far_left` (:215).
- `req_to_size(req, ctx_size)` (:247-272):
  - Integer means px, and a negative Integer means `ctx + req`.
  - Float means a fraction, and a negative Float means `1.0 + f`.
  - `"NN%"` means a percentage.
  - Anything else raises.
- Rendering: `App#full_calculate_and_draw` (app.rb:97-112) calls `document_root.calculate_layout({"width"=>@width,"height"=>@height,"left"=>0,"top"=>0})`, clears the `Gtk::Fixed`, then `put_to_canvas`. Each widget does `set_size_request(w,h)` and `canvas.put(obj, left+offset, top+offset)` (drawable.rb:176-183). **This runs once, in the `activate` signal. It is never re-run.**
- Tests: `test/test_positioning.rb` (367 lines) builds a `TestPosDrawable` with fake `native_size` and asserts layout hashes, with no window. **Copy this idea: keep the layout engine pure and test it headless** (in Rust, `cargo test` on a layout tree).
- Bugs and gaps:
  - `requested_margin` uses undefined `context_width`/`context_height` (:277-287) and is never called. **Margins and padding are not applied at all.**
  - Flow compares a relative `next_left` against the absolute `far_left = out_ctx["left"]` (:205, :215), which is wrong for a Flow with a non-zero left.
  - No `displace_*`, `hidden`, `right`/`bottom`, or scroll support.

### 3.3 Events

- Button `clicked` sends `send_self_event(event_name: "click")` (button.rb:11-13).
- `Gtk::EventControllerMotion` `enter`/`leave`/`motion(x,y)` send `hover`/`leave`/`motion` with `x, y` (drawable.rb:79-93).
- Check `toggled` sends `click` only if the new value differs from `@checked` (check.rb:12-17). The value then comes back as a `prop_change "checked"`.
- Radio: GTK4 `CheckButton#group` with a class-level registry (radio.rb:17-39). **Bug:** `group_name` is `@group.to_s || ...` (:55), and `nil.to_s` is `""`, which is truthy, so the parent-slot fallback never happens.
- The `builtin "alert"` handler shows a `Gtk::MessageDialog` (app.rb:33-49). `"font"` raises "Implement me!".
- Text:
  - Para becomes a `Gtk::Label` with Pango markup built from `text_items`. Strings go in raw, and TextDrawable ids are looked up to `to_markup` (para.rb:14-24).
  - Bugs: strings are **not markup-escaped**, so `<` or `&` in text breaks it. `"\n"` becomes `"<br>"`, which is not Pango.
  - TextDrawables (`code del em strong span sub sup ins`) map to Pango span attrs via `tagged_text_drawable` (text_drawable.rb:139-162).
  - Their `prop_change` and `destroy` handlers **raise "Implement me!"** (:23-29).
  - `Link#visual_items` is a typo for `visual_item` (:167), so links render as plain spans.

### 3.4 How it ran Shoes-Spec

- `Scarpe::GTK::Test.run_shoes_spec_test_code(code, class_name: nil, test_name: nil)` (shoes_spec.rb:9-34). It has **no `filename:`/`line:`**, so it would ArgumentError against current Lacci, which passes both (app.rb:101).
- It defines the test class and queues `Minitest.run []; Shoes::App.instance.destroy` in `App#on_post_init`, which fires after the window's `activate`. **`Shoes::App.instance` does not exist in current Lacci**; use `Shoes.APPS`.
- Proxy `trigger(:click|:hover|:leave|:motion, *args)` goes to `@display.trigger(...)`, which calls `send_self_event` (shoes_spec.rb:65-72; drawable.rb:95-104; button.rb:27-34). Tests fake the display-side Shoes event rather than synthesising a GTK click.
- There is no timeout support.
- The harness `shoes-spec/implementations/gtk-scarpe/gtk_scarpe_runner.rb:19-37` sets `SHOES_SPEC_TEST`, `SCARPE_DISPLAY_SERVICE=gtk-scarpe`, `SHOES_MINITEST_EXPORT_FILE`, `SHOES_MINITEST_CLASS_NAME=<category with / as _>` and `SHOES_MINITEST_METHOD_NAME=<test name>`. It runs `system(RbConfig.ruby, which("gtk-scarpe"), "--dev", app_file)` and reads the JSON with `Scarpe::Components::MinitestResult` (`error?`/`fail?`/`skip?`).
- Results in `shoes-spec/results/gtk-scarpe/expected/results-local-gtk.yaml`: **pass** on `drawables/button/basic_click`, `drawables/button/button_events`, `drawables/para/para_replace`, `dsl/slot/self_slot`, `manual/examples/example_1` and `test_code/assertions/pass`. Errors on `dsl/app/add_drawables`, the legacy examples and the exception cases.

### 3.5 Design lessons for the Rust backend

1. **Ship it as its own entry point** that requires only `shoes` + `lacci/scarpe_core` + `scarpe-components`, as gtk-scarpe and space_shoes both do. `lib/scarpe.rb` still works (`SCARPE_DISPLAY_SERVICE=native`), but the service must not pull in `scarpe/wv`.
2. **Own the Shoes layout in one pure, testable place.** Shoes layout is simple (Stack, Flow, out-of-flow absolute, px/float/percent/negative sizes, margins). Measure native sizes, meaning text metrics and control intrinsics, through a single `min_size` hook. Noah's `Scarpe::Positioning` is a reference spec, but has the gaps above (margins, relayout).
3. **Relayout on every structural or prop change from day one.** gtk-scarpe's "raise on unknown prop / never relayout" is why it stalled after 6 passing cases. Rust can afford a full-tree relayout per frame.
4. **Carry the parent at creation** (gtk's `new(props, parent:)`). Lacci already passes `parent_id:`.
5. **Test triggers:** gtk faked Shoes events, which is cheap but skips hit-testing. The Rust backend can offer both a direct dispatch and a "click at drawable centre" path through its own hit-test.
6. **Handle `exit`, `SystemExit` and exceptions** thrown inside UI callbacks explicitly (gtk-scarpe.rb:13-19).

---

## 4. space_shoes (Noah, to 2024-08-20, `ref/space_shoes`)

- **Guest/host split** (ARCHITECTURE.md). The guest is ruby.wasm in a browser page running Lacci plus an HTML (Calzini) display service. The host is packaging, an HTTP server and Capybara tests.
- Entry `lib/scarpe/space_shoes.rb`:
  - `:3` sets `ENV['SCARPE_DISPLAY_SERVICE']="space_shoes"`, then `require "shoes"; require "lacci/scarpe_core"`.
  - PrintLogImpl (:12-14). `Shoes::Spec.instance = SpaceShoes::ShoesSpec` (:34-35). `set_display_service_class(SpaceShoes::DisplayService)` (:87).
  - `browser_shoes_code(url, code)` evals the app segment of an `.sspec` (:90-102).
- **Bridge:** `SpaceShoes::WasmCalls` binds Ruby procs as JS globals (`JS.global[:self][name] = proc {...}`) and converts JS values to Ruby with `rubify` (guest/wasm_calls.rb:21-48). JS calls back into `scarpeHandler(name, *args)`, which goes to `App#handle_callback`.
- **Event loop:** `App#run` sends `custom_event_loop "return"` because the browser owns the loop (guest/app.rb:90-96). The heartbeat is a JS `setInterval` that calls into Ruby.
- **Specs:** Minitest runs **inside the guest** on `:next_heartbeat`, with `Minitest.parallel_executor` stubbed because there are no threads (guest/app.rb:31-69). Results go into the DOM (`document.shoes_spec` and a `div.minitest_result` with `data-cases/assertions/failures/errors/skips`). The host (`lib/space_shoes/host/shoes-spec-capybara-test.rb`) drives headless Chrome via Selenium and reads that DOM.
- **Lesson for Rust:** when the renderer lives across a process boundary, run the test code on the Lacci (Ruby) side, where the objects are. Export results through the existing JSON reporter. Give the renderer only a small "introspect/synthesise input/screenshot" control channel.

---

## 5. The relay (`wv_relay`): status, datagram format, spike

### 5.1 Status today: broken (reproduced)

```
SCARPE_DISPLAY_SERVICE=wv_relay bundle exec ruby exe/scarpe --dev examples/button.rb
webview_relay_display.rb:39:in 'Scarpe::Webview::RelayDisplayService#initialize':
  undefined method 'bind_shoes_event' for an instance of Scarpe::Webview::RelayDisplayService (NoMethodError)
```

The child worker then dies with `AppShutdownError: Got an unexpected EOF reading datagram! Did the parent process die?` No window opens. Exit 1. The relay files were last touched on 2023-11-12 (ae589f1). The `parent_id:/is_widget:` signature arrived on 2023-12-16 (c09799b, "Draw context inheritance").

### 5.2 All bugs found

| # | Location | Bug | Effect |
|---|---|---|---|
| 1 | webview_relay_display.rb:39 (and :46 `bind_shoes_event` usage) | `Shoes::DisplayService` instances aren't `Shoes::Linkable`s, so there is no `bind_shoes_event` | NoMethodError at first drawable (**first failure**) |
| 2 | webview_relay_display.rb:46 | `if event_name == "run"`, but `event_name` is not a local; it is in `kwargs[:event_name]` | NameError inside every relayed event |
| 3 | webview_relay_display.rb:70 | `create_display_drawable_for(drawable_class_name, drawable_id, properties)` has the stale signature | ArgumentError "unknown keywords: :parent_id, :is_widget" |
| 4 | webview_relay_util.rb:111 | the child calls `@wv_display.create_display_drawable_for(class_name, id, properties)` without `parent_id:`/`is_widget:`, and the `:create` datagram doesn't carry them | ArgumentError "missing keywords" |
| 5 | webview_relay_util.rb:36 | `(str_data.length.to_s + "a" + str_data).encode(Encoding::BINARY)`: the length counts **characters**, and `.encode(BINARY)` **raises `Encoding::UndefinedConversionError` for any non-ASCII** text | verified: `JSON.dump({text:"café ☕"})` gives length 17 but bytesize 20, and the encode raises. Use `.b` and `bytesize` |
| 6 | webview_relay_display.rb:81 | `@events_subs` typo for `@event_subs` | unsubscribe is a no-op (harmless) |

Design limits even when fixed:
- Both sides poll at 0.1 s. The parent does `sleep 0.1` (:57-61). The child pumps via `wrangler.periodic_code("datagramProcessor", 0.1)` (wv_display_worker.rb:53-58). That can mean up to ~200 ms from click to repaint.
- The child blocks for up to `event_loop_for(2.5)` (:70) before Webview takes over.
- TCP on `127.0.0.1` with an ephemeral port.
- **Shoes-Spec can't run across it.** `Scarpe::ShoesSpecProxy#initialize` needs `query_display_drawable_for` in the same process, and `Scarpe::Test` needs CatsCradle and the Webview control interface in-process (lib/scarpe/shoes_spec.rb:150-194, 215-239).
- **Builtins can't return values**, because it is fire-and-forget (§1.5).

### 5.3 Datagram format (lib/scarpe/wv/webview_relay_util.rb)

- **Framing:** ASCII decimal length, then the letter `a`, then the JSON body. Example: `93a{"type":"event",...}`.
  - `send_datagram(hash)` (:34-50) does `JSON.dump`, prepends `"#{len}a"` and loops `@to.write` until everything is written.
  - `receive_datagram` (:56-91) reads 10-byte chunks until it finds an `a`, parses the length, then reads exactly that many bytes. EOF or any exception is re-raised as `Scarpe::AppShutdownError`.
  - `ready_to_read?(timeout=0.0)` is `IO.select([@from], [], [@from,@to], timeout)` and raises `Scarpe::ConnectionError` on an error set (:17-28).
- **Messages** (`respond_to_datagram`, :95-122):
  - `{"type":"create","class_name":<String>,"id":<Integer>,"properties":{...}}`. Parent to child only; the parent raises `InvalidOperationError` if it receives one. **Add** `"parent_id":<Integer|null>,"is_widget":<bool>`.
  - `{"type":"event","args":[...],"kwargs":{"event_name":<String>,"event_target":<Integer, omitted when nil>,"relayed":true, ...}}`. Both directions. The receiver calls `send_shoes_event(*args, event_name:, target:, **kwargs_sym)`. The `relayed` flag stops the receiver's own `:any/:any` subscription from echoing it back.
  - `{"type":"destroy"}`. The child `exit 0`s. The parent sets `@shutdown = true`.
- **Transport:** the parent opens `TCPServer.new("127.0.0.1", 0)`, then `spawn(RbConfig.ruby, "wv_display_worker.rb", port)`, then `server.accept`. The child connects with `TCPSocket.new("localhost", port)`. A single socket carries both directions (`@from = @to`).

### 5.4 Spike: the relay pattern works once patched

Files are in `research/spike_relay/`:
- `relay_patch.rb` monkeypatches `RelayDisplayService` and `WVRelayUtil`. It fixes bugs 1-4 and logs every datagram to `$RELAY_LOG`.
- `spike_worker.rb` is a copy of the worker that loads the patch.
- `run_relay.rb` stands in for `exe/scarpe --dev`.
- `roundtrip_app.rb` is the test app.
- `relay.log` holds the captured datagrams.

Run it with:

```
RELAY_LOG=... bundle exec ruby run_relay.rb roundtrip_app.rb
```

Result: exit 0 in 5.5 s wall for an app that quits itself at t = 3 s, and no worker is left running. Observed wire sequence (parent to child unless noted):

```
create DocumentRoot id=2 parent_id=nil   | create App id=1 parent_id=nil | event init
event prop_change target=3 [{"text_items":["before"]}]      <- before Para's create
create Para id=3 parent_id=2 | create Button id=4 parent_id=2 | create SubscriptionItem id=5 (timer 1) | id=6 (timer 3)
event run
child->parent: event timer target=5
event prop_change target=3 [{"text_items":["timer fired in parent pid N"]}]   x2 (double-fire, §7.1)
child->parent: event timer target=6  -> parent Shoes.quit
event destroy (x3; shutdown actually completes on socket EOF -> AppShutdownError on both sides)
```

**Recommendation for the Rust child.** Reuse these message shapes nearly verbatim: they map one to one onto `create_display_drawable_for` and `dispatch_event`. Fix the framing and transport:
- Use **newline-delimited JSON**, which is safe because JSON escapes newlines inside strings, or a 4-byte big-endian length prefix. Count **bytes**.
- Use **stdin/stdout pipes** via `IO.popen`/`Open3.popen2`, or a Unix socket, instead of TCP. That avoids port races and possible firewall prompts in packaged apps (a guess, not tested), and gives a free "parent died → stdin EOF → child exits" orphan guard.
- Add request/response ids for `builtin` answers, and a ready ack so the Ruby side knows when the first frame is up (the natural moment to run Shoes-Spec, the way Niente uses its first heartbeat).
- Ruby should pump inbound messages from a heartbeat that blocks on `IO.select`: the `"wait"` loop type, or `"return"` plus an at_exit loop like Niente. That way Ruby keeps its main thread and the Rust process owns the AppKit main thread.

---

## 6. Tests and CI: where a new backend slots in

### 6.1 Rake tasks (Rakefile)

- `:test` (:54-58): `libs test, lib`, files **`test/**/test_*.rb`**. Any new `test/native/test_*.rb` is picked up by `rake test` too. Either add `.exclude("test/native/**")` or put native tests elsewhere and add `Rake::TestTask.new(:native_test)`.
- `:lacci_test` (:60-64) covers `lacci/test/**/test_*.rb` with Niente. `:component_test` (:66-70) covers `scarpe-components/test/**`.
- `test:check_html_fixtures` and `test:regenerate_html_fixtures` (:72-84) are Webview HTML golden files (`test/wv/html_fixtures/*.html`, 71 files).
- `default: [test, lacci_test, component_test]` (:86).
- **`ci_test` (:8-52) is destructive for local use.** It runs `brew install pkg-config portaudio`, `git checkout main` and `bundle install`, and reports nothing on failure (it uses `system`). Do not run it.

### 6.2 Helpers that already take a `display_service:` parameter

- `lacci/test/test_helper.rb` `NienteTest#run_test_niente_app(app, app_test_code:, timeout:, class_name:, method_name:, expect_process_fail:, expect_minitest_exception:, display_service: "niente", log_level:)` (:35-91).
  - It builds the env string and runs `ruby exe/scarpe --dev <app>`, then reads the JSON via `Scarpe::Components::MinitestResult` (`error?`, `fail?`, `skip?`, `assertions`).
  - **Passing `display_service: "native"` lets the whole Lacci suite (105 tests) run against the new backend** once it honours §1.8.
  - It writes `lacci/test/niente_test.json` (:46).
- `test/test_helper.rb`:
  - `ShoesSpecLoggedTest#run_scarpe_sspec(filename, process_success:, expect_assertions_min/max:, expect_result:, timeout:, wait_after_test:, display_service: "wv_local", html_renderer:)` (:44-94).
  - `run_test_scarpe_app(app, app_test_code:, timeout:, exit_immediately:, allow_fail:, display_service: "wv_local")` (:106-166). It prepends Webview-only `timeout N` and `exit_on_first_heartbeat` DSL to the test code (:114-118), so the native Shoes-Spec should implement `timeout` and `exit_on_first_heartbeat` too, or not use this helper.
  - **Bug:** lines :73-74 and :139-140 concatenate `LOCALAPPDATA=\"...\"` + `"ruby ..."` with **no space**. The shell runs `exe/scarpe` through its shebang, and `LOCALAPPDATA` gets `ruby` glued on. It works by accident. gtk-scarpe's test_helper.rb:53-54 has the same bug.
- `test/test_examples.rb` runs **every** `examples/**/*.rb` on Webview (only `/not_checked/`, `/bloopsaphone/` and optionally `/skip_ci/` excluded). That now includes `examples/legacy/for_playtest` (191), `working` (59), `shoes3_only` (48), `needs_deps` (3) and `path_issues` (1): 302 legacy plus 122 other `.rb` files.
- `tasks/test_legacy_examples.rb` is **stale**. It points at `examples/legacy/not_checked` (:13), which no longer exists, and shells out to GNU `timeout` (:63), which macOS doesn't have. It reports 0 examples, or fails everything with exit 127.
- `tasks/visual_check.sh` scrapes Webview `innerHTML` from debug output, and is also Webview-only.

### 6.3 CI (.github/workflows/ci.yml)

- Triggers: push and PR on `main`, ignoring docs and `*.md` (:3-16). `runs-on: macos-latest`, `timeout-minutes: 30`.
- `ruby/setup-ruby@v1` with `bundler-cache: true` and no `ruby-version`, so it **reads `.ruby-version` = 3.2.0**. `dev.yml` also says 3.2.0.
- Steps: `CI_RUN=true bundle exec rake lacci_test`, then `component_test`, then `rake test:check_html_fixtures`, then `CI_RUN=true bundle exec rake test`, then upload `logger/test_failure*.out.log`.
- To slot in a Rust backend:
  - add `dtolnay/rust-toolchain@stable` and `Swatinem/rust-cache@v2`.
  - `cargo build --release` (and `cargo test` for the pure layout and protocol) before the Ruby steps.
  - then `CI_RUN=true bundle exec rake native_test`.
  - macOS runners have a GUI session (the Webview tests already open windows there). For Linux runners, run under `xvfb-run`.
- `.github/workflows/build-webview-extensions.yml` is the release-artifact matrix to copy for prebuilt Rust binaries (§2.5).

### 6.4 Environment gotchas measured here

- Local Ruby is 4.0.1 through mise, even though `.ruby-version` says 3.2.0; mise isn't honouring the idiomatic file. Bundler is 2.4.10, which prints about 16 lines of `Gem::Platform` "already initialized constant" warnings on every `bundle exec`. They are noise; filter with `grep -v "Gem::Platform\|previous definition"`.
- `Gemfile.lock` is **already modified** in the working tree (ffi 1.17.2 → 1.17.4, from a prior `bundle install`). That wasn't me. Keep it out of any commit.
- Bare `ruby -I lib -I lacci/lib -I scarpe-components/lib exe/scarpe ...` works (0.35 s) but loads **minitest 6.0.6**. The run prints the default reporter and **never writes `SHOES_MINITEST_EXPORT_FILE`**. Under `bundle exec` it writes correctly (minitest 5.27.0, minitest-reporters 1.7.1).
- Niente with no `SHOES_SPEC_TEST` never exits: an at_exit heartbeat spin at 100% CPU. My `examples/button.rb` run hit the 20 s alarm (exit 142). Always give headless runs a test or an alarm.
- `Shoes::Changelog#get_latest_release_info` shells out to `git rev-parse HEAD` in the **cwd** at require time (lacci/lib/shoes/changelog.rb:22-24). When the app dir isn't a git repo, as in the spike worker, it prints `fatal: not a git repository` to stderr. It is harmless noise, but costs a fork per boot.

---

## 7. Cross-cutting traps found along the way

### 7.1 Lacci `SubscriptionItem` fires every callback twice (affects every backend)

- `lacci/lib/shoes/drawables/subscription_item.rb:24-87` binds a per-type handler (`animate`, `every`, `timer`, `hover`, `leave`, `motion`, `click`, `release`, `keypress`, `wheel`).
- Then **:89-91 unconditionally binds `bind_self_event(shoes_api_name) { |*args| @callback&.call(*args) }` again.**
- Both originate in 2023 (05072013 and aa368dbd).
- Repro under Niente (`research/spike_relay/double_fire_app.rb` + `double_fire_test.rb`): one `dispatch_event` each for timer, animate and a Button `trigger_click` gives `{timer: 2, animate: 2, click: 1}`.
- The relay capture shows the same thing: one `timer` datagram, two identical `prop_change` replies.
- Fix: delete :89-91, or make it the `else` branch. A backend team will otherwise chase "animation runs at double speed" or "counter increments by 2" and blame the renderer.

### 7.2 Ordering and idempotency the Rust side must tolerate

- `prop_change` can arrive **before** `create` for the same id (Para; §1.5). Drop it; the create carries the value.
- `destroy` (untargeted) arrives several times at shutdown.
- A target-less `prop_change` never happens. Untargeted events are `init`, `run`, `destroy`, `builtin`, `heartbeat` and `custom_event_loop`.

### 7.3 Two Ruby versions to satisfy

- The packaged runtime is TR **3.4.7**. CI is **3.2.0**. Dev is **4.0.1**.
- Write Ruby that parses on 3.2: no `it`, and keep to features 3.2 has, including `Data` and anonymous block/rest forwarding.
- `exe/scarpe` itself avoids new syntax so the version check can run (`exe/scarpe:49-51`).

### 7.4 `Kernel#require` is globally wrapped by Lacci

`lacci/lib/shoes/compat_require.rb:24-39` aliases `Kernel#require` to `shoes_original_require`. On a `LoadError` it retries with a case map (`CSV→csv` and so on) or the downcased name. Two consequences:
- Every missing-file backtrace starts at `compat_require.rb:28`.
- A `require "scarpe/Native"` would silently resolve to `scarpe/native`.

I verified the load point with `SCARPE_DISPLAY_SERVICE=doesnotexist`. Under `--dev`, the `LoadError` comes from `lib/scarpe.rb:14`, called from `bundler/runtime.rb:60` (`Bundler.require`), which confirms §1.1.

### 7.5 Docs that look authoritative but aren't

`docs/display_service_separation.md` and `docs/event_loops.md` are generic, with invented APIs such as a `register_handler` `EventLoop` class. `display_service_separation.md` claims "the display service runs as a separate process", which is false for the default `wv_local`, which runs in-process. CLAUDE.md repeats that claim and still points at `examples/legacy/not_checked/`. Trust the code and the line refs above over those pages.
