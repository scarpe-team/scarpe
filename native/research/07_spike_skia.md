# Spike A: custom-rendered Rust stack (tiny-skia + cosmic-text + winit + softbuffer)

Verdict: **it works, first try, and it is fast.** The full Shoes-ish scene renders headless to a 1600x1200 PNG in **~1.9 ms per frame** (release, warm glyph cache, M5), opens a real Retina window that presents **~120-150 fps** for 3 s and exits cleanly with exit code 0, and the same `Scene` object answers synthetic clicks, link hits and typing with no window at all. Output is **bit-identical run to run** (md5 stable). The weak spots are all in text *appearance* vs CoreText: text is ~15% lighter than native, and the macOS system font renders with the wrong optical size (tight tracking). Both have measured fixes or workarounds, listed below.

Everything lives in `<scratch>/spikes/a` (call it `$A`).

## 1. Artifacts

| File | What |
|---|---|
| `$A/scene.png` | 1600x1200 headless render (2x of 800x600 logical), system fonts |
| `$A/scene_after.png` | same scene after the synthetic click/typing session (visited link purple, typed edit_line) |
| `$A/scene_1x.png` | 800x600 at scale 1.0 |
| `$A/scene_bundled.png`, `scene_after_bundled.png`, `scene_1x_bundled.png` | deterministic mode: only bundled Inter, zero system fonts |
| `$A/window_last_frame.png` | the exact pixmap last handed to softbuffer in `--window` mode (pressed Help button, text typed via EventLoopProxy). It is our buffer, not a screen capture. |
| `$A/compare/coretext.png`, `coretext_font.png` | same para rendered by AppKit/CoreText (`compare/coretext.swift`), SF and Helvetica Neue |
| `$A/compare/ours.png`, `ours_font.png` | our render of that strip |
| `$A/run_headless.txt`, `run_headless_bundled.txt` | full transcripts |
| `$A/src/paint.rs` (253 lines) | glyph blitter, `draw_buffer`, rounded rect, star, experimental embolden rasteriser |
| `$A/src/scene.rs` (505 lines) | retained scene, layout of flow, render, hit test, click routing, editor plumbing |
| `$A/src/main.rs` (473 lines) | headless + bench + synthetic session, `--window`, `--compare`, `--bundled-fonts` |
| `$A/src/bin/{fontprobe,shapeprobe,axesprobe}.rs` | font resolution, kerning/ligature/fallback, variation-axis probes |
| `$A/fonts/InterVariable*.ttf` + `Inter-LICENSE` (OFL) | copied from the cosmic-text crate's `fonts/` dir |

Run: `cd $A && cargo build --release && ./target/release/shoes_skia_spike` (headless), `... --bundled-fonts`, `... --window` (3 s, scripted, does not take focus), `... --window --seconds 0` (interactive until closed), `FONT="Helvetica Neue" ./target/release/shoes_skia_spike --compare`.

## 2. Versions and Cargo.toml that worked

Resolved (Cargo.lock): tiny-skia **0.12.0**, cosmic-text **0.19.0** (pulls fontdb 0.23.0, harfrust 0.5.2, skrifa 0.40.0 and 0.44.0, swash 0.2.10), winit **0.30.13**, softbuffer **0.4.8**, image **0.25.10**. rustc 1.93.1. cosmic-text 0.19 has `rust-version = 1.89`.

```toml
[dependencies]
tiny-skia = "0.12"          # default features: std, simd, png-format
cosmic-text = "0.19"        # default features: std, swash, fontconfig (swash is REQUIRED for SwashCache/Shaping::Basic)
winit = "0.30"              # NOT 0.31 (0.31.0-beta.3 is the crates.io "latest")
softbuffer = "0.4"
swash = "0.2"               # only needed for the custom embolden rasteriser experiment
image = { version = "0.25", default-features = false, features = ["png"] }

[profile.dev]
opt-level = 1
[profile.dev.package."*"]
opt-level = 3               # without this a debug frame is ~150 ms instead of ~7 ms
```

