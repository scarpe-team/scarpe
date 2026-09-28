# 08 · Spike B: egui / eframe / egui_kittest as a Shoes renderer

Spike dir: `<scratch>/spikes/b` (below: `$B`).
Final PNG: `$B/scene.png` (1120x1120, 560x560 logical at pixels_per_point 2.0).

## TL;DR

- **It works, and it is fast.** The whole scene (bold title, rich para with a clickable link, 6 wrapped buttons, edit_line, gradient rounded rect, oval, star, line, bezier heart) renders headlessly via `egui_kittest` + wgpu/Metal in **~6-7 ms per warm frame including GPU readback**, egui pass alone **~20 µs**, tessellation **~11 µs** (40 shapes, 2,922 vertices).
- **Headless == live.** Same `eframe::App` struct drives both `Harness::build_eframe` and a real `eframe::run_native` window. Pixel diff of kittest PNG vs the live window's own framebuffer capture: **0 pixels differ by more than 1/255** (the 1/255 noise is dithering, off in kittest's `RendererOptions::PREDICTABLE`).
- **Spoofed user tests work out of the box**: find by label/role through the AccessKit tree, `.click()`, `.type_text()`, then assert on labels or on app state. 6 tests run in **0.05-0.09 s wall** in parallel. Snapshot diffing catches a one-digit label change (670 px).
- **Things egui does not do for you** (all solved in the spike, code referenced below): concave polygon fill (PathShape fills convex only, wrong on a star, fixed with `lyon_tessellation`), gradients on anything but an axis-aligned rect (fixed by recolouring tessellated vertices), bold/italic without loading real font files (bundled font is Ubuntu-Light only), per-span links in a paragraph (no span hit-testing or AccessKit node, fixed with `ui.interact` overlays), smooth large ellipses (EllipseShape is visibly faceted).
- **MSRV trap:** egui 0.36.x needs **rustc 1.95**. This machine's default toolchain is **1.93.1** (`rustup` reports 1.98.1 available). egui 0.35.0 is the last on MSRV 1.92. I installed a sandboxed stable 1.98.1 under `$B/.rustup` rather than touch the user's toolchain (see `$B/env.sh`).
- **Not native-looking widgets.** egui paints its own flat buttons and text fields. Styling gets them close to Shoes (I added 1px borders) but a macOS user will not mistake them for NSButton.

## 1. Versions (resolved in `$B/Cargo.lock`, 400 packages)

| crate | version |
|---|---|
| egui / eframe / egui_kittest / egui-wgpu / egui-winit / epaint | 0.36.2 (released 2026-09-08) |
| wgpu | 30.0.1 |
| winit | 0.30.13 |
| accesskit / accesskit_macos | 0.24.1 / 0.26.3 |
| kittest | 0.4.0 |
| text stack inside epaint | **harfrust 0.12.0** (HarfBuzz port, real shaping) + **skrifa 0.44.0** (variable fonts) |
| lyon_tessellation | 1.0.22 |
| fontdb | 0.24.0 |
| image | 0.25.10 |

`$B/Cargo.toml`:

```toml
[dependencies]
egui = "0.36.2"
eframe = { version = "0.36.2", default-features = false, features = ["wgpu", "default_fonts", "accesskit"] }
egui_kittest = { version = "0.36.2", features = ["wgpu", "snapshot", "eframe"] }
image = { version = "0.25", default-features = false, features = ["png"] }
lyon_tessellation = "1.0.22"
fontdb = "0.24"
```

egui_kittest features (from crates.io metadata): `snapshot` = dify+image+png, `wgpu` = egui-wgpu+pollster+wgpu, `eframe` = lets `Harness::build_eframe` drive an `eframe::App`.

Rust: `rustc 1.98.1 (48a229cea 2026-09-01)` via `source $B/env.sh` (sets `RUSTUP_HOME=$B/.rustup CARGO_HOME=$B/.cargo-home RUSTUP_TOOLCHAIN=stable`). With stock 1.93.1 the build fails with `egui@0.36.2 requires rustc 1.95`.

## 2. Files

