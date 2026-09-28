---
layout: default
title: CI for the native display service
---

# CI for the native display service

This page says what our GitHub Actions workflows run, which of those steps have been run for
real and where, and which have not. It was written on 28 Sep 2026 on the `w6/ci` branch, which
holds the workflows and the fixes CI needed, and that branch merged into `native-rust` the same
morning with the other wave-6 branches ("After the merge", below). The same day `native-rust`
went up as draft pull request [#591](https://github.com/scarpe-team/scarpe/pull/591), and its
first runs on GitHub turned up two things no local run could: "The first runs on GitHub", below.

## What runs where

`.github/workflows/native.yml` is new. It runs on every pull request and every push to `main`,
except for changes that touch only `docs/` or Markdown files. On a pull request GitHub applies
that filter to the whole pull request's diff from `main`, not to the push, so every push to #591
runs it: this page's own update, `aa0f22c`, changed nothing else and still ran both workflows
(run 4, below). Only a push to `main` of nothing but those files runs neither.

| job | runner | what it runs |
|---|---|---|
| Rust on macOS | `macos-26` | in `native/`: `cargo clippy --all-targets --release --locked -- -D warnings`, then `cargo test --release --locked`, on Rust 1.89 |
| Rust on Linux | `ubuntu-24.04` | the same |
| Rust on Windows | `windows-2025` | the same, but a failure does not fail the run (`continue-on-error`). It first passed on 28 Sep 2026; making it count is one line (below) |
| Ruby 3.2 on macOS, Ruby 4.0 on macOS | `macos-26` | builds the renderer; `rake native_test`, `lacci_test`, `component_test`, `spec:selftest`; `spec/run --check`; the spec suite on Niente and on native; `spec/run --examples --display native`; packages `examples/button.rb`; `rake package_test` |
| Ruby 3.2 on Linux, Ruby 4.0 on Linux | `ubuntu-24.04` | the same, less packaging an app (native packages are macOS apps; `package_test` runs its other tests) |

A Ruby job that fails uploads `spec/results/` (the results files, the spec snapshots and the
example gallery) and `logger/*.log`. A Rust job that fails uploads what its golden tests drew,
from `native/target/tmp/golden-actual/`. Both are kept for 14 days.

The three older workflows are the webview ones. They changed only where the runners had moved
under them:

| workflow | runner | what it runs |
|---|---|---|
| `ci.yml` (CI) | `macos-26` | the webview suite: `lacci_test`, `component_test`, `test:check_html_fixtures`, `rake test` |
| `build-docs.yml` | `ubuntu-24.04` | YARD docs to the `pages` branch, on pushes to `main` |
| `build-webview-extensions.yml` | `ubuntu-22.04`, `macos-15-intel`, `macos-14` | prebuilt webview extensions, when dispatched or when the file itself changes |

On your own machine, `bundle exec rake ci_native` runs the native steps in the same order,
headless, and `bundle exec rake ci_test` runs the webview job's four test steps (those open
windows). Neither installs, checks out or uploads anything any more; `ci_test` used to run
`brew install` and `git checkout main`.

## Choices in the workflows

- **Pinned runner images.** `macos-latest` became macOS 26 in July, and `ubuntu-latest` moves
  to 26.04 between 19 October and 19 November 2026. Each move breaks builds whose code has not
  changed: the docs workflow has failed since `ubuntu-latest` became 24.04. With pinned images,
  a new runner arrives as a one-line pull request that CI can test.
- **Rust 1.89**, the crate's `rust-version`. The newest `rust-version` among the locked
  dependencies is also 1.89 (cosmic-text 0.19 and smol_str 0.3.6), so the promise is exactly
  what the dependencies allow, and CI keeps out code that needs a newer compiler.
- **WebKitGTK on Linux.** The `scarpe` gem depends on `webview_ruby`, which compiles against
  GTK and WebKitGTK while the bundle installs, so even the native jobs need `libgtk-3-dev` and
  `libwebkit2gtk-4.1-dev`. `webview_ruby` 0.1.2 asks pkg-config for `webkit2gtk-4.0`, which
  Ubuntu stopped shipping in 24.04. 4.1 is the same API on libsoup 3, so the job writes a
  four-line `webkit2gtk-4.0.pc` that requires 4.1 and points `PKG_CONFIG_PATH` at it.