Notes: `cosmic_text::fontdb` is re-exported (`cosmic-text/src/font/system.rs:14`), so no direct fontdb dep is needed. On Linux, winit's default `wayland-csd-adwaita` feature pulls a second copy, tiny-skia 0.11.4 (it did not compile on macOS; `cargo tree -i tiny-skia@0.11.4` is empty for the host target).

## 3. Measurements (Apple M5, macOS 26.2, 10 cores)

The machine was shared with other lanes (load average 6 to 64 during runs). Quiet-ish numbers first, loaded numbers in brackets.

| Metric | Value |
|---|---|
| Headless raster @2x (1600x1200), avg of 50 frames, warm glyph cache | **1.90 ms** (min 1.84, median 1.90, p90 1.95) [loaded: 2.3 to 3.6 ms avg] |
| Re-shape all text + raster @2x, avg of 50 | 2.06 ms [loaded: 2.9 to 4.4 ms] |
| Raster @1x (800x600), avg of 50 | 0.70 ms |
| First frame, cold glyph cache @2x | 4.6 to 5.6 ms |
| `pixmap.fill` 1600x1200 | 0.07 to 0.24 ms |
| RGBA8 premultiplied -> softbuffer `0x00RRGGBB` u32 conversion | 0.28 ms |
| `FontSystem::new()` (822 system faces) | 11 ms warm disk cache, up to 150 ms cold |
| `Scene::new` (shape all text, first font matching) with system fonts | 26 to 45 ms (cost is `get_font_matches` scanning all 822 faces per distinct `Attrs`) |
| Same with bundled fonts only (`--bundled-fonts`) | FontSystem 1.7 ms, Scene::new 1.4 ms |
| Window mode, 3 s | 358 to 471 frames (119 to 157 fps); render 2.1 to 2.7 ms, `buffer_mut`+convert 0.34 to 0.45 ms, `present()` **3.9 to 4.6 ms** |
| Cold `cargo build --release` (deps already downloaded, 91 crates) | **19.3 s** wall / 136 s CPU [45.7 s under load 20 to 55] |
| Cold `cargo build` (dev, deps opt-level 3) | 50 s under load; plain dev profile 19 s |
| Incremental release rebuild after touching main.rs | 1.7 to 2.3 s; dev 0.6 s |
| Debug-build frame without the dev profile tweak | 150 ms (60x slower) ; with it 7 ms |
| Release binary | 4.2 MB (6.3 MB with 1.8 MB of Inter embedded via `include_bytes!`), stripped 3.5 MB |
| Peak memory | headless 43 MB RSS / 32 MB footprint; window 133 MB RSS / 63 MB footprint |
| Glyph image cache entries for the scene | 533 to 535 |

`present()` on AppKit copies the whole buffer into a `CGImage` every frame (softbuffer doc, `softbuffer-0.4.8/src/lib.rs:197-200`, "Currently Buffer::present must block copying image data on ... AppKit"). It dominates frame time; a real app should redraw on demand (`ControlFlow::Wait`), not in a Poll loop like the spike's fps test.

## 4. The scene and what each element used

Logical 800x600, all drawing in logical coords with `Transform::from_scale(scale, scale)`; text laid out in logical px and rasterised at physical size via `LayoutGlyph::physical(offset, scale)`.