| path | what |
|---|---|
| `$B/src/lib.rs` (585 lines) | every Shoes element as a function, `ShoesApp` (eframe::App), fonts |
| `$B/src/bin/render.rs` | headless render to PNG + timings |
| `$B/src/bin/live.rs` | real native window; `SPIKE_AUTOCLOSE=out.png` self-screenshots and quits |
| `$B/src/bin/layout.rs` → `$B/layout.png` | Shoes slot semantics: 50% stacks, margins, background, wrapping flow, absolute top/left |
| `$B/src/bin/weights.rs` → `$B/weights.png` | per-span `:weight` 200..900, `:kerning`, `:fill`, `:strikethrough`, `:undercolor`, sup/sub, `wdth`, `:leading` |
| `$B/src/bin/fonts.rs` | fontdb system font lookup by family/bold/italic |
| `$B/tests/interaction.rs` | 6 kittest tests (click by label, role, coordinates; type; snapshot; snapshot-diff) |
| `$B/tests/snapshots/scene_after_click.png` (+ `.diff.png`, `.new.png` from the deliberate failing comparison) | |
| `$B/scene.png`, `$B/live.png`, `$B/scene_builtin.png` | SF fonts headless / live window capture / egui bundled font only |

## 3. The scene, element by element (exact calls that worked)

Line numbers are in `$B/src/lib.rs`.

### title (bold, 34 pt)
`title()` L138: `LayoutJob::append(text, 0.0, TextFormat { font_id: FontId::new(34.0, FontFamily::Name("bold".into())), color, ..Default::default() })` then `ui.label(job)`.
Real bold via SF variable font (see fonts). With the bundled font only, it is NOT bold (`scene_builtin.png`).

### para with spans (one LayoutJob, wraps)
`para_job()` L167 builds one `egui::text::LayoutJob` (`job.wrap.max_width = ui.available_width()`), one `job.append(text, 0.0, TextFormat{..})` per span:
- strong: `font_id: FontId::new(16.0, FontFamily::Name("bold".into()))`
- em: `FontFamily::Name("italic".into())` (plus `italics: true` shear when only the bundled font exists, `SYNTHETIC_ITALIC` L46)
- link: `color: LINK_BLUE, underline: Stroke::new(1.0, LINK_BLUE)`
- red span: `color: Color32::from_rgb(0xd0,0x1c,0x1c)`
- all spans: `valign: Align::BOTTOM` (so mixed sizes share a baseline)

`para()` L220: `let (pos, galley, response) = egui::Label::new(job).sense(Sense::click()).layout_in_ui(ui);` then `ui.painter().galley(pos, galley.clone(), INK)`.

**Gotcha 1:** painting a galley yourself (instead of `ui.label`) leaves the widget **invisible to AccessKit/kittest**. Fix: `response.widget_info(|| egui::WidgetInfo::labeled(egui::WidgetType::Label, true, &text));` (Before the fix, `get_by_label_contains("A Shoes para with")` panicked "No nodes found".)

**Gotcha 2:** egui has no per-span hit test and no per-span AccessKit node. `Glyph::section_index` is `pub(crate)` and reset after layout. What worked: compute each link's on-screen rects from the galley, then lay an invisible widget over each:
- `span_rects()` L251: byte range → char range (`text[..b].chars().count()`), per char `galley.pos_from_cursor(egui::text::CCursor::new(c))` (note `CCursor.index` is a `CharIndex` newtype in 0.36, use `.into()` to get `usize`), union per visual row.
- per rect: `let r = ui.interact(rect, ui.id().with(("shoes_link", n, k)), Sense::click()); r.widget_info(|| egui::WidgetInfo::labeled(egui::WidgetType::Link, true, label));` then `r.clicked()`, `r.hovered()` → `ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand)`. Later-registered widgets win hit tests, so the overlay beats the Label underneath.
- Result: kittest can do `h.get_by_role_and_label(Role::Link, "link you can click").click()`. A click on plain para text does not count (tested).

### flow of 6 buttons wrapping onto 2 lines
L~405: `ui.horizontal_wrapped(|ui| { ui.set_max_width(440.0); for name in [...] { ui.add(egui::Button::new(name).min_size(vec2(96.0, 30.0))) } })` → 4 + 2. `layout.png` also shows `ui.allocate_ui_with_layout(vec2(160.0, 0.0), Layout::left_to_right(Align::Min).with_main_wrap(true), ..)` wrapping 9 buttons 5 + 4.