- **xzcat on macOS.** The lockfile builds nokogiri 1.15.7 from source, and nokogiri unpacks its
  libxml2 from a `.tar.xz` with `xzcat`, which macOS does not ship. The `macos-26` image has one
  only because Homebrew's `zstd` depends on `xz`, so the macOS jobs install `xz` if it is ever
  missing.
- **Ruby "3.2" means 3.2.11.** The `macos-26` image's clang 21 (Xcode 26.6) warns inside the
  headers of Ruby 3.2.0 and 3.2.2 (`struct RString retval;`), nokogiri's configure checks run
  with `-Werror`, and so a cold bundle cannot install there. 3.2.11 fixed the header. The
  webview job read `.ruby-version` (3.2.0), so it now asks for `"3.2"` as the native jobs do.
- **The stubs first on PATH.** `spec/support/fakebin` holds stand-ins for `osascript`, `say`,
  `afplay`, `open`, `pbcopy`, `pbpaste` and `xclip`. It goes first on PATH for every Ruby step,
  so no test can reach the runner's desktop, and the local runs that proved these steps used the
  same PATH.
- **Caches.** setup-ruby caches the bundle for each Ruby and runner. rust-cache keeps compiled
  dependencies under one key per OS (`native`): the Rust jobs save it and the Ruby jobs only read
  it, so once a cache exists a Ruby job compiles only the scarpe-native crate. The macOS Ruby
  jobs also cache the Traveling Ruby that packaging downloads, keyed on `lib/scarpe/package.rb`.
- **The lockfile is unchanged.** setup-ruby's macOS Rubies call themselves `arm64-darwin22`
  (3.2.0) and `arm64-darwin23` (3.2.11 and 4.0.7), both in the lockfile's PLATFORMS, and Linux
  is `x86_64-linux`. An arm Linux job (`ubuntu-24.04-arm`) would need `aarch64-linux` added, and
  Bundler 2.4.10's `bundle lock --add-platform` also swaps nokogiri and sqlite3 for precompiled
  gems, whose nokogiri 1.15.7 does not install on Ruby 4.0. That is left for later.

## What CI needed fixed

Each of these failed, or would have, the first time the steps ran somewhere new.

| commit | what failed | where it showed |
|---|---|---|
| Time the startup stand-ins without Bundler | `StartupTest` gave a stand-in child 0.8 s to answer; it inherited `RUBYOPT=-rbundler/setup` and spent most of that resolving the bundle (`ChildTimeout`) | Linux container |
| Ask for a macOS package by name in its tests | six package tests built a packager for the host OS, which raises on Linux | Linux container |
| Let an example's expected failure name its Rubies | `info.rb` and `ruby_racer.rb` fail only on Ruby 4.0 (a RubyGems constant 4.0 removed, a gem 4.0 unbundled), so on 3.2 they passed against `status: fails` and failed the run. An `examples.yml` entry can now say `ruby: ">= 4.0"` | Linux container, Ruby 3.2 |
| Keep a failed golden's picture; reap zombies on Unix | a golden failure on another machine could not be seen; one test runs `sh` and `ps`, which Windows lacks | read, for CI and Windows |
| Make sure macOS has xzcat before the bundle installs | `xzcat not found` building nokogiri | this Mac, without Homebrew on PATH |
| Give the webview job a Ruby 3.2 that builds nokogiri | `'nokogiri_gumbo.h' file not found`, after `-Wdefault-const-init-field-unsafe` | this Mac, Ruby 3.2.2 |
| Mend the webview and docs workflows for today's runners | `libwebkit2gtk-4.0-dev` is gone from Ubuntu 24.04; setup-ruby v1.146.0 predates 24.04; `macos-13` was retired in December 2025 | GitHub, on `main` |
| Rename the three spec cases whose names held a question mark | checkout: `invalid path 'spec/manual/app-builtins-rules/app.started?.sspec'`; NTFS keeps no `?` | GitHub, `windows-2025` |
| Ask the real-clock animate test for movement, not a frame rate | `Expected 2 to be >= 3.`: the runner fired 3 frames of `animate(20)` in a 0.3 s peek where this Mac fires 6 | GitHub, `macos-26` |
| Ask the real-clock timer tests for counts, not a rate | `Expected 4 to be >= 5.`: `animate(40)` fired 4 frames in 0.4 s where 16 were due | GitHub, `macos-26`, Ruby 4.0 |
| Let the HTML fixture tasks run without a window; Regenerate the webview HTML fixtures | "Check HTML output": all 67 examples it checks differed from their fixtures | GitHub, `macos-26`, and on `main` since June |

