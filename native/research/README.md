# Research behind the native display service

These reports were written before and during the first build of Scarpe's Rust display service,
all on 27 Sep 2026. They are the evidence `native/DESIGN.md` and `spec/LEDGER.md` cite. They are
kept as written: where the code has moved on since, DESIGN and the ledger say so, and they win.

Reports 01 to 08 were written in the first hour, before any native code existed, against the repo
at `fdcee7a` (so their line numbers are from that commit). Report 09 came with the first build
wave that afternoon. Paths under `<scratch>/` or a "session scratchpad" point at
working folders from those sessions; they are gone, and anything worth keeping from them is in
this folder.

## The reports

| file | written | what it is | read it when |
|---|---|---|---|
| `01_display_contract.md` | 27 Sep, 13:44 | The contract between Lacci and a display service at the protocol level, found by running Lacci and Niente with an event logger: which drawables a display is asked to create, their lifecycle, text, timers, input events, builtins, what gets reported back, and a proposed message set for a display in another process | you touch the wire (DESIGN 4) or the shim (DESIGN 5) |
| `02_visual_semantics.md` | 27 Sep, 13:45 | How the Webview display and its Calzini HTML renderer turn each drawable's props into pixels: units, the stack and flow model, colours, art, backgrounds, text, widgets, events, and a drawable-to-visual table | you change layout or painting and want to know what Scarpe did before |
| `03_manual_inventory.md` with `manual_inventory.json` | 27 Sep, 13:43 to 13:46 | Every testable claim in the Shoes manual (`docs/static/manual.md`) as 539 entries with an id, the claim, its lines and how it can be tested, plus the manual's 37 internal contradictions. The ids name the spec cases, and the contradictions are ledger rows M1 to M37 | you write a spec case: its `manual:` id comes from here |
| `04_examples_and_specs.md` with `examples_inventory.json` and `niente_baseline.json` | 27 Sep, 13:52 to 14:01 | Noah Gibbs' Shoes-Spec system and its 805 cases, the 424 examples and which DSL they use, and how every example ran under Niente that morning | you work on the spec runner, the imported corpus or `spec/examples.yml` |
| `05_integration_and_prior_art.md` | 27 Sep, 13:47 | How the CLI loads a display service, the packager's state that day, Noah's two other display services (gtk-scarpe on GTK4, space_shoes on ruby.wasm in a browser), a spike that revived his relay (`wv_relay`) end to end, and where tests and CI plug in | you want the history, or you touch `exe/scarpe` or packaging |
| `06_discrepancy_ledger_seed.md` | 27 Sep, 13:51 | Where the manual, Shoes 3, Shoes 4, the examples and Lacci disagree, with a first ruling for each. It seeded `spec/LEDGER.md` (rows A1 to L4 keep its ids) | you want the reasoning behind an early ledger row |
| `07_spike_skia.md` | 27 Sep, 13:51 | Spike A: tiny-skia, cosmic-text, winit and softbuffer drawing a Shoes-like scene headless and in a window, with timings, the API calls that worked and the traps. This is the stack we chose; DESIGN 7's API notes come from it | you work in `native/src/text` or `native/src/paint` |
| `08_spike_egui.md` | 27 Sep, 14:02 | Spike B: the same scene in egui, eframe and egui_kittest. It works and its test harness is good, but its widgets do not look native, several Shoes shapes needed work-arounds, and the current egui needs a newer Rust than the machine had. DESIGN took Spike A's stack; this is the road not taken | you wonder why we did not use egui |
| `09_lacci_fixes.md` | 27 Sep, afternoon (first build wave) | The ten Lacci defects of DESIGN section 10: each defect, its ruling with manual lines and Shoes 3/4 source, the change, the test that failed before it, and the examples it moves | you touch those parts of Lacci |

## The data and the sources

- `manual_inventory.json`: the 539 manual entries (`id, section, signature, claim, example_lines,
  testability, version_note`). `spec/run --check` validates every case's `manual:` id against it.
- `examples_inventory.json`: every example with the DSL calls it makes, from report 04.
- `niente_baseline.json`: how each example behaved under Niente on the morning of 27 Sep.
- `sources/`: excerpts of the Shoes 3 (`shoes/shoes3@master`) and Shoes 4 (`shoes/shoes4@main`)
  source, both MIT licensed, fetched on 27 Sep 2026 so the ledger's citations can be checked
  without the network. `sources/README.md` has the file-name mapping (`s3t_shape.c` is
  `shoes/types/shape.c`).

## After the research

What was built from this is in `native/DESIGN.md` (the contract), `native/PERF.md` (the
performance work), `docs/native_packaging.md` (packaging) and `docs/native.md` (the user guide).
The rulings on everything the sources disagree about live in `spec/LEDGER.md`.
