# 04. Examples and Shoes-Spec, as they exist today

Lane: examples + Noah Gibbs' Shoes-Spec system. Scarpe clone: `<repo>` @ `fdcee7a` (master). Shoes-Spec clone: `.../scratchpad/ref/shoes-spec` @ `1e766c6` (2026-02-21). Ruby 4.0.1 (mise), Bundler 2.4.10.
All paths below are relative to one of those two roots unless absolute; `SS/` = shoes-spec root, `SC/` = scarpe-native root.

Artifacts written by this lane (all under `.../scratchpad/research/`):

| file | what |
|---|---|
| `04_examples_and_specs.md` | this report |
| `examples_inventory.json` | 424 rows `{path, category, dsl[], needs[], status_note, niente_load, sspec_case, sspec_niente, sspec_webview_2026_02_19}` |
| `freq_table.md` | full DSL-feature frequency table (208 rows) |
| `needs_table.md` | needs frequency |
| `niente_baseline.json` | Part C: every example run under Niente, one row each |
| `sspec_niente_results.json` | bonus: all 805 `.sspec` cases run under Niente against today's scarpe-native |
| `tools/inventory.rb`, `tools/niente_baseline.rb`, `tools/sspec_niente.rb` | re-runnable scripts (sandboxed; see Part C) |

---

## TL;DR for builders

1. **The spec contract is tiny and in-process.** Lacci reads `ENV["SHOES_SPEC_TEST"]` in `Shoes::App#initialize` (`SC/lacci/lib/shoes/app.rb:97-103`) and calls `Shoes::Spec.instance.run_shoes_spec_test_code(code, filename:, line:)`. The display service supplies that object. Test code runs *in the Ruby process that owns the Lacci tree*: finders call `Shoes::App#find_drawables_by` directly and proxies forward to the real `Shoes::Drawable`. 20 case files even call `Shoes::App.find_drawables_by(Shoes::Button)` (the class-level, all-apps finder) themselves and get raw Lacci objects back, no proxy. So the Rust backend must keep Lacci + test code in Ruby; Rust is the renderer on the other side of the display-service boundary.
2. **Copy Niente's spec layer, not Webview's.** `SC/lacci/lib/scarpe/niente/shoes_spec.rb` (180 lines) is display-agnostic and today matches `results/ideal/results-perfect.yaml` on all 18 cases it covers, and passes the 6 newer check/radio cases too. Webview's (`SC/lib/scarpe/shoes_spec.rb`) adds `wait`, `dom_html`, `timeout`, dialog stubs, but depends on `control_interface`/`wrangler`/JS.
3. **Fresh baseline (today, Niente, all 805 cases):** pass 496, skip 114, fail 24, error 83, no_result 86, not_run 2. **68 of the 83 errors are only `dom_html` missing** (webview-only helper). 272 of the 301 `html.include?(...)` checks in those cases test plain text. A `dom_html` shim that serialises the Lacci tree's visible text would flip most of them.
4. **The case corpus is weak.** Of 805 cases: 306 have real portable assertions; 180 are `skip` as first statement; 122 are only `assert true`; 73 only assert existence; 70 use `dom_html`; 43 are comments-only (pass vacuously); 7 skip conditionally; 4 have no assertions. 718 still carry the front-matter comment `# TODO: Add meaningful assertions`. Only **452 distinct app bodies** exist; 353 cases are duplicate app copies (every duplicate has *different* auto-generated test code).
5. **Examples:** 424 `.rb` files. Under Niente (6 s alarm) 351 load, 9 exit 0, 3 load with logged errors, 58 fail, 1 hangs (WEBrick), 2 not run by me. 35 of the 58 fails are `legacy/shoes3_only`, 10 are `bloopsaphone` (no `bloops` gem). Outside shoes3_only/needs_deps/path_issues/bloops, Lacci itself is nearly clean.
6. **Build order from usage** (% of the 350-example target set): `Shoes.app` 96.9, `para` 64.6, `width:` 46.0, `stack` 45.4, `height:` 36.3, `button` 31.7, named colors 28.3, app `width/height` 27.1, `background` 27.1, `margin:` 22.9, `flow` 20.3, app `title:` 18.0, `stroke:` 15.1, `.replace` 14.6, `top:`/`left:` 14.0/13.7, hex colors 13.4, `animate` 13.4, `.text` 13.1, `title` 12.3, `size:` 11.4, `fill` 10.9, `oval` 10.6, `edit_line` 9.1, `alert` 8.3, `stroke` 8.0, `image` 7.7, `rgb` 7.7, `link` 7.1.

---

## Part A. The spec machinery

### A1. Where things live

| concern | file (line) |
|---|---|
| Spec hook in Lacci (`Shoes::Spec`, `SpecInstance`, `SpecProxy` docs-only base classes) | `SC/lacci/lib/shoes-spec.rb:8-94` |
| Where test code is picked up | `SC/lacci/lib/shoes/app.rb:95-103` |
| Niente spec implementation | `SC/lacci/lib/scarpe/niente/shoes_spec.rb:8-180`, registered at `SC/lacci/lib/scarpe/niente.rb:24-25` |
| Webview spec implementation (+dialog stubs, CatsCradle) | `SC/lib/scarpe/shoes_spec.rb:16-497`, registered at `SC/lib/scarpe/wv.rb:83-92` |
| CatsCradle fiber scheduler | `SC/lib/scarpe/cats_cradle.rb:10-253` |
| `.sspec`/`.scas` loader | `SC/scarpe-components/lib/scarpe/components/segmented_file_loader.rb:5-184` |
| JSON result exporter (child process) | `SC/scarpe-components/lib/scarpe/components/minitest_export_reporter.rb:27-81` |
| JSON result importer (parent) | `SC/scarpe-components/lib/scarpe/components/minitest_result.rb:15-127` |
| Drawable finder logic | `SC/lacci/lib/shoes/app.rb:289-353` (`all_drawables`, `self.find_drawables_by`, `find_drawables_by`) |
| Scarpe's own test harnesses | `SC/test/test_helper.rb:31-167` (`ShoesSpecLoggedTest`), `SC/lacci/test/test_helper.rb:21-95` (`NienteTest`) |
| Shoes-Spec case discovery | `SS/lib/shoes-spec/test_list.rb:13-64` |
| Shoes-Spec results YAML + compare | `SS/lib/shoes-spec/report_results.rb:6-137` |
| Per-implementation runners | `SS/implementations/{niente,scarpe-webview,gtk-scarpe,space-shoes,scarpe-wasm}/*_runner.rb` |
| Nick's Feb-2026 whole-suite runner (webview) | `SS/lib/tasks/scarpe.rake` (`rake scarpe:all/summary/failing/category/categories`) |
| Feb-2026 batch runners (Niente) | `SS/run_batch{11..25}*.rb` (read `batches/batch_NN.txt`, which is **not in the repo**; `SHOES_SPEC_DIR` hard-coded to `~/Progrumms/shoes-spec`) |

### A2. The `.sspec` file format, precisely

Canonical shape (every one of the 805 cases in `SS/cases` has exactly this):

```
---
# optional YAML front matter (comments only in all 805 cases)
----------- app code
Shoes.app do
  ...
end
----------- test code
assert_equal "OK", button().text
```

Rules as implemented by `SegmentedFileLoader.front_matter_and_segments_from_file` (`segmented_file_loader.rb:75-117`):