- **Background** `pm.fill(Color::from_rgba8(0xf7,0xf7,0xf5,0xff))`.
- **title** 34 px bold (manual: "Shoes styles these elements to 34 pixels high", `docs/static/manual.md:2127-2129`), with an emoji; the emoji rasterises as `SwashContent::Color` (Apple Color Emoji sbix) and blits fine.
- **para** 16 px with 9 rich spans (plain, `strong` bold, `em` italic, blue underlined link, red span). Also a 12 px line (manual para size, `manual.md:2064-2067`) to judge small text.
- **flow(width: 300) of 6 buttons** wraps onto exactly 2 lines (asserted in the transcript: rows at y=180 and y=216). Rounded 6 px, vertical `LinearGradient` fill, 1 px border inset by 0.5, two translucent shadow paths, centred 13 px label measured from `LayoutRun::line_w`. Hover and pressed variants.
- **edit_line x2**: box + focus ring; one empty (placeholder + caret), one filled purely through `Editor` actions with "Rust" selected via `set_selection(Selection::Normal(cursor))` + `Motion::LeftWord`.
- **rect(curve: 16)** filled by a diagonal `LinearGradient` (purple to blue) with white semibold caption on top.
- **oval** `PathBuilder::from_oval(Rect)`, fill tomato at alpha 115, stroke width 3, drawn over a solid block so alpha is visible.
- **5-point star** `star(470, 465, 5, 90, 38)`: 10-vertex concave polygon, `FillRule::Winding`, stroke width 2 with `LineJoin::Round`. Fills correctly.
- **line** width 3, `LineCap::Round`.

## 5. Exact API calls that worked

### 5.1 tiny-skia 0.12
- `Pixmap::new(w, h) -> Option<Pixmap>`; `pm.fill(Color)`; `pm.data_mut() -> &mut [u8]` (RGBA8 **premultiplied**); `pm.data()`; `pm.clone().take_demultiplied() -> Vec<u8>` (new in 0.12; feed to `image::RgbaImage::from_raw`).
- `Paint::default()`; `paint.set_color_rgba8(r,g,b,a)`; `paint.shader = Shader::SolidColor(Color)`; fields `anti_alias: bool`, `blend_mode`, `colorspace: ColorSpace` (new in 0.12, default `Linear` = blend in sRGB bytes like browsers; `Gamma2`, `SimpleSRGB`, `FullSRGBGamma` force the high-quality pipeline, `tiny-skia-0.12.0/src/color.rs:453-477`, `painter.rs:49-56`).
- `pm.fill_path(&path, &paint, FillRule::Winding, transform, None)`, `pm.stroke_path(&path, &paint, &Stroke { width, line_cap: LineCap::Round, line_join: LineJoin::Round, ..Stroke::default() }, transform, None)`, `pm.fill_rect(Rect, &paint, transform, None)`.
- `LinearGradient::new(Point::from_xy(..), Point::from_xy(..), vec![GradientStop::new(0.0, Color), GradientStop::new(1.0, Color)], SpreadMode::Pad, Transform::identity()) -> Option<Shader<'static>>`. Gradient points are in path space; the `transform` passed to `fill_path` scales them too, so logical coordinates just work.
- `RadialGradient::new(start: Point, start_radius: f32, end: Point, end_radius: f32, stops, mode, transform)`: **0.12 added `start_radius`** (changelog). `SweepGradient` is new in 0.12.
- `PathBuilder::new()`, `move_to`, `line_to`, `quad_to`, `cubic_to`, `close`, `finish() -> Option<Path>`; `PathBuilder::from_rect(Rect) -> Path`, `from_oval(Rect) -> Option<Path>`, `from_circle(cx, cy, r) -> Option<Path>`, `push_rect/push_oval/push_circle/push_path`. **No rounded-rect and no arc helper**: `$A/src/paint.rs:218` `rounded_rect()` (cubic k = 0.5522848) and `:238` `star()`. Shoes `arc`/`arc_to` will need a cubic arc helper.
- Clipping: `Mask::new(w,h)`, `mask.fill_path(&path, FillRule, anti_alias, transform)` (`mask.rs:259`), pass `Some(&mask)` to any fill/stroke. Images: `pm.draw_pixmap(x, y, pixmap.as_ref(), &PixmapPaint { opacity, blend_mode, quality: FilterQuality::Bicubic }, transform, None)`.
- **No blur** anywhere in tiny-skia: Shoes `shadow`/`blur` effects need a hand-written box blur on a Pixmap.