## What was run, and how

**macOS**, on this Mac (Apple M5, 10 cores, shared with other work all night). Each leg started
from a fresh `git clone` of `w6/ci` at `eb512e6`, in a scratch directory with its own HOME and
TMPDIR, and ran the workflow's commands in order: setup-ruby's bundle config (`path
vendor/bundle`, `deployment true`) with Bundler 2.4.10, Rust 1.89 with clippy from a scratch
rustup, Homebrew on PATH as on the runner, and `fakebin` first on PATH. The 3.2 leg used Ruby
3.2.11 compiled into the scratch directory; the 4.0 leg used Ruby 4.0.1 (CI will use 4.0.7).

**Linux**, in Docker Desktop on the same Mac, `linux/amd64` under Rosetta: the official
`ruby:3.2` (3.2.11) and `ruby:4.0` (4.0.7) images, which are Debian 13 with GCC 14 and, like
Ubuntu 24.04, WebKitGTK 4.1 and no 4.0. On top: the workflow's apt packages (and `xvfb`, which
nothing used), Bundler 2.4.10 as setup-ruby installs it, rustup with Rust 1.89 and clippy, a
`runner` user, and 4 CPUs
(`--cpuset-cpus 0-3`, as many as a GitHub Linux runner has). Each leg started from a fresh clone
(`661d66c` for 3.2, `eb512e6` for 4.0; the commits between touch only the macOS steps), ran the
Rust job's two commands, then the Ruby job's steps in order.

| step | macOS, Ruby 3.2.11 | macOS, Ruby 4.0.1 | Linux, Ruby 3.2.11 | Linux, Ruby 4.0.7 |
|---|---|---|---|---|
| bundle install, cold | 88 s | 75 s | 319 s | 331 s |
| clippy, warnings denied | clean, 32 s | (once per OS) | clean, 161 s | clean, 136 s |
| `cargo test --release` | 306 pass, 8 ignored, 117 s | (once per OS) | 306 pass, 8 ignored, 461 s | 306 pass, 8 ignored, 420 s |
| build the renderer | 0 s (built by the tests) | 48 s | 1 s | 2 s |
| `rake native_test` | 177 runs, 0 failures, 8 skips, 44 s | the same, 49 s | the same, 106 s | the same, 87 s |
| `rake lacci_test` | 205, 0 failures, 50 s | 205, 43 s | 205, 136 s | 205, 68 s |
| `rake component_test` | 126, 1 s | 126, 1 s | 126, 2 s | 126, 1 s |
| `rake spec:selftest`, `spec/run --check` | 16 runs; 1019/1019 valid | the same | the same | the same |
| spec suite on Niente | 540 pass, 12 xfail, 466 n/a, 1 skip, 57 s | the same, 56 s | the same, 131 s | the same, 74 s |
| spec suite on native | 1003 pass, 15 xfail, 1 skip, 163 s | the same, 110 s | the same, 254 s | the same, 141 s |
| examples on native | 319 pass, 21 xfail, 90 skip, 98 s | 317 pass, 23 xfail, 90 skip, 83 s | 319, 21, 90, 193 s | 317, 23, 90, 172 s |
| package an app | `Button.app`, 10 s (Traveling Ruby fetched) | 7 s | (macOS only) | (macOS only) |
| `rake package_test` | 30 runs, 0 skips, 6 s | 30 runs, 0 skips, 4 s | 30 runs, 5 skips, 2 s | 30 runs, 5 skips, 1 s |
| whole leg | 11 min | 8 min | 30 min | 24 min |

