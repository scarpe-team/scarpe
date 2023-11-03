class Fret
  def initialize(string, fret_idx, note, octave)
    @string = string
    @fret_idx = fret_idx
    @note = note
    @octave = octave
  end

  attr_reader :note
  attr_reader :fret_idx
  attr_reader :string

  def to_s
    "#{@note}#{@octave}"
  end
end

class GuitarString
  NOTES = %w{a a# b c c# d d# e f f# g g#}
  FRET_COUNT = 23

  include Enumerable

  attr_reader :frets
  attr_reader :fret_radios

  def initialize(idx, open_note, starting_octave)
    @root_note_index = NOTES.index(open_note)
    octave = starting_octave


    fret_index = 0
    @frets = NOTES.cycle
      .take(FRET_COUNT + @root_note_index)
      .to_a[@root_note_index..-1]
      .map { |note|
        if note == NOTES.first
          octave +=1
        end
        Fret.new(idx, fret_index, note, octave)
      }
    @fret_radios = {}
  end

  def render(app)
    frets = @frets
    string = self

    app.flow(height: "15%") do
      frets.each do |f|
        flow width: "3%" do
          border black, strokewidth: 1
          background linen
          string.fret_radios[f] = radio(f.string)
          caption f.note
        end
      end
    end
  end
end

class Tunings
  STANDARD  = %w{ e a d g b e }
  DSTANDARD = %w{ d g c f a d }
  DADGAD    = %w{ d a d g a d }

  def self.get(constname)
    tconst = constname.upcase.gsub(" ", "")
    const_get(tconst).reverse.map.with_index do |n, idx|
      GuitarString.new(idx, n, 2)
    end
  end
end

def bloops
  @bloops ||= Bloops.new
end

def play_chord(notes)
  bloops.clear
  sound = bloops.sound Bloops::SQUARE
  sound.sustain = 0.05
  sound.decay = 0.35

  notes.each do |n|
    bloops.tune sound, n
  end

  bloops.play
end

Shoes.app(width: 1280, height: 400) do
  @tuning = "standard"
  @strings = Tunings::get(@tuning)
  @fretboard = []

  render_strings = ->(app) {
    @strings.each do |string|
      string.render(app)
    end
  }

  flow do
    @current_tuning = title @tuning
    @fretboard = stack width: "100%", margin: 20, &render_strings

    stack do
      button "Play" do
        fretted_notes = @strings.flat_map { |s|
          s.fret_radios.select { |k, v| v.checked? }.keys
        }.map(&:to_s)

        play_chord(fretted_notes)

        @strings.map do |s|
          s.fret_radios.map { |_, r| r.checked = false }
        end
      end

      flow do
        caption "Select a tuning:"
        @tuning_select = list_box(
                                  items: ["d standard", "dadgad", "standard"]
                                 ).change { |tuning| @tuning = tuning }

        button "Change Tuning" do
          self.instance_variable_set("@strings", Tunings::get(@tuning))
          @fretboard.clear
          @fretboard.append(&render_strings)
          @current_tuning.replace @tuning
        end
      end
    end
  end
end