### 5.2 cosmic-text 0.19
- `FontSystem::new()` loads all system fonts (`font/system.rs:191`). Deterministic alternative (`$A/src/main.rs:29`):
  ```rust
  let mut db = cosmic_text::fontdb::Database::new();
  db.load_font_data(include_bytes!("../fonts/InterVariable.ttf").to_vec());
  db.load_font_data(include_bytes!("../fonts/InterVariable-Italic.ttf").to_vec());
  db.set_sans_serif_family("Inter Variable");
  let fs = FontSystem::new_with_locale_and_db("en-US".into(), db);
  ```
- `Buffer::new(&mut fs, Metrics::new(font_size, line_height))` (panics if line_height is 0); `buffer.set_size(Some(w), None)`; `buffer.set_wrap(Wrap::Word | WordOrGlyph | Glyph | None)` (default `WordOrGlyph`); `buffer.set_text(&str, &Attrs, Shaping::Advanced, None::<Align>)`; `buffer.set_rich_text(spans, &default_attrs, Shaping::Advanced, None)` where `spans: IntoIterator<Item = (&str, Attrs)>` (`buffer.rs:1102`); **then** `buffer.shape_until_scroll(&mut fs, false)` before reading layout (set_text does not shape).
- `Attrs::new().family(Family::SansSerif).weight(Weight::BOLD).style(Style::Italic).color(cosmic_text::Color::rgb(r,g,b)).underline(UnderlineStyle::Single).metadata(usize)` (`attrs.rs:323-382`); also `.strikethrough()`, `.overline()`, `.underline_color(c)`, `.letter_spacing(em)`, `.metrics(Metrics)` (per-span size, used for `sub`/`sup`/`size:`), `.font_features(..)`. `Attrs` is `Clone`, not `Copy`: use `base.clone().weight(..)`.
- Reading layout: `for run in buffer.layout_runs()` gives `LayoutRun { line_i, text, rtl, glyphs: &[LayoutGlyph], decorations: &[DecorationSpan], line_y (baseline), line_top, line_height, line_w }` (`buffer.rs:36-55`). Text block size = max `line_w`, height = last `line_top + line_height`.
- `LayoutGlyph` has `start, end` (byte range in the line), `x, y, w`, `font_id`, `font_weight`, `color_opt`, **`metadata`** (copied from `Attrs::metadata`, `layout.rs:60`), `cache_key_flags`.
- Rasterise: `let pg = glyph.physical((ox * scale, (oy + run.line_y) * scale), scale);` (offset is PHYSICAL px, `layout.rs:89`), then `swash_cache.get_image(&mut fs, pg.cache_key) -> &Option<SwashImage>` (`swash.rs:164`); image fields `placement { left, top, width, height }`, `content: SwashContent::{Mask, Color, SubpixelMask}`, `data: Vec<u8>`. Blit at `(pg.x + placement.left, pg.y - placement.top)`: `$A/src/paint.rs:42` `blit_glyph()` does premultiplied source-over into `pm.data_mut()`. `SubpixelMask` is never produced by cosmic-text (it always requests `Format::Alpha`), so it is grayscale AA only.
- Decorations: cosmic-text 0.19 computes them (`run.decorations`, each `DecorationSpan { glyph_range, data: GlyphDecorationData { text_decoration, underline_metrics: DecorationMetrics { offset, thickness } (EM units), strikethrough_metrics, ascent }, color_opt, font_size }`), and `cosmic_text::render_decoration(renderer, &run, color)` draws them through the `Renderer` trait in **logical i32** rects. I drew them myself in float, snapped to the physical grid (`$A/src/paint.rs:173-203`): `y = round((oy + line_y - offset*font_size)*scale)`, `h = max(round(thickness*font_size*scale), 1)`.
- `Renderer` trait (`render.rs:11-18`: `fn rectangle(&mut self, x, y, w, h, Color)`, `fn glyph(&mut self, PhysicalGlyph, Color)`) plus `buffer.render(&mut fs, &mut renderer, color)` is the other route; it calls `glyph.physical((0., run.line_y), 1.0)`, i.e. **scale 1 only**, so it is unsuitable for HiDPI without your own loop.

