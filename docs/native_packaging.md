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
| `--minimal` | strip optional Ruby libraries: a 17.7 MB app instead of 32.4 MB; OpenSSL goes, so https image downloads cannot work |
| `--name`, `--icon`, `--output`, `--verbose` | as for any `scarpe package` build |

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
  Resources/app/                  myapp.rb and its assets
  Resources/scarpe/               lib, lacci/lib, scarpe-components/lib, CHANGELOG   0.6 MB
  Resources/bytecode/             150 precompiled files and a manifest               1.5 MB
  Resources/runtime/ruby/         Traveling Ruby 3.4.7, stripped                    23.4 MB
  Resources/licenses/             Inter and Fira Mono (OFL), compiled into the binary
```

`lib/` goes in without the webview display service (`scarpe/wv*`, `scarpe/assets.rb`) and without
the packager itself. No gems are copied at all: Lacci and the shim need only Ruby's standard
library, and Shoes-Spec (minitest) stays out, so `Shoes::Spec` is off in a packaged app.

Starting the app: LaunchServices runs `scarpe-launcher`, which sets `RUBYLIB`, `GEM_HOME` and
`SCARPE_NATIVE_BIN` for the bundle and execs the bundled Ruby on `boot.rb`. Ruby loads Lacci and
the shim, and the shim starts `scarpe-native` beside the launcher as its child, as in development.

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
remove `net/http`, `resolv` and `digest`, which the shim loads at boot; native minimal builds put
them back).

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

Bytecode takes about 15 ms off `require "scarpe"` and 6 to 22 ms off the first frame. The biggest
single item left on the Ruby side is `lib/scarpe/native/normalize.rb` requiring `net/http` and
`uri` at load time for image downloads: 18 ms from source. Moving those two requires into
`download` measured 116 ms against 107 ms to first frame for button with bytecode (15 rounds).

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
headless from bytecode, and boots a moved copy from source.

## Not done yet

- Universal (`x86_64` + `arm64`) builds, Linux and Windows native packages.
- Notarisation. The app is ad-hoc signed, so a downloaded copy needs right-click, Open the first time.
- A Ruby runtime with YJIT.
- Bytecode for an app run from somewhere other than `--install-dir` (it loads source there). A
  per-user cache compiled on first launch, bootsnap-style, would cover it.
- LaunchServices identity: the window belongs to `scarpe-native`, a child of the launcher. Dock
  name and icon for a double-clicked app were not checked, since that needs `open`.
- Like the webview packager, only the app file and its assets are copied; other `.rb` files the
  app requires are not.
