# Kanban: a board of cards in three columns, To do, Doing and Done.
#
# Drag a card to move it, or click it to open it: change its title, its labels,
# its column and its notes. Press N for a new card, Escape to put things away.
# The board is saved as you go, in ~/Library/Application Support/Kanban.

require "json"
require "fileutils"

INK = "#1e2140"
MUTED = "#6b6f86"
FAINT = "#9a9db0"
ACCENT = "#5b5bd6"
CORAL = "#e5484d"
COLUMNS = { "todo" => ["To do", "#7c8095"], "doing" => ["Doing", "#e8a33d"], "done" => ["Done", "#30a46c"] }
LABELS = {
  "Design" => "#8e4ec6", "Build" => "#3e63dd", "Bug" => "#e5484d",
  "Research" => "#d68a00", "Writing" => "#12a594", "Launch" => "#d6409f",
}
SAVE_FILE = File.join(Dir.home, "Library", "Application Support", "Kanban", "board.json")

# The board: every card, in order, kept in one JSON file. Plain Ruby, no Shoes.
# A card is { "id" => 3, "title" => "...", "notes" => "...", "labels" => ["Bug"], "column" => "doing" }.
class Board
  attr_reader :cards

  def self.open
    File.exist?(SAVE_FILE) ? new(JSON.parse(File.read(SAVE_FILE))) : sample
  rescue JSON::ParserError
    FileUtils.mv(SAVE_FILE, "#{SAVE_FILE}.unreadable") # keep it, but start again
    sample
  end

  def initialize(data)
    @cards = data["cards"]
    @next_id = data["next_id"] || (@cards.map { |card| card["id"] }.max || 0) + 1
  end

  def save
    FileUtils.mkdir_p(File.dirname(SAVE_FILE))
    File.write("#{SAVE_FILE}.new", JSON.pretty_generate("cards" => @cards, "next_id" => @next_id))
    File.rename("#{SAVE_FILE}.new", SAVE_FILE) # a crash mid-write never leaves half a file
  end

  def in(column) = @cards.select { |card| card["column"] == column }

  def add(title, column)
    card = { "id" => @next_id, "title" => title, "notes" => "", "labels" => [], "column" => column }
    @next_id += 1
    @cards << card
    save
    card
  end

  # Moves a card into a column, just before another card, or to the end of it.
  def move(card, column, before = nil)
    @cards.delete(card)
    card["column"] = column
    at = before ? @cards.index(before) : (@cards.rindex { |c| c["column"] == column } || @cards.size - 1) + 1
    @cards.insert(at, card)
    save
  end

  def delete(cards)
    @cards -= cards
    save
  end

  # Puts cards back where they were, for Undo.
  def restore(cards)
    @cards = cards
    save
  end

  def self.sample
    cards = [
      ["Interview five customers", "todo", ["Research"], "Ask what they use today, and what annoys them about it."],
      ["Write the launch email", "todo", ["Writing", "Launch"], ""],
      ["Price the Pro plan", "todo", ["Research"], "Look at three competitors first."],
      ["Record a two minute demo", "todo", ["Launch"], ""],
      ["Sketch the landing page", "doing", ["Design"], "A big headline, three features, one quote and a button."],
      ["Fix sign in on Safari", "doing", ["Bug", "Build"], "Only on the first visit. Cookies?"],
      ["Pick a colour palette", "doing", ["Design"], ""],
      ["Set up the domain", "done", ["Build"], ""],
      ["Choose a name", "done", ["Writing"], "Went with the short one."],
      ["Draw the app icon", "done", ["Design"], ""],
    ]
    new("cards" => cards.each_with_index.map do |(title, column, labels, notes), i|
      { "id" => i + 1, "title" => title, "notes" => notes, "labels" => labels, "column" => column }
    end)
  end
end

