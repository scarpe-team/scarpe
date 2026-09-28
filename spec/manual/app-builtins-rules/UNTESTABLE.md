# Entries with no case

Manual entries in the `intro`, `install`, `rules`, `shoes`, `builtins`, `app`, `classes` and
`andsoforth` groups that get no `.sspec`, one line of reason each. Every other entry in these
groups has at least one case in this directory.

| entry | lines | why there is no case |
|---|---|---|
| `intro.manual_is_shoes_program` | 31 | True of the Shoes 2/3 built-in manual app; Scarpe's copy is a Jekyll Markdown page. |
| `intro.cross_platform` | 28-29 | A claim about where Shoes runs; one sandboxed process on one OS cannot check another. |
| `intro.platform_screenshots` | 42-71 | Screenshots of samples on Tiger, Vista and Ubuntu; history, not behaviour. |
| `intro.no_tabs_or_toolbars` | 137-144 | Describes what Shoes leaves out; there is nothing to call. |
| `intro.cairo_engine` | 146-148 | Names Shoes 3's drawing library (Cairo); an implementation detail, not behaviour. |
| `install.no_ruby_needed` | 83-90 | Packaging: a Shoes install bundles its own Ruby. Covered by `scarpe package`, not by an app. |
| `install.installers` | 92-102 | Platform installers (.dmg, .exe, compiling on Linux) of the Shoes 2/3 era. |
| `install.program_is_rb_file` | 104-106 | A definition, and the runner's own mechanism: `spec/run` writes every case's app code to a plain `app.rb` and launches it with `scarpe app.rb`. |
| `install.run_by_drop_or_file_picker` | 125-133 | Launcher behaviour (dock icon, a file picker when started with no file). A case is an app run by path, and `exe/scarpe` with no file prints its usage instead. |
| `rules.fixed_height_cost` | 368-370 | Performance advice (nested windows cost memory), no behaviour to assert. |
| `rules.group_shapes_perf` | 428-430 | Performance advice (grouping shapes saves memory and speed), no behaviour to assert. |
| `rules.main_app_isolation` | 508-515 | Raisins-era sandbox rules; the note at 489 says Policeman runs at the top level, and ledger L1 rules the spec asserts nothing about the sandbox. |
| `shoes.reference_navigation` | 537-569 | The manual's own table of contents and its Search page. |
| `builtins.console_hotkey` | 721-722 | Alt-/ opens the Shoes console in a second window (ledger H10, K8, since 28 Sep 2026), which a spec case does not open; `test/native/errors_test.rb` presses it and reads the console, and `lacci/test/test_console.rb` opens it on Niente. |
| `builtins.font.formats` | 754-764 | Which font file formats each OS supports; platform-specific and outside Scarpe's control. |
| `builtins.info.shy_loading` | 812-813 | Shy is the Shoes 2/3 packaging format; Scarpe has no Shy loader. |
| `classes.hierarchy` | 1558-1564 | The chart is an unexpanded `{INDEX}` placeholder (M38); there is nothing in the manual to check against. |
| `andsoforth.sample_apps` | 3521-3525 | An unexpanded `{SAMPLES}` placeholder (M38). |
| `andsoforth.faq` | 3527-3533 | Links to the mailing list, source and wiki. |

## Halves of a claim left out

These entries have cases, but part of the claim is not asserted:

- `intro.draw_animate_effects`: the blur and shadow effects. The manual never documents an effects API, and ledger E9 rules effects EXT.
- `intro.consistent_look_native_controls`: "shapes, text, images and videos look the same on every platform". One run on one OS cannot compare platforms; the case checks that controls keep the size they are given.
- `app.style.resizable`: whether a real window refuses a drag-resize. Headless runs have no window frame, so the case checks the style reaches the app.
- `app.visit`: that an absolute `http` URL must serve a Shoes app. That needs the network.
- `builtins.ask.secret`: the masking itself happens inside the dialog, which headless runs never draw. The case checks that the secret flag reaches the dialog.
- `builtins.exit`: that Ruby's own exit stays reachable as `Kernel.exit`. Ruby guarantees that.
- `rules.main_app_anonymous_class` and `rules.temporary_vs_required_classes`: the Raisins-era anonymous `(shoes)` class and classes that vanish when the app ends (L1).
- `rules.utf8_font_fallback`: the Japanese example. The deterministic native run bundles no CJK font, so the case uses a Latin string with a family list whose first entry does not exist.