### 5.3 winit 0.30.13 + softbuffer 0.4.8
- `EventLoop::<Cmd>::with_user_event().build()`, `event_loop.create_proxy()` then `proxy.send_event(cmd)` from any thread; `impl ApplicationHandler<Cmd> for App { resumed, window_event, user_event, about_to_wait }`; `event_loop.run_app(&mut app)`; `el.exit()`. This is the natural hook for a Lacci IPC reader thread. Proven: a background thread drove link click, focus, typing and a button press into the live window (`$A/src/main.rs:331-344`, transcript in section 6).
- Window: `el.create_window(Window::default_attributes().with_title(..).with_inner_size(LogicalSize::new(800.0, 600.0)).with_active(false))`; `window.scale_factor()` = 2.0 here, `inner_size()` = 1600x1200 physical.
- **Focus theft:** the first scripted run showed `"engetyped via EventLoopProxy"`, i.e. keystrokes typed elsewhere landed in the test window because it activated itself. For automated runs use `.with_active(false)` and, on macOS, `winit::platform::macos::EventLoopBuilderExtMacOS::with_activate_ignoring_other_apps(false)` (`winit-0.30.13/src/platform/macos.rs:435`). Applied in `$A/src/main.rs`; later runs were clean, but I cannot prove nobody typed.
- softbuffer: `softbuffer::Context::new(window.clone())` and `softbuffer::Surface::new(&context, window.clone())` with `Rc<Window>`; `surface.resize(NonZeroU32, NonZeroU32)` (only when size changes); `let mut buf = surface.buffer_mut()?; /* write u32 */; buf.present()?`. Pixel format is `0x00RRGGBB` per u32 (`lib.rs:170-186`, bit layout at `:183`), so convert from tiny-skia's premultiplied RGBA bytes (`$A/src/main.rs:180`); opaque background means no demultiply needed.
- Mouse: `WindowEvent::CursorMoved { position }` is physical; divide by `scale_factor()`. Keys: `KeyEvent.logical_key` (`Key::Named(NamedKey::ArrowLeft)`, ...) and `event.text: Option<SmolStr>` for insertion; `WindowEvent::ModifiersChanged(m)` then `m.state().shift_key()`.

## 6. cosmic-text answers

### 6.1 System fonts on macOS
`FontSystem::new()` found **822 faces**, locale `en-GB`. cosmic-text hardcodes default families that do not exist on macOS (`font/system.rs:204-206`: monospace "Noto Sans Mono", sans "Open Sans", serif "DejaVu Serif"). Resolution observed (`fontprobe`):

| Request | Face actually used |
|---|---|
| `Family::SansSerif` | **"System Font" `.SFNS-Regular`** (San Francisco), reached via the macOS fallback list (`font/fallback/macos.rs:30-38`: ".SF NS", "Menlo", "Apple Color Emoji", "Geneva", "Arial Unicode MS") |
| SansSerif + `Weight::BOLD` | same `.SFNS-Regular` file, bold through the variable `wght` axis (glyph.font_weight=700, line gets wider 79.94 to 86.37) |
| SansSerif + `Style::Italic` | real `.SFNS-RegularItalic` (no FAKE_ITALIC flag) |
| `Family::Serif` | **also San Francisco** (DejaVu Serif missing): serif text silently renders sans |
| `Family::Monospace` | Menlo (via fallback) |
| `Family::Name("NoSuchFont")` | San Francisco |

Fix for builders: at startup call `fs.db_mut().set_serif_family("Times New Roman")`, `set_monospace_family("Menlo")`, and optionally `set_sans_serif_family("Helvetica Neue")` (all verified to resolve to real Regular/Bold/Italic faces). Per-OS defaults are needed on Linux/Windows too.