### edit_line with hint
`ui.add(egui::TextEdit::singleline(&mut st.edit_line).hint_text("edit_line: type here").desired_width(300.0))`. Shoes `change {}` maps to `response.changed()`.
**Looks off by default:** egui's light theme draws inactive text fields and buttons with no border. `apply_style()` L546 adds `s.visuals.widgets.inactive.bg_stroke = Stroke::new(1.0, Color32::from_gray(190))` via `ctx.style_mut_of(egui::Theme::Light, |s| ..)`.

### counter
`ui.horizontal(|ui| { if ui.add(egui::Button::new("Click me").min_size(..)).clicked() { st.clicks += 1 } ui.label(format!("Clicks: {}", st.clicks)); .. })`

### art canvas
`let (_resp, painter) = ui.allocate_painter(vec2(ui.available_width(), 232.0), Sense::hover()); let o = painter.clip_rect().min;` then absolute coords `o + vec2(x, y)` (this is how Shoes `left:`/`top:` inside a slot maps).

#### rect, curve 16, linear gradient: `gradient_rounded_rect()` L278
egui has no gradient paint except `Shape::gradient_rect(rect, Direction, [from, to])` (axis-aligned, square corners). What worked, with egui's own anti-aliased edges:
```rust
use egui::epaint::{tessellator::{Path, path::rounded_rectangle}, CornerRadiusF32, Mesh};
let mut points = Vec::new();
rounded_rectangle(&mut points, rect, CornerRadiusF32::same(radius));
let mut path = Path::default();
path.add_line_loop(&points);
let mut mesh = Mesh::default();
path.fill(1.0 / painter.ctx().pixels_per_point(), Color32::WHITE, &mut mesh); // feathered
for v in &mut mesh.vertices {
    let t = ((v.pos.x - rect.min.x) / rect.width()).clamp(0.0, 1.0);
    v.color = from.lerp_to_gamma(to, t).gamma_multiply_u8(v.color.a()); // keep AA coverage
}
painter.add(Shape::mesh(mesh));
```
A 2-stop linear gradient is affine in position, so per-vertex colours are exact on any triangulation: the same recolour trick works for ovals, stars, any `shape`, and Shoes `:angle` (project onto a direction vector instead of x). Multi-stop or radial gradients would need subdivided meshes or a texture. `gradient_rect_mesh()` L302 is the naive 4-vertex `Mesh` (`Vertex { pos, uv: WHITE_UV, color }`, indices `[0,1,2,0,2,3]`): fine but square and aliased-edge.
Gradient **strokes** are native: `PathStroke { width, color: ColorMode::UV(Arc<dyn Fn(Rect, Pos2) -> Color32 + Send + Sync>), kind }` (epaint `color.rs:10`). Not exercised in the PNG.
`RectShape.brush: Option<Arc<Brush { fill_texture_id, uv }>>` gives textured rounded rects (image backgrounds). Not exercised.

#### oval with stroke and alpha fill: `oval()` L315 and `oval_smooth()` L488
`painter.add(EllipseShape { center, radius, fill: Color32::from_rgba_unmultiplied(0x1a,0x5f,0xd6,90), stroke: Stroke::new(3.0, blue), angle: 0.0 })`.
**Looks off:** visibly faceted at 55x36 pt. `Tessellator::tessellate_ellipse` (epaint `tessellator.rs:1542`) uses `max(8, radius_px / 16)` points per quarter, so 8 per quarter here (32 total). Fix: own polygon with segment count from a chord tolerance, `n = ceil(PI / acos(1 - 0.1 / r_px))`, drawn with `PathShape::convex_polygon(pts, fill, stroke)`; smooth in the PNG. Also note: EllipseShape/CircleShape strokes are drawn **outside** the radius (`PathStroke::from(stroke).outside()`), whereas Shoes/Cairo strokes are centred on the outline. A builder must pick one and keep it consistent across rect/oval/shape.

