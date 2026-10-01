# Windows port: handover

From a cloud session (Linux container, no Windows machine) to a session on a real Windows
machine. Written 1 Oct 2026, at `main` = `8e5439f`. Delete this file once its open items are
done or moved elsewhere.

The cloud session could only test on Windows through the GitHub Actions leg
"Ruby 3.2 on Windows" in `.github/workflows/native.yml`. Everything below marked
**unverified** has never run on a real Windows desktop.

## Where things stand

The route to Windows is the **native display** (`scarpe --native`, the Rust renderer in
`native/`), not the webview. The renderer already built and passed its tests on Windows;
the Ruby side was Unix-only. The webview path is still blocked: `webview_ruby` 0.1.2 compiles
`webview.cpp` at install time, and its Windows backend needs MSVC and the WebView2 SDK (C++/WinRT
headers), which MinGW (RubyInstaller's toolchain) cannot build.

Commits on `main` (oldest first):

| commit | what |
|---|---|
| `3f5adc2` | Windows leg on the native Ruby CI job (experimental, `continue-on-error`); lockfile gains `x64-mingw-ucrt`; `webview_ruby`'s native build runs as `rake --dry-run` on Windows |
| `42219ba` | renderer and test children spawn with `new_pgroup` on Windows (Ruby rejects `pgroup:` there), are ended with KILL / `taskkill /T`; binary found as `scarpe-native.exe`; `Shoes.run_program` runs in-process on Windows; test helpers pass env as a Hash |
| `91bba34` | Windows leg uses Ruby 3.2: the locked nokogiri 1.15.7 and sqlite3 1.6.9 ship `x64-mingw-ucrt` gems for 3.1–3.2 only (nokogiri's libiconv fails to build from source with the runner's gcc); those two platform entries were added to `Gemfile.lock` by hand |
| `50f2374` | native shim tests: `.rb` stand-in renderer runs through Ruby; signal and run_program tests skip on Windows |
| `f78be32` | six tests fitted to Windows (cache path/modes, `.exe`, start-up timing, USR1, spec selftest) |
| `dd8c474` | spec sandbox passes `SystemRoot` & co. case-insensitively (MSYS bash upper-cases them; Winsock needs SystemRoot); drive-letter-aware test regexes; macOS-package tests skip on Windows |
| `c92b302` | `Child` reads the renderer's stdout on a thread + `Thread::Queue` on Windows instead of `IO.select` (which polls pipes every ~10 ms there); waits sliced at 0.1 s so Ctrl-C still wakes the pump |
| `8e5439f` | `app.clipboard` through the renderer (new `clipboard` req, arboard, Wayland feature on); Lacci fallback `Shoes::Clipboard` (PowerShell on Windows, wl-paste/wl-copy, xclip, pbpaste/pbcopy); `SCARPE_CLIPBOARD_FILE` stand-in used by spec/run and the Lacci tests |

### Last Windows CI results

Run 6 (`dd8c474`), the last one fully read:

| step | Windows |
|---|---|
| bundle, renderer build, Rust tests, component tests, spec selftest, package tests | pass |
| native shim tests (`rake native_test`) | 196 runs, 0 failures, 24 skips |
| Lacci | 258/259; the failure was the clipboard (fixed since, in `8e5439f`) |
| spec suite on Niente | 541 pass; 4 not: 3 clipboard (fixed since), `selfitude` (see below) |
| spec suite on native | 1022 pass, 6 fail, 8 error, 11 timeout |
| examples on native | 359 pass, 3 fail (`say`, `parrot`, `change_my_audio_source`: macOS commands) |

Run 7 (`c92b302`, the queue read path) and run 8 (`8e5439f`, clipboard) had not been read when
this was written. Run 7's Windows job (110423298522) still failed Lacci, Niente, native and
examples, which the clipboard and sound causes alone would explain; whether the 11 native
timeouts went away is **not known**.

## Open items, most useful first

1. **Read run 8's Windows job**, or better, run the suites on this machine (below). Expect the
   clipboard cases to pass now. If the 11 text-style native timeouts remain
   (`manual/elements-common/element.link.sspec`, `element.sup.default_style`,
   `element.sub.default_style`, `manual/styles/styles.rise__negative`, ...), profile one:
   they scan glyph boxes with thousands of `pixel_at` reqs, and the queue read path in
   `lib/scarpe/native/child.rb` (`WINDOWS_READS`) was meant to remove the ~10 ms per reply.
   Check it is taken (`Gem.win_platform?`) and time a single `pixel_at` round trip.
2. **Check the real clipboard by hand** (unverified): run an app with `--native` in a real
   window, `app.clipboard = "x"`, paste in Notepad, copy something in Notepad, read
   `app.clipboard`. Then the same with `SCARPE_DISPLAY_SERVICE=niente` (exercises
   `Shoes::Clipboard`'s PowerShell path, `lacci/lib/shoes/clipboard.rb`, never run on Windows;
   its scripts were only parsed and encoding-checked with pwsh on Linux).
3. **Run a real windowed app** (`bundle exec ruby exe/scarpe --native examples/button.rb`):
   nothing has opened an actual window on Windows yet. Also try Ctrl-C in the console
   (new_pgroup + the sliced queue wait), closing the window, and an app that calls
   `Shoes.run_program` (in-process on Windows).
4. **Sound** (agreed with the user, not started): a cross-platform sound call. Decided: make
   the manual's `video "file.wav"` actually play audio files, and add a small invisible call for
   sound effects, probably named `audio("pop.wav").play` (the user wrote "Instead of sound audio";
   confirm the name with them). Playback would go in the Rust renderer (e.g. `rodio`: CoreAudio,
   WASAPI, ALSA; Linux then needs `libasound2-dev` to build). Headless runs must record instead of
   play, so the `kids/` specs can assert what was played. Then port the ten
   `examples/native/kids/*` apps off `afplay` (they synthesise WAVs in Ruby and `spawn("afplay")`).
   New features need an entry in `docs/SCARPE_FEATURES.md`.
5. **Speech** (agreed, not started): a cross-platform text-to-speech call (macOS `say`, Windows'
   built-in voices via PowerShell `System.Speech`, Linux `spd-say`/`espeak` if installed), plus a
   voice list, so `examples/skip_ci/say.rb` and `parrot.rb` can use it. `change_my_audio_source.rb`
   drives Homebrew's `SwitchAudioSource` (picks the Mac's output device); leave it macOS-only.