Nothing failed, errored, timed out or passed unexpectedly anywhere. The 8 skips in
`native_test` are the tests that open real windows (`SCARPE_NATIVE_WINDOWED_TESTS`); the spec
suite's one skip is `spec/harness/skipped.sspec`, which checks that skipping works; the 90
examples skipped are the ones `examples.yml` marks `skip` (the network, Shoes 3 only and the
like); and on Linux the 5 package tests skipped need a macOS Traveling Ruby. The two extra
expected failures on Ruby 4.0 are the two examples above. On Linux the example gallery came out
the same as on macOS: the four snapshots compared (`button`, `for_noah`, `shapes`, `calc`)
differ in no pixel, and `for_noah.png` is the same file byte for byte, so the bundled fonts and
tiny-skia draw alike on x86_64 and Apple silicon.

`bundle exec rake ci_native` also ran end to end in the macOS 4.0.1 clone, every step green, in
8 minutes. `yardoc`, the docs workflow's build step, ran in the Linux 3.2 container and finished
cleanly in 12 s.

**Workflow syntax.** actionlint 1.7.12, in Docker: no findings in `native.yml`, `ci.yml` or
`build-docs.yml`. `build-webview-extensions.yml` has six shellcheck notes, all in lines this
branch did not touch (mostly `$(pkg-config ...)` left unquoted, which needs its word
splitting); before this branch it also had `label "macos-13" is unknown`.

**Other targets.** clippy with warnings denied, Rust 1.89, from macOS: clean for
`aarch64-apple-darwin`, `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu` and
`x86_64-pc-windows-msvc`.

**After the merge.** `w6/zarking`, `w6/apps` and `w6/ci` merged into `native-rust` on 28 Sep
2026. The merged branch failed its first `rake ci_native` at clippy: one line from the apps
lane, a double negative that `nonminimal_bool` rejects, fixed in `399068e`. After that fix,
`bundle exec rake ci_native` ran every step green on this Mac on Ruby 4.0.1 in 257 s: clippy
clean; `cargo test` 311 pass, 8 ignored; `native_test` 177 runs, 8 skips; `lacci_test` 210;
`component_test` 126; `spec:selftest` 16 runs; `spec/run --check` 1026/1026 valid; Niente 540
pass, 12 xfail, 473 n/a, 1 skip; native 1010 pass, 15 xfail, 1 skip; examples on native 340
pass, 23 xfail, 90 skip of 453; `Button.app` packaged; `package_test` 37 runs, 0 skips. Rust
1.89 from a scratch rustup gave clippy clean and 311 passed. `package_test` also ran on Linux
(`ruby:4.0.1-slim`, arm64, with minitest 5.27.0): 37 runs, 0 failures, 5 skips, after the
merge made the packager tests from `w6/zarking` ask for a macOS package by name as this
branch's do. On Ruby 3.2.2, with a small bundle of Lacci and pure-Ruby gems (nokogiri 1.15.7
does not build there), Lacci's tests passed 210 of 210, and every Ruby file the merge changed
parses. The Linux legs as a whole, and the rest of the Ruby 3.2 leg, were not run again.

**After the fourth GitHub run.** On `ci/fixes`, which is `native-rust` with 84 commits not yet on
#591 and the fixes for that run ("The first runs on GitHub"), `bundle exec rake ci_native` ran
every step green on this Mac on Ruby 4.0.1 in 8.5 min, with a scratch HOME and `fakebin` first on
PATH: clippy clean on Rust 1.93.1, and on 1.89.0 from a scratch rustup; `cargo test` 331 pass, 8
ignored; `native_test` 184 runs, 8 skips; `lacci_test` 236; `component_test` 126; `spec:selftest`
16 runs; `spec/run --check` 1060/1060 valid; Niente 545 pass, 11 xfail, 503 n/a, 1 skip; native
1045 pass, 14 xfail, 1 skip; examples on native 360 pass, 23 xfail, 90 skip of 473; `Button.app`
packaged; `package_test` 39 runs, 0 skips. The load average stayed near 40 throughout. Ruby 3.2 and
the Linux legs were not run.

## The first runs on GitHub

Four runs of `native.yml` on pull request #591, all on 28 Sep 2026.

