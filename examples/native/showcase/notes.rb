# Notes: a sidebar of notes and an editor that counts words as you type.
#
# The first line of a note is its title. Pick a tag from the list box;
# New note starts a fresh one at the top.

TAGS = {
  "Ideas" => "#6c7ce0",
  "Work" => "#e0674f",
  "Personal" => "#4f9d7e",
  "Reading" => "#d99a2b",
  "Recipes" => "#c0609a",
}
INK = "#24262b"
MUTED = "#8a8d93"
SIDEBAR = "#f4f2ee"
LINE = "#e4e0d8"
HOVER = "#ebe8e2"

NOTES = [
  { tag: "Ideas", body: "Welcome to Notes\n\nEverything here is plain Shoes: a list box for the tag, " \
    "an edit box for the words, and a para that counts them as you type. Pick a note on the left " \
    "to open it, or start a new one." },
  { tag: "Recipes", body: "Sourdough, Saturday\n\nFeed the starter on Friday night. 500 g flour, " \
    "350 g water, 100 g starter, 10 g salt. Fold four times, an hour apart, then shape and leave it " \
    "in the fridge overnight. Bake at 250 degrees: twenty minutes with the lid on, twenty-five off." },
  { tag: "Reading", body: "Reading list\n\nThe Shoes manual, start to finish. Why's (Poignant) Guide " \
    "to Ruby. Rebuilding Rails. Something with no code in it at all." },
  { tag: "Work", body: "Team day, Thursday\n\nBook the long room. Everyone brings one thing " \
    "that went well and one thing to change. Cake after, not before." },
  { tag: "Personal", body: "Weekend\n\nFarmers market at nine. Call home. Fix the back brake on the " \
    "bike, then try the river path if it stays dry." },
]

Shoes.app(title: "Notes", width: 780, height: 540, resizable: false) do
  def title_of(note)
    title = note[:body].lines.first.to_s.strip
    title.empty? ? "New note" : title
  end

  def preview_of(note)
    rest = note[:body].lines.drop(1).join(" ").split.join(" ")
    rest.empty? ? "No text yet" : rest
  end

  def words_in(text)
    text.split.size
  end

  # One row in the sidebar: title, a line of preview, and the tag.
  def note_row(note)
    row = stack(width: 1.0, height: 74, margin: [10, 0, 10, 4]) do
      note[:look] = background white, curve: 10, hidden: true
      note[:edge] = border LINE, strokewidth: 1, curve: 10, hidden: true
      note[:title] = para "", size: 13, weight: "semibold", stroke: INK, wrap: "trim", margin: [12, 10, 12, 0]
      note[:preview] = para "", size: 12, stroke: MUTED, wrap: "trim", margin: [12, 2, 12, 0]
      flow margin: [12, 5, 0, 0] do
        note[:dot] = oval 0, 4, 7
        note[:tag_label] = para "", size: 11, stroke: MUTED, margin: [11, 0, 0, 0]
      end
    end
    row.click { open_note(note) }
    row.hover { highlight(note, open: false) unless note == @note }
    row.leave { note[:look].hide unless note == @note }
    show_row(note)
  end

  def show_row(note)
    note[:title].replace title_of(note)
    note[:preview].replace preview_of(note)
    note[:dot].style(fill: TAGS[note[:tag]], stroke: TAGS[note[:tag]])
    note[:tag_label].replace note[:tag]
  end

  # The open note's row is white with an edge; a row under the pointer is tinted.
  def highlight(note, open:)
    note[:look].style(fill: open ? white : HOVER, hidden: false)
    note[:edge].hidden = !open
  end

  def open_note(note)
    if @note
      @note[:look].hide
      @note[:edge].hide
    end
    @note = note
    highlight(note, open: true)
    @tag.choose(note[:tag])
    @editor.text = note[:body]
    count_words
  end

  def count_words
    words = words_in(@editor.text)
    minutes = (words / 200.0).ceil
    @count.replace "#{words} #{words == 1 ? "word" : "words"}  ·  #{minutes} min read"
  end

  def new_note
    note = { tag: @note ? @note[:tag] : "Ideas", body: "" }
    @notes.unshift(note)
    @list.prepend { note_row(note) }
    @total.replace "#{@notes.size} notes"
    open_note(note)
    @editor.focus
  end

  @notes = NOTES.map(&:dup)

  background white

  # the sidebar
  stack left: 0, top: 0, width: 250, height: 540 do
    background SIDEBAR
    background LINE, left: 249, width: 1
    flow margin: [22, 22, 16, 10] do
      stack width: 130 do
        para "Notes", size: 22, weight: "bold", stroke: INK, margin: 0
        @total = para "#{@notes.size} notes", size: 12, stroke: MUTED, margin: [0, 2, 0, 0]
      end
      new_button = stack(width: 76, height: 38, margin_top: 6) do
        background INK, curve: 16
        para "New note", align: "center", size: 12, weight: "semibold", stroke: white, margin_top: 8
      end
      new_button.click { new_note }
    end
    @list = stack(width: 1.0) do
      @notes.each { |note| note_row(note) }
    end
  end

  # the editor
  stack left: 250, top: 0, width: 530, height: 540 do
    flow margin: [32, 24, 32, 0], height: 76 do
      para "Tag", size: 12, weight: "semibold", stroke: MUTED, margin: [0, 7, 10, 0]
      @tag = list_box(items: TAGS.keys, width: 140) do |box|
        @note[:tag] = box.text
        show_row(@note)
      end
      @count = para "", align: "right", size: 12, stroke: MUTED, margin: [0, 7, 0, 0]
    end
    @editor = edit_box(width: 530, height: 440, margin: [32, 0, 32, 0], font: "Iowan Old Style, Georgia, serif 15px") do
      @note[:body] = @editor.text
      show_row(@note)
      count_words
    end
  end

  open_note @notes.first
end
