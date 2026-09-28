# Showcase

Six small apps in plain Shoes, each leaning on a different strength of the native display service.

| app | what it shows |
|---|---|
| `for_noah.rb` | typography, a shoe drawn from curves, soft gradients: a card for Noah Gibbs |
| `pomodoro.rb` | an animated arc ring, `every` and `animate`, a timer that sleeps when paused |
| `sketchpad.rb` | drawing with the mouse (`click`, `motion`, `release`), smooth strokes, undo |
| `starfield.rb` | 420 stars in three layers at `animate(60)`, with the frame rate as measured |
| `notes.rb` | an `edit_box` with a live word count, a `list_box` for tags, a sidebar of notes |
| `snake.rb` | arrow keys, a game loop on `every`, a game-over overlay and a restart |

Run one with `scarpe --native examples/native/showcase/pomodoro.rb`.

`shoe_icon.rb` is For Noah's app icon, the card's shoe on a tile, drawn by Scarpe itself. Its
opening comment has the three commands that turn it into `For Noah.app` with that icon:
`scarpe peek` draws it, one ImageMagick line cuts the corners, `scarpe package` does the rest.

`spec/showcase/` holds a Shoes-Spec case per app that drives it headless and looks at the
pixels. They run with the rest of the suite, or alone: `spec/run --display native spec/showcase`.