**Run 1, [36407505591](https://github.com/scarpe-team/scarpe/actions/runs/36407505591), at
`178d93e`.** Windows stopped at checkout after 23 s:

```
invalid path 'spec/manual/app-builtins-rules/app.started?.sspec'
The process 'C:\Program Files\Git\bin\git.exe' failed with exit code 128
```

NTFS keeps no `?` in a file name, and three cases were named after manual ids that end in one.
Nothing on this Mac or in the Linux containers could have caught it: both keep `?` happily, and
the clippy cross-check never checks anything out. The cases became `app.started_p`,
`check.checked_p` and `radio.checked_p` (`d6f0431`), and `spec/README.md` now says how to spell a
`?`, before `video.playing?` gets a case. The next push cancelled this run.

**Run 2, [36408153897](https://github.com/scarpe-team/scarpe/actions/runs/36408153897), at
`d6f0431`.** Windows passed on a cold cache in 6.4 min: clippy clean in 63 s, then 310 tests
passed and 8 ignored in 245 s. That is Unix's 311, less `a_finished_opener_is_reaped`, which is
`cfg(unix)`. Both macOS Ruby jobs failed `rake native_test` on one test, as the 4.0 job had in
run 1:

```
EndToEndTest#test_animate_runs_on_the_real_clock_too [test/native/end_to_end_test.rb:165]:
Expected 2 to be >= 3.
```

The test peeks at an `animate(20)` app after 0.3 s and wanted frame 3 or later. This Mac shows
frame 5, then 12, every time. By the first look the 3-core runner had fired 3 frames where this
Mac fires 6, and a late timer skips the deadlines it missed, so the count measured the runner.
The test now asks only that frames move on during each wait (`866e824`). It failed on macOS in
three of four runs and on Linux in none. Whether that gap is the runner's speed or something
macOS does to a background process's timers is not known.

**Run 3, [36409323983](https://github.com/scarpe-team/scarpe/actions/runs/36409323983), at
`866e824`.** Every native job passed, with warm caches, on setup-ruby's own 3.2.11 and 4.0.7:

| job | time | what it reported |
|---|---|---|
| Rust on Linux, macOS, Windows | 1.3, 1.6, 2.3 min | clippy clean; `cargo test` 311, 311, 310 pass, 8 ignored |
| Ruby 3.2 on macOS | 9.5 min | `native_test` 178 runs, 8 skips; Niente 540 pass, 12 xfail, 473 n/a, 1 skip; native 1010 pass, 15 xfail, 1 skip; examples 342 pass, 21 xfail, 90 skip; `package_test` 38 runs, 0 skips |
| Ruby 4.0 on macOS | 11 min | as Ruby 3.2 on macOS, but examples 340 pass, 23 xfail |
| Ruby 3.2 on Linux | 9.7 min | as Ruby 3.2 on macOS, but `package_test` 38 runs, 6 skips |
| Ruby 4.0 on Linux | 9.6 min | as Ruby 4.0 on macOS, but `package_test` 38 runs, 6 skips |

The spec steps ran 3 cases at once on macOS and 4 on Linux, and the slowest step was examples on
native, 230 s on macOS Ruby 3.2. The webview job stopped at "Check HTML output" each time, as it
does on `main`.

**Run 4, [36410714919](https://github.com/scarpe-team/scarpe/actions/runs/36410714919), at
`aa0f22c`**, this page's update and nothing else. Every native job passed but Ruby 4.0 on macOS,
which failed in 1.9 min, at `rake native_test`, on another count of timer fires:

```
AppTest#test_ruby_timers_fire_at_the_right_counts_in_real_time [test/native/app_test.rb:98]:
Expected 4 to be >= 5.
```

`animate(40)` had fired 4 frames in 0.4 s where 16 were due, once every 100 ms or so, the pace
run 2's runner kept as well. This Mac keeps that pace when the process runs at a lower QoS: under
`taskpolicy -c background` a 25 ms `IO.select` wakes after 120 to 134 ms, against 30 ms at the
default, and the test failed there with the same `Expected 4 to be >= 5`. So the count measured
how often the machine wakes a sleeping process, the second of run 2's two guesses. Whether GitHub
runs its macOS jobs at a lower QoS is not known; its counts match this Mac's under one. The test
now asks for the counting itself, 0, 1, 2 one at a time with at least two of each, and
`test_peek_waits_in_real_time_and_resizes_first`, which asked the same `>= 3` of an `animate(20)`
after 0.3 s, asks for a frame past 0 ("Ask the real-clock timer tests for counts, not a rate").
The webview job stopped at "Check HTML output" again, on all 67 examples it checks ("The webview
fixtures", below).

**`continue-on-error`.** In run 1 the pull request listed "Rust on Windows" as failed, while the
other jobs ran on. `continue-on-error` on a job keeps it from failing the workflow run; it does
not turn the job's own check grey, so a Windows failure still shows red on the pull request. The
run was cancelled before it concluded, so the run-level half was not seen. Windows has now
passed twice. To make it count, delete `experimental: true` from its matrix row; to keep it a
report, leave it, and do not make it a required check.

## The webview fixtures

"Check HTML output" (`rake test:check_html_fixtures`, in `ci.yml`) runs the examples in
`examples/*.rb`, 67 of the 71 since 4 say `# html_ci: false`, keeps the first page Scarpe hands
the webview, beautifies it and compares it line by line with `test/wv/html_fixtures`. That page
is Calzini's HTML, built in Ruby before any JavaScript runs, so getting it needs no window.
`WINDOWLESS=1` puts `tasks/windowless_webview` first on the examples' load path, and its
`webview_ruby.rb` stands in for the gem: the same methods, no window and no JavaScript. It plays
the page's calls back into Ruby, `scarpeInit();` and the heartbeat, which is all the fixture
tasks wait for, and the task stops before the first example unless the stand-in is what loads.

```sh
WINDOWLESS=1 bundle exec rake test:regenerate_html_fixtures   # then read the diff
WINDOWLESS=1 bundle exec rake test:check_html_fixtures
```

On Ruby 4.0, `examples/ruby_racer.rb` needs `benchmark`, which 4.0 no longer ships as a default
gem, so either task wants `RUBYOPT="-I$(dirname "$(gem which benchmark)")"` there. The webview job
runs Ruby 3.2.

The stand-in's pages are the real webview's. At `aa0f22c` its page for each of the 67 examples
matched, line for line, the page CI's real webview drew in [run
36410714827](https://github.com/scarpe-team/scarpe/actions/runs/36410714827), rebuilt from the
check's diffs against the old fixtures, and the commits since `aa0f22c` change none of the 67. The
regenerated fixtures ("Regenerate the webview HTML fixtures") are those pages. 56 of them are
exactly the files upstream [#589](https://github.com/scarpe-team/scarpe/pull/589) regenerates for
`main`. The other 11 add this branch's Lacci changes on top, each traced to the commit that made
it: from `e75b5a0`, `oval` (the third argument is a diameter), `span` and `text_sizes` (`ins` is
the underline fragment), and `para_cursor_demo` (`#333` is `#333333`), with CSS alpha `1.0` for
`255` there and in `border`, `background_with_image`, `margin_check`, `simple_slides` and
`simpler-menu`; `progress` (the fraction starts at 0.0, `c91ffd6`); and `shoes_splorer` (the App
answers `transform`, `5cd2ed1`). With them the check passes 67 of 67 here.

## What was not run

1. **Windows, here.** There is no Windows machine here. The crate's tests have run on Windows
   only on GitHub's `windows-2025` ("The first runs on GitHub"). The Ruby side is Unix-only
   today: the shim starts the renderer in a process group of its own (`pgroup: true`) and
   signals the group, which Ruby on Windows does not offer, so there is no Windows Ruby job.
2. **`rake test`, the webview job's last step.** It opens real webview windows, which nothing in
   this work may do on this Mac, and on GitHub it has not run since at least 29 June 2026: "Check
   HTML output" stopped the job before it, on `main` ([run
   28374518146](https://github.com/scarpe-team/scarpe/actions/runs/28374518146)) and on every run
   of #591. With the fixtures regenerated, the next run reaches it. Its example smoke run,
   `test/test_examples.rb`, did run here, with the windowless stand-in on `RUBYOPT`, Ruby 4.0.1 and
   `fakebin` first on PATH, for this branch and for `main`. `main` failed 53 of its 407 examples,
   and this branch the same 53 of 456, once `examples/native/bench/` was left out ("Leave the
   native benchmarks out of the webview smoke run"). The 53 are Shoes 3 only examples, missing
   gems, a path issue, examples that open dialogs (`fakebin` refuses them; the webview job has no
   `fakebin`, so on GitHub they reach a real `osascript`), `legacy/working/info.rb` on Ruby 4.0,
   and `local_assets/local_file_server.rb`, whose `at_exit` joins a server thread that never ends:
   it hung here until killed, and on GitHub a hang runs into the job's 30-minute timeout. The rest
   of `rake test` waits on JavaScript the stand-in never runs, and was not run. What it needs: on a
   Mac with a screen, `CI_RUN=true bundle exec rake test`.
3. **`build-docs.yml` and `build-webview-extensions.yml` on GitHub.** The docs job's apt,
   setup-ruby and `yardoc` steps ran in the Linux container; pushing to the `pages` branch did
   not. The extension build did not run; actionlint accepts `macos-15-intel`.

## Estimated CI minutes

For one push of a pull request, from the timings above. These are estimates: the runners are
slower per core than this Mac and faster than an emulated container.

| job | cold caches | warm caches |
|---|---|---|
| Rust on macOS, Linux | 5 to 8 min each | 3 to 4 min each |
| Rust on Windows | 8 to 12 min (a guess: never run) | 4 to 6 min |
| Ruby on macOS (2 jobs) | 18 to 25 min each | 13 to 18 min each |
| Ruby on Linux (2 jobs) | 13 to 18 min each | 9 to 12 min each |
| webview job | about 4 min to the fixture check; `rake test` after it has not been timed | the same |

That is roughly 85 to 120 runner minutes per push with cold caches and 60 to 80 with warm ones,
and 20 to 25 minutes of waiting, since the jobs run side by side. GitHub-hosted runners cost
nothing for a public repository like `scarpe-team/scarpe`. What binds is concurrency: a free
organisation runs at most 5 macOS jobs at once, and one push starts 4 (the Rust job, two Ruby
jobs and the webview job). If the first push also starts `build-webview-extensions.yml`, its two
macOS legs make 6, and one job waits its turn.

Measured on 28 Sep, run 3 with warm caches: Rust 1.3 to 2.3 min a job, Ruby 9.5 to 11 min, the
webview job 3.4 min. That is about 49 runner minutes and 11 minutes of waiting, well under
the estimates. The one cold Rust job seen, Windows in run 2, took 6.4 min. No Ruby job has been
timed on a cold cache.

## Pushing the branch and opening the pull request

`w6/ci` is merged into `native-rust`, and its worktree and branch are gone. One draft pull
request carries the whole native branch, CI included, the way the earlier waves landed. It was
opened like this, and the merge stays with you.

```sh
cd ~/Progrumms/scarpe-native          # native-rust is checked out here
git push -u origin native-rust
gh pr create --repo scarpe-team/scarpe --base main --head native-rust --draft \
  --title "Scarpe native: a Rust display service" --body "<your description>"
```

A draft pull request runs `native.yml` and `ci.yml`; neither needs to be on `main` first.
Pushing the branch can also start `build-webview-extensions.yml` once, since the branch
changes that file, and its Linux arm64 leg builds under QEMU, which takes a while.
`build-docs.yml` runs only on `main`.

The branch went up as draft pull request #591 on 28 Sep, and "The first runs on GitHub" says what
its first four runs found. With the fixtures regenerated, the webview job's next run goes on to
`rake test`, where `main`'s own failing examples wait for it ("What was not run", item 2).

The native jobs were green in run 3, and in run 4 all but Ruby 4.0 on macOS, whose count is
loosened since. Next, make the two Rust jobs on macOS and Linux and the four Ruby jobs
required checks in the branch protection for `main`.

## Later

- **Formatting.** `cargo fmt --check` would fail in 1,168 places, because the crate uses longer
  lines than rustfmt's default. A `rustfmt.toml` would have to come first.
- **Arm Linux.** A `ubuntu-24.04-arm` job needs `aarch64-linux` in the lockfile without the
  swap to precompiled nokogiri, or a newer Bundler.
- **Windows Ruby.** A Windows Ruby job, once the shim can start and stop the renderer without a
  Unix process group.