Shoes.app(title: "Kanban", width: 1040, height: 680, resizable: false) do
  @board = Board.open
  @views = {}    # column => { card id => its slot on the board }
  @lists = {}    # column => the slot its cards are in
  @counts = {}   # column => the number in its header
  @lefts = {}    # column => where it sits across the window
  @edges = {}    # column => its border, lit up while a card is dragged over it
  @filter = nil  # a label name, or nil for every card

  # ---- little helpers ------------------------------------------------------------------

  # A colour at a fraction of its strength over white, for soft fills.
  def tint(hex, strength)
    r, g, b = hex.scan(/\h\h/).map(&:hex)
    rgb(*[r, g, b].map { |c| (255 - (255 - c) * strength).round })
  end

  def label(text, margin: [0, 0, 0, 8])
    para text.upcase, size: 10, weight: "semibold", kerning: 1.4, stroke: FAINT, margin: margin
  end

  # A small rounded pill with a label's name in it. Its width is a guess from the name.
  def pill(name, color, size: 10)
    stack width: name.length * size * 0.62 + 21, height: size + 13, margin: [0, 0, 5, 5] do
      background tint(color, 0.14), curve: (size + 8) / 2
      para name, size: size, weight: "semibold", stroke: color, align: "center", margin: [0, 3, 0, 0]
    end
  end

  def toast(*message, undo: nil)
    message << link("Undo", stroke: "#b4b4ff") { undo.call; @toast.hide } if undo
    @toast_text.replace(*message)
    @toast.show
    @toast_timer&.stop
    @toast_timer = timer(4) { @toast.hide }
  end

  # ---- the board -----------------------------------------------------------------------

  def header
    flow left: 28, top: 22, width: 640, height: 44 do
      stack width: 34, height: 34, margin_top: 2 do
        background INK, curve: 9
        nostroke
        fill white
        rect 7, 8, 5, 18, curve: 2
        rect 14.5, 8, 5, 12, curve: 2
        fill "#b4b4ff"
        rect 22, 8, 5, 15, curve: 2
      end
      para "Spring launch", size: 22, weight: "bold", stroke: INK, margin: [12, 3, 0, 0]
      @summary = para "", size: 13, stroke: MUTED, margin: [12, 10, 0, 0]
    end
    button("New card", width: 112, height: 34, color: INK, stroke: white, left: 900, top: 26, tooltip: "N") { start_adding("todo") }
    flow left: 28, top: 76, width: 980, height: 30 do
      para "Show", size: 12, stroke: MUTED, margin: [2, 6, 10, 0]
      @chips = {}
      ([nil] + LABELS.keys).each do |name|
        color = name ? LABELS[name] : INK
        words = name || "Every card"
        look = words_para = nil
        chip = stack width: words.length * 6.8 + (name ? 46 : 32), height: 28, margin_right: 6 do
          look = background white, curve: 14
          border tint(color, 0.3), curve: 14
          if name
            nostroke
            fill color
            oval 12, 10, 8
          end
          words_para = para words, size: 12, weight: "medium", stroke: INK, margin: [name ? 26 : 12, 6, 0, 0]
        end
        chip.click { choose_filter(name) unless @open_card }
        @chips[name] = [look, words_para, color]
      end
    end
  end

  def column(key, left)
    name, color = COLUMNS[key]
    @lefts[key] = left
    stack left: left, top: 120, width: 320, height: 540 do
      background rgb(255, 255, 255, 0.55), curve: 18
      @edges[key] = border rgb(255, 255, 255, 0.95), curve: 18, strokewidth: 1.5
      flow margin: [18, 16, 16, 0], height: 40 do
        nostroke
        fill color
        oval 0, 6, 10
        para name, size: 14, weight: "bold", stroke: INK, margin: [18, 0, 0, 0]
        @counts[key] = para "", size: 12, weight: "semibold", stroke: FAINT, margin: [8, 2, 0, 0]
        if key == "done"
          para link("Clear", stroke: FAINT) { clear_done }, size: 12, align: "right", margin: [0, 2, 0, 0]
        end
      end
      @lists[key] = stack left: 0, top: 46, width: 320, height: 494, scroll: true do end
    end
  end

  def refresh(*columns)
    columns = COLUMNS.keys if columns.empty?
    columns.each do |key|
      cards = @board.in(key)
      shown = cards.select { |card| shows?(card) }
      @counts[key].replace(shown.size == cards.size ? cards.size.to_s : "#{shown.size} of #{cards.size}")
      dragging_here = @drag && @drag[:key] == key
      @edges[key].stroke = dragging_here ? rgb(91, 91, 214, 0.45) : rgb(255, 255, 255, 0.95)
      @views[key] = {}
      @lists[key].clear do
        shown.each do |card|
          space_for_drag if dragging_here && card.equal?(@drag[:before])
          card_view(card) unless @drag && card.equal?(@drag[:card])
        end
        space_for_drag if dragging_here && @drag[:before].nil?
        if @adding == key
          add_box(key)
        elsif shown.empty? && @filter
          para "No #{@filter} cards here", size: 12, stroke: FAINT, align: "center", margin: [0, 16, 0, 0]
        end
        add_row(key) unless @adding == key
      end
    end
    done = @board.in("done").size
    @summary.replace "#{@board.cards.size} cards, #{done} done"
  end

  def shows?(card) = @filter.nil? || card["labels"].include?(@filter)

  # One card: its labels, its title and the first line of its notes.
  # A soft shadow peeks out underneath; pointing at it rings it in blue.
  def card_view(card)
    edge = nil
    view = stack width: 308, margin: [12, 0, 0, 10] do
      background rgb(30, 33, 80, 0.07), curve: 11, top: 2
      background white, curve: 10, bottom: 2
      edge = border rgb(30, 33, 80, 0.07), curve: 10, bottom: 2
      stack margin: [14, 12, 14, 14] do
        unless card["labels"].empty?
          flow(margin_bottom: 3) { card["labels"].each { |name| pill(name, LABELS[name]) } }
        end
        title = card["title"].to_s.strip.empty? ? "Untitled card" : card["title"]
        para title, size: 13.5, weight: "semibold", stroke: card["column"] == "done" ? MUTED : INK, margin: [0, 0, 18, 0]
        notes = card["notes"].to_s.strip
        para notes.lines.first.to_s.strip, size: 12, stroke: MUTED, wrap: "trim", margin: [0, 5, 0, 0] unless notes.empty?
      end
      if card["column"] == "done"
        nostroke
        fill COLUMNS["done"][1]
        oval 262, 12, 18
        stroke white
        strokewidth 2
        cap :curve
        line 267, 21, 270, 24
        line 270, 24, 275, 17
      end
    end
    view.hover { edge.stroke = ACCENT unless @drag }
    view.leave { edge.stroke = rgb(30, 33, 80, 0.07) }
    view.click { |_button, x, y| press(card, view, x, y) }
    @views[card["column"]][card["id"]] = view
  end

  def add_row(key)
    look = nil
    row = flow width: 308, height: 38, margin: [12, 0, 0, 10] do
      look = background tint(INK, 0.05), curve: 10, hidden: true
      para "+  Add a card", size: 13, weight: "medium", stroke: MUTED, margin: [14, 10, 0, 0]
    end
    row.hover { look.show }
    row.leave { look.hide }
    row.click { start_adding(key) unless @open_card }
  end

  # A new card is typed into an edit box; Return adds it, Escape gives up.
  def add_box(key)
    stack width: 308, margin: [12, 0, 0, 10] do
      background white, curve: 10
      border ACCENT, curve: 10, strokewidth: 1.5
      stack margin: [10, 10, 10, 10] do
        @new_title = edit_box width: 276, height: 54
        @new_title.change do
          add_card(key) if @new_title.text.include?("\n")
        end
        flow margin_top: 8 do
          button("Add card", width: 88, height: 28, color: ACCENT, stroke: white) { add_card(key) }
          para link("Cancel", stroke: MUTED) { stop_adding }, size: 12, margin: [12, 7, 0, 0]
          para "Return adds", size: 11, stroke: FAINT, align: "right", margin: [0, 8, 0, 0]
        end
      end
    end
  end

  def start_adding(key)
    close_sheet if @open_card
    @adding = key
    refresh
    @new_title.focus
  end

  def stop_adding
    @adding = nil
    refresh
  end

  def add_card(key)
    title = @new_title.text.delete("\n").strip
    if title.empty?
      @new_title.text = ""
      return
    end
    @board.add(title, key)
    refresh(key)
    @new_title.focus # ready for the next one
  end

  def clear_done
    before = @board.cards.map(&:dup)
    done = @board.in("done")
    return if done.empty?

    @board.delete(done)
    refresh("done")
    toast "Cleared #{done.size} done #{done.size == 1 ? "card" : "cards"}. ", undo: -> { @board.restore(before); refresh }
  end

  def choose_filter(name)
    @filter = name
    @chips.each do |each_name, (look, words, color)|
      on = each_name == name
      every_card = each_name.nil?
      look.fill = on ? (every_card ? INK : tint(color, 0.16)) : white
      words.stroke = on && every_card ? white : INK
    end
    refresh
  end

  # ---- dragging ------------------------------------------------------------------------

  # A press on a card might be the start of a drag or just a click; the pointer decides.
  # In Shoes a press reaches every slot under the pointer, even ones covered by the
  # sheet, so the board ignores presses while a card is open.
  def press(card, view, x, y)
    return if @open_card

    @press = { card: card, x: x, y: y, dx: x - view.left - 12, dy: y - view.top, height: view.height - 10 }
  end

  def pointer_moved(x, y)
    return unless @press

    start_drag(x, y) if !@drag && Math.hypot(x - @press[:x], y - @press[:y]) > 4
    return unless @drag

    @ghost.move(x - @press[:dx], y - @press[:dy])
    key, before = drop_place(x, y)
    return if key == @drag[:key] && before.equal?(@drag[:before])

    old_key = @drag[:key]
    @drag[:key], @drag[:before] = key, before
    refresh(*[old_key, key].uniq)
  end

  # The card lifts off the board: a copy follows the pointer, and a space the size
  # of the card opens wherever it would land, starting where it was.
  def start_drag(x, y)
    card = @press[:card]
    shown = @board.in(card["column"]).select { |each| shows?(each) }
    @drag = { card: card, key: card["column"], before: shown[shown.index(card) + 1] }
    @ghost = stack left: x - @press[:dx], top: y - @press[:dy], width: 296 do
      background rgb(30, 33, 80, 0.16), curve: 12, top: 6
      background white, curve: 10, bottom: 4
      border ACCENT, curve: 10, bottom: 4, strokewidth: 1.5
      stack margin: [14, 12, 14, 18] do
        flow(margin_bottom: 3) { card["labels"].each { |name| pill(name, LABELS[name]) } } unless card["labels"].empty?
        para card["title"], size: 13.5, weight: "semibold", stroke: INK, margin: [0, 0, 18, 0]
      end
    end
    refresh(card["column"])
  end

  # The column nearest the pointer, and the card the dragged one would land before
  # (nil for the end of the column).
  def drop_place(x, y)
    key = COLUMNS.keys.min_by { |each| (x - (@lefts[each] + 160)).abs }
    before = @board.in(key).find do |card|
      view = @views[key][card["id"]]
      view && y < view.top + view.height / 2
    end
    [key, before]
  end

  def space_for_drag
    stack width: 308, height: @press[:height] + 10, margin: [12, 0, 0, 10] do
      background rgb(91, 91, 214, 0.07), curve: 10
      border rgb(91, 91, 214, 0.35), curve: 10, strokewidth: 1.5
    end
  end

  def released(_x, _y)
    press = @press
    @press = nil
    return unless press
    return open_sheet(press[:card]) unless @drag

    drag = @drag
    @drag = nil
    @ghost.remove
    from = drag[:card]["column"]
    @board.move(drag[:card], drag[:key], drag[:before])
    refresh(*[from, drag[:key]].uniq)
  end

  # ---- the card sheet ------------------------------------------------------------------

  def sheet
    @dim = stack left: 0, top: 0, width: 1040, height: 680, hidden: true do
      @dim_look = background rgb(24, 26, 56, 0.0)
    end
    @dim.click { |_button, x, _y| close_sheet if x < @sheet.left } # a press on the sheet reaches the dim too
    @sheet = stack left: 1040, top: 0, width: 380, height: 680, hidden: true do
      background white
      background rgb(30, 33, 80, 0.08), width: 1
      stack margin: [28, 26, 28, 0] do
        flow do
          label "Card", margin: [0, 6, 0, 0]
          close = stack width: 30, height: 30, right: 0, top: 0 do
            para "×", size: 20, stroke: MUTED, align: "center", margin: [0, 1, 0, 0]
          end
          close.click { close_sheet }
        end
        @title_box = edit_box width: 324, height: 72, margin_top: 8, font: "semibold 16px"
        @title_box.change do
          title = @title_box.text
          if title.include?("\n")
            @title_box.text = title.delete("\n")
            @notes_box.focus
          end
          @open_card["title"] = @title_box.text.strip
          @board.save
          refresh(@open_card["column"])
        end

        label "Labels", margin: [0, 20, 0, 8]
        @label_chips = {}
        flow do
          LABELS.each do |name, color|
            look = words = nil
            chip = stack width: 108, height: 34, margin: [0, 0, 6, 6] do
              look = background white, curve: 14
              border tint(color, 0.35), curve: 14
              words = para name, size: 12, weight: "semibold", stroke: color, align: "center", margin: [0, 6, 0, 0]
            end
            chip.click { toggle_label(name) }
            @label_chips[name] = [look, words, color]
          end
        end

        label "Column", margin: [0, 16, 0, 8]
        @column_chips = {}
        flow width: 324, height: 34 do
          background tint(INK, 0.06), curve: 17
          COLUMNS.each do |key, (name, color)|
            chip = nil
            segment = stack width: 108, height: 34 do
              chip = background white, curve: 14, margin: 3, hidden: true
              nostroke
              fill color
              oval 26, 13, 8
              para name, size: 12, weight: "semibold", stroke: INK, margin: [40, 9, 0, 0]
            end
            segment.click { move_open_card(key) }
            @column_chips[key] = chip
          end
        end

        label "Notes", margin: [0, 20, 0, 8]
        @notes_box = edit_box width: 324, height: 150
        @notes_box.change do
          @open_card["notes"] = @notes_box.text
          @board.save
          refresh(@open_card["column"])
        end

        flow margin_top: 22 do
          para link("Delete card", stroke: CORAL) { delete_open_card }, size: 13, margin: [0, 8, 0, 0]
          button("Done", width: 90, height: 32, color: INK, stroke: white, right: 0, top: 0) { close_sheet }
        end
      end
    end
  end

  def open_sheet(card)
    stop_adding if @adding
    @open_card = card
    @title_box.text = card["title"]
    @notes_box.text = card["notes"]
    show_card_labels
    @column_chips.each { |key, chip| chip.hidden = key != card["column"] }
    slide_sheet(open: true)
  end

  def close_sheet
    return unless @open_card

    @open_card = nil
    slide_sheet(open: false)
  end

  # The sheet glides in from the right edge while the board dims behind it.
  def slide_sheet(open:)
    @dim.show
    @sheet.show
    @slide&.stop
    from = @sheet.style[:left] || 1040
    to = open ? 660 : 1040
    @slide = animate(60) do |frame|
      t = [frame / 14.0, 1].min
      ease = 1 - (1 - t)**3
      @sheet.move((from + (to - from) * ease).round, 0)
      shade = open ? ease : 1 - ease
      @dim_look.fill = rgb(24, 26, 56, (0.28 * shade).round(3))
      next unless t >= 1

      @slide.stop
      @dim.hide unless open
      @sheet.hide unless open
    end
  end

  def show_card_labels
    @label_chips.each do |name, (look, words, color)|
      on = @open_card["labels"].include?(name)
      look.fill = on ? color : white
      words.stroke = on ? white : color
    end
  end

  def toggle_label(name)
    labels = @open_card["labels"]
    labels.include?(name) ? labels.delete(name) : labels.push(name)
    labels.sort_by! { |each| LABELS.keys.index(each) }
    @board.save
    show_card_labels
    refresh(@open_card["column"])
  end

  def move_open_card(key)
    from = @open_card["column"]
    return if from == key

    @board.move(@open_card, key)
    @column_chips.each { |each_key, chip| chip.hidden = each_key != key }
    refresh(from, key)
  end

  def delete_open_card
    card = @open_card
    before = @board.cards.map(&:dup)
    close_sheet
    @board.delete([card])
    refresh(card["column"])
    toast "Deleted “#{card["title"]}”. ", undo: -> { @board.restore(before); refresh }
  end

  # ---- putting it together -------------------------------------------------------------

  background "#e9ebf8".."#f5eff9", angle: 30
  header
  COLUMNS.keys.each_with_index { |key, i| column(key, 20 + i * 340) }
  sheet
  @toast = stack left: 330, top: 612, width: 380, height: 42, hidden: true do
    background INK, curve: 21
    @toast_text = para "", align: "center", size: 13, stroke: white, margin: [14, 12, 14, 0]
  end
  refresh
  choose_filter(nil)

  motion { |x, y| pointer_moved(x, y) }
  release { |_button, x, y| released(x, y) }
  keypress do |key|
    case key
    when "n" then start_adding("todo") unless @open_card
    when :escape
      close_sheet
      stop_adding if @adding
    end
  end
end