### 6.2 Shaping quality
- **Kerning works** with `Shaping::Advanced` (harfrust): "AV" 38.02 vs 40.52 unkerned, "To" 31.36 vs 35.58, "AVATAR" 107.69 vs 118.94. `Shaping::Basic` does **no kerning and no fallback** (emoji/CJK become gid 0 tofu). Always use Advanced.
- Ligatures: Helvetica Neue forms `ffi` and `fl`; SF and Times New Roman do not (font design, not a bug).
- Fallback: emoji to AppleColorEmoji (renders in colour), Arabic to GeezaPro (RTL), **CJK to ArialUnicodeMS**, not PingFang/Hiragino (the `han_unification` list names "PingFang SC", which fontdb does not see, presumably because it is a downloadable asset font).

### 6.3 Rich text with per-span attrs
`set_rich_text` with `(text, Attrs)` pairs, one `Attrs::metadata(id)` per Shoes text fragment. Spans equal to the default attrs are not stored in the line's `AttrsList` (`buffer.rs:1019-1022`), so give every clickable fragment a non-zero metadata. Each glyph carries its span's `metadata`, colour and decorations.

### 6.4 Hit-testing a point to a glyph/span (link clicks)
Two working routes, both in the transcript:
1. **Glyph scan** (`$A/src/scene.rs:394`): for each `run`, check `line_top <= y < line_top + line_height`, then find the glyph with `g.x <= x < g.x + g.w` and read `g.metadata`. Precise: returns nothing in blank space.
2. **`Buffer::hit(x, y) -> Option<Cursor { line, index, affinity }>`** (`buffer.rs:1144`) then `buffer.lines[c.line].attrs_list().get_span(c.index).metadata` (`attrs.rs:543`). Caveat: `hit` always returns a cursor (nearest position, even past the end of a line or below the text), so it needs a bounds check before being treated as a click on a span.

Transcript:
```
click link at (743.3,89.5) -> Some(Link("link you can click"))
click strong at (531.0,89.5) -> Some(ParaSpan(1, "strong words"))
Buffer::hit(713.3,11.5) -> Cursor { line: 0, index: 106, affinity: Before } -> attrs_list().get_span(index).metadata = 3
click blank at (700,150) -> None
click Help at (57.0,230.0) -> Some(Button(4, "Help"))
```
(the link wraps across two visual lines; the whole-span text comes from `attrs_list().spans_iter()`, `$A/src/scene.rs:497`).

### 6.5 Editor (edit_line / edit_box)
`Editor::new(buffer)` (owned `Buffer` converts into `BufferRef`), trait `cosmic_text::Edit` must be in scope. Out of the box:
- **Insert/delete:** `editor.action(&mut fs, Action::Insert(c))`, `Action::Backspace`, `Action::Delete`, `Action::Enter`, `Action::Indent/Unindent`; `insert_string(&str, None)`, `delete_selection()`, `copy_selection() -> Option<String>`.
- **Cursor movement:** `Action::Motion(Motion::{Left, Right, Previous, Next, Up, Down, Home, SoftHome, End, LeftWord, RightWord, PreviousWord, NextWord, ParagraphStart, ParagraphEnd, PageUp, PageDown, BufferStart, BufferEnd, GotoLine(n), Vertical(px)})` (`cursor.rs:87-132`).
- **Selection:** `Selection::{None, Normal(anchor), Line(anchor), Word(anchor)}`; `set_selection`, `selection_bounds() -> Option<(Cursor, Cursor)>`; mouse: `Action::Click { x, y }`, `DoubleClick` (selects word), `TripleClick` (line), `Drag` (extends from current cursor), coordinates are **i32 relative to the buffer origin**. `Action::Escape` clears selection. `Action::Scroll { pixels }`.
- **Not handled for you:** shift-extension and plain-motion collapse. `Action::Motion` never touches the selection (transcript: plain Right after shift+Home still reports a selection). The key handler must `set_selection(Selection::Normal(cursor))` when shift is held and no selection exists, and `set_selection(Selection::None)` when it is not (`$A/src/main.rs:303-311`). Also missing: clipboard integration, IME/preedit, undo stack (only `start_change`/`finish_change`/`apply_change` primitives), password masking for `edit_line(secret: true)`, placeholder text.
- Drawing: `editor.shape_as_needed(&mut fs, false)`, then `editor.with_buffer(|buf| ...)`; selection rects from `LayoutRun::highlight(start, end) -> impl Iterator<Item = (x, width)>` (`buffer.rs:66`), caret x from `LayoutRun::cursor_position(&cursor) -> Option<f32>` (`buffer.rs:120`). `Editor::render` exists but draws a 1 px caret at scale 1 via the Renderer trait.

