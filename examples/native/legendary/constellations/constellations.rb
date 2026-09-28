# Constellations: join the stars into pictures of your own, name them, keep them.
#
# Click a star, then another, and another: lines join them. Click the last star
# again to finish, give it a name, and it goes in your catalog. The sky grows
# from one seed, so it is the same sky every time you come back.
#
# Three pages, each a url: "/" is the sky, "/catalog" your constellations
# (and "/catalog/2" one of them), "/about" this app.

require "json"
require "fileutils"

W, H = 920, 620
HORIZON = 540 # stars stay above the hills
SEED = 1609
SERIF = "Iowan Old Style, Georgia, serif"
INK = "#e9ecff"
MUTED = "#8a93b8"
GOLD = [255, 214, 140]
CYAN = [120, 220, 255]
REACH = 22 # how close a click has to be to a star

Shoes.app(title: "Constellations", width: W, height: H, resizable: false) do
  url "/", :sky
  url "/catalog", :catalog
  url "/catalog/(\\d+)", :constellation
  url "/about", :about

  # ---------------------------------------------------------------- keeping them

  # ~/Library/Application Support/Constellations on a Mac, ~/.local/share elsewhere.
  def data_file
    base = if RUBY_PLATFORM.include?("darwin")
             File.join(Dir.home, "Library", "Application Support")
           else
             ENV.fetch("XDG_DATA_HOME", File.join(Dir.home, ".local", "share"))
           end
    File.join(base, "Constellations", "constellations.json")
  end

  def load_catalog
    return [] unless File.exist?(data_file)

    JSON.parse(File.read(data_file)).select do |c|
      c["edges"].is_a?(Array) && c["edges"].flatten.all? { |i| i.is_a?(Integer) && @bright[i] }
    end
  rescue JSON::ParserError
    []
  end

  # One constellation to a line, so the file is easy to read and to mend by hand.
  def save_catalog
    FileUtils.mkdir_p(File.dirname(data_file))
    File.write(data_file, "[\n" + @named.map { |c| "  #{JSON.generate(c)}" }.join(",\n") + "\n]\n")
  end

  # ---------------------------------------------------------------- the sky, grown from its seed

  def grow_sky
    seed = Random.new(SEED)
    @faint = Array.new(420) { [seed.rand(0.0..W), seed.rand(56.0..HORIZON), seed.rand(1.2..2.4), seed.rand(0.2..0.75)] }
    # The Milky Way: a band of fainter, tinier stars from bottom left to top right.
    @milky = Array.new(300) do
      t = seed.rand
      spread = (seed.rand + seed.rand + seed.rand - 1.5) * 70
      [-40 + (W + 80) * t + spread * 0.4, 500 - 420 * t + 40 * Math.sin(t * 4) + spread, seed.rand(1.1..1.7), seed.rand(0.1..0.4)]
    end
    @bright = []
    until @bright.size == 64
      x = seed.rand(40..W - 40)
      y = seed.rand(96..HORIZON - 50)
      next if @bright.any? { |bx, by| Math.hypot(bx - x, by - y) < 46 }

      @bright << [x, y, seed.rand(3.0..5.2).round(1)]
    end
  end

  # The star under the pointer, if there is one close enough.
  def star_near(x, y)
    index = @bright.each_index.min_by { |i| Math.hypot(@bright[i][0] - x, @bright[i][1] - y) }
    index if Math.hypot(@bright[index][0] - x, @bright[index][1] - y) < REACH
  end

  # ---------------------------------------------------------------- drawing kit

  # A line between two stars with a soft glow under it. Returns both, glow first.
  def glow_line(a, b, color, alpha)
    ax, ay = @bright[a]
    bx, by = @bright[b]
    [line(ax, ay, bx, by, strokewidth: 7, stroke: rgb(*color, alpha * 0.22)),
      line(ax, ay, bx, by, strokewidth: 1.6, stroke: rgb(*color, alpha))]
  end

  # Where a constellation's name goes: centred under its stars.
  def label_spot(c)
    stars = c["edges"].flatten.uniq.map { |i| @bright[i] }
    cx = stars.sum { |s| s[0] } / stars.size
    [(cx - 110).clamp(8, W - 228), [stars.map { |s| s[1] }.max + 16, HORIZON - 6].min]
  end

  # A constellation drawn small, fitted into a box: for the catalog and its pages.
  def miniature(c, left, top, width, height, dots: 2.2)
    stars = c["edges"].flatten.uniq
    xs = stars.map { |i| @bright[i][0] }
    ys = stars.map { |i| @bright[i][1] }
    scale = [(width - 40.0) / [xs.max - xs.min, 1].max, (height - 40.0) / [ys.max - ys.min, 1].max, 2.4].min
    ox = left + (width - (xs.max - xs.min) * scale) / 2 - xs.min * scale
    oy = top + (height - (ys.max - ys.min) * scale) / 2 - ys.min * scale
    at = ->(i) { [ox + @bright[i][0] * scale, oy + @bright[i][1] * scale] }
    cap :curve
    c["edges"].each do |a, b|
      strokewidth 5 * dots / 2.2
      stroke rgb(*GOLD, 0.14)
      line(*at.(a), *at.(b))
      strokewidth 1.4 * dots / 2.2
      stroke rgb(*GOLD, 0.8)
      line(*at.(a), *at.(b))
    end
    nostroke
    stars.each do |i|
      x, y = at.(i)
      oval x, y, dots * 4, center: true, fill: rgb(255, 255, 255, 0.12)
      oval x, y, dots * 1.6, center: true, fill: white
    end
  end

  def night_background
    background "#02040c".."#111a42"
    nostroke
    @faint.each { |x, y, size, alpha| oval x, y, size, center: true, fill: rgb(225, 232, 255, alpha * 0.6) }
  end

  # A soft rounded button; `gold` for the one that matters most.
  def pill(text, width, gold: false, &on_click)
    button = stack(width: width + 10, height: 46, margin: [0, 0, 10, 10]) do # margins sit inside the size
      background gold ? rgb(*GOLD, 0.9) : rgb(255, 255, 255, 0.08), curve: 18
      border rgb(255, 255, 255, gold ? 0 : 0.14), curve: 18
      para text, align: "center", size: 13, weight: "semibold", stroke: gold ? "#1b1405" : INK, margin: [0, 9, 0, 0]
    end
    button.click(&on_click)
    button
  end

  # Links to the three pages; the one you are on is lit.
  def nav(here)
    stack(left: 0, top: 0, width: W, height: 56) do
      background rgb(2, 4, 12, 0.55)
      para "Constellations", size: 20, family: SERIF, stroke: INK, left: 24, top: 15
      flow(left: W - 262, top: 19, width: 250) do
        [["Sky", "/"], ["Catalog", "/catalog"], ["About", "/about"]].each do |name, path|
          lit = here == path
          para link(name, click: path, stroke: lit ? INK : MUTED, underline: lit ? "single" : "none"),
            size: 13, weight: lit ? "semibold" : "normal", margin: [14, 0, 14, 0]
        end
      end
    end
  end

  # ---------------------------------------------------------------- page one: the sky

  def sky
    @draft = nil
    background "#02040c".."#1a2556"
    nostroke
    fill rgb(170, 185, 255, 0.009)
    56.times do |i| # the Milky Way's haze: many faint discs, so no edge shows
      t = i / 55.0
      oval(-40 + (W + 80) * t, 500 - 420 * t + 40 * Math.sin(t * 4), 90 + 50 * Math.sin(i * 1.7).abs, center: true)
    end
    @milky.each { |x, y, size, alpha| oval x, y, size, center: true, fill: rgb(215, 222, 255, alpha) }
    @twinklers = @faint.map { |x, y, size, alpha| oval x, y, size, center: true, fill: rgb(225, 232, 255, alpha) }

    @saved_layer = stack(left: 0, top: 0, width: W, height: H) {}
    @draft_layer = stack(left: 0, top: 0, width: W, height: H) {}
    cap :curve
    strokewidth 1.4
    @band = line 0, 0, 0, 0, stroke: rgb(*CYAN, 0.5), hidden: true # the line that follows the pointer

    @glows = @bright.map do |x, y, size|
      oval x, y, size * 5.5, center: true, fill: rgb(200, 215, 255, 0.04)
      oval x, y, size * 2.8, center: true, fill: rgb(200, 215, 255, 0.1) # the inner glow breathes
    end
    @bright.each do |x, y, size|
      oval x, y, size, center: true, fill: white
    end
    nofill
    strokewidth 1.5
    @hover_ring = oval 0, 0, 22, center: true, stroke: rgb(255, 255, 255, 0.55), hidden: true
    strokewidth 2
    @last_ring = oval 0, 0, 18, center: true, stroke: rgb(*CYAN, 0.95), hidden: true
    @meteor = line 0, 0, 0, 0, stroke: rgb(255, 255, 255, 0), strokewidth: 1.6, hidden: true

    hills
    nav "/"
    @status = stack(left: W / 2 - 280, top: H - 64, width: 560, height: 52) {}
    draw_saved
    show_status

    click do |_button, x, y|
      star = star_near(x, y)
      pick(star) if star && y > 56 && @naming.nil?
    end
    motion { |x, y| follow(x, y) }
    keypress do |key|
      case key
      when :escape then let_go
      when "\n" then finish
      when :backspace then take_back
      end
    end
    animate(12) { |frame| twinkle(frame) }
    @focus_frames = 72 if @focus
  end

  # Rolling hills, a few pines and a little observatory with its slit open.
  def hills
    nostroke
    fill "#080e26"
    shape do
      move_to 0, 548
      curve_to 180, 500, 330, 520, 470, 540
      curve_to 610, 510, 760, 500, 920, 530
      line_to 920, 620
      line_to 0, 620
    end
    fill "#050915"
    shape do
      move_to 0, 578
      curve_to 140, 548, 260, 556, 380, 580
      curve_to 520, 602, 700, 560, 920, 566
      line_to 920, 620
      line_to 0, 620
    end
    [[60, 560, 26], [84, 556, 34], [108, 562, 22], [800, 560, 30]].each do |x, y, tall|
      shape { move_to x - tall * 0.3, y; line_to x, y - tall; line_to x + tall * 0.3, y }
    end
    rect 708, 540, 52, 30
    shape { move_to 702, 541; curve_to 702, 514, 766, 514, 766, 541; line_to 702, 541 }
    stroke "#050915"
    strokewidth 5
    line 736, 526, 756, 506 # the telescope, looking up
    nostroke
    fill rgb(255, 205, 130, 0.95)
    shape { move_to 731, 541; line_to 732, 521; line_to 736, 521; line_to 737, 541 }
    rect 716, 552, 8, 8
    rect 744, 552, 8, 8
  end

  def draw_saved
    @saved_lines = []
    @saved_layer.clear do
      cap :curve
      @named.each do |c|
        @saved_lines << c["edges"].flat_map { |a, b| glow_line(a, b, GOLD, 0.62) }
        left, top = label_spot(c)
        para c["name"].upcase, size: 10, kerning: 3, align: "center", stroke: rgb(*GOLD, 0.85),
          left: left, top: top, width: 220
      end
    end
  end

  def draw_draft
    @draft_layer.clear do
      cap :curve
      @draft[:edges].each { |a, b| glow_line(a, b, CYAN, 0.95) }
    end
    x, y = @bright[@draft[:last]]
    @last_ring.move(x, y)
    @last_ring.show
  end

  # One click on a star: start, carry on from it, or finish on the star you ended at.
  def pick(star)
    if @draft.nil?
      @draft = { edges: [], last: star }
    elsif star == @draft[:last]
      return finish
    else
      edge = [@draft[:last], star]
      @draft[:edges] << edge unless @draft[:edges].any? { |e| e.sort == edge.sort }
      @draft[:last] = star
    end
    draw_draft
    show_status
  end

  def finish
    return let_go if @draft.nil? || @draft[:edges].empty?

    @naming = true
    @band.hide
    show_status
  end

  def take_back
    return unless @draft && @naming.nil?

    gone = @draft[:edges].pop
    return let_go if gone.nil?

    @draft[:last] = gone[0]
    draw_draft
  end

  def let_go
    @draft = nil
    @naming = nil
    @draft_layer&.clear
    @last_ring.hide
    @band.hide
    show_status
  end

  def save_draft
    name = @name_field.text.strip
    name = "Nameless No. #{@named.size + 1}" if name.empty?
    @named << { "name" => name, "edges" => @draft[:edges], "made" => Time.now.strftime("%-d %b %Y") }
    save_catalog
    @focus = @named.size - 1
    @focus_frames = 48
    @draft = nil
    @naming = nil
    @draft_layer.clear
    @last_ring.hide
    draw_saved
    show_status("Saved #{name}. It is in your catalog now.")
  end

  def follow(x, y)
    star = star_near(x, y)
    if star
      @hover_ring.move(*@bright[star].first(2))
      @hover_ring.show
    else
      @hover_ring.hide
    end
    return @band.hide unless @draft && @naming.nil?

    from = @bright[@draft[:last]]
    to = star ? @bright[star] : [x, y]
    @band.style(left: from[0], top: from[1], x2: to[0], y2: to[1], hidden: false)
  end

  def show_status(note = nil)
    @status.clear do
      background rgb(8, 12, 32, 0.78), curve: 26
      border rgb(255, 255, 255, 0.08), curve: 26, strokewidth: 5
      if @naming
        flow(margin: [20, 8, 0, 0]) do
          para "Name it", size: 13, stroke: MUTED, margin: [0, 10, 10, 0]
          @name_field = edit_line width: 250, margin: [0, 4, 10, 0]
          pill("Save", 76, gold: true) { save_draft }
          para link("Let it go", click: proc { let_go }, stroke: MUTED), size: 12, margin: [4, 10, 0, 0]
        end
        @name_field.focus
      else
        text = note || if @draft.nil?
                         "Click a star to begin a constellation."
                       else
                         "Keep clicking stars. Click the last one again to finish."
                       end
        para text, align: "center", size: 13, stroke: INK, margin: [0, 17, 0, 0]
      end
    end
  end

  # Stars twinkle; now and then one falls.
  def twinkle(frame)
    5.times do
      i = rand(@twinklers.size)
      @twinklers[i].fill = rgb(225, 232, 255, @faint[i][3] * rand(0.3..1.0))
    end
    @glows.each_with_index { |glow, i| glow.fill = rgb(200, 215, 255, 0.1 + 0.05 * Math.sin(frame / 7.0 + i)) } if frame % 3 == 0
    fall(frame)
    pulse(frame)
  end

  def fall(frame)
    @falling = { x: rand(200..W - 60).to_f, y: rand(80..220).to_f, age: 0 } if @falling.nil? && frame % 80 == 40
    return unless @falling

    @falling[:age] += 1
    k = @falling[:age] / 10.0
    x = @falling[:x] - 260 * k
    y = @falling[:y] + 110 * k
    @meteor.style(left: x, top: y, x2: x + 60, y2: y - 25, stroke: rgb(255, 255, 255, 0.8 * (1 - k)), hidden: k >= 1)
    @falling = nil if k >= 1
  end

  # A constellation you just saved, or asked to see, pulses for a few seconds.
  def pulse(frame)
    lines = @focus && @focus_frames && @saved_lines[@focus]
    return @focus = nil unless lines

    @focus_frames -= 1
    glow = @focus_frames.positive? ? (1 - Math.cos(frame / 2.0)) / 2 : 0
    alpha = 0.62 + 0.38 * glow
    lines.each_slice(2) do |under, over|
      under.stroke = rgb(*GOLD, alpha * 0.22)
      over.stroke = rgb(*GOLD, alpha)
    end
    @focus = @focus_frames = nil unless @focus_frames.positive?
  end

  # ---------------------------------------------------------------- page two: the catalog

  def catalog
    night_background
    nav "/catalog"
    stars = @named.sum { |c| c["edges"].flatten.uniq.size }
    summary = if @named.empty?
                "Nothing here yet."
              else
                "#{@named.size} #{@named.size == 1 ? "constellation" : "constellations"}, #{stars} stars. Click one to see it up close."
              end
    stack(left: 40, top: 80, width: W - 80) do
      title "Your catalog", family: SERIF, size: 34, stroke: INK, margin: [0, 0, 0, 4]
      para summary, size: 13, stroke: MUTED
    end
    if @named.empty?
      stack(left: 40, top: 200, width: 400) do
        para "The sky is waiting. ", link("Go and draw one", click: "/", stroke: rgb(*GOLD)), ".", size: 15, stroke: INK
      end
      return
    end
    flow(left: 30, top: 170, width: W - 60, height: H - 180, scroll: true) do
      @named.each_with_index { |c, n| card(c, n) }
    end
  end

  def card(c, n)
    box = stack(width: 206, height: 216, margin: 7) do
      background rgb(255, 255, 255, 0.05), curve: 14
      border rgb(255, 255, 255, 0.08), curve: 14
      stack(width: 192, height: 128, margin: [0, 0, 0, 0]) do
        background rgb(0, 0, 0, 0.35), curve: 12
        miniature(c, 0, 0, 192, 128)
      end
      para c["name"], size: 15, family: SERIF, stroke: INK, margin: [12, 10, 8, 0]
      para "#{c["edges"].flatten.uniq.size} stars · #{c["made"]}", size: 11, stroke: MUTED, margin: [12, 2, 8, 0]
    end
    box.click { visit "/catalog/#{n}" }
  end

  # ---------------------------------------------------------------- one constellation

  def constellation(n)
    c = @named[n.to_i]
    return visit("/catalog") unless c

    night_background
    nav "/catalog"
    stack(left: 40, top: 84, width: 520, height: 400) do
      background rgb(0, 0, 0, 0.35), curve: 18
      border rgb(255, 255, 255, 0.08), curve: 18
      miniature(c, 0, 0, 520, 400, dots: 3.4)
    end
    stars = c["edges"].flatten.uniq.size
    stack(left: 590, top: 96, width: 300) do
      para c["name"], size: 30, family: SERIF, stroke: INK, margin: [0, 0, 0, 10]
      para "#{stars} stars joined by #{c["edges"].size} #{c["edges"].size == 1 ? "line" : "lines"}.", size: 13, stroke: MUTED
      para "Drawn on #{c["made"]}.", size: 13, stroke: MUTED, margin: [4, 0, 4, 24]
      pill("Show in the sky", 160, gold: true) do
        @focus = n.to_i
        visit "/"
      end
      pill("Forget it", 110) do
        @named.delete_at(n.to_i)
        @focus = nil
        save_catalog
        visit "/catalog"
      end
      para link("Back to the catalog", click: "/catalog", stroke: rgb(*GOLD)), size: 13, margin: [4, 24, 0, 0]
    end
  end

  # ---------------------------------------------------------------- page three: about

  def about
    night_background
    nav "/about"
    stack(left: 48, top: 88, width: 480) do
      title "About", family: SERIF, size: 34, stroke: INK, margin: [0, 0, 0, 12]
      para "Every star here grows from one seed, the number #{SEED}, so the sky is the same each time ",
        "you open it and your constellations always find their stars.", size: 14, stroke: INK, leading: 7
      para "Click a star, then another, and a line joins them. Click the last star again to finish, ",
        "give it a name, and it goes in your catalog.", size: 14, stroke: INK, leading: 7
      para strong("Return"), " finishes, ", strong("Backspace"), " takes back a line, ", strong("Escape"), " lets it all go.",
        size: 13, stroke: MUTED
      para "Your catalog is kept in ", code(File.dirname(data_file).sub(Dir.home, "~")), ".", size: 12, stroke: MUTED, margin: [4, 14, 4, 4]
      para "Written in Shoes, a little Ruby for drawing, and painted by Scarpe in Rust.",
        size: 12, stroke: MUTED, emphasis: "italic", margin: [4, 14, 4, 4]
    end
    # A constellation of our own, for the shoe that Scarpe is named after.
    boot = [[640, 150], [640, 250], [650, 330], [700, 350], [780, 352], [820, 330], [770, 300], [720, 280], [705, 150]]
    stack(left: 590, top: 110, width: 290, height: 300) do
      background rgb(0, 0, 0, 0.25), curve: 18
    end
    cap :curve
    boot.zip(boot.rotate).each do |(ax, ay), (bx, by)| # each star to the next, and round again
      strokewidth 6
      stroke rgb(*GOLD, 0.14)
      line ax, ay, bx, by
      strokewidth 1.5
      stroke rgb(*GOLD, 0.8)
      line ax, ay, bx, by
    end
    nostroke
    boot.each do |x, y|
      oval x, y, 14, center: true, fill: rgb(255, 255, 255, 0.12)
      oval x, y, 5, center: true, fill: white
    end
    para "CALCEUS, THE SHOE", size: 10, kerning: 3, stroke: rgb(*GOLD, 0.85), align: "center", left: 590, top: 368, width: 290
    para "Not a real constellation. Yet.", size: 11, emphasis: "italic", stroke: MUTED, align: "center", left: 590, top: 386, width: 290
  end

  # ---------------------------------------------------------------- off we go

  grow_sky
  @named = load_catalog
end
