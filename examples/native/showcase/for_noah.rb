# For Noah: a dedication card.
#
# Noah Gibbs designed Scarpe's display services so that a new one could be
# dropped in. This window is drawn by the newest one, in Rust.

INK = "#2b2320"
MUTED = "#8a6f62"
BODY = "#4a3d36"
CLAY = "#c4604a"
CREAM = "#fbf5ec"
SERIF = "Iowan Old Style, Georgia, serif"

Shoes.app(title: "For Noah", width: 560, height: 608, resizable: false) do
  # Light fading out from a centre: circles, each smaller than the last.
  def glow(x, y, radius, color)
    nostroke
    fill color
    16.times { |i| oval x, y, radius * 2 * (1 - i / 16.0), center: true }
  end

  # A soft shadow: a few faint rounded rectangles, each a little larger.
  def shadow(left, top, width, height)
    nostroke
    fill rgb(90, 60, 40, 0.035)
    4.times { |i| rect left - i, top + 2 + i * 2, width + i * 2, height + i, curve: 24 + i }
  end

  # Whatever the block draws, drawn twice like a real lace: dark, then cream on top.
  def lace
    stroke INK
    strokewidth 5
    yield
    stroke CREAM
    strokewidth 3
    yield
  end

  # A lace-up shoe, toe to the right, with its top left corner at (x, y).
  def shoe(x, y)
    nostroke
    fill rgb(90, 60, 40, 0.08)
    oval x + 126, y + 106, 236, 12, center: true

    upper x, y
    sole x, y
    laces x, y
  end

  # Heel, collar, tongue, vamp and toe in one outline.
  def upper(x, y)
    stroke INK
    strokewidth 3
    fill "#dc8a6f".."#c4604a"
    shape do
      move_to x + 14, y + 88
      curve_to x + 4, y + 70, x + 4, y + 44, x + 18, y + 32
      curve_to x + 34, y + 22, x + 62, y + 26, x + 78, y + 34
      curve_to x + 82, y + 22, x + 96, y + 14, x + 108, y + 18
      curve_to x + 112, y + 30, x + 116, y + 40, x + 126, y + 46
      curve_to x + 160, y + 56, x + 196, y + 60, x + 220, y + 68
      curve_to x + 236, y + 72, x + 242, y + 82, x + 238, y + 88
      line_to x + 14, y + 88
    end
  end

  # The rubber toe cap and the sole, with a stripe round it.
  def sole(x, y)
    fill CREAM
    shape do
      move_to x + 188, y + 88
      curve_to x + 188, y + 74, x + 202, y + 63, x + 220, y + 68
      curve_to x + 236, y + 72, x + 242, y + 82, x + 238, y + 88
      line_to x + 188, y + 88
    end
    shape do
      move_to x + 10, y + 86
      line_to x + 236, y + 86
      curve_to x + 246, y + 88, x + 246, y + 102, x + 232, y + 102
      line_to x + 16, y + 102
      curve_to x + 8, y + 102, x + 6, y + 90, x + 10, y + 86
    end
    stroke CLAY
    strokewidth 2
    line x + 18, y + 94, x + 230, y + 94
  end

  # Five laces across the tongue, their eyelets, and a bow on top.
  def laces(x, y)
    cap :curve
    5.times do |i|
      ex = x + 86 + i * 10
      ey = y + 38 + i * 3.5
      lace { line ex, ey, ex + 9, ey - 10 }
    end

    stroke INK
    strokewidth 1.5
    fill CREAM
    5.times { |i| oval x + 83 + i * 10, y + 35 + i * 3.5, 6 }

    nofill
    lace { bow x + 98, y + 24 }
  end

  # Two loops and two loose ends, tied at (kx, ky).
  def bow(kx, ky)
    shape do
      move_to kx, ky
      curve_to kx - 10, ky - 16, kx - 26, ky - 12, kx - 22, ky - 2
      curve_to kx - 18, ky + 6, kx - 8, ky + 4, kx, ky
      curve_to kx + 10, ky - 16, kx + 26, ky - 12, kx + 22, ky - 2
      curve_to kx + 18, ky + 6, kx + 8, ky + 4, kx, ky
    end
    shape do
      move_to kx, ky
      curve_to kx - 4, ky + 8, kx - 12, ky + 12, kx - 16, ky + 24
    end
    shape do
      move_to kx, ky
      curve_to kx + 4, ky + 8, kx + 8, ky + 16, kx + 16, ky + 26
    end
  end

  background "#fcf7f0".."#f2e3d5"
  glow 70, 60, 150, rgb(255, 255, 255, 0.06)
  glow 510, 560, 180, rgb(214, 150, 118, 0.025)
  shadow 36, 36, 488, 536

  stack left: 36, top: 36, width: 488, height: 536 do
    background rgb(255, 255, 255, 0.9), curve: 24
    border rgb(90, 60, 40, 0.08), curve: 24

    stack height: 150 do
      shoe 118, 36
    end

    banner "For Noah", align: "center", stroke: INK, family: SERIF
    tagline "who made Scarpe's display services swappable",
      align: "center", stroke: MUTED, family: SERIF, emphasis: "italic"

    stack height: 12 do
      stroke CLAY
      strokewidth 1
      line 214, 6, 274, 6
    end

    stack margin: [48, 18, 48, 0] do
      para "Noah Gibbs designed Scarpe's display services so that a new one could be dropped in ",
        "without changing a line of the Shoes apps they draw. ",
        strong("This window is drawn by the newest one:"), " Rust, with no browser in between.",
        align: "center", size: 13, stroke: BODY
      para "Shoes-Spec was his idea too: ",
        em("write down what Shoes is as tests that any display service can run."),
        " Those tests are how this one learned to draw.",
        align: "center", size: 13, stroke: BODY
      para "Thank you, Noah. The code lives on at ",
        link("scarpe-team/scarpe", click: "https://github.com/scarpe-team/scarpe", stroke: CLAY),
        ".", align: "center", size: 13, stroke: BODY
    end

    inscription "Scarpe is Italian for shoes. Lacci, the layer that ties apps to their displays, means laces.",
      align: "center", stroke: MUTED, margin: [48, 8, 48, 0]
  end
end