Transcript:
```
typed -> "Nick Schwaderer" cursor=Cursor { line: 0, index: 15, affinity: Before }
LeftWord + Backspace -> "NickSchwaderer" cursor=Cursor { line: 0, index: 4, affinity: Before }
End, shift+Home -> selection_bounds=Some((Cursor{0,0}, Cursor{0,15})) copy_selection=Some("Nick Schwaderer")
Right w/o clearing selection -> selection_bounds=Some((Cursor{0,1}, Cursor{0,15})) (Motion does NOT clear selection)
click at text x=20 -> Some(EditLine(0)); Editor Action::Click moved cursor to Cursor { line: 0, index: 3, affinity: After }
DoubleClick x=50 -> selection=Word(Cursor { line: 0, index: 8, affinity: After }) copy=Some("Schwaderer")
```
Window mode, driven from a background thread through `EventLoopProxy`:
```
proxy click (740,89.5) -> Some(Link("link you can click"))
proxy click (160,285) -> Some(EditLine(0))
proxy typed -> Some("typed via EventLoopProxy")
proxy click (57,230) -> Some(Button(4, "Help"))
window closed cleanly: 462 frames in 3.00s (153.9 fps); avg render 2.147907ms, avg buffer_mut+convert 348.063µs, avg present 3.906114ms
```

## 7. Ugly spots

