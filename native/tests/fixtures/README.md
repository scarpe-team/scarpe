# Protocol fixtures

Each `.ndjson` file is what the Ruby side sends for one small Shoes app: the create, props and
destroy messages Lacci produced (recorded under Niente, normalised as DESIGN 5.3 says), then
`run`, `flush`, a few requests, and `quit`. Shape commands are re-sent after the shape block, the
way Lacci fix 2 will send them.

| fixture | what it covers |
|---|---|
| `hello` | one para |
| `button_para` | a button and a para in a stack; clicking the button |
| `layout` | flows and stacks with every width form, margins, wrapping, text shrink-to-fit, left/top and right/bottom |
| `art` | rect, oval (gradient), star, line, arrow, arc, shape, rotate, nofill |
| `widgets` | button, check, radio, edit_line (and secret), edit_box, list_box, progress, image, video; typing, tab, the list_box popup |
| `rich_text` | banner to inscription, strong/em/code/del/link/span/sup/sub, nesting, align; clicking a link |
| `scroll` | a document taller than its window; the wheel |
| `events` | slot click subscription, `has_click`, keypress and motion items |

Feed one to the headless binary from `native/` (snapshots land in `target/shots/`):

    cat tests/fixtures/widgets.ndjson | target/release/scarpe-native --headless --scale 2 --fonts bundled

`tests/protocol.rs` and `tests/golden.rs` load them too; `UPDATE_GOLDEN=1 cargo test --release
--test golden` accepts new pictures into `tests/golden/`.