#### 5-point star (concave): `star_naive()` L331 vs `star_lyon()` L337
`PathShape::convex_polygon(points, fill, stroke)` on the 10-point star: **the stroke is correct, the fill is wrong** (fan fill spills over the notches between the top arms and cuts off the top spike, see middle-bottom of `scene.png`, zoom in `$B/crops/stars_big.png`). epaint documents it: `path_shape.rs:14` "Fill is only supported for convex polygons." There is no concave fill anywhere in epaint 0.36.
Fix that worked (`fill_polygon_lyon()` L342):
```rust
use lyon_tessellation::{BuffersBuilder, FillOptions, FillRule, FillTessellator, FillVertex, VertexBuffers, math::point, path::Path as LyonPath};
let mut b = LyonPath::builder(); b.begin(point(x0, y0)); /* b.line_to(..) */ b.close();
let path = b.build();
let mut buffers: VertexBuffers<Pos2, u32> = VertexBuffers::new();
FillTessellator::new().tessellate_path(&path,
    &FillOptions::default().with_fill_rule(FillRule::NonZero).with_tolerance(0.05),
    &mut BuffersBuilder::new(&mut buffers, |v: FillVertex<'_>| pos2(v.position().x, v.position().y)))?;
let mut mesh = Mesh::default();
mesh.vertices = buffers.vertices.iter().map(|&pos| Vertex { pos, uv: WHITE_UV, color }).collect();
mesh.indices = buffers.indices;
painter.add(Shape::mesh(mesh));
painter.add(PathShape::closed_line(pts.to_vec(), PathStroke::from(stroke))); // egui's feathered stroke hides the aliased mesh edge
```
lyon meshes have no feathering (hard edges); the egui stroke on top anti-aliases the outline. A fill with no stroke would show jaggies at 1x (fine at 2x). `heart_lyon()` L503 shows Shoes `shape { move_to; curve_to }` with `b.cubic_bezier_to(ctrl1, ctrl2, to)`; outline via `path.iter().flattened(0.05)` (needs `use lyon_tessellation::path::iterator::PathIterator as _;`) mapped from `Event::Begin { at }` / `Event::Line { to, .. }` into `PathShape::closed_line`.

#### line strokewidth 3
`painter.line_segment([a, b], Stroke::new(3.0, color))`. **No line caps or joins in egui**: `PathStroke` is `{ width, color: ColorMode, kind: StrokeKind }` only. Shoes `:cap` (`:curve`, `:rect`, `:project`) needs lyon's `StrokeTessellator` (has `LineCap::{Butt, Square, Round}`, joins).

## 4. Fonts

- egui 0.36 bundles only `Ubuntu-Light.ttf`, `Hack-Regular.ttf`, `NotoEmoji-Regular.ttf`, `emoji-icon-font.ttf` (epaint_default_fonts). **No bold, no italic face.** The only built-in style knob is `TextFormat.italics: bool` (a shear). Compare `$B/scene_builtin.png` (title and `strong` not bold, `em` sheared) with `$B/scene.png`.
- epaint 0.36 shapes text with **harfrust** and reads fonts with **skrifa**, and supports **variable fonts**: `FontData::variation_axes()` reports SFNS.ttf axes `wdth=30..150, opsz=17..96, GRAD=400..1000, wght=1..1000`.
- Loading system fonts is a file read, not an API. What worked (`install_fonts()` L53):
  ```rust
  let mut defs = egui::FontDefinitions::default();
  let mut bold = egui::epaint::text::FontTweak::default();
  bold.coords = egui::epaint::text::VariationCoords::new([(b"wght", 700.0)]);
  defs.font_data.insert("sf_bold".into(), Arc::new(egui::FontData::from_owned(std::fs::read("/System/Library/Fonts/SFNS.ttf")?).tweak(bold)));
  defs.families.insert(FontFamily::Name("bold".into()), vec!["sf_bold".into(), /* then egui's default Proportional list as glyph fallbacks */]);
  ctx.set_fonts(defs);
  ```
  Italic from `/System/Library/Fonts/SFNSItalic.ttf` the same way. `FontData` has `pub index: u32` for `.ttc` collections.
