---
layout: default
title: CI for the native display service
---

# CI for the native display service

This page says what our GitHub Actions workflows run, which of those steps have been run for
real and where, and which have not. It was written on 28 Sep 2026 on the `w6/ci` branch, which
holds the workflows and the fixes CI needed, and that branch merged into `native-rust` the same
morning with the other wave-6 branches ("After the merge", below). Nothing has run on GitHub
yet: the first push will be the first real run, and the last sections say how to make it.

## What runs where

`.github/workflows/native.yml` is new. It runs on every pull request and every push to `main`,
except for changes that touch only `docs/` or Markdown files.

| job | runner | what it runs |
|---|---|---|
| Rust on macOS | `macos-26` | in `native/`: `cargo clippy --all-targets --release --locked -- -D warnings`, then `cargo test --release --locked`, on Rust 1.89 |
| Rust on Linux | `ubuntu-24.04` | the same |
| Rust on Windows | `windows-2025` | the same, but a failure does not fail the run (`continue-on-error`) until it has passed there once |
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

## What was not run

1. **Windows.** There is no Windows machine here, so no test has ever run on Windows. The crate
   compiles for it (the clippy check above), and the Rust job on `windows-2025` will be the first
   run of its tests. It cannot fail the workflow until it has passed once; then remove
   `experimental: true` from its matrix row. The Ruby side is Unix-only today: the shim starts
   the renderer in a process group of its own (`pgroup: true`) and signals the group, which Ruby
   on Windows does not offer, so there is no Windows Ruby job.
2. **GitHub's runners themselves.** A `macos-26` runner has 3 cores and a Linux runner 4, and
   `spec/run` runs one case per core (up to 8), so the macOS spec steps run 3 cases at once where
   this Mac ran 8. setup-ruby's own prebuilt Rubies were not run: they only work
   installed under `/Users/runner/hostedtoolcache`, so the macOS legs used a Ruby 3.2.11 built
   here and mise's 4.0.1.
3. **The webview job on this branch.** It opens real webview windows, which nothing in this work
   may do on this Mac. On `main` it has stopped at "Check HTML output" since at least 29 June
   2026 ([run 28374518146](https://github.com/scarpe-team/scarpe/actions/runs/28374518146)): the
   fixtures in `test/wv/html_fixtures` no longer match the HTML Calzini writes, and upstream
   [#589](https://github.com/scarpe-team/scarpe/pull/589) regenerates 67 of the 71. This branch
   also changes Lacci in ways the webview HTML can show (DESIGN section 10), and `rake test`
   smoke-runs every example on webview, now including the 40 under `examples/native/` (the
   showcase, the benches and the eleven legendary apps with their icons).
   What it needs: on a Mac with a screen, `bundle exec rake test:regenerate_html_fixtures`, read
   the diff, commit it, then `bundle exec rake test` for the rest of the webview suite.
4. **`build-docs.yml` and `build-webview-extensions.yml` on GitHub.** The docs job's apt,
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
| webview job | about 4 min, to where it stops today | the same |

That is roughly 85 to 120 runner minutes per push with cold caches and 60 to 80 with warm ones,
and 20 to 25 minutes of waiting, since the jobs run side by side. GitHub-hosted runners cost
nothing for a public repository like `scarpe-team/scarpe`. What binds is concurrency: a free
organisation runs at most 5 macOS jobs at once, and one push starts 4 (the Rust job, two Ruby
jobs and the webview job). If the first push also starts `build-webview-extensions.yml`, its two
macOS legs make 6, and one job waits its turn.

## Pushing the branch and opening the pull request

`w6/ci` is merged into `native-rust`, and its worktree and branch are gone. `native-rust` is not
on GitHub yet, so one draft pull request carries the whole native branch, CI included, the way
the earlier waves landed. The merge stays with you.

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

On the first run, look at:

- the Windows Rust job, the only one never run anywhere;
- the webview job, which will stop at "Check HTML output" until the fixtures are regenerated;
- how long each Ruby job takes on a cold cache, against the estimates above.

Once the native jobs are green, make the two Rust jobs on macOS and Linux and the four Ruby jobs
required checks in the branch protection for `main`.

## Later

- **Formatting.** `cargo fmt --check` would fail in 1,168 places, because the crate uses longer
  lines than rustfmt's default. A `rustfmt.toml` would have to come first.
- **Arm Linux.** A `ubuntu-24.04-arm` job needs `aarch64-linux` in the lockfile without the
  swap to precompiled nokogiri, or a newer Bundler.
- **Windows Ruby.** A Windows Ruby job, once the shim can start and stop the renderer without a
  Unix process group.