6. **`selfitude`** (`spec/shoes_spec/examples/selfitude.sspec`, from `examples/selfitude.rb`)
   writes to a hard-coded `/tmp/shoesy_stuff.txt`. The case is generated by
   `spec/import_shoes_spec.rb`, whose `FIXES` only rewrite test code, so either the importer or
   the example has to change.
7. **Remaining Windows-only gaps in the code**: `Shoes.run_program` in its own process (it
   talks to the child on fds 3 and 4, which Windows cannot hand over; a loopback socket would do);
   native packaging is macOS-only; the webview needs a Windows `webview_ruby` build (MSVC).
8. When the Windows leg is green, make it count: drop `experimental: true` from the
   `Ruby 3.2 on Windows` matrix entry in `native.yml` (and the Rust Windows leg's), and update
   `FOR_AGENTS.md` ("Windows | not yet") and `docs/native_ci.md`.

## Running it on this machine

- Ruby: RubyInstaller **Ruby+Devkit 3.2** (x64). Not 3.3+ until nokogiri/sqlite3 are bumped:
  the locked versions have prebuilt Windows gems only for 3.1–3.2.
- Rust: rustup with the MSVC toolchain; the crate promises Rust 1.89.
- Gems: `webview_ruby` cannot build here, so skip its native build:
  `set BUNDLE_BUILD__WEBVIEW_RUBY=--dry-run` (PowerShell: `$env:BUNDLE_BUILD__WEBVIEW_RUBY="--dry-run"`),
  then `bundle install`.
- `git config core.autocrlf false` before checking out, as the CI does.
- Build the renderer: `cd native && cargo build --release --locked`.
- Suites (what CI runs, in a bash shell such as Git Bash; `spec/run` is a Ruby script):
  `bundle exec rake native_test`, `lacci_test`, `component_test`, `spec:selftest`,
  `spec/run --check`, `spec/run --display niente`, `spec/run --display native --no-build`,
  `spec/run --examples --display native --no-build`, `bundle exec rake package_test`.
- CI puts `spec/support/fakebin` first on `PATH`; its stand-ins are `/bin/sh` scripts, which do
  nothing on Windows. The clipboard no longer needs them (`SCARPE_CLIPBOARD_FILE`); sound and
  `say` still do, which is why the `kids/` sound cases fail on Windows until item 4.

## Things learned the hard way

- `Process.spawn(..., pgroup: true)` raises `ArgumentError: wrong exec option symbol: pgroup` on
  Windows; use `new_pgroup: true`. `Process.kill(sig, -pid)` and TERM do not work there.
- `IO.select` on a pipe polls about every 10 ms on Windows; a signal trap runs only once
  `Thread::Queue#pop` returns.
- Under MSYS bash, Windows variables arrive upper-cased (`SYSTEMROOT`); a scratch environment
  built with `unsetenv_others` must copy them case-insensitively or Winsock fails with E10106.
- The GitHub log tool returns at most the last 5000 lines of a job, and the log blob host is
  blocked in the cloud container, so a long failing run can hide its first failures.