- **Per-span weight without extra families works:** `TextFormat { coords: VariationCoords::new([(b"wght", w)]), .. }` renders a visible 200..900 ramp on SF (`$B/weights.png`, zoom `$B/crops/weights_row.png`). `wdth` 60/120 also works. So Shoes `:weight` numbers map directly for variable fonts. Static fonts (Georgia, Arial) need their Bold/Italic faces loaded as separate families.
- **Gotcha 3 (panic):** `ctx.set_fonts` only takes effect at the start of the **next** pass. Using `FontFamily::Name("bold")` in the same pass panics: `FontFamily::Name("bold") is not bound to any fonts` (epaint `fonts.rs:1025`). Install fonts in the eframe creator (`ShoesApp::new(cc)` L567 calls `install_fonts(&cc.egui_ctx, ..)`), or skip drawing for one pass and `request_repaint()` (`weights.rs` does this). Every font a Shoes app names must be registered before the frame that uses it, so a runtime `font "X"` needs a one-frame deferral.
- Family lookup by name: `fontdb` (`find_system_font()` L122, `$B/src/bin/fonts.rs`): `db.load_system_fonts()` = **822 faces in 92 ms** (cache the db once). `db.query(&fontdb::Query { families: &[fontdb::Family::Name("Helvetica Neue")], weight: fontdb::Weight::BOLD, style: fontdb::Style::Italic, ..Default::default() })` → `HelveticaNeue-BoldItalic (face index 3)`; Georgia Italic, Arial-BoldMT, Menlo-Regular, ComicSansMS all resolved; unknown family → `None`. `db.with_face_data(id, |data, index| ..)` gives bytes + ttc index for `FontData`.
- Memory: SFNS.ttf is 8.3 MB; my spike loads it twice as `from_owned` (regular + bold). A builder should share one buffer (`FontData { font: Cow::Borrowed(leaked) , .. }`) or use per-span coords instead of a second family.
- Text quality: crisp at 2x, correct kerning (`$B/crops/para_big.png`).

## 5. kittest: headless rendering and spoofed interaction

Harness construction that worked (`$B/tests/interaction.rs:6`, `$B/src/bin/render.rs`):
```rust
let mut h: Harness<'static, ShoesApp> = Harness::builder()
    .with_size(SCENE_SIZE)            // logical points
    .with_pixels_per_point(2.0)
    .with_theme(egui::Theme::Light)
    .wgpu()                           // WgpuTestRenderer, RendererOptions::PREDICTABLE
    .build_eframe(|cc| ShoesApp::new(cc, FontMode::SystemSf));
h.run();                              // step until no repaint requested (max_steps default 4)
let img: image::RgbaImage = h.render()?;   // GPU render + readback
img.save("scene.png")?;
```
- `build_ui(|ui| ..)` / `build_ui_state(|ui, st| .., st)` also work; they wrap your UI in `Frame::central_panel(..).outer_margin(8.0)` (`app_kind.rs`), and give no hook to set fonts before the first pass (hence `build_eframe` above).
- Default wgpu adapter selection (`egui_kittest/src/wgpu.rs:19`) prefers CPU adapters (lavapipe/llvmpipe in Linux CI), then discrete GPU; on this Mac it uses Metal.
- `h.state()` / `h.state_mut()` return the `ShoesApp`, so tests assert on app state directly (`h.state().state.clicks`).

Interaction API that worked (all in `tests/interaction.rs`):

