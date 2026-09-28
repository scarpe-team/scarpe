# Ledger: where the money came from, where it went, and what is left.
#
# Add what comes in and what goes out, give each a category, and Ledger keeps
# a running balance, a chart for every month and a budget for every category.
# Three pages, reached with url and visit:
#
#   /                 the balance, a form to add an entry, the latest entries
#   /month/2026-09    one month: its running balance, spending against budgets, a CSV export
#   /categories       every category and its monthly budget
#
# Everything is saved as you go, in ~/Library/Application Support/Ledger.

require "json"
require "date"
require "fileutils"

CURRENCY = "$"
PAPER = "#f7f4ee"
SIDEBAR = "#efe9dd"
LINE = "#e4ddcf"
INK = "#1d2a23"
MUTED = "#8a8377"
GREEN = "#2e7d5b"
CORAL = "#d4613e"
SERIF = "Iowan Old Style, Georgia, serif"
SWATCHES = ["#5b6bbf", "#4f9d7e", "#e07a5f", "#d9a13b", "#5a8fb8", "#b86ba4", "#3fa7a0", "#8c7a5b"]
SAVE_FILE = File.join(Dir.home, "Library", "Application Support", "Ledger", "ledger.json")

# The book: every entry and category, kept in one JSON file. Plain Ruby, no Shoes.
# An entry is { "date" => "2026-09-14", "note" => "Coffee", "category" => "Eating out",
# "amount" => -4.5 }: money in is positive, money out is negative.
class Book
  attr_reader :entries, :categories

  def self.open
    File.exist?(SAVE_FILE) ? new(JSON.parse(File.read(SAVE_FILE))) : sample
  rescue JSON::ParserError
    FileUtils.mv(SAVE_FILE, "#{SAVE_FILE}.unreadable") # keep it, but start again
    sample
  end

  def initialize(data)
    @entries = data["entries"]
    @categories = data["categories"]
    @sample = data["sample"]
  end

  def sample? = @sample

  def save
    FileUtils.mkdir_p(File.dirname(SAVE_FILE))
    data = { "categories" => @categories, "entries" => @entries, "sample" => @sample }
    File.write("#{SAVE_FILE}.new", JSON.pretty_generate(data))
    File.rename("#{SAVE_FILE}.new", SAVE_FILE) # a crash mid-write never leaves half a file
  end

  def add(amount, note, category, date = Date.today)
    @entries << { "date" => date.to_s, "note" => note, "category" => category, "amount" => amount.round(2) }
    save
  end

  def remove(entry)
    @entries.delete(entry)
    save
  end

  def start_fresh
    @entries = []
    @sample = false
    save
  end

  def category(name)
    @categories.find { |c| c["name"] == name } || { "name" => name, "color" => GREEN, "budget" => 0 }
  end

  def add_category(name, color)
    @categories << { "name" => name, "color" => color, "budget" => 0 }
    save
  end

  # Oldest first; entries on the same day keep the order they were added in.
  def in_order(list = @entries)
    list.each_with_index.sort_by { |entry, i| [entry["date"], i] }.map(&:first)
  end

  def in_month(month)
    in_order(@entries.select { |e| e["date"].start_with?(month.strftime("%Y-%m")) })
  end

  def balance(before: nil)
    list = before ? @entries.select { |e| e["date"] < before.to_s } : @entries
    list.sum { |e| e["amount"] }
  end

  def money_in(month) = in_month(month).select { |e| e["amount"] > 0 }.sum { |e| e["amount"] }
  def money_out(month) = -in_month(month).select { |e| e["amount"] < 0 }.sum { |e| e["amount"] }

  def spent(month, name)
    -in_month(month).select { |e| e["category"] == name && e["amount"] < 0 }.sum { |e| e["amount"] }
  end

  def budget = @categories.sum { |c| c["budget"] }

  def csv(month)
    rows = in_month(month).map { |e| [e["date"], e["note"], e["category"], format("%.2f", e["amount"])] }
    ([%w[date note category amount]] + rows).map { |row| row.map { |cell| quote(cell) }.join(",") }.join("\n") + "\n"
  end

  # Two months of a made-up life, so a first launch has something to show:
  # last month in full and this month up to today.
  def self.sample
    days = [
      [1, "Salary", "Income", 3900], [1, "Rent", "Home", -1850], [2, "Farmers market", "Groceries", -38.4],
      [3, "Metro card", "Transport", -64], [4, "Coffee and a croissant", "Eating out", -7.8],
      [5, "Phone", "Bills", -45], [6, "Supermarket", "Groceries", -82.15], [7, "Cinema", "Fun", -24],
      [8, "Pizza night", "Eating out", -36.5], [9, "Gym", "Health", -39], [10, "Internet", "Bills", -60],
      [11, "Bakery", "Groceries", -12.6], [12, "Bike repair", "Transport", -45], [13, "Record shop", "Fun", -31.99],
      [14, "Supermarket", "Groceries", -91.3], [15, "Logo for a friend's cafe", "Income", 480],
      [16, "Electricity", "Bills", -72.4], [17, "Lunch with Sam", "Eating out", -22], [18, "Pharmacy", "Health", -14.25],
      [19, "Supermarket", "Groceries", -76.8], [20, "Train to the coast", "Transport", -38],
      [21, "Birthday present", "Fun", -45], [22, "Coffee", "Eating out", -4.5], [23, "Farmers market", "Groceries", -41.2],
      [24, "Streaming", "Bills", -11.99], [25, "Dinner out", "Eating out", -58], [26, "Supermarket", "Groceries", -68.45],
      [27, "Books", "Fun", -27.5], [28, "Taxi home", "Transport", -18], [29, "Coffee", "Eating out", -4.5],
      [30, "Supermarket", "Groceries", -55.1],
    ]
    this_month = Date.new(Date.today.year, Date.today.month, 1)
    entries = [{ "date" => (this_month << 1).to_s, "note" => "Opening balance", "category" => "Income", "amount" => 1240.0 }]
    [this_month << 1, this_month].each_with_index do |month, n|
      days.each do |day, note, category, amount|
        date = Date.new(month.year, month.month, [day, Date.new(month.year, month.month, -1).day].min)
        next if date > Date.today

        wobble = amount.abs < 500 ? 1 + ((day * 7 + n * 3) % 11 - 5) / 40.0 : 1 # no two months alike
        entries << { "date" => date.to_s, "note" => note, "category" => category, "amount" => (amount * wobble).round(2) }
      end
    end
    categories = [
      ["Home", 0, 1850], ["Groceries", 1, 480], ["Eating out", 2, 120], ["Transport", 3, 180],
      ["Bills", 4, 200], ["Fun", 5, 150], ["Health", 6, 80],
    ].map { |name, swatch, budget| { "name" => name, "color" => SWATCHES[swatch], "budget" => budget } }
    new("entries" => entries, "categories" => categories, "sample" => true)
  end

  private

  def quote(cell)
    cell = cell.to_s
    cell.match?(/[",\n]/) ? "\"#{cell.gsub('"', '""')}\"" : cell
  end
end

Shoes.app(title: "Ledger", width: 960, height: 640, resizable: false) do
  @book = Book.open
  @this_month = Date.new(Date.today.year, Date.today.month, 1)

  url "/", :overview
  url '/month/(\d+)-(\d+)', :month
  url "/categories", :categories

  # ---- little helpers ------------------------------------------------------------------

  # 1234.5 -> "$1,234.50". sign: true puts a plus or a minus in front; cents: false rounds.
  def money(amount, sign: false, cents: true)
    digits = cents ? format("%.2f", amount.abs) : amount.abs.round.to_s
    text = CURRENCY + digits.gsub(/(\d)(?=(\d{3})+(\.|\z))/, '\1,')
    return text if amount.zero? || !(sign || amount.negative?)

    (amount.negative? ? "−" : "+") + text
  end

  # A chart's label: "$4.2k" when the chart spans thousands, "$4,147" when it does not.
  def chart_money(amount, span)
    span >= 3000 ? "#{CURRENCY}#{(amount / 1000.0).round(1)}k" : money(amount, cents: false)
  end

  def month_path(month) = "/month/#{month.strftime("%Y-%m")}"

  # A colour at a fraction of its strength over white, for soft fills.
  def tint(hex, strength)
    r, g, b = hex.scan(/\h\h/).map(&:hex)
    rgb(*[r, g, b].map { |c| (255 - (255 - c) * strength).round })
  end

  def label(text, **style)
    para text.upcase, size: 10, weight: "semibold", kerning: 1.5, stroke: MUTED, margin: [0, 0, 0, 6], **style
  end

  # A white card with a hairline edge.
  def card(**style, &contents)
    stack(**style) do
      background white, curve: 14
      border LINE, curve: 14
      contents.call
    end
  end

  # Shows a short message at the foot of the window for a moment.
  def toast(message)
    @toast_text.replace message
    @toast.show
    @toast_timer&.stop
    @toast_timer = timer(2.6) { @toast.hide }
  end

  # ---- the frame every page sits in: framed(:overview) { ... } -------------------------

  def framed(current, &contents)
    background PAPER
    sidebar(current)
    stack left: 220, top: 0, width: 740, height: 640, scroll: true do
      stack margin: [40, 34, 40, 40], &contents
    end
    @toast = stack left: 430, top: 572, width: 320, height: 40, hidden: true do
      background INK, curve: 20
      @toast_text = para "", align: "center", size: 13, stroke: white, margin: [12, 11, 12, 0]
    end
  end

  def sidebar(current)
    stack left: 0, top: 0, width: 220, height: 640 do
      background SIDEBAR
      background LINE, left: 219, width: 1
      flow margin: [24, 30, 0, 26] do
        logo
        para "Ledger", family: SERIF, size: 24, stroke: INK, margin: [10, 0, 0, 0]
      end
      nav_item "Overview", "/", current == :overview, :grid
      nav_item @this_month.strftime("%B"), month_path(@this_month), current == :month, :calendar
      nav_item "Categories", "/categories", current == :categories, :dots
      stack left: 24, top: 548, width: 172 do
        label "Balance"
        @sidebar_balance = para money(@book.balance), family: SERIF, size: 22, stroke: INK, margin: 0
      end
    end
  end

  # The mark: three rising bars on a green tile.
  def logo
    stack width: 30, height: 30, margin_top: 1 do
      background GREEN, curve: 8
      nostroke
      fill white
      rect 7, 17, 4, 7, curve: 1
      rect 13, 12, 4, 12, curve: 1
      rect 19, 7, 4, 17, curve: 1
    end
  end

  def nav_item(text, path, current, icon)
    look = nil
    item = flow width: 220, height: 42 do
      look = background(current ? white : tint(INK, 0.06), curve: 10, margin: [16, 2, 16, 2], hidden: !current)
      stack(width: 58, height: 42) { nav_icon(icon, current ? GREEN : MUTED) }
      para text, size: 14, weight: current ? "semibold" : "regular", stroke: current ? INK : "#5d574c", margin: [0, 12, 0, 0]
    end
    unless current
      item.hover { look.show }
      item.leave { look.hide }
    end
    item.click { visit path }
  end

  # Tiny icons drawn with shapes, in the 58 x 42 box before a menu item.
  def nav_icon(kind, color)
    nostroke
    fill color
    case kind
    when :grid
      [[28, 13], [36, 13], [28, 21], [36, 21]].each { |x, y| rect x, y, 6, 6, curve: 1.5 }
    when :calendar
      rect 27, 13, 16, 15, curve: 3
      fill white
      rect 29, 18, 12, 8, curve: 1
      fill color
      rect 31, 20, 3, 2
      rect 36, 20, 3, 2
    when :dots
      oval 27, 13, 7
      oval 36, 13, 7
      oval 27, 22, 7
      fill tint(color, 0.45)
      oval 36, 22, 7
    end
  end

  # ---- the overview --------------------------------------------------------------------

  def overview
    @shown_balance = @book.balance
    framed :overview do
      label Date.today.strftime("%A %-d %B")
      flow do
        @balance = para money(@shown_balance), family: SERIF, size: 46, stroke: INK, margin: [0, 0, 16, 0]
        @change = stack margin_top: 20 do
          @change_look = background tint(GREEN, 0.14), curve: 13
          @change_text = para "", size: 12, weight: "semibold", stroke: GREEN, margin: [12, 6, 12, 6]
        end
      end
      if @book.sample?
        para "These are sample entries, to show you around. ", link("Start fresh", stroke: GREEN) { start_fresh },
          size: 12, stroke: MUTED, margin: [0, 2, 0, 0]
      end
      entry_form
      flow margin_top: 24 do
        stack width: 392 do
          flow do
            para "Recent", size: 16, weight: "semibold", stroke: INK, margin: [0, 0, 0, 8]
            para link("All of #{@this_month.strftime("%B")}", stroke: GREEN) { visit month_path(@this_month) },
              align: "right", size: 12, margin: [0, 5, 8, 0]
          end
          @recent = stack {}
        end
        @summary = stack(width: 268, margin_left: 16) {}
      end
      refresh_overview
      keypress { |key| add_entry if [:alt_enter, :control_enter].include?(key) }
    end
  end

  def refresh_overview
    count_balance_to(@book.balance)
    @sidebar_balance.replace money(@book.balance)
    change = @book.money_in(@this_month) - @book.money_out(@this_month)
    words = "#{money(change, sign: true)} this month"
    @change_text.replace words
    @change.width = words.length * 6 + 28
    @change_look.fill = tint(change.negative? ? CORAL : GREEN, 0.14)
    @change_text.stroke = change.negative? ? CORAL : GREEN
    @recent.clear do
      recent = @book.in_order.last(6).reverse
      para "Nothing yet. Add your first entry above.", size: 13, stroke: MUTED, margin_top: 12 if recent.empty?
      recent.each { |entry| entry_row(entry) { refresh_overview } }
    end
    @summary.clear { month_card }
  end

  # The big number runs to its new value instead of jumping there.
  def count_balance_to(target)
    from = @shown_balance
    @counter&.stop
    @counter = animate(60) do |frame|
      t = [frame / 24.0, 1].min
      @shown_balance = from + (target - from) * (1 - (1 - t)**3)
      @balance.replace money(@shown_balance)
      @counter.stop if t >= 1
    end
  end

  # The form: money out or in, how much, what for, which category.
  def entry_form
    @kind ||= :expense
    card margin_top: 18, width: 660 do
      stack margin: [20, 18, 20, 20] do
        flow do
          @kinds = {}
          flow width: 196, height: 34 do
            background tint(INK, 0.06), curve: 17
            { expense: "Money out", income: "Money in" }.each do |kind, text|
              segment = stack width: 98, height: 34 do
                chip = background white, curve: 14, margin: 3, hidden: true
                words = para text, align: "center", size: 12, weight: "semibold", margin_top: 9
                @kinds[kind] = [chip, words]
              end
              segment.click { choose_kind(kind) }
            end
          end
          @form_hint = para "", align: "right", size: 12, stroke: MUTED, margin: [0, 9, 0, 0]
        end
        flow margin_top: 14 do
          stack width: 130 do
            label "Amount"
            @amount = edit_line width: 118, tooltip: "How much, like 12.50"
          end
          stack width: 244 do
            label "What for"
            @note = edit_line width: 232
            @amount.finish = @note.finish = proc { add_entry }
          end
          @category_box = stack width: 150 do
            label "Category"
            @category = list_box items: @book.categories.map { |c| c["name"] }, width: 138
          end
          stack width: 96, margin_top: 17 do
            button "Add", width: 96, height: 30, color: INK, stroke: white, tooltip: "Adds the entry (Return)" do
              add_entry
            end
          end
        end
      end
    end
    @category.choose(@last_category || @book.categories.first["name"])
    choose_kind(@kind)
  end

  def choose_kind(kind)
    @kind = kind
    @kinds.each do |each_kind, (chip, words)|
      chip.hidden = each_kind != kind
      words.stroke = each_kind == kind ? INK : MUTED
    end
    @category_box.hidden = kind == :income
    @form_hint.stroke = MUTED
    @form_hint.replace(kind == :income ? "Pay, gifts, anything coming in" : "")
  end

  def add_entry
    amount = @amount.text.delete("#{CURRENCY}, ").to_f
    if amount <= 0
      @form_hint.replace "Enter an amount, like 12.50"
      @form_hint.stroke = CORAL
      @amount.focus
      return
    end
    category = @kind == :income ? "Income" : @category.text
    note = @note.text.strip.empty? ? category : @note.text.strip
    @last_category = @category.text
    @book.add(@kind == :income ? amount : -amount, note, category)
    @amount.text = ""
    @note.text = ""
    choose_kind(@kind)
    refresh_overview
    toast "Added #{note}, #{money(amount)}"
    @amount.focus
  end

  def start_fresh
    @book.start_fresh
    visit "/"
    toast "A clean page. Over to you."
  end

  # One entry: a round badge, what it was, when, and how much.
  # Pointing at it shows a cross that takes it out again.
  def entry_row(entry, &after_removing)
    category = @book.category(entry["category"])
    look = cross = nil
    row = flow height: 50, margin_bottom: 2 do
      look = background white, curve: 10, hidden: true
      stack width: 50, height: 50 do
        nostroke
        fill tint(category["color"], 0.18)
        oval 7, 8, 34
        para category["name"][0], align: "center", size: 14, weight: "bold", stroke: category["color"], margin: [0, 16, 0, 0]
      end
      stack width: 214 do
        para entry["note"], size: 13, weight: "semibold", stroke: INK, wrap: "trim", margin: [0, 8, 0, 0]
        day = Date.parse(entry["date"])
        para "#{category["name"]} · #{day.strftime("%a %-d %b")}", size: 11, stroke: MUTED, margin: [0, 2, 0, 0]
      end
      para money(entry["amount"], sign: true), align: "right", size: 14, weight: "semibold",
        stroke: entry["amount"].positive? ? GREEN : INK, margin: [0, 16, 4, 0], width: 100
      cross = stack width: 28, height: 50, hidden: true, tooltip: "Take this out" do
        para "×", size: 17, stroke: CORAL, align: "center", margin: [0, 12, 0, 0]
      end
    end
    cross.click do
      @book.remove(entry)
      toast "Took out #{entry["note"]}"
      after_removing.call
    end
    row.hover { look.show; cross.show }
    row.leave { look.hide; cross.hide }
    row
  end

  # How this month is going against the budget, as a ring.
  def month_card
    spent = @book.money_out(@this_month)
    budget = @book.budget
    share = budget.positive? ? spent / budget : 0
    card margin_top: 2 do
      stack margin: [20, 18, 20, 18] do
        label @this_month.strftime("%B")
        flow margin_top: 4 do
          stack width: 96, height: 96 do
            nofill
            strokewidth 9
            cap :curve
            stroke tint(INK, 0.08)
            oval 6, 6, 84
            stroke share > 1 ? CORAL : GREEN
            arc 6, 6, 84, 84, -Math::PI / 2, -Math::PI / 2 + 2 * Math::PI * [share, 0.999].min if share > 0.004
            para "#{(share * 100).round}%", align: "center", size: 18, weight: "semibold", stroke: INK, margin: [0, 30, 0, 0]
            para "of budget", align: "center", size: 10, stroke: MUTED, margin: 0
          end
          stack width: 116, margin: [16, 8, 0, 0] do
            label "In"
            para money(@book.money_in(@this_month), cents: false), size: 16, weight: "semibold", stroke: GREEN, margin: [0, 0, 0, 10]
            label "Out"
            para money(spent, cents: false), size: 16, weight: "semibold", stroke: INK, margin: 0
          end
        end
        left = budget - spent
        para(left >= 0 ? "#{money(left, cents: false)} left to spend this month" : "#{money(-left, cents: false)} over budget",
          size: 12, stroke: left >= 0 ? MUTED : CORAL, margin: [0, 14, 0, 0])
      end
    end
  end

  # ---- a month -------------------------------------------------------------------------

  def month(year, number)
    @month = Date.new(year.to_i, number.to_i, 1)
    framed(@month == @this_month ? :month : :other_month) do
      flow do
        step_button("‹", "The month before") { visit month_path(@month << 1) }
        para @month.strftime("%B %Y"), family: SERIF, size: 30, stroke: INK, margin: [12, 0, 0, 0]
        step_button("›", "The month after", margin_left: 12) { visit month_path(@month >> 1) }
        button "Export CSV", width: 116, height: 32, color: GREEN, stroke: white, right: 0, top: 5 do
          export_csv
        end
      end
      flow margin_top: 18 do
        saved = @book.money_in(@month) - @book.money_out(@month)
        tile "Money in", money(@book.money_in(@month)), GREEN, 12
        tile "Money out", money(@book.money_out(@month)), INK, 12
        tile saved.negative? ? "Overspent" : "Kept", money(saved), saved.negative? ? CORAL : INK, 0
      end
      balance_chart
      category_bars
      stack margin_top: 26 do
        para "Every entry", size: 16, weight: "semibold", stroke: INK, margin: [0, 0, 0, 8]
        entries = @book.in_month(@month).reverse
        para "Nothing in #{@month.strftime("%B")}.", size: 13, stroke: MUTED if entries.empty?
        entries.each { |entry| entry_row(entry) { visit month_path(@month) } }
      end
      keypress do |key|
        visit month_path(@month << 1) if key == :left
        visit month_path(@month >> 1) if key == :right
      end
    end
  end

  def step_button(text, tooltip, margin_left: 0, &go)
    look = nil
    button = stack width: 34 + margin_left, height: 40, margin: [margin_left, 6, 0, 0], tooltip: tooltip do
      look = background white, curve: 17
      border LINE, curve: 17
      para text, align: "center", size: 20, stroke: INK, margin: [0, 2, 0, 0]
    end
    button.hover { look.fill = tint(GREEN, 0.14) }
    button.leave { look.fill = white }
    button.click(&go)
  end

  # A figure on a card; the gap after it is part of its width.
  def tile(title, value, color, gap)
    card width: 212 + gap, margin_right: gap do
      stack margin: [18, 16, 18, 16] do
        label title
        para value, family: SERIF, size: 24, stroke: color, margin: 0
      end
    end
  end

  # The balance at the end of every day of the month: a line over a soft fill, drawn in
  # from the left when the page opens. Point at a day to read its balance.
  def balance_chart
    days = Date.new(@month.year, @month.month, -1).day
    last = @month == @this_month ? Date.today.day : days
    last = 0 if @month > @this_month
    running = @book.balance(before: @month)
    by_day = @book.in_month(@month).group_by { |e| Date.parse(e["date"]).day }
    @balances = (1..last).map { |day| running += (by_day[day] || []).sum { |e| e["amount"] } }
    low, high = (@balances.empty? ? [running, running] : @balances.minmax)
    pad = [(high - low) * 0.2, 60].max
    low -= pad
    high += pad
    w, h = 572, 150
    @chart_x = ->(day) { 44 + (day - 1) * w / (days - 1.0) }
    @chart_y = ->(value) { 12 + h - (value - low) / (high - low) * h }

    @chart = card margin_top: 16, width: 660, height: 244 do
      label "Running balance", left: 20, top: 18
      @point_text = para "", size: 12, weight: "semibold", stroke: INK, align: "right", left: 360, top: 15, width: 280
      stack left: 0, top: 44, width: 660, height: 196 do
        if @balances.empty?
          para "Nothing to draw yet", size: 13, stroke: MUTED, align: "center", left: 44, top: 60, width: w, margin: 0
          next
        end
        points = @balances.each_with_index.map { |value, i| [@chart_x.(i + 1), @chart_y.(value)] }
        nostroke
        fill gradient(rgb(46, 125, 91, 0.26), rgb(46, 125, 91, 0.02))
        shape do
          move_to points.first[0], 12 + h
          points.each { |x, y| line_to x, y }
          line_to points.last[0], 12 + h
        end
        nofill
        stroke GREEN
        strokewidth 2.5
        cap :curve
        shape do
          move_to(*points.first)
          points.drop(1).each { |x, y| line_to x, y }
        end
        fill white
        oval(*points.last, 9, center: true)
        # a white curtain that slides off to the right, uncovering the line
        nostroke
        fill white
        curtain = rect 30, 0, 610, h + 20
        # three faint lines, labelled on the left, and the days along the bottom
        [0.2, 0.5, 0.8].each do |at|
          value = low + (high - low) * at
          stroke tint(INK, 0.07)
          strokewidth 1
          line 44, @chart_y.(value), 44 + w, @chart_y.(value)
          para chart_money(value, high - low), size: 9, stroke: MUTED, left: 0, top: @chart_y.(value) - 7, width: 38, align: "right", margin: 0
        end
        [1, 8, 15, 22, days].each do |day|
          para day.to_s, size: 9, stroke: MUTED, left: @chart_x.(day) - 15, top: h + 20, width: 30, align: "center", margin: 0
        end
        # the pointer's guide and dot, hidden until a day is pointed at
        stroke tint(INK, 0.25)
        strokewidth 1
        @guide = line 0, 12, 0, 12 + h, hidden: true
        nostroke
        fill GREEN
        @dot = oval 0, 0, 10, center: true, hidden: true
        # one invisible column per day hears the pointer
        (1..last).each do |day|
          step = w / (days - 1.0)
          column = stack(left: @chart_x.(day) - step / 2, top: 0, width: step, height: h + 20) {}
          column.hover { point_at(day) }
        end
        reveal = animate(60) do |frame|
          t = [frame / 40.0, 1].min
          ease = 1 - (1 - t)**3
          curtain.style(left: 30 + 610 * ease, width: 610 * (1 - ease))
          reveal.stop if t >= 1
        end
      end
    end
    @chart.leave { point_at(nil) }
    point_at(nil)
  end

  def point_at(day)
    return @point_text.replace("") if @balances.empty?

    day = nil if day && day > @balances.size
    @guide.hidden = @dot.hidden = day.nil?
    shown = day || @balances.size
    @point_text.replace "#{money(@balances[shown - 1])} on #{(@month + shown - 1).strftime("%-d %B")}"
    return unless day

    x, y = @chart_x.(day), @chart_y.(@balances[day - 1])
    @guide.move(x, 12)
    @dot.move(x, y)
  end

  # Spending in each category against its budget; the bars grow in when the page opens.
  # In the current month a thin mark shows where spending would be at an even pace.
  def category_bars
    rows = @book.categories.map { |c| [c, @book.spent(@month, c["name"])] }
    rows = rows.reject { |c, spent| spent.zero? && c["budget"].zero? }.sort_by { |_, spent| -spent }
    days = Date.new(@month.year, @month.month, -1).day
    pace = @month == @this_month ? Date.today.day / days.to_f : nil
    bars = []
    card margin_top: 16, width: 660 do
      stack margin: [20, 18, 20, 14] do
        flow do
          label "Spending against budget"
          para "the mark is where an even pace would be today", size: 11, stroke: MUTED, align: "right", margin: 0 if pace
        end
        para "Nothing spent yet.", size: 13, stroke: MUTED if rows.empty?
        rows.each do |category, spent|
          budget = category["budget"]
          share = budget.positive? ? spent / budget : 1.0
          over = budget.positive? && spent > budget
          flow height: 34 do
            nostroke
            fill category["color"]
            oval 0, 12, 10
            para category["name"], size: 13, stroke: INK, margin: [18, 8, 0, 0], width: 124
            stack width: 336, height: 34 do
              fill tint(over ? CORAL : category["color"], 0.16)
              rect 0, 13, 336, 10, curve: 5
              fill over ? CORAL : category["color"]
              bars << [rect(0, 13, 0, 10, curve: 5), 336 * [share, 1].min]
              if pace && budget.positive?
                fill tint(INK, 0.55)
                rect 336 * pace - 1, 9, 2, 18, curve: 1
              end
            end
            words = budget.positive? ? "#{money(spent, cents: false)} of #{money(budget, cents: false)}" : money(spent, cents: false)
            words = "#{money(spent - budget, cents: false)} over" if over
            para words, size: 12, align: "right", stroke: over ? CORAL : MUTED, weight: over ? "semibold" : "regular",
              margin: [0, 9, 0, 0], width: 160
          end
        end
      end
    end
    grow = animate(60) do |frame|
      t = [frame / 36.0, 1].min
      ease = 1 - (1 - t)**3
      bars.each { |bar, width| bar.style(width: (width * ease).round) }
      grow.stop if t >= 1
    end
  end

  def export_csv
    path = ask_save_file
    return if path.nil? || path.to_s.empty?

    path = "#{path}.csv" unless path.to_s.end_with?(".csv")
    File.write(path, @book.csv(@month))
    toast "Saved #{@book.in_month(@month).size} entries to #{File.basename(path)}"
  end

  # ---- categories ----------------------------------------------------------------------

  def categories
    framed :categories do
      para "Categories", family: SERIF, size: 30, stroke: INK, margin: 0
      para "Every category has a budget for the month. Spending starts again on the 1st.",
        size: 13, stroke: MUTED, margin: [0, 6, 0, 20]
      flow do
        @book.categories.each_with_index { |category, i| category_card(category, i) }
        new_category_card(@book.categories.size)
      end
    end
  end

  # Three cards to a row; the gap after the first two is part of their width.
  def cell(i, &contents)
    gap = i % 3 == 2 ? 0 : 18
    stack width: 208 + gap, height: 158, margin: [0, 0, gap, 18], &contents
  end

  def category_card(category, i)
    spent = @book.spent(@this_month, category["name"])
    cell i do
      card width: 208, height: 140 do
        stack margin: [18, 16, 18, 0] do
          flow do
            nostroke
            fill category["color"]
            oval 0, 3, 14
            para category["name"], size: 15, weight: "semibold", stroke: INK, margin: [22, 0, 0, 0]
          end
          spent_text = para "", size: 12, stroke: MUTED, margin: [0, 10, 0, 8]
          track = stack width: 172, height: 8 do
            background tint(category["color"], 0.16), curve: 4
          end
          bar = nil
          track.append { bar = background(category["color"], curve: 4, width: 0) }
          show_spent = lambda do
            budget = category["budget"]
            share = budget.positive? ? spent / budget : (spent.positive? ? 1 : 0)
            bar.style(width: (172 * [share, 1].min).round, fill: share > 1 ? CORAL : category["color"])
            words = budget.positive? ? "#{money(spent, cents: false)} of #{money(budget, cents: false)} spent" : "#{money(spent, cents: false)} spent"
            spent_text.replace words
            spent_text.stroke = share > 1 ? CORAL : MUTED
          end
          flow margin_top: 16 do
            para "Budget #{CURRENCY}", size: 12, stroke: INK, margin: [0, 7, 6, 0]
            box = edit_line width: 90, text: format("%g", category["budget"])
            box.change do
              category["budget"] = [box.text.delete(",").to_f, 0].max
              @book.save
              show_spent.call
            end
          end
          show_spent.call
        end
      end
    end
  end

  def new_category_card(i)
    @new_color ||= SWATCHES[7]
    cell i do
      stack width: 208, height: 140 do
        border tint(INK, 0.2), curve: 14, strokewidth: 1.5
        stack margin: [18, 16, 18, 0] do
          para "New category", size: 15, weight: "semibold", stroke: INK, margin: 0
          @new_name = edit_line width: 172, margin_top: 10
          @new_name.finish = proc { add_category }
          flow margin_top: 10 do
            @swatches = SWATCHES.map do |color|
              ring = nil
              swatch = stack width: 21.5, height: 22 do
                nostroke
                fill color
                oval 2, 3, 16
                nofill
                stroke color
                strokewidth 1.5
                ring = oval 0, 1, 20, hidden: color != @new_color
              end
              swatch.click { pick_color(color) }
              [color, ring]
            end
          end
          button "Add", width: 72, height: 38, margin_top: 10 do
            add_category
          end
        end
      end
    end
  end

  def pick_color(color)
    @new_color = color
    @swatches.each { |each_color, ring| ring.hidden = each_color != color }
  end

  def add_category
    name = @new_name.text.strip
    return @new_name.focus if name.empty?
    return toast("There is already a #{name}") if @book.categories.any? { |c| c["name"].casecmp?(name) }

    @book.add_category(name, @new_color)
    visit "/categories"
    toast "Added #{name}"
  end
end
