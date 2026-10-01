# Packaging a Shoes app for the native display service

`scarpe package --native` turns a Shoes app into a macOS `.app` (and a `.dmg`) that draws with
Scarpe's Rust display service: no webview, no WebKit, no Ruby needed on the machine that runs it.
The design lives in `native/DESIGN.md` section 11; this page is how to use it, what ends up
inside, and what it measured.

## Package an app

```sh
scarpe package myapp.rb --native --dmg
```

That writes `MyApp.app` and `MyApp.dmg` in the current directory. `SCARPE_DISPLAY_SERVICE=native`
in the environment picks the native path too, so `SCARPE_DISPLAY_SERVICE=native scarpe package
myapp.rb` does the same.

| option | what it does |
|---|---|
| `--native` | package for the Rust display service (macOS only for now) |
| `--dmg` | also make a compressed disk image with an `/Applications` link |
| `--install-dir DIR` | where the app will live once installed (default `/Applications`); its Ruby is precompiled for that place, see [Bytecode](#bytecode) |
| `--no-bytecode` | skip precompiling |
| `--minimal` | strip optional Ruby libraries: a 17.7 MB app instead of 32.4 MB; OpenSSL and FastImage go, so https image downloads and image sizes cannot work |
| `--include PATH` | also carry a file or folder the app reads (repeatable): one inside the app's folder keeps its relative path, one elsewhere lands under its own name; an included `.rb` file is compiled like the app |
| `--name NAME` | the name Finder, the Dock and the disk image show, kept as written (`"For Noah"`); without it the name comes from the file, CamelCased (`for_noah.rb` is `ForNoah`) |
| `--icon`, `--output`, `--verbose` | as for any `scarpe package` build |

A native package is always ad-hoc signed (Apple silicon runs nothing unsigned, and stripping the
Rust binary drops the signature the linker gave it). `--universal` is not supported yet.

The packager takes Scarpe, Lacci and scarpe-components straight from the source tree it lives in,
never from installed gems, and takes the Rust binary from `SCARPE_NATIVE_BIN` or
`native/target/release/scarpe-native` (running `cargo build --release` first when that is missing
or older than the crate's sources).

## What is inside

```
MyApp.app/Contents/
  Info.plist                      CFBundleExecutable is scarpe-launcher
  MacOS/scarpe-launcher           bash: Traveling Ruby's environment, then exec ruby boot.rb
  MacOS/scarpe-native             the release Rust binary, stripped and signed      6.5 MB
  Resources/boot.rb               bytecode on, require "scarpe", YJIT later, run the app
  Resources/app/                  myapp.rb, its assets and anything named with --include
  Resources/scarpe/               lib, lacci/lib, scarpe-components/lib, CHANGELOG,  0.7 MB
                                  and docs/static/manual.md for Shoes.show_manual
  Resources/scarpe/gems/          fastimage and base64 (pure Ruby), for image sizes
  Resources/bytecode/             150 precompiled files and a manifest               1.5 MB
  Resources/runtime/ruby/         Traveling Ruby 3.4.7, stripped                    23.4 MB
  Resources/licenses/             Inter and Fira Mono (OFL), compiled into the binary
```

`lib/` goes in without the webview display service (`scarpe/wv*`, `scarpe/assets.rb`) and without
the packager itself. The manual goes in at the path Lacci reads it from, so `Shoes.show_manual` opens
its window in a packaged app as it does in a checkout. No gems are installed: Lacci and the shim
need only Ruby's standard library, and Shoes-Spec (minitest) stays out, so `Shoes::Spec` is off in a
packaged app. Two pure-Ruby gems are copied as plain source onto `RUBYLIB`, from the packager's own
Ruby: FastImage, which `Image#size`, `full_width`, `full_height` and `imagesize` read files with,
and base64, which FastImage needs and Ruby 3.4 no longer ships. `--minimal` leaves both out, since
FastImage also needs the OpenSSL that `--minimal` strips, so those four raise `LoadError` in a
minimal app.

Starting the app: LaunchServices runs `scarpe-launcher`, which sets `RUBYLIB`, `GEM_HOME` and
`SCARPE_NATIVE_BIN` for the bundle and execs the bundled Ruby on `boot.rb`. Ruby loads Lacci and
the shim, and the shim starts `scarpe-native` beside the launcher as its child, as in development.
Started from Finder, the Dock or `open`, an app gets no `LANG`, and Ruby would read every file as
US-ASCII, so `boot.rb` makes UTF-8 the default then, as a Mac terminal has it.

Finder, the Dock and `open` start the launcher under launchd with its output going to `/dev/null`.
Then the launcher sends that output to `~/Library/Logs/<name>/launcher.log` instead, one line
opening each start, with one older log kept once it passes 5 MB. Run from a terminal, the output
stays on the terminal.

Running a given file: with `SCARPE_RUN_FILE=/path/to/program.rb` in its environment the launcher
runs that file, on the bundled Ruby and Scarpe, instead of the app (`SCARPE_RUN_DIR` and
`SCARPE_RUN_ARGS`, a JSON Array, set its directory and `ARGV`). That is how a packaged app's
`Shoes.run_program` starts a program in a process of its own: the launcher exports
`SCARPE_LAUNCHER`, its own path, and `run_program` starts it again (native/DESIGN.md 5.5). It
goes back through the launcher because Traveling Ruby hands a running process the environment it
was started with, so the app's Ruby no longer has the bundle's `RUBYLIB` to give a child. A
program started so from a double-clicked app writes its lines to the same log.

## Bytecode

At package time the bundled Ruby compiles Lacci, the shim, scarpe-components, the app and every
standard library file that `require "scarpe"` loads into `RubyVM::InstructionSequence` binaries.
At boot, `boot.rb` installs `RubyVM::InstructionSequence.load_iseq` (the hook bootsnap uses), so
`require` and `load` take the binary instead of parsing and compiling the source.

An instruction sequence remembers the path it was compiled for. `__FILE__`, `__dir__`,
`require_relative` and backtraces all read it, so a binary compiled in the build directory would
point every one of them back at the build machine. The binaries are therefore compiled for where
the app will be installed: `/Applications/MyApp.app/Contents/Resources/...` unless you pass
`--install-dir`. The app loads plain source, as it would without any of this, when:

- it runs from anywhere else (the manifest names the place it was compiled for),
- the Ruby is not the one that compiled it (the manifest and every binary carry `RUBY_REVISION`),
- a source file changed since (each binary carries the size and mtime of its source),
- a binary does not load (damaged, or another format).

`SCARPE_BYTECODE=0` turns it off for one launch. The DMG copy uses `ditto`, which keeps the mtimes;
a plain `FileUtils.cp_r` would reset them and every file would quietly load from source.

The compile step is also a boot check: it runs the bundled Ruby through `require "scarpe"`, so a
library the strip removed fails the build instead of the app (that is how `--minimal` was found to
remove `net/http`, `resolv` and `digest`, which the shim needs for image downloads; native minimal
builds put them back).

## YJIT

The bundled Traveling Ruby 3.4.7 (release 20251122, the newest) is built without YJIT:
`RubyVM::YJIT` is not defined. So YJIT does nothing in a packaged app today. The
policy is in place for a runtime that has it: `boot.rb` switches YJIT on at the first heartbeat,
once the app is up, and `RUBY_YJIT_ENABLE=0` keeps it off.

Why not at process start: on a YJIT build of Ruby (4.0.5 from mise, running the bundle's
`boot.rb` from source), YJIT from the start made the first frame 28 to 57 ms later, while
switching it on after boot cost 1 to 4 ms (headless, 5 interleaved rounds, medians):

| YJIT | button | othello |
|---|---|---|
| off | 136 ms | 149 ms |
| on after the first heartbeat (what `boot.rb` does) | 140 ms | 150 ms |
| on from process start (`RUBY_YJIT_ENABLE=1`) | 164 ms | 206 ms |

The Ruby YJIT speeds up is what runs every frame: `animate`, `every` and `motion` handlers.

## Numbers

Measured on an Apple silicon Mac (arm64, macOS 26.2), 27 Sep 2026, with
`scripts/native_cold_start.rb`: it packages a copy of the app with
`scripts/native_first_frame_probe.rb` appended, launches `Contents/MacOS/scarpe-launcher`, waits
for the first painted frame and reports milliseconds from exec to that frame. Variants run
round-robin, 5 rounds, medians. Other builds were sharing the machine (load average 12 to 15 for
the numbers below; earlier sessions at load 30 to 46 ran up to twice as slow and are left out). The
first launch after packaging took 390 to 660 ms (cold caches); the median drops it.

### Sizes

| | full | `--minimal` |
|---|---|---|
| `.app` | 32.4 MB | 17.7 MB |
| `.dmg` (button, othello, calc) | 13.4 / 12.5 / 12.4 MB | 6.5 MB (button) |
| `scarpe-native` | 6.5 MB (7.1 MB before `strip -x`) | 6.5 MB |
| Ruby runtime | 23.4 MB | 8.9 MB |
| Scarpe, Lacci, components source | 0.6 MB | 0.6 MB |
| bytecode | 1.5 MB | 1.5 MB |

Packaging takes about 20 seconds with the runtime cached, most of it `hdiutil` and `codesign`.

### Cold start to first frame

| app | mode | bytecode | no bytecode (`SCARPE_BYTECODE=0`) |
|---|---|---|---|
| button | headless | 117 ms | 123 ms |
| button | windowed, inactive | 157 ms | 165 ms |
| othello | headless | 123 ms | 134 ms |
| othello | windowed, inactive | 249 ms | 271 ms |

Where the time goes (button, 15 rounds, the bundled Ruby run directly):

| step | median |
|---|---|
| Ruby starts (`ruby -e ''`, RubyGems included) | 18 ms |
| `require "scarpe"` from source | +43 ms |
| `require "scarpe"` from bytecode | +28 ms |
| `scarpe-native --headless` start, handshake, exit | 22 ms |

Bytecode takes about 15 ms off `require "scarpe"` and 6 to 22 ms off the first frame. When these
were measured, the biggest single item left on the Ruby side was `lib/scarpe/native/normalize.rb`
requiring `net/http` and `uri` at load time for image downloads: 18 ms from source. Moving those
two requires into `download` measured 116 ms against 107 ms to first frame for button with
bytecode (15 rounds), and the shim now loads them on the first download (native/PERF.md).

## Try a packaged app without taking the keyboard

`open MyApp.app` activates the app. To check a build, run the launcher directly with an inactive
window that closes itself:

```sh
SCARPE_NATIVE_INACTIVE=1 SCARPE_NATIVE_ARGS='--exit-after 3' MyApp.app/Contents/MacOS/scarpe-launcher; echo $?
```

That prints `0` with nothing on stderr for button, othello and calc. From a script or an agent,
add `SCARPE_NATIVE_GHOST=1`: the window still opens and presents frames, but nobody sees it or can
click it (native/DESIGN.md section 12). Headless with a snapshot of the first frame:

```sh
ruby scripts/native_cold_start.rb myapp.rb --runs 1 --snapshot first_frame.png
```

`rake package_test` builds one small app for real, checks its contents and signature, boots it
headless from bytecode, boots a moved copy from source, checks that output sent to `/dev/null`
lands in the log, and that `font(path)` names and loads a font inside the bundle. The bundled Ruby
carries no encoding transcoders, so Lacci reads a font's UTF-16 names by hand; with
`String#encode`, `font` answered nil there and the font never reached the renderer.

A file an app reads from outside its own folder travels with `--include`, landing beside the app
under its own name: the Kids apps share `examples/native/kids/_fonts`, so they are packaged with
`--include ../_fonts`, and each looks for Fredoka in `_fonts/` beside itself as well as in
`../_fonts`.

Every recipe here passes the renderer a flag (`--headless`, `--ghost`, `--exit-after`), and a
double-click passes none. That difference once hid a start that failed only from Finder: with no
flags, Ruby handed the renderer's lone path to `/bin/sh`, and `ZARKING (Rust).app` was a syntax
error there. The shim now starts the renderer without a shell, and `rake native_test` starts a
stand-in from bundles named `ZARKING (Rust).app` and `For Noah.app` with no flags. The log above is
where to look when a double-click shows nothing.

## Not done yet

- Universal (`x86_64` + `arm64`) builds, Linux and Windows native packages.
- Notarisation. The app is ad-hoc signed, so a downloaded copy needs right-click, Open the first time.
- A Ruby runtime with YJIT.
- Bytecode for an app run from somewhere other than `--install-dir` (it loads source there). A
  per-user cache compiled on first launch, bootsnap-style, would cover it.
- LaunchServices identity: the window belongs to `scarpe-native`, a child of the launcher. Opened
  with `open` on 28 Sep 2026, ZARKING (Rust) checked in under its bundle name and id
  (`lsappinfo list`), frontmost; its Dock icon was not looked at. A program the app starts with
  `Shoes.run_program` draws with a second `scarpe-native` from the same bundle, which may show
  a second Dock icon for the app while it runs; nobody has looked.
- Like the webview packager, the app file, the pictures and sounds beside it and the `images`,
  `assets`, `fonts` and `sounds` folders are copied on their own; any other file or folder the
  app reads, `.rb` files it requires included, needs an `--include`.