| action | call |
|---|---|
| find widget by visible text | `h.get_by_label("Click me")` (panics if absent), `h.query_by_label(..) -> Option<Node>` |
| substring | `h.get_by_label_contains("A Shoes para with")` |
| by role | `h.get_by_role(egui::accesskit::Role::TextInput)`, `h.get_by_role_and_label(Role::Link, "link you can click")`, `Role::Button` |
| click | `node.click()` (hover + press + release at `node.rect().center()`), `node.click_accesskit()` (AccessKit action, works off-screen) |
| type | `node.focus(); node.type_text("hello shoes");` then `h.run()` (**must focus first**) |
| read value | `node.value() -> Option<String>` (TextInput content) |
| click at coordinates | `h.hover_at(pos); h.event(egui::Event::PointerButton { pos, button: PointerButton::Primary, pressed: true, modifiers: Modifiers::NONE }); /* then pressed: false */` |
| keys | `h.key_press(egui::Key::Enter)`, `h.key_combination(&[..])` (not exercised) |
| advance | `h.run()` after every input; `h.step()` for exactly one pass |
| clean snapshot | `h.remove_cursor(); h.run();` (else the hovered state and a synthetic cursor triangle get drawn) |
| snapshot | `h.snapshot_options("name", &SnapshotOptions::new().output_path("tests/snapshots"))`; first run needs `UPDATE_SNAPSHOTS=1`; mismatch writes `name.diff.png`/`name.new.png` |
| non-panicking compare | `h.try_snapshot_options(..) -> Result<(), SnapshotError>`; **also call `h.take_snapshot_results()`** or the harness panics on Drop with the recorded error |

Tests (all pass, `cargo test --release`, 6 tests, 0.05-0.09 s wall):
`click_button_by_label_bumps_counter` (asserts `Clicks: 0` → `Clicks: 1` → `Clicks: 2` labels exist and `Clicks: 1` is gone), `flow_button_and_edit_line`, `click_link_span_by_role_and_label`, `click_link_span_inside_para_by_coordinates` (plain-text click = 0 link clicks, link-rect click = 1), `snapshot_after_interaction` (PNG shows `Clicks: 1` and `typed by kittest` in a focused field), `snapshot_catches_a_one_digit_change` ("Clicks: 2" vs recorded "Clicks: 1": **Diff: 670 px**; failing pixels by threshold 0.0..2.0 = 670, 10.0 = 664, so the default threshold 0.6 is not masking real changes).

Relevance to the spec system: a Shoes-spec case can be "run the Ruby app against this display service in a kittest harness, query by label/role, click, assert labels, snapshot". The AccessKit tree is the query surface, so every hand-painted Shoes element must call `response.widget_info(..)` or it is untestable (Gotcha 1).

## 6. Live native window

`$B/src/bin/live.rs`: `eframe::run_native("Scarpe on egui", eframe::NativeOptions { viewport: egui::ViewportBuilder::default().with_title(..).with_inner_size(SCENE_SIZE), ..Default::default() }, Box::new(|cc| Ok(Box::new(Live { app: ShoesApp::new(cc, ..), .. }))))`.
eframe 0.36 `App` trait: required `fn ui(&mut self, ui: &mut egui::Ui, frame: &mut eframe::Frame)` (given Ui has **no margin/background**, wrap in `egui::CentralPanel::default_margins().frame(..).show(ui, ..)`, note `show_inside` is deprecated, renamed `show`); optional `fn logic(&mut self, ctx, frame)` (runs even while hidden), `fn clear_color(&self, &Visuals) -> [f32; 4]`.

Measured on Apple M5 (10 cores), Retina (window ppp 2.0):
- renderer ready 108-166 ms after `main`; first `ui()` 96-189 ms; window reported visible (`ctx.input(|i| i.viewport().visible()) == Some(true)`) at ~256-300 ms.
- **Idle: 0.0% CPU** (eframe is reactive: no passes without input or `request_repaint`), 0.20 s CPU total over 4 s. **RSS ~148-177 MB** (Metal + 2x SFNS in memory).
- Self-screenshot: `ui.ctx().send_viewport_cmd(egui::ViewportCommand::Screenshot(Default::default()))`, then on a LATER pass read `egui::Event::Screenshot { image: Arc<ColorImage>, .. }` from `ctx.input(|i| i.raw.events..)`. **Gotcha 4:** eframe only services Screenshot on a pass where the window is known visible (`wgpu_integration.rs:~800`, inside `if is_visible`), and an idle app runs no further pass, so keep `request_repaint()` going until the event lands. Before the window is visible, eframe ran ~640 unpainted passes in ~250 ms when I spun on `request_repaint()`.
- `$B/live.png` vs `$B/scene.png`: identical at max channel delta 1.
- Release binary 13.9 MB (11.1 MB stripped, default `opt-level=3`, no LTO). `otool -L` shows only system frameworks and libs (AppKit, ApplicationServices, CoreGraphics, CoreVideo, Carbon, CoreFoundation, Foundation, QuartzCore, Metal, ColorSync, CoreServices, libSystem, libobjc, libiconv): nothing to bundle besides the binary (and any non-system fonts).