1. **Wrong optical size for San Francisco.** SFNS is variable with axes `wdth[30..150]`, `opsz[17..96 default 28]`, `GRAD`, `wght`, plus a `trak` table (`axesprobe`). cosmic-text only ever sets `wght` (`font/mod.rs:143` for shaping, `swash.rs:31-40` for raster), so every size renders at opsz 28 ("Display") with no tracking. Result: 12 to 16 px text is visibly tighter than native (see `compare/ours_crop.png` vs `coretext_crop.png`; CoreText's line is about a word longer at the same width; in the gradient caption "t(" nearly touch). It cannot be fixed at raster time alone because advances come from shaping. Options: use a static font (Helvetica Neue; metrics then match CoreText exactly), bundle a font, or fork cosmic-text to pass `opsz = font_size` in both places (small patch, not attempted).
2. **Text is about 15% lighter than CoreText.** "Ink" (sum of darkness) ours/CoreText: SF 0.836 (16 px) and 0.868 (12 px); Helvetica Neue, where metrics are identical, 0.842 and 0.874. So it is the rasteriser (CoreText stem darkening), not the font. A coverage gamma LUT (`TEXT_GAMMA`, `$A/src/paint.rs:28`) only closes part of it (gamma 0.7 gives 0.891/0.939). **swash `Render::embolden(0.2)` at 2x matches CoreText within 5%** (0.970 / 1.048) and looks right side by side. It needs our own rasteriser because cosmic-text hardcodes its `Render` (`TEXT_EMBOLDEN`, `$A/src/paint.rs:110-146`, a 30-line copy of `cosmic-text/src/swash.rs:18-80` with `.embolden(strength)`; note a separate glyph cache keyed by `CacheKey`).
3. **Blending/gamma.** Glyph masks and tiny-skia paths blend in sRGB byte space (tiny-skia `ColorSpace::Linear`, the default). That matches how browsers composite, so Scarpe-Webview and native screenshots stay comparable for alpha; it is also why light-on-dark text looks slightly thin (the white caption on the gradient is fine at 2x).
4. **Grayscale AA only, no LCD subpixel AA, and no metric hinting by default** (`Hinting::Disabled`, `layout.rs:197`). At 1x, 12 px text is legible but soft (`scene_1x.png`). For 1x displays use `buffer.set_hinting(Hinting::Enabled)` with layout in physical px; not tested here.
5. **Colour on macOS is unmanaged:** softbuffer's CoreGraphics backend tags frames with `CGColorSpace::new_device_rgb()` (`softbuffer-0.4.8/src/backends/cg.rs:229`), so on a P3 panel sRGB colours come out slightly more saturated than the Webview's.
6. **`present()` copies** 7.7 MB per frame on AppKit (3.9 to 4.6 ms): fine for on-demand redraw, wasteful for animation. No damage-rect benefit on macOS (`present_with_damage` exists but CG copies anyway).
7. Cosmetic: the caret overlaps the first placeholder glyph (drawn at the same x); emoji sits a little high on the title baseline; CJK falls back to Arial Unicode MS.
8. Bundled-only mode has **no emoji** (Inter's "NO GLYPH" box, visible in `scene_bundled.png`); a deterministic spec font set would need a colour emoji font (untested whether swash handles CBDT/COLRv1 in e.g. Noto Color Emoji).
9. **Debug builds are unusable without optimising deps** (150 ms/frame); keep the `[profile.dev.package."*"] opt-level = 3` block.
10. This stack draws its own widgets. There is no accessibility tree (VoiceOver sees nothing), no native menus, dialogs, clipboard or IME. Crates that would cover those (accesskit/accesskit_winit, muda, rfd, arboard, winit `WindowEvent::Ime`) were **not** exercised in this spike.

## 8. Recommendations for the builders

- **Architecture that fell out naturally:** a retained `Scene` (plain Rust structs per drawable, logical px) with `render(&mut Pixmap, scale)`, `hit(x, y) -> Option<Hit>`, `click(x, y)`, `key_action(Action)`. The window, the headless PNG path and the synthetic test path all call the same methods, so a spec can "click" at logical coordinates and assert both on returned hits and on the PNG. That is the cheapest way to get the "look and click" tests Nick asked for.
- **Commands from Ruby:** read IPC on a background thread and forward with `EventLoopProxy::send_event`; handle in `ApplicationHandler::user_event`, mutate the scene, `window.request_redraw()`. Use `ControlFlow::Wait` for real apps; the spike's Poll loop only exists to measure fps.
- **Deterministic specs:** build the `FontSystem` from bundled fonts only (`fontdb::Database::new()` + `load_font_data` + `FontSystem::new_with_locale_and_db`). It is 50x faster to start (1.7 ms vs 30 to 150 ms), independent of the host's fonts, and output was bit-identical across runs. Cross-architecture pixel identity (x86 SIMD vs NEON in tiny-skia) is unverified, so golden-image comparison should allow a small tolerance.
- **Real apps:** system `FontSystem::new()` on a background thread during window creation (it plus first font matching can take 50 to 200 ms), then set serif/mono/sans families explicitly (section 6.1).
- **Text:** lay out in logical px, rasterise with `glyph.physical(offset_physical, scale)`, draw decorations yourself in float, give every span a `metadata` id, and hit-test by glyph scan. Consider the embolden rasteriser if matching macOS text weight matters.
- **Shapes still to write:** rounded rect (done), star (done), arc and `arc_to`, blur/shadow (no support in tiny-skia), Shoes `cap` (:curve/:rect/:project map to `LineCap::Round/Butt/Square`), `rotate/translate/scale/skew` map to `Transform`.