- The whole file is split with `contents.split(/\n-{5,}/)`. **Any line in the app code that starts with 5+ dashes is treated as a divider.** (`vjot.sspec` has `----------` lines in a heredoc and parses into 5 segments; its "test code" becomes a fragment of app code. Two cases affected: `scarpe_examples/examples/legacy/for_playtest/simple/vjot.sspec`, `scarpe_examples/legacy/for_playtest/simple/vjot.sspec`.)
- First segment: if it starts with `"---\n"` or equals `"---"`, it is YAML front matter (`YAML.load`; `nil` becomes `{}`); otherwise if it starts with `-----` it is a normal segment; a file with no divider at all is one unnamed segment.
- Each following segment: `/\A-* +(.*?)\n/` gives a named segment (name = text after the dashes and a space, e.g. `"app code"`, `"test code"`); `/\A-* *\n/` gives an unnamed segment with generated name `"%5d" % n` (e.g. `"    1"`). Duplicate names raise.
- **Segment names are ignored for dispatch.** `file_load` (`:119-167`) uses position: if front matter has `:segments` (a *Symbol* key; `YAML.load("---\n:segments:\n- shoes\n- app_test\n")` works) its size must equal the segment count; otherwise 1 segment means `["shoes"]`, 2 means `["shoes", "app_test"]`, and more than 2 raises `Scarpe::FileContentError`.
- Handlers (`:174-182`): `"shoes"` → `after_load { load seg_file }` (the app is loaded after all segments are processed, from a tempfile); `"app_test"` → `ENV["SHOES_SPEC_TEST"] = seg_file` and `ENV["SHOES_MINITEST_EXPORT_FILE"] ||= "sspec.json"` (**relative to the cwd, which `Shoes.run_app` has already changed to the .sspec's directory**, `SC/lacci/lib/shoes.rb:205-226`).
- `call(path)` only claims files ending in `.scas` or `.sspec` (`:52-57`). Extra segment types can be registered with `add_segment_type(type, handler)`.
- The loader must be registered by the display service: `Shoes.add_file_loader Scarpe::Components::SegmentedFileLoader.new` (`SC/lib/scarpe/wv.rb:56-58`, `SC/lacci/lib/scarpe/niente.rb:27-29`). Loaders are prepended ahead of the default "load anything as Ruby" loader (`SC/lacci/lib/shoes.rb:228-244`).

**There is a second, different parser.** The Shoes-Spec harnesses (`SS/lib/tasks/scarpe.rake:231-240`, `SS/run_batch*.rb:16-27`, `SS/implementations/scarpe-webview/run_single.rb:7-9`) use `content.split(/^-{3,}\s*(app code|test code)\s*$/i)` and take `parts[2]` / `parts[4]`. That one keys on the segment *names*. The official per-implementation runners (`SS/implementations/*/..._runner.rb`) use `with_each_loaded_test` → `SegmentedFileLoader.front_matter_and_segments_from_file` → `segmap.values[0]`, `segmap.values[1]` (`SS/lib/shoes-spec/test_list.rb:51-64`). Both then write app and test code to *separate tempfiles* and run `scarpe --dev app_tempfile` with `SHOES_SPEC_TEST=test_tempfile`. They never run the `.sspec` file directly, so relative asset paths in app code resolve against the tempdir, not the example's folder.

Front matter actually present: all 805 start with `---`. 718 contain the comment lines `# Auto-imported from scarpe/<path>` and `# TODO: Add meaningful assertions` (generator: `SS/Rakefile` `generate_sspec`, and the placeholder test body `skip "TODO: Add assertions for <name>"`, though **no case still contains that literal skip**; they were rewritten in the Feb-2026 mass passes).

### A3. How a spec is executed

Env vars (all real, with where they are read):

| var | read at | meaning |
|---|---|---|
| `SCARPE_DISPLAY_SERVICE` | `SC/lib/scarpe.rb:11-14` | `require "scarpe/#{d_s}"`; default `wv_local`. `niente` → `SC/lacci/lib/scarpe/niente.rb`. A gem can supply `scarpe/<name>`. |
| `SHOES_SPEC_TEST` | `SC/lacci/lib/shoes/app.rb:97-101` | path to test code file; read once (`Shoes::App.set_test_code` guard); empty file = no test |
| `SHOES_MINITEST_EXPORT_FILE` | `minitest_export_reporter.rb:34-37` | JSON output path; `activate!` raises if unset |
| `SHOES_MINITEST_CLASS_NAME` | `niente/shoes_spec.rb:18`, `lib/scarpe/shoes_spec.rb:166` | Minitest class; default `TestShoesSpecCode`; passed through `StringHelpers.camelize` then `Object.const_set` |
| `SHOES_MINITEST_METHOD_NAME` | same files `:19` / `:167` | method; `"test_"` prefixed if missing; default `test_shoes_spec` |
| `SCARPE_SSPEC_TIMEOUT` | `lib/scarpe/shoes_spec.rb:174-175` | webview only; seconds (default `"30"`), `"none"` disables. Timeout just shuts down; it does not fail the test |
| `SCARPE_SSPEC_TIMEOUT_WAIT_AFTER_TEST` | `lib/scarpe/shoes_spec.rb:180-183` | webview only; `Y` = keep app alive after tests until the timeout |
| `SCARPE_HTML_RENDERER` | `SC/lib/scarpe/wv.rb:36-44` | webview only: `calzini` (default) or `tiranti` |
| `SCARPE_LOG_CONFIG`, `SCARPE_DEBUG` | `SC/lib/scarpe/wv.rb:47-54` | webview logging |
| `NIENTE_LOG_LEVEL` | `SC/lacci/lib/scarpe/niente.rb:11-18` | `debug/info/warn/error`. **Default is debug to stdout**: 6 s of Niente heartbeats wrote 345 MB in my probe. Always set `warn` or `error`. |
| `LOCALAPPDATA` / `APPDATA` / `HOME` | `SC/lacci/lib/shoes/constants.rb:6-24` | `LIB_DIR` = first existing of `$LOCALAPPDATA/Shoes`, `$APPDATA/Shoes`, `$HOME/.shoes`. Examples write there (e.g. `sample-data/simple-sqlite3.db`). Harnesses set `LOCALAPPDATA=Dir.tmpdir`. |
| `MINITEST_REPORTER` | set to `ShoesExportReporter` at `minitest_export_reporter.rb:4` | |

Sequence (Niente, which is the one to copy):

1. `exe/scarpe --dev app.rb` → `require "scarpe"` → `require "scarpe/niente"`, which sets `Shoes::Spec.instance = Niente::Test`, adds the segmented loader, `set_display_service_class(Niente::DisplayService)`, pushes `:multi_app` to `Shoes::FEATURES`.
2. `Shoes.run_app` chdirs to the app's dir, `load`s it. `Shoes.app` → `Shoes::App.new` → DocumentRoot + App display drawable created → **then** test code is registered (`app.rb:97-103`) → `app.init` runs the app block → `app.run` sends the `run` event.
3. `Niente::Test.run_shoes_spec_test_code` (`niente/shoes_spec.rb:9-35`): raises `Shoes::Errors::MultipleShoesSpecRunsError` if called twice; `Minitest::Reporters::ShoesExportReporter.activate!`; subscribes to the `"heartbeat"` Shoes event; builds `Class.new(Niente::ShoesSpecTest)`, `const_set`s it, `define_method(test_name) { eval(code, nil, filename, line) }`.
4. `Niente::App#run` (`niente/app.rb:16-29`) replies `send_shoes_event("return", event_name: "custom_event_loop")`, then registers `at_exit { until @do_shutdown; Shoes::DisplayService.dispatch_event("heartbeat", nil); end }`. That is a busy loop at 100% CPU.
5. First heartbeat: `Minitest.run []` (synchronously, all assertions run now), then `Shoes.APPS.each(&:destroy)`, which ends the loop; the reporter writes JSON; the process exits 0 even when the test failed.

Consequences: **test code runs after the app block completed and before any timer, animation, download callback or display-side event fired.** Under Niente, `animate`/`every`/`timer` never fire at all (nothing dispatches those events), and `download` callbacks run later on a background `Thread` (`SC/lacci/lib/shoes/download.rb:37`).

Webview differs (`lib/scarpe/shoes_spec.rb:150-194`): installs dialog stubs (prepends `Scarpe::DialogStubsInterceptor` to `Shoes::Builtins`), includes `Scarpe::ShoesSpecTest` into `Scarpe::CCInstance`, calls `event_init`, arms `timeout`, and runs `Minitest.run ARGV` inside a CatsCradle fiber `on_event(:next_heartbeat)`, then `shut_down_shoes_code` (dispatches `destroy`). Heartbeat is 0.1 s (`SC/lib/scarpe/wv/web_wrangler.rb:68`).

The official Shoes-Spec Niente runner (`SS/implementations/niente/scarpe_niente_runner.rb:17-33`) sets `SHOES_MINITEST_CLASS_NAME = category.gsub("/", "_")`. **Categories containing `-` (e.g. `scarpe_examples/legacy/for_playtest/shoes-contrib/app`) produce `ScarpeExamples...Shoes-contribApp`, and `Object.const_set` raises `NameError: wrong constant name`**, so the case errors before any test runs. `SS/lib/tasks/scarpe.rake:290-291` does `.gsub("-", "_")` on both names; do the same.

### A4. Result formats

Child writes (`minitest_export_reporter.rb:56-80`) a JSON **array** of one object per test:

```json
[{"name":"test_basic_click","klass":"DrawablesButton","assertions":2,
  "failures":[["exception","{\"json_class\":\"Minitest::Assertion\",\"m\":\"Expected ...\",\"b\":[...]}"],
              ["unexpected","{\"json_class\":\"Minitest::UnexpectedError\",\"m\":\"NoMethodError: ...\"}","{...inner error json...}"]],
  "time":0.001,"metadata":{},"exporter_metadata":{},"source_location":["...",1]}]
```

`failures[i][0]` is `"exception"` (Assertion or Skip) or `"unexpected"` (UnexpectedError). Classify on `JSON.parse(failures[i][1])["json_class"]`: `Minitest::UnexpectedError` → error, `Minitest::Assertion` → fail, `Minitest::Skip` → skip (`minitest_result.rb:40-56`). `MinitestResult.new(file)` raises unless the array has exactly 1 element. `check(expect_result:, min_asserts:, max_asserts:)` returns `[bool, msg]`.

**The `run_batch1{2..25}*.rb` scripts mis-classify.** They test `failures.first[0] == "skip"` / `"pending_implementation"`, which never occurs, so every Skip is counted as `fail`. Their per-batch fail counts are inflated by skips. `rake scarpe:*` classifies correctly but pre-empts skips textually: `test_code =~ /^\s*skip\s+["'](.+?)["']/` → status `skip` without running the app (`scarpe.rake:242-247`). So in its numbers a skip-placeholder whose app would crash still counts as `skip`.

Parent side, Shoes-Spec proper: `ShoesSpec::ReportResults#report(result, test_name:, category:)` with `result` in `[:pass, :fail, :skip, :error]`, `#complete` writes `SS/results/<display>/results-<config>.yaml` shaped `{display:, config:, results: {category => {test_name => :pass}}}`, and `compare_results(display:, config:)` diffs against `SS/results/<display>/expected/results-<config>.yaml`. `compare_vs_perfect` diffs against `SS/results/ideal/results-perfect.yaml`. The expected/ideal YAMLs cover only the 18 hand-written cases (see A8).

### A5. The test API available inside test code

Test code is `eval`ed inside a `Minitest::Test` subclass instance, so **every Minitest assertion is available** (`assert`, `assert_equal`, `assert_includes`, `assert_match`, `assert_nil`, `refute*`, `assert_raises`, `skip`, `flunk`, ...). Webview additionally mixes in `Scarpe::Test::HTMLAssertions#assert_html(actual_html, expected_tag, **opts, &block)` and `#assert_contains_html` (`SC/scarpe-components/lib/scarpe/components/unit_test_helpers.rb:221-252`).

Finders (identical in Niente `niente/shoes_spec.rb:54-145` and Webview `lib/scarpe/shoes_spec.rb:272-372`, generated at class-body time from `Shoes::Drawable.drawable_classes`):

- Singular `<dsl_name>(*specs)` for every drawable class: raises `Shoes::Errors::MultipleDrawablesFoundError` if >1 match, `Shoes::Errors::NoDrawablesFoundError` if 0, else returns a proxy. The generated names (today): `app stack flow mask document_root text code del em strong span sub sup ins subscription_item arc line rect shape star oval arrow button check edit_box edit_line image link link_hover list_box para radio video progress border background`. `dsl_name` = class basename minus `Drawable`, snake-cased (`SC/lacci/lib/shoes/drawable.rb:40-43`). Any new Lacci drawable class gets a finder for free, but only if it exists when the spec module's class body runs (at `require` time, before app code loads). A `Shoes::Widget` subclass defined in the app gets no named finder; use `drawable(MyWidget)`.
- Plural: `pluralize_dsl_name` adds `es` after `box`/`ss`, else `s`: `buttons`, `paras`, `edit_boxes`, `list_boxes`, `progresses`, `stacks`, ... returns `[]` when nothing matches.
- `title banner caption subtitle tagline inscription` (no args) and plurals `titles banners ...`: filter `Shoes::Para` by `d.size == :title` etc. (Lacci creates these as `Para` with `size:`).
- `drawable(*specs)` / `drawables(*specs)` / `find_all(*specs)` (= `drawables`).
- `find_button(text)` matches `Shoes::Button#text ==`.
- Aliases `all_ovals all_rects all_buttons all_paras`.
- **Selector grammar** (`find_drawables_by`, `app.rb:312-353`), applied as successive filters: a `Class` (`===`); `Shoes::App`; a String/Symbol starting with `$` (global var, via `eval`) or `@` (instance var of the **app**; locals like `p = para` in the app block are not findable); `"id:<Integer>"` via `Shoes::Drawable.drawable_by_id`. **Anything else raises `Shoes::Errors::InvalidAttributeValueError, "Don't know how to find drawables by ..."`.** Text selectors (`button("Save")`) and hash selectors (`edit_line(text: "...")`) are not supported; 6 cases still error on exactly this today.
- Niente searches all apps (`Shoes::App.find_drawables_by` = `Shoes.APPS.flat_map`); Webview uses `Shoes.APPS[0]` only.

Proxy (`Niente::ShoesSpecProxy`, `niente/shoes_spec.rb:148-180`; `Scarpe::ShoesSpecProxy`, `lib/scarpe/shoes_spec.rb:208-250`):

- `attr_reader :obj, :linkable_id, :display`; `display` = `Shoes::DisplayService.display_service.query_display_drawable_for(obj.linkable_id)` (Webview raises if missing).
- `method_missing` forwards anything the Lacci drawable `respond_to?`s, defining a singleton method on first use. So `.text`, `.text=`, `.checked?`, `.checked=`, `.items`, `.chosen`, `.fraction`, `.style`, `.replace(...)`, `.width`, `.hidden`, `.contents`, `.parent`, `.show/.hide/.toggle/.move/.remove` are just Lacci. Relevant Lacci accessors: `Para#text` (`para.rb:145`, concatenated text items), `Button`/`EditLine`/`EditBox`/`Link` `shoes_styles :text`, `EditLine#text=`/`EditBox#text=` fire the change block (`edit_line.rb:30`), `ListBox#text` = chosen (`list_box.rb:46`), `shoes_style :chosen`, `Check#checked?` (`check.rb:25`), `Radio#checked?` (`radio.rb:45`), `Progress shoes_styles :fraction`, `Image shoes_styles :url`.
- Triggers. **Niente:** `trigger_click`, `trigger_hover`, `trigger_leave` only (`JS_EVENTS = [:click, :hover, :leave]`), each `Shoes::DisplayService.dispatch_event(event.to_s, @linkable_id, *args, **kwargs)`, i.e. it fires the Lacci-side Shoes event directly. **No `trigger_change` in Niente** (NoMethodError). **Webview:** `trigger_click/hover/leave/change(*args)` → `Scarpe::Webview::DisplayService.instance.app.handle_callback("#{linkable_id}-#{event}", *args)`, i.e. through the display drawable's registered JS callback. GTK: `trigger_click/hover/leave/motion` → `@display.trigger(name, *args)`; `change` raises "Implement me".
- Lacci handlers the triggers reach (`bind_self_event(name)` = `bind_shoes_event(event_name:, target: linkable_id)`, `drawable.rb:481-487`): Button `"click"` (no args) `button.rb:42`; Check `"click"` toggles `checked` `check.rb:14`; Radio `"click"` unchecks group and checks self `radio.rb:27`; Link `"click"` `link.rb:24`; ListBox `"change"(new_item)` sets `chosen` `list_box.rb:23`; EditLine/EditBox `"change"(new_text)` sets text and calls block `edit_line.rb:15`, `edit_box.rb:15`; every drawable `"hover"`, `"leave"`, `"motion"(x, y)` `drawable.rb:416-424`; `SubscriptionItem` (`animate`/`every`/`timer`/`click`/`release`/`keypress`/`wheel`/`motion`/`hover`/`leave`) `subscription_item.rb:19-80`, with `animate(frame)`, `every(count)`, `timer()`, `click(button, x, y)`, `keypress(key)` where `":left"` becomes `:left`.

Webview-only extras (in `Scarpe::ShoesSpecTest`, `lib/scarpe/shoes_spec.rb:383-496`): `wait(seconds)`, `catscradle_dsl(&blk)`, `dom_html` (waits `fully_updated`, then JS `document.getElementById('wrapper-wvroot').innerHTML`), `timeout(t = 5.0)`, `exit_on_first_heartbeat`, `stub_alert`, `stub_ask(returns: "")`, `stub_confirm(returns: true)`, `stub_ask_color(returns: "#000000")`, `stub_ask_open_file(returns: nil)`, `stub_ask_save_file(returns: nil)`, `stub_ask_open_folder(returns: nil)`, `stub_ask_save_folder(returns: nil)`, `reset_dialog_stubs`.

Usage across the 805 cases' test code (comments stripped): `assert` 413 files, `assert_equal` 263, `para` 206, `skip` 187, `.text` 283, `button` 132, `dom_html` 70, `assert_includes` 59, `stack` 52, `.trigger_click` 39, `image` 31, `title` 29, `edit_line` 23, `edit_box` 21, `.find_drawables_by` 20, `drawable` 15, `list_box` 15, `radio` 15, `refute_nil` 14, `check` 10, `.checked?` 7, `.items` 7, `find_button` 3, `stub_alert`/`stub_ask`/`stub_confirm` 1 each, `wait` 1, `.trigger_hover` 1, `drawables` 1. `trigger_change` 0 (it is used in `SC/test/test_list_box.rb`).

### A6. Timing and waiting

- **Webview:** everything test-side is sequenced by CatsCradle (`cats_cradle.rb`). `CCInstance` holds a manager fiber and `@waiting_fibers` of `{promise:, fiber:, on_event:, block:}`. `on_event(:next_heartbeat | :every_heartbeat | :next_redraw | :every_redraw | :init, &blk)` queues a fiber; `event_init` hooks `control_interface.on_event(:every_heartbeat)` and `(:every_redraw)` to fulfil promises and `@manager_fiber.resume`. Inside a CC fiber, `wait(promise)` does `@manager_fiber.transfer(promise)`, so the test fiber sleeps until the promise is fulfilled. `timed_promise(seconds)` is fulfilled by the first heartbeat after the deadline (`:95-102`), so `wait 0.5` has 0.1 s heartbeat granularity. `fully_updated` = `@wrangler.promise_dom_fully_updated`. `shut_down_shoes_code` dispatches `destroy`, and calling it twice `exit 0`s.
- **Niente:** no waiting at all; `Minitest.run` is synchronous inside the first heartbeat handler. Animation-dependent assertions (e.g. `Expected "STARTING" to include "FRAME"`) fail.
- **Recommendation for a Rust service:** keep Niente's synchronous model (deterministic, 0.5 s per case) and add *virtual time*: `advance_frames(n)` / `trigger_animate(frame)` on `subscription_item(...)` proxies dispatch `"animate"`/`"every"`/`"timer"` Shoes events directly. That makes animations testable without sleeping. Offer `wait(seconds)` for real-time tests that pumps the native event loop.

### A7. What a new display service must implement to run Shoes-Spec

Minimum (mirrors Niente, which passes every curated case today):

1. A requirable `scarpe/<name>.rb` (from `SC/lib` or a gem) that `lib/scarpe.rb` loads via `SCARPE_DISPLAY_SERVICE=<name>`, or its own executable (GTK: `gtk-scarpe --dev`).
2. `Shoes.add_file_loader Scarpe::Components::SegmentedFileLoader.new`.
3. `Shoes::Spec.instance = <obj>` where `obj.run_shoes_spec_test_code(code, class_name: nil, test_name: nil, filename: "(eval)", line: 1)` exists. **It must accept `filename:` and `line:`**: Lacci passes them (`app.rb:101`); GTK's older signature `(code, class_name: nil, test_name: nil)` would raise `ArgumentError`. Only one spec per process (`Shoes::Errors::MultipleShoesSpecRunsError`).
4. In that method: `require "scarpe/components/minitest_export_reporter"; Minitest::Reporters::ShoesExportReporter.activate!`; build and `const_set` the test class (camelized `SHOES_MINITEST_CLASS_NAME`), `define_method("test_" + name) { eval(code, nil, filename, line) }`; schedule `Minitest.run []` **after** the app block has run and the first frame is up (Niente: first `"heartbeat"` Shoes event; GTK: `App.instance.on_post_init`); then destroy all apps so the process exits.
5. Finders and a proxy as in A5 (copy `Niente::ShoesSpecTest` and `Niente::ShoesSpecProxy` wholesale, adding `trigger_change(value)` → `dispatch_event("change", linkable_id, value)`, `trigger_motion(x, y)`, `trigger_release`, `trigger_keypress(key)`, and the `subscription_item` triggers above).
6. **Emit `"heartbeat"` Shoes events** (`Shoes::DisplayService.dispatch_event("heartbeat", nil)`) from the native event loop, or the Niente-style trigger never fires.
7. **Answer `"builtin"` events** (`SC/lacci/lib/shoes/builtins.rb:66-75`): subscribe to `"builtin"` with args `(cmd_name, args)` and call `Shoes::DisplayService.set_builtin_response(value)` synchronously. If the response stays `nil`, Lacci falls back to **real macOS `osascript` dialogs** for `ask`, `confirm`, `ask_open_file`, `ask_save_file`, `ask_open_folder`, `ask_save_folder` (`builtins.rb:79-105`), and the test process blocks until a human clicks. Under test, the service must answer every builtin with a stub value. Note that `ask` returning `nil` (Cancel) also triggers the fallback.

Recommended on top (to lift today's numbers):

- `dom_html` shim returning a serialisation of the Lacci tree (visible text of every `Para`/`Button`/`EditLine`/`EditBox`/`ListBox`/`Link`, optionally tag-ish markers and colours). This alone would convert most of the 68 dom_html-only errors (272 of 301 `html.include?` checks look for plain text).
- `stub_alert/stub_ask/stub_confirm/...` with the same signatures as Webview (3 cases use them).
- Text selectors: accept `button("Save")` / `para("...")` as text match instead of raising (6 cases).
- A native-level trigger mode (`trigger_click` synthesises a click on the Rust widget and lets it round-trip) alongside the direct-dispatch mode, so specs can verify both Lacci logic (fast) and the wiring (real).
- Rename-safe class names: `gsub(/[^A-Za-z0-9_]/, "_")` before camelize.

### A8. Results as recorded, and a fresh baseline

**Recorded expectations** (only the 18 hand-written cases): `SS/results/ideal/results-perfect.yaml` wants all pass except `test_code/assertions/fail: :fail`, `.../skip: :skip`, and the three `test_code/exceptions/*: :error`. `SS/results/niente/expected/results-local.yaml` records `legacy_examples/misc/speedometer_app` and `superleg` as `:error`, everything else ideal. gtk-scarpe expected: `dsl/app/add_drawables`, `legacy_examples/simple/{calc,image}`, `legacy_examples/misc/*` error. space-shoes expected: 9 cases pass.

**`SS/results/scarpe-suite/results.json`** (webview `wv_local` + calzini via `rake scarpe:all`, timestamp 2026-02-19 12:09:39, 800.6 s, 801 specs): pass 494, skip 187, fail 89, error 31. Top reasons: `InvalidAttributeValueError` 48 (text selectors), "No result file produced" 31, `MultipleDrawablesFoundError` 11, `NoDrawablesFoundError` 11, `ArgumentError` 6. Commits after that run fixed selectors and assertions in the case files (`966c36b`, `e6d3d9b`, `18c2db4`), so it is stale.

**Batch JSONs** (`SS/implementations/niente/batch_{11,15,16,18,19,20,21,22}_results.json`, `SS/results/batch{12,_23,_24,_25}_results.json`, 29 cases each, Niente, Feb 2026): e.g. batch_25 pass 9 / fail 16 / error 1; batch_16 29/29 pass. They predate the `assert_include` → `assert_includes` fix (`599cc1e`) and count skips as fails (A4), so treat them as history only. `SS/results/batch_04_results.yaml`: 29 × pass, 1-2 assertions each.

**Fresh run, today, all 805 cases, Niente, scarpe-native `fdcee7a`** (`tools/sspec_niente.rb`; emulates the official Niente runner but with `-` stripped from class names, a 20 s alarm, stubbed `osascript`; 0.52 s mean per case, 417 CPU-seconds total):

| status | count | by test-body kind |
|---|---|---|
| pass | 496 | real asserts 340, `assert true` only 113, comments-only 43 |
| skip | 114 | skip-first 109, asserts 5 |
| fail | 24 | all real-assert cases |
| error | 83 | `dom_html` 68, other 15 |
| no_result (process ended with no JSON) | 86 | skip-first 71 (app crashes before `Shoes.app`, so the skip never runs), `assert true` 9, asserts 5, dom_html 1 |
| not_run (side effects outside sandbox) | 2 | `selfitude`, `bronx_army_knife` |

Transition from the Feb webview run to today's Niente run (same case path): pass→pass 416, skip→skip 114, pass→error 74 (mostly `dom_html`), skip→error 73 (textual skip pre-emption vs actually running), fail→pass 61 (case fixes since), fail→fail 21, error→pass 15, error→error 15, fail→error 7, pass→fail 3.

The 11 `no_result` cases with an empty message are scripts with **no `Shoes.app` call** (`builtins/debug.rb`, `info.rb`, `FONTS.rb`, `kernel/font.rb`, `feepogram.rb`). Test code is only hooked from `Shoes::App#initialize`, so no app means no test and no JSON.

Curated conformance set, today (Niente now equals ideal on all 18 ideal-covered cases; the 6 check/radio cases have no expectation recorded):

| case | ideal | niente expected (Feb) | niente today |
|---|---|---|---|
| drawables/button/basic_click | pass | pass | pass |
| drawables/button/button_events | pass | pass | pass |
| drawables/check/check_default_value | (none) | (none) | pass |
| drawables/check/check_initial_value | (none) | (none) | pass |
| drawables/para/para_replace | pass | pass | pass |
| drawables/radio/radio_click_callback | (none) | (none) | pass |
| drawables/radio/radio_default_value | (none) | (none) | pass |
| drawables/radio/radio_group_switching | (none) | (none) | pass |
| drawables/radio/radio_separate_groups | (none) | (none) | pass |
| dsl/app/add_drawables | pass | pass | pass |
| dsl/slot/self_slot | pass | pass | pass |
| legacy_examples/misc/speedometer_app | pass | error | pass |
| legacy_examples/misc/superleg | pass | error | pass |
| legacy_examples/simple/calc | pass | pass | pass |
| legacy_examples/simple/image | pass | pass | pass |
| manual/examples/example_1 | pass | pass | pass |
| test_code/assertions/fail | fail | fail | fail |
| test_code/assertions/pass | pass | pass | pass |
| test_code/assertions/skip | skip | skip | skip |
| test_code/exceptions/raise_before_shoes_app | error | error | error |
| test_code/exceptions/raise_in_shoes_app | error | error | error |
| test_code/exceptions/raise_in_test_code | error | error | error |


Every fail and every non-`dom_html` error, today, under Niente (`se/` = `scarpe_examples/`):

| case | status | message |
|---|---|---|
| se/examples/legacy/for_playtest/expert/tooltips.sspec | error | Shoes::Errors::InvalidAttributeValueError: Don't know how to find drawables by "Demonstrates how to write tool tips"! |
| se/examples/legacy/for_playtest/expert/url.sspec | fail | Should show welcome message on root |
| se/examples/legacy/for_playtest/good/plots.sspec | error | NoMethodError: undefined method 'plot' for an instance of Shoes::App |
| se/examples/legacy/for_playtest/philippe/ask_confirm_demo.sspec | error | Shoes::Errors::InvalidAttributeValueError: Don't know how to find drawables by "ask()"! |
| se/examples/legacy/for_playtest/philippe/guessing_game.sspec | error | Shoes::Errors::InvalidAttributeValueError: Don't know how to find drawables by "Make a guess!"! |
| se/examples/legacy/for_playtest/philippe/hh_patterns_test.sspec | error | Shoes::Errors::InvalidAttributeValueError: Don't know how to find drawables by "Show Tab 1"! |
| se/examples/legacy/for_playtest/philippe/shape_curves.sspec | error | ArgumentError: wrong number of arguments (given 1, expected 0) |
| se/examples/legacy/for_playtest/shoes-contrib/animation/rotating-star.sspec | error | Shoes::Errors::NoDrawablesFoundError: Found no star matching []! |
| se/examples/legacy/for_playtest/shoes-contrib/app/download-and-save.sspec | fail | Should have a title |
| se/examples/legacy/for_playtest/shoes-contrib/app/download.sspec | fail | Should have a title |
| se/examples/legacy/for_playtest/shoes-contrib/app/get-google.sspec | fail | Should have a title |
| se/examples/legacy/for_playtest/shoes-contrib/app/mouse-detection.sspec | fail | Para should display mouse info |
| se/examples/legacy/for_playtest/shoes-contrib/basic/basic-oval-image.sspec | fail | Should have 300 ovals inside image. |
| se/examples/legacy/for_playtest/shoes-contrib/simple/simple-dialogs.sspec | error | Shoes::Errors::MultipleDrawablesFoundError: Found more than one button matching []! |
| se/examples/legacy/for_playtest/simple/clock.sspec | fail | Clock should have time display para |
| se/examples/legacy/for_playtest/simple/form.sspec | error | Shoes::Errors::InvalidAttributeValueError: Don't know how to find drawables by "Save"! |
| se/examples/legacy/for_playtest/speedometer_app.sspec | error | Shoes::Errors::InvalidAttributeValueError: Don't know how to find drawables by {text: "Enter a number between 0 and 100"}! |
| se/examples/page_navigation_single_app.sspec | fail | Home page should have welcome text. |
| se/examples/shoes_school.sspec | error | Shoes::Errors::MultipleDrawablesFoundError: Found more than one para matching []! |
| se/examples/shoes_splorer.sspec | fail | Expected code elements showing method names |
| se/legacy/for_playtest/shoes-contrib/basic/shoes-notes.sspec | fail | Expected "Shoes Notebook" to include "Add a note.". |
| se/legacy/for_playtest/shoes-contrib/basic/two-column.sspec | fail | Expected "Column one" to include "200 pixels wide". |
| se/legacy/for_playtest/shoes-contrib/elements/common-styles.sspec | fail | Should have a banner |
| se/legacy/for_playtest/shoes3-tests/curl/m1.sspec | fail | Should have a title |
| se/legacy/for_playtest/shoes3-tests/curl/m2.sspec | fail | Should have a title |
| se/legacy/for_playtest/shoes3-tests/curl/m3.sspec | fail | Should have a title |
| se/legacy/for_playtest/shoes3-tests/dialogs/ask.sspec | error | NoMethodError: undefined method 'stub_ask' for an instance of ScarpeExamplesLegacyForPlaytestShoes3TestsDialogs |
| se/legacy/for_playtest/shoes3-tests/dialogs/confirm.sspec | error | NoMethodError: undefined method 'stub_confirm' for an instance of ScarpeExamplesLegacyForPlaytestShoes3TestsDialogs |
| se/legacy/for_playtest/shoes3-tests/opacity_test.sspec | fail | Expected "App Opacity Demo" to include "Click buttons to change window opacity". |
| se/legacy/for_playtest/shoes3-tests/radio/multiple.sspec | fail | --- expected |
| se/legacy/for_playtest/shoes_manual/alert_button.sspec | error | NameError: undefined local variable or method 'stub_alert' for an instance of ScarpeExamplesLegacyForPlaytestShoesManual |
| se/legacy/for_playtest/shoes_manual/animate.sspec | fail | Expected "STARTING" to include "FRAME". |
| se/legacy/for_playtest/simple/clock.sspec | fail | Time para should exist |
| se/legacy/for_playtest/simple/path-animation.sspec | fail | Should have at least the starting oval |
| se/legacy/working/philippe/guessing_game.sspec | fail | --- expected |
| se/legacy/working/shoes_manual/save_download.sspec | fail | Expected "Downloading Google image" to include "One moment". |
| se/legacy/working/simple/clock.sspec | fail | Para should exist with time display |
| test_code/assertions/fail.sspec | fail | Expected true to not be truthy. |
| test_code/exceptions/raise_in_test_code.sspec | error | NameError: undefined local variable or method 'raise_exception_in_test_code' for an instance of TestCodeExceptions |


Readings: `Should have a title` (download*, get-google, curl/m*) and `clock`/`animate`/`path-animation` depend on callbacks Niente never fires; `radio/multiple` and `guessing_game` show `--- expected` diffs; the `InvalidAttributeValueError`/`Multiple`/`NoDrawables` errors are spec-authoring bugs.

### A9. Corpus shape (what "consolidate" has to work with)

`SS/cases` directories: `drawables/` 9 hand-written (button 2, check 2, para 1, radio 4) + `NATIVE.md` (cNative method list); `dsl/` 2; `manual/examples/example_1.sspec` (the only manual-derived case; its test is `button().trigger_click` + a TODO about verifying the alert); `test_code/` 6 (harness self-tests); `legacy_examples/` 4 `.sspec` + 152 raw `.rb` (not run by anything); `shoes3_tests/` 67 raw Shoes3 `.rb` + assets, 0 `.sspec`; `scarpe_examples/` 783 auto-imported (`examples/` 480 mirroring `SC/examples/**`, `legacy/` 303 re-importing `examples/legacy/{working,for_playtest}` a second time).

Test-body strength across all 805 (comments stripped): real portable asserts 306; `skip` first 180; only `assert true` 122; existence-only asserts (`assert obj`, `refute_nil`) 73; uses `dom_html` 70; comments-only 43; conditional skip 7; no assertion 4.

Duplication: 452 distinct app bodies. 245 app bodies appear more than once (353 extra copies), and in all 245 the copies carry different test code, because the two import passes generated tests independently. 3 current examples have no case (`legacy/working/custom-list-box`, `info`, `superleg`: they were in `needs_deps` at import time and moved later); 59 cases point to example paths that have since moved (mostly `for_playtest` → `working`).

The manual (`SC/docs/static/manual.md`, 3,533 lines) has 92 fenced ```ruby blocks, 78 lines with `Shoes.app`; only one became a case. (The manual itself is another lane.)

---

## Part B. The examples

### B1. Layout and recorded status

424 `.rb` under `SC/examples` (plus 5 README.md, 4 yaml, 2 png, 2 db, 2 csv, 1 svg, 1 mp4, 1 gif). Counts by category (see Part C table). Status is recorded only by folder plus READMEs:

- `legacy/README.md`: legacy examples are "not modified"; "the ones marked working have to at least boot up". It still mentions a `not_checked` dir that no longer exists (and `SC/tasks/test_legacy_examples.rb:13` still points at `examples/legacy/not_checked`, so that task is dead).
- `legacy/for_playtest/README.md`: "Run without errors (agent verified); Need human playtesting before moving to `working/`", with a 4-item checklist (visual, interactions, window sizing, console errors).
- `legacy/needs_deps/README.md`: `expert-funnies.rb` (hpricot, dead), `expert-irb.rb` (irb `set_input` removed in Ruby 3.x), `simple-rubygems.rb` (`Shoes.setup` installs bluecloth). Notes that `info.rb`, `custom-list-box.rb`, `superleg.rb` were fixed by adding `bigdecimal`, `observer`, `csv` gems and moved to `working/`.
- `legacy/shoes3_only/README.md`: plot, systray, terminal, menus, gapp (`Shoes.settings`), events (ShoeEvent), switch, cache, curl (typhoeus), spinner, svg/tests_svg, video_vlc/tests_video_vlc, decoration (`app.decorated=`), tests_color (`Shoes.terminal`), video-player, cardflip (svghandle), simple-chipmunk. "will NOT be implemented in Scarpe".
- `legacy/path_issues/README.md`: `_why-stories.rb` needs `#{DIR}/samples/good/_why-stories.yaml`.
- `SC/test/test_examples.rb` runs every `examples/**/*.rb` except `/not_checked/` and `/bloopsaphone/` (and `/skip_ci/` when `CI_RUN`) under `wv_local` + calzini with `exit_immediately: true`. That checks boot only.
- `SC/docs/scarpe_shoes_incompatibilities.md` lists unsupported Shoes3 widgets and APIs and behavioural differences (scripts without `Shoes.app`, method definition order, widget positioning, `ask()` cancel, pre-app dialogs). `SC/docs/SCARPE_FEATURES.md` lists Scarpe-only additions (e.g. `page(:name)` + `visit(:name)`).

Each inventory row's `status_note` concatenates: the folder note, any README line for that file, the matching `.sspec` case path and its test kind (skip reason / asserts / dom_html / trivial), the Feb-2026 webview result, today's Niente load result, and today's Niente `.sspec` result.

### B2. How `examples_inventory.json` was derived (so you know its error bars)

`tools/inventory.rb` strips comments and string literals, then:
- **bare DSL calls**: word not preceded by `.`, `:`, `@`, `$`, word char; not followed by `name:` (hash key) or `=` (assignment). If the file also uses the word as a local variable or block param (e.g. `|line|`), it only counts call syntax (`line(`, `line 10, ...`, `line do`, `line {`).
- **dot calls**: `.replace`, `.text`, `.click`, `.checked?`, `.move`, ...
- **`style:<key>`**: `key: value` or `:key => value` for known Shoes style keys (margin, width, height, top, left, stroke, fill, font, size, align, curve, radius, ...).
- specials: `Shoes.app`, `Shoes.url`, `Shoes::Widget`, `class X < Shoes`, `Shoes.setup/terminal/settings/show_log`, `app opts: title|width/height|resizable`, `multi Shoes.app`, `named_color` (any of Lacci's 139 color names used as a bareword or call), `hex_color_string`, `color_range(..)` (gradient via `a..b`), `self-hash style :key => v` (Ruby 1.8 hash syntax).
- **needs**: `network` (an http(s) URL literal in non-comment code; often just a `link` target), `network:download`, `network:net_http`, `remote_image`, `asset:<basename>` (quoted local media/data file; `(missing?)` if not found relative to the example), `asset:__dir__-relative`, `gem:<name>` (non-stdlib `require`), `gem:<name>(Shoes.setup)`, `require_relative:<x>`, `dialog`, `timer/animation`, `audio`, `video`, `shell`, `file_write`, `stdin/readline`, `shoes3_only_widget`, `no_shoes_app_call`.

Spot checks against source (6 files) matched. Known limits: heredoc text is not stripped; `named_color` may over-count single-word colors used as method names; `network` over-counts.

### B3. Frequency table (what to build first)

"Target set" = the 350 examples that load under Niente, excluding `shoes3_only`, `needs_deps`, `path_issues`. Full 208-row table in `freq_table.md`. Top rows:

| feature | examples (all 424) | target set (350) | % of target |
|---|---|---|---|
| `Shoes.app` | 402 | 339 | 96.9% |
| `para` | 277 | 226 | 64.6% |
| `style:width` | 203 | 161 | 46.0% |
| `stack` | 207 | 159 | 45.4% |
| `style:height` | 162 | 127 | 36.3% |
| `self-hash style :key => v` | 134 | 126 | 36.0% |
| `button` | 160 | 111 | 31.7% |
| `named_color` | 119 | 99 | 28.3% |
| `app opts: width/height` | 119 | 95 | 27.1% |
| `background` | 106 | 95 | 27.1% |
| `style:margin` | 91 | 80 | 22.9% |
| `flow` | 108 | 71 | 20.3% |
| `style:title` | 94 | 66 | 18.9% |
| `app opts: title` | 69 | 63 | 18.0% |
| `style:stroke` | 59 | 53 | 15.1% |
| `.replace` | 56 | 51 | 14.6% |
| `style:top` | 51 | 49 | 14.0% |
| `style:left` | 51 | 48 | 13.7% |
| `hex_color_string` | 52 | 47 | 13.4% |
| `animate` | 51 | 47 | 13.4% |
| `.text` | 61 | 46 | 13.1% |
| `title` | 45 | 43 | 12.3% |
| `style:size` | 45 | 40 | 11.4% |
| `fill` | 40 | 38 | 10.9% |
| `oval` | 40 | 37 | 10.6% |
| `edit_line` | 43 | 32 | 9.1% |
| `alert` | 34 | 29 | 8.3% |
| `stroke` | 30 | 28 | 8.0% |
| `image` | 34 | 27 | 7.7% |
| `rgb` | 31 | 27 | 7.7% |
| `link` | 27 | 25 | 7.1% |
| `style:font` | 34 | 23 | 6.6% |
| `.width` | 26 | 22 | 6.3% |
| `.click` | 25 | 21 | 6.0% |
| `.height` | 23 | 20 | 5.7% |
| `.clear` | 25 | 19 | 5.4% |
| `style:fill` | 24 | 19 | 5.4% |
| `style:resizable` | 22 | 19 | 5.4% |
| `download` | 20 | 19 | 5.4% |
| `edit_box` | 29 | 18 | 5.1% |
| `click` | 24 | 18 | 5.1% |
| `strong` | 22 | 18 | 5.1% |
| `strokewidth` | 20 | 18 | 5.1% |
| `list_box` | 19 | 18 | 5.1% |
| `.append` | 31 | 16 | 4.6% |
| `style:align` | 21 | 16 | 4.6% |
| `style:items` | 17 | 16 | 4.6% |
| `style:strokewidth` | 24 | 15 | 4.3% |
| `app opts: resizable` | 18 | 15 | 4.3% |
| `rect` | 17 | 15 | 4.3% |
| `color_range(..)` | 16 | 14 | 4.0% |
| `line` | 15 | 14 | 4.0% |
| `clear` | 14 | 14 | 4.0% |
| `style:underline` | 15 | 13 | 3.7% |
| `motion` | 14 | 13 | 3.7% |
| `style:radius` | 14 | 13 | 3.7% |
| `shape` | 13 | 13 | 3.7% |
| `.move` | 17 | 12 | 3.4% |
| `.style` | 16 | 12 | 3.4% |
| `caption` | 15 | 12 | 3.4% |
| `border` | 14 | 12 | 3.4% |
| `style:curve` | 14 | 12 | 3.4% |
| `.hide` | 13 | 12 | 3.4% |
| `radio` | 13 | 12 | 3.4% |
| `style` | 13 | 10 | 2.9% |
| `banner` | 12 | 10 | 2.9% |
| `hover` | 12 | 10 | 2.9% |
| `style:margin_top` | 12 | 10 | 2.9% |
| `.show` | 11 | 10 | 2.9% |
| `.stop` | 17 | 9 | 2.6% |
| `confirm` | 12 | 9 | 2.6% |
| `nofill` | 11 | 9 | 2.6% |
| `nostroke` | 10 | 9 | 2.6% |


Tail worth knowing (target-set counts): `radio` 12, `caption` 12, `border` 12, `.hide` 12, `.move` 12, `banner` 10, `hover` 10, `.show` 10, `confirm` 9, `nofill` 9, `nostroke` 9, `star` 9, `keypress` 8, `span` 8, `Shoes::Widget` 8, `progress` 8, `inscription` 8, `visit` 8, `timer` 7, `move_to` 7, `check` 6, `Shoes.url`/`url` 6, `ask` 6, `subtitle` 6, `tagline` 5, `start` 5, `leave` 5, `arc` 5, `curve_to` 5, `mask` 5, `gradient` 4, `rotate` 4, `arrow` 4, `window` 4, `page` 4, `ask_open_file` 3, `ask_color` 3, `code` 3, `every` 2, `video` 2, `wheel` 2, `release` 2, `em` 2, `line_to` 2, `translate` 2, `arc_to` 1, `cap` 1, `scale` 1, `skew` 1, `sub` 1, `sup` 1, `del` 1, `mouse` 1, `set_window_title` 1. Zero in target set: `Shoes.settings`, `menubar`, `menu`, `switch`, `systray`, `spinner`, `keyup`, `keydown`, `.scroll_top`, `.scroll_max`.

Suggested tiers, by coverage of the 350:
- **Tier 0 (every app):** window with `title`/`width`/`height`/`resizable`, `stack`/`flow` layout with `width`/`height` (px and `"100%"`/fractions), `margin*`, `top`/`left` absolute placement, `para` + text-size variants (`title`, `banner`, `subtitle`, `tagline`, `caption`, `inscription`) + inline `strong`/`em`/`span`/`link`/`code`/`ins`/`del`/`sub`/`sup`, `button`, `background` (color, gradient range, `curve:`), colors (named, hex, `rgb`, `gray`), `.replace`/`.text`/`.clear`/`.append`.
- **Tier 1:** 2D drawing (`oval`, `rect` w/ `curve:`, `line`, `star`, `arrow`, `arc`, `shape` + `move_to`/`line_to`/`curve_to`, `fill`, `stroke`, `strokewidth`, `nofill`, `nostroke`, `rotate`, `border`, `mask`), `animate` (13.4%!), `timer`, `every`, `edit_line`, `edit_box`, `list_box`, `check`, `radio`, `progress`, `image` (local and remote), `alert`/`confirm`/`ask`, `click`/`hover`/`leave`/`motion`/`keypress`/`release`/`wheel`, `.show/.hide/.toggle/.move/.style/.remove`.
- **Tier 2:** `download` (19), `visit`/`url`/`page` routing, `Shoes::Widget` (8), `ask_open_file` family, `ask_color`, `video`, `window`/`dialog` multi-window, `gutter`, `clipboard`, cursor/`hit`/`marker`/`highlight` text APIs.

### B4. Needs

| need | all | target |
|---|---|---|
| timer/animation | 64 | 55 |
| dialog | 60 | 43 |
| asset | 46 | 26 |
| shoes3_only_widget | 42 | 4 |
| network | 37 | 34 |
| gem | 23 | 4 |
| no_shoes_app_call | 22 | 11 |
| audio | 14 | 3 |
| remote_image | 10 | 9 |
| shell | 8 | 6 |
| file_write | 7 | 4 |
| video | 6 | 3 |
| require_relative | 4 | 0 |
| stdin/readline | 3 | 1 |


`gem:*` seen: `bloops` (bloopsaphone, 6 + `skip_ci/guitar_fretboard.rb`), `hpricot`, `sqlite3`, `typhoeus`, `nokogiri` (via Lacci's `download`), `readline`, `test/unit`, `shoes/data`, `shoes/chipmunk`, `shoes/videoffi`, `benchmark` (Ruby 4.0 no longer ships it as default; `ruby_racer.rb` fails on it). Asset-bearing folders: `image/`, `local_assets/` (+ `local_file_server.rb` runs a WEBrick server), `legacy/for_playtest/shoes-contrib/*` via `File.join(__dir__, "../../../../../docs/static/...")`.

---

## Part C. Baseline: examples under Niente (Lacci only, no renderer)

### C1. Method

Ran **all 424** examples (superset of the ~60 sample asked for; a full pass took ~12 min at 6-way parallel): `SCARPE_DISPLAY_SERVICE=niente NIENTE_LOG_LEVEL=warn bundle exec ruby exe/scarpe --dev <file>` from `SC`, under `perl -e 'alarm 6'`. Classification: SIGALRM (termsig 14) with no Ruby error text on stderr/stdout = **loads**; SIGALRM with error text = **loads_with_errors**; exit 0 = **exited_0**; non-zero exit = **fail**; still alive after alarm+4 s = **hung_killed** (SIGKILL). "Loads" means Lacci built the tree and survived 6 s of heartbeats. It does *not* mean timers, animations, downloads or clicks work; Niente never fires them.

Safety (so the runs touched nothing outside the scratchpad): examples were run from a copy at `research/sandbox/examples` (with `docs/static` symlinked for `__dir__`-relative images), `HOME` and `LOCALAPPDATA` pointed into the sandbox (so `LIB_DIR` and `~/.gentlereminder` writes landed there), and `PATH` was prefixed with stub `osascript`/`say`/`open`/`afplay`/`caffeinate`/`SwitchAudioSource` that exit 1. Not run: `selfitude.rb` (appends to `/tmp/shoesy_stuff.txt` at top level) and `bloopsaphone/working/bronx_army_knife.rb` (runs ffmpeg avfoundation device listing at top level). **Incident:** the first pass did not stub `osascript`, so 9 dialog examples raised **real macOS dialogs** on this Mac through Lacci's `native_builtin_fallback`. 6 of those processes ended within 7-19 s; 3 (`shoes_manual/builtins/ask.rb`, `working/shoes-contrib/kernel/confirm.rb`, `working/shoes-manual/builtins/ask_open_file.rb`) sat on an open dialog for 7.5-9 min until I killed them and their `osascript` children (likely mechanism: Ruby turns SIGALRM into a `SignalException`, but `Open3.capture2`'s cleanup joins the child-wait thread, so the process lingers until `osascript` exits). Those 9 were re-run with the stub; the table reflects the re-run. `SC` and `SS` git trees were verified unchanged afterwards (`SC/Gemfile.lock` was already modified before this lane started; its sha1 `7abf9555...` is unchanged).

### C2. Results by category

| category | n | loads | exited_0 | loads_with_errors | fail | hung_killed | not_run |
|---|---|---|---|---|---|---|---|
| (top-level) | 71 | 68 | 0 | 0 | 2 | 0 | 1 |
| bloopsaphone | 13 | 1 | 1 | 0 | 10 | 0 | 1 |
| flags | 3 | 3 | 0 | 0 | 0 | 0 | 0 |
| image | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| legacy/for_playtest | 191 | 182 | 6 | 2 | 1 | 0 | 0 |
| legacy/needs_deps | 3 | 0 | 0 | 0 | 3 | 0 | 0 |
| legacy/path_issues | 1 | 0 | 0 | 0 | 1 | 0 | 0 |
| legacy/shoes3_only | 48 | 13 | 0 | 0 | 35 | 0 | 0 |
| legacy/working | 59 | 52 | 2 | 1 | 4 | 0 | 0 |
| local_assets | 2 | 1 | 0 | 0 | 0 | 1 | 0 |
| para | 9 | 9 | 0 | 0 | 0 | 0 | 0 |
| radio | 3 | 3 | 0 | 0 | 0 | 0 | 0 |
| shapes | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| skip_ci | 4 | 2 | 0 | 0 | 2 | 0 | 0 |
| stack | 5 | 5 | 0 | 0 | 0 | 0 | 0 |
| turtle | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| **total** | 424 | 351 | 9 | 3 | 58 | 1 | 2 |



### C3. Every example that did not simply load

| example | result | first error line |
|---|---|---|
| bloopsaphone/working/1901_by_Aanand_Prasad.rb | fail | examples/bloopsaphone/working/1901_by_Aanand_Prasad.rb:4:in '<top (required)>': uninitialized constant Bloops (NameError) |
| bloopsaphone/working/b1.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- bloops (LoadError) |
| bloopsaphone/working/b2.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- bloops (LoadError) |
| bloopsaphone/working/bloops_test.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- bloops (LoadError) |
| bloopsaphone/working/bloopsaphone_theme_song_by_why.rb | fail | examples/bloopsaphone/working/bloopsaphone_theme_song_by_why.rb:3:in '<top (required)>': uninitialized constant Bloops (NameError) |
| bloopsaphone/working/bronx_army_knife.rb | not_run | not run: shells out to ffmpeg/avfoundation device listing (mic permission prompt risk) |
| bloopsaphone/working/feepogram.rb | exited_0 |  |
| bloopsaphone/working/le_dance_des_rubis.rb | fail | examples/bloopsaphone/working/le_dance_des_rubis.rb:3:in '<top (required)>': uninitialized constant Bloops (NameError) |
| bloopsaphone/working/pixel_dreams_in_ruby.rb | fail | examples/bloopsaphone/working/pixel_dreams_in_ruby.rb:3:in '<top (required)>': uninitialized constant Bloops (NameError) |
| bloopsaphone/working/simpsons_theme_song_by_why.rb | fail | examples/bloopsaphone/working/simpsons_theme_song_by_why.rb:2:in '<top (required)>': uninitialized constant Bloops (NameError) |
| bloopsaphone/working/tune_cheeky_drat.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- bloops (LoadError) |
| bloopsaphone/working/type_rebellion.rb | fail | examples/bloopsaphone/working/type_rebellion.rb:3:in '<top (required)>': uninitialized constant Bloops (NameError) |
| legacy/for_playtest/shoes-contrib/app/download-and-save.rb | loads_with_errors | Shoes::App#download error: An error occurred while downloading: wrong number of arguments (given 1, expected 2) |
| legacy/for_playtest/shoes-contrib/kernel/ask_save_file.rb | fail | examples/legacy/for_playtest/shoes-contrib/kernel/ask_save_file.rb:6:in 'IO.read': no implicit conversion of nil into String (TypeError) |
| legacy/for_playtest/shoes3-tests/curl/m2.rb | loads_with_errors | Shoes::App#download error: An error occurred while downloading: wrong number of arguments (given 1, expected 2) |
| legacy/for_playtest/shoes_manual/builtins/FONTS.rb | exited_0 |  |
| legacy/for_playtest/shoes_manual/builtins/ask.rb | exited_0 | sandbox-stub osascript refused |
| legacy/for_playtest/shoes_manual/builtins/ask_save_folder.rb | exited_0 | sandbox-stub osascript refused |
| legacy/for_playtest/shoes_manual/builtins/confirm.rb | exited_0 | sandbox-stub osascript refused |
| legacy/for_playtest/shoes_manual/builtins/debug.rb | exited_0 | [DEBUG] Running Shoes on arm64-darwin25 |
| legacy/for_playtest/shoes_manual/builtins/info.rb | exited_0 | [INFO] You just ran the info example on Shoes Strangers. |
| legacy/needs_deps/expert-funnies.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- hpricot (LoadError) |
| legacy/needs_deps/expert-irb.rb | fail | examples/legacy/needs_deps/expert-irb.rb:12:in 'MimickIRB#initialize': undefined method 'set_input' for an instance of MimickIRB (NoMethodError) |
| legacy/needs_deps/simple-rubygems.rb | fail | <ruby>/bundler-2.4.10/lib/bundler/rubygems_integration.rb:280:in 'block (2 levels) in Kernel#replace_gem': bluecloth =2.0.6 is not part of the bundle. Add it to your Gemfile. (Gem::LoadError |
| legacy/path_issues/_why-stories.rb | fail | <ruby>/psych-5.3.1/lib/psych.rb:717:in 'File#initialize': No such file or directory @ rb_sysopen - samples/good/_why-stories.yaml (Errno::ENOENT) |
| legacy/shoes3_only/cache/cache.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- shoes/data (LoadError) |
| legacy/shoes3_only/cardflip.rb | fail | lacci/lib/shoes/builtins.rb:32:in 'Shoes::Builtins#ask_open_file': wrong number of arguments (given 1, expected 0) (ArgumentError) |
| legacy/shoes3_only/curl/typ.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- typhoeus (LoadError) |
| legacy/shoes3_only/events/event0.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'shoesevent' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/events/event1.rb | fail | lacci/lib/shoes/drawable.rb:497:in 'Shoes::Drawable#event': wrong number of arguments (given 0, expected 1+) (ArgumentError) |
| legacy/shoes3_only/events/event4.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'svg' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/events/event5.rb | fail | lacci/lib/shoes/drawable.rb:497:in 'Shoes::Drawable#event': wrong number of arguments (given 0, expected 1+) (ArgumentError) |
| legacy/shoes3_only/events/event6.rb | fail | lacci/lib/shoes/drawable.rb:497:in 'Shoes::Drawable#event': wrong number of arguments (given 0, expected 1+) (ArgumentError) |
| legacy/shoes3_only/gapp/fullscreen.rb | fail | examples/legacy/shoes3_only/gapp/fullscreen.rb:4:in 'block (2 levels) in <top (required)>': undefined method 'settings' for class Shoes (NoMethodError) |
| legacy/shoes3_only/gapp/icon.rb | fail | examples/legacy/shoes3_only/gapp/icon.rb:4:in 'block (2 levels) in <top (required)>': undefined method 'settings' for class Shoes (NoMethodError) |
| legacy/shoes3_only/gapp/mon1.rb | fail | examples/legacy/shoes3_only/gapp/mon1.rb:4:in 'block (2 levels) in <top (required)>': undefined method 'settings' for class Shoes (NoMethodError) |
| legacy/shoes3_only/gapp/title1.rb | fail | examples/legacy/shoes3_only/gapp/title1.rb:4:in 'block (2 levels) in <top (required)>': undefined method 'settings' for class Shoes (NoMethodError) |
| legacy/shoes3_only/menus/menu1.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'id' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/menus/menu2.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined local variable or method 'menubar' for an instance of Shoes::App (NameError) |
| legacy/shoes3_only/plot/cstest.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/gr1.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/gr2.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/gr3.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/gr4.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/gr5.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/gr6.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/gr7.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/plot/grcsv.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for #<Shoes::App:0x00000001044c5338> (NoMethodError) |
| legacy/shoes3_only/plot/manual.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'plot' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/simple-chipmunk.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- shoes/chipmunk (LoadError) |
| legacy/shoes3_only/spinner.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined local variable or method 'spinner' for an instance of Shoes::App (NameError) |
| legacy/shoes3_only/svg.rb | fail | examples/legacy/shoes3_only/svg.rb:3:in '<top (required)>': uninitialized constant Test (NameError) |
| legacy/shoes3_only/switch/switch.rb | fail | lacci/lib/shoes/drawable.rb:833:in 'Shoes::Drawable#method_missing': undefined method 'switch' for an instance of Shoes::App (NoMethodError) |
| legacy/shoes3_only/terminal/ed.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- readline (LoadError) |
| legacy/shoes3_only/terminal/el.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- readline (LoadError) |
| legacy/shoes3_only/tests_color.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- test/unit (LoadError) |
| legacy/shoes3_only/tests_svg.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- test/unit (LoadError) |
| legacy/shoes3_only/tests_video_vlc.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- test/unit (LoadError) |
| legacy/shoes3_only/video-player.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- shoes/videoffi (LoadError) |
| legacy/shoes3_only/video_vlc.rb | fail | examples/legacy/shoes3_only/video_vlc.rb:3:in '<top (required)>': uninitialized constant Test (NameError) |
| legacy/working/info.rb | fail | examples/legacy/working/info.rb:7:in 'block in <top (required)>': uninitialized constant Gem::RubyGemsVersion (NameError) |
| legacy/working/shoes-contrib/kernel/confirm.rb | exited_0 | sandbox-stub osascript refused |
| legacy/working/shoes-contrib/kernel/font.rb | exited_0 |  |
| legacy/working/shoes-contrib/simple/simple-sqlite3.rb | fail | <ruby>/sqlite3-1.6.9/lib/sqlite3/database.rb:177:in 'SQLite3::Statement#initialize': table t1 already exists (SQLite3::SQLException) |
| legacy/working/shoes-manual/builtins/ask_open_file.rb | fail | examples/legacy/working/shoes-manual/builtins/ask_open_file.rb:4:in 'IO.read': no implicit conversion of nil into String (TypeError) |
| legacy/working/shoes_manual/save_download.rb | loads_with_errors | Shoes::App#download error: An error occurred while downloading: wrong number of arguments (given 1, expected 2) |
| legacy/working/simple/sqlite3.rb | fail | examples/legacy/working/simple/sqlite3.rb:18:in 'block in <top (required)>': uninitialized constant SQLite3 (NameError) |
| local_assets/local_file_server.rb | hung_killed | [2026-09-27 13:51:54] INFO  WEBrick 1.7.0 |
| ruby_racer.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- benchmark (LoadError) |
| scarpe_ext.rb | fail | lacci/lib/shoes/app.rb:73:in 'Shoes::App#initialize': Shoes app needs features: [:html] (Shoes::Errors::UnsupportedFeatureError) |
| selfitude.rb | not_run | not run: appends to /tmp/shoesy_stuff.txt at top level (outside sandbox) |
| skip_ci/change_my_audio_source.rb | fail | examples/skip_ci/change_my_audio_source.rb:11:in 'Kernel#`': No such file or directory - SwitchAudioSource (Errno::ENOENT) |
| skip_ci/guitar_fretboard.rb | fail | lacci/lib/shoes/compat_require.rb:28:in 'Kernel#require': cannot load such file -- bloops (LoadError) |


Root causes, grouped: Shoes3-only APIs (`plot` ×10, `Shoes.settings` ×4, `Drawable#event` arity ×3, `test/unit` ×3, `readline` ×2, `Test` const ×2, `switch`, `spinner`, `menubar`, `menu id`, `svg`, `shoesevent`, `shoes/data`, `shoes/chipmunk`, `shoes/videoffi`, `typhoeus`, `ask_open_file(title)`); audio (`bloops` gem missing: 5 LoadError + 6 `uninitialized constant Bloops`); dead deps (hpricot, bluecloth, irb `set_input`); dialogs returning `nil` (stubbed) then `IO.read(nil)` or script end; no `Shoes.app` (builtins demos, `font.rb`); Ruby 4.0 default-gem removals (`benchmark`); `Gem::RubyGemsVersion` removed (`legacy/working/info.rb`, marked working); `SQLite3` constant / DB state (`legacy/working/simple/sqlite3.rb`, `legacy/working/shoes-contrib/simple/simple-sqlite3.rb`); `scarpe_ext.rb` requires feature `:html` (webview-only, raises `Shoes::Errors::UnsupportedFeatureError`); WEBrick keeps running.

### C4. Lacci-level defects this baseline surfaced (independent of any renderer)

1. `Shoes::App#download` (`SC/lacci/lib/shoes/download.rb:31-125`): `handle_failure(response.response.code)` is called with 1 argument but defined `def handle_failure(code, logger)`, so every non-2xx response is logged as `wrong number of arguments (given 1, expected 2)` (3 examples). It also `require "nokogiri"` unconditionally, always calls `parse_rss` after `save:`, and runs the user block on a background `Thread`. A renderer receiving display updates from that thread must marshal them to its UI thread.
2. Builtins fall back to `osascript` whenever the display service leaves the builtin response `nil` (`builtins.rb:66-105`), including a legitimate `nil` from `ask` (Cancel). Headless runs block on a GUI dialog.
3. `ask_open_file` etc. take 0 args; Shoes3 accepted a title (`cardflip.rb`).
4. `all_drawables` (`app.rb:289-299`) seeds `to_add = [@document_root, @document_root.children]`, so the children *Array* itself becomes an element of the result. Class-filtered finders hide it; `drawables()` with no spec would return it.
5. Niente's default log level floods stdout (hundreds of MB per minute).
6. Scripts that never call `Shoes.app` cannot run spec code (the hook lives in `App#initialize`).

---

## Surprises that will bite an implementer

1. Lacci builtins pop **real macOS dialogs** (`osascript`) whenever the display service does not answer the `"builtin"` event with a non-nil `set_builtin_response`. That includes `ask` Cancel (`nil`). Headless test runs hang on them (`SC/lacci/lib/shoes/builtins.rb:66-105`).
2. Niente's default log level is `debug` to stdout: roughly 57 MB/s from heartbeat logging. Set `NIENTE_LOG_LEVEL=warn`.
3. The spec process exits 0 whether tests pass, fail or error. Only the JSON tells you. No JSON means the app died before `Shoes.app`, or there was no `Shoes.app`.
4. `SHOES_MINITEST_CLASS_NAME` with `-` crashes `Object.const_set` (the official Niente runner only replaces `/`).
5. Two `.sspec` parsers disagree. The loader splits on any `\n-{5,}` line, so app code containing a `-----` line breaks it (vjot).
6. Test code runs once, synchronously, on the first heartbeat, before any `animate`/`every`/`timer`/`download` callback. Niente never fires timers at all. `wait` exists only in Webview (CatsCradle, 0.1 s heartbeat granularity).
7. Finders accept only Class / `"@ivar"` / `"$global"` / `"id:N"`; plain text raises `InvalidAttributeValueError`. `@ivar` resolves on the **app** object only.
8. `trigger_change` does not exist on Niente's proxy; Webview's goes through JS callback names `"#{linkable_id}-change"`; GTK raises.
9. `rake scarpe:*` counts textual `skip "..."` as skip without running the app; `run_batch*` counts real skips as fails. Neither recorded number is comparable with a straight run.
10. 20 cases call `Shoes::App.find_drawables_by` directly, and all finders return in-process Lacci objects, so test code must share a process with Lacci.
11. `Shoes.run_app` `chdir`s into the app's directory, and `LIB_DIR` resolves from `LOCALAPPDATA`/`APPDATA`/`HOME`. Examples write files there and into cwd; sandbox both when batch-running.
12. `download` runs callbacks on a background Ruby `Thread`, so display updates can arrive off the main thread. Its failure path is broken (`handle_failure` arity).
13. Ruby 4.0 removed default gems some examples need (`benchmark`, `readline`) and `Gem::RubyGemsVersion` (`legacy/working/info.rb`, which is filed as working).
14. `SC/tasks/test_legacy_examples.rb` targets `examples/legacy/not_checked`, which no longer exists, and `SS/run_batch*.rb` need `batches/*.txt`, which is not committed.