## 7. Performance and build numbers

Headless (`target/release/render`, 3 runs):
| phase | time |
|---|---|
| wgpu init + app creation + first passes (`build_eframe`) | 24-57 ms |
| first `render()` (GPU + readback of 1120x1120) | 10-20 ms |
| warm `render()` | 5.7-8.5 ms |
| 50x (`step()` + `render()`) | 5.5-12.6 ms/frame (readback-dominated) |
| 50x egui pass only (layout + shape list, galley cache warm) | 16-28 µs/frame |
| `ctx.tessellate(shapes, 2.0)`: 40 clipped shapes → 2,922 vertices | ~11 µs |

Build (M5, 10 cores, sandboxed rustc 1.98.1):
| build | time |
|---|---|
| cold `cargo build --release --bins` (176 crates) | **39.98 s wall** (290 s CPU). A first attempt reached the lib error at 67 s (colder disk cache). |
| incremental release after `touch src/lib.rs` | 2.0-2.3 s |
| cold `cargo build` (dev) | 21.3 s; incremental 1.2 s |
| `cargo test --release --no-run` incremental | 0.9-2.3 s |
| disk | `target/` 2.4 GB (debug + release), registry 650 MB, toolchain 447 MB |

## 8. Shoes → egui mapping notes (what a builder will hit)

Layout (`$B/layout.png`):
- `stack` = vertical `Ui`; `flow` = `Layout::left_to_right(Align::Min).with_main_wrap(true)` or `ui.horizontal_wrapped`. egui is single-pass immediate mode: width flows top-down (`ui.available_width()`), height is known only after children draw. That matches Shoes (width %, content height).
- `width: 0.5` = `ui.allocate_ui_with_layout(vec2(parent_w * 0.5, 0.0), Layout::top_down(Align::Min), |ui| { ui.set_width(parent_w * 0.5); .. })`.
- `margin:` + `background` = `egui::Frame::new().fill(color).inner_margin(Margin::same(m as i8))` (`Margin::same` takes `i8` in 0.36). Shoes layers multiple backgrounds/borders as elements; paint them via `painter.add(Shape::Noop)` placeholders set after content (not exercised) or Frame for the single case.
- absolute `top:/left:` = `ui.scope_builder(UiBuilder::new().max_rect(Rect::from_min_size(slot_origin + vec2(left, top), size)), ..)` or painter coordinates.
- `height:` fixed = `ui.allocate_exact_size(vec2(w, h), Sense::hover())`; `scroll: true` = `egui::ScrollArea` (not exercised).

Text styles (manual `docs/static/manual.md` L1073-L1540) → `TextFormat` fields (epaint `text_layout_types.rs:478`):
| Shoes | egui | status |
|---|---|---|
| `:stroke` | `color` | works |
| `:fill` (highlighter) | `background` (+ `expand_bg`) | works |
| `:size` / `:family` / `:font` | `FontId { size, family }` + registered families | works, family needs pre-registration (Gotcha 3) |
| `:weight` names/numbers | `coords: VariationCoords::new([(b"wght", n)])` on variable fonts, else a Bold face family | works |
| `:emphasis` italic / oblique | italic face family / `italics: true` shear | works |
| `:underline` "single" / `:undercolor` | `underline: Stroke` | works; "double", "low", "error" (wavy) NOT supported, custom paint needed |
| `:strikethrough` "single" | `strikethrough: Stroke` | works |
| `:kerning` | `extra_letter_spacing` | works |
| `:leading` | `line_height: Option<f32>` | works (absolute line height, not "extra 4px") |
| `sup`/`sub`, `:rise` | smaller `FontId` + `valign: Align::TOP/BOTTOM` | approximate; no pixel `:rise` |
| `:variant` "smallcaps" | none (no OpenType feature API on TextFormat) | NOT supported |
| `:align`, `:justify` | `job.halign`, `job.justify` | not exercised |

Widgets available in egui 0.36 (`egui/src/widgets/`): button, checkbox (`check`), radio_button (`radio`), text_edit (`edit_line` singleline, `edit_box` multiline), slider, progress_bar (`progress`), image, hyperlink, spinner, color_picker; `containers/combo_box.rs` (`list_box`). Images via `egui::Image` need loaders (e.g. `egui_extras::install_image_loaders`), not tested here.

Art: Shoes `fill "image.png"` on any shape (manual L1685) = textured `Mesh` with per-vertex `uv` (`Mesh::with_texture(id)`), tiling via `TextureOptions { wrap_mode: TextureWrapMode::Repeat, .. }`. Feasible, not tested. `arc`/`arrow` = lyon paths. `:cap` = lyon StrokeTessellator (egui has none).

## 9. egui-specific architecture constraints for a Scarpe display service

- Immediate mode: the Rust side must own a **retained mirror of the Lacci drawable tree** (create/update/destroy messages from Ruby mutate it) and walk it every pass to emit egui calls. Widget identity across frames comes from `Id`s: derive them from Lacci's linkable ids (e.g. `egui::Id::new(linkable_id)` via `ui.push_id` / `id_salt`) so TextEdit contents/focus survive reordering.
- Events flow back from `Response::clicked()/changed()/hovered()` during the pass; the display service queues them to Ruby.
- eframe/winit own the **main thread** on macOS. Ruby cannot also sit on the main thread in the same process unless Rust calls into Ruby. Out-of-process (Ruby spawns the Rust binary, messages over a pipe/socket) fits egui well: an IO thread applies messages to the shared tree and calls `ctx.request_repaint()` (`egui::Context` is `Clone + Send + Sync`) to wake the reactive loop. Shoes `animate(fps)` / `every` = `ctx.request_repaint_after(Duration)`.
- Idle cost is ~0% CPU because egui repaints only on demand.

## 10. What looks off (honest list)

1. Widgets are egui-flat, not macOS-native. Default light theme even drops borders on inactive buttons/fields (patched with `widgets.inactive.bg_stroke`).
2. `EllipseShape` faceted at moderate sizes (8 points/quarter under 128 px radius). Use own polygon.
3. `PathShape` fills concave polygons incorrectly, silently. Use lyon for every `shape`/`star`/`arrow` fill.
4. lyon fill meshes are not anti-aliased; rely on an egui stroke on top or on 2x displays. A stroke-less concave fill at 1x will show jaggies.
5. Oval/circle strokes sit outside the radius (Shoes/Cairo centre them).
6. Gradient midpoint (orange → purple) is interpolated in gamma space (`lerp_to_gamma`), slightly muddy; CSS in the Webview backend does the same by default, so it matches today's Scarpe.
7. No line caps/joins, no double/wavy underline, no smallcaps, no pixel `:rise`.
8. Bundled font has no bold/italic: without system font loading, `strong`/`title` are not bold (`scene_builtin.png`).
9. Fonts must be registered a pass before use or egui panics (not a soft fallback).
10. Toolchain: egui 0.36 requires rustc ≥ 1.95.

## 11. How to reproduce

```sh
B=<scratch>/spikes/b
source $B/env.sh && cd $B
cargo build --release --bins
./target/release/render scene.png            # SF fonts
./target/release/render scene_builtin.png builtin
cargo test --release                         # 6 kittest tests; UPDATE_SNAPSHOTS=1 re-records
SPIKE_AUTOCLOSE=$B/live.png ./target/release/live   # opens a real window ~0.4 s, captures, quits
./target/release/layout; ./target/release/weights; ./target/release/fonts
```

## 12. Housekeeping disclosures

- Before switching `CARGO_HOME` to the spike dir, my first `cargo fetch` (run with stock `~/.cargo`) downloaded crates into the user's shared cargo cache `~/.cargo/registry` (cache only, no config or toolchain changes). Everything after that used `$B/.cargo-home` and `$B/.rustup`.
- A shell typo created an empty `/tmp/null`; I deleted it.
- The live window was opened on the user's display three or four times, under a second each (the idle measurement kept it up about 4 s).
- No git operations, no changes to the scarpe clones.
