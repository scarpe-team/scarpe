require_relative 'feepogram'

bloops = Bloops.new
bloops.tempo = 160  # Slower tempo for dreamy feel

song = Feepogram.new(bloops) do
  # Soft percussion
  sound :soft_kick, Bloops::SINE do |s|
    s.volume = 0.3
    s.punch = 0.15
    s.sustain = 0.1
    s.decay = 0.3
  end

  sound :chimes, Bloops::SINE do |s|
    s.volume = 0.35
    s.punch = 0.1
    s.sustain = 0.8
    s.decay = 0.6
    s.slide = 0.1
  end

  # Main melody instrument
  sound :crystal, Bloops::SQUARE do |s|
    s.volume = 0.45
    s.punch = 0.1
    s.sustain = 0.4
    s.decay = 0.3
    s.phase = 0.3
  end

  # Sparkly accent notes
  sound :sparkle, Bloops::SQUARE do |s|
    s.volume = 0.25
    s.punch = 0.1
    s.sustain = 0.1
    s.decay = 0.4
    s.phase = 0.2
    s.lpf = 0.6
  end

  # Warm bass pad
  sound :dream_pad, Bloops::SINE do |s|
    s.volume = 0.25
    s.sustain = 0.6
    s.decay = 0.4
    s.slide = 0.1
    s.lpf = 0.4
  end

  def gentle_rhythm
    soft_kick " c 4 4 4 " * 8
    chimes " 4 c6 4 c6 " * 4
  end

  def dream_bass
    dream_pad %{
      2:c3 2:g3
      2:a3 2:e3
      2:f3 2:c3
      2:g3 2:e3
    }
  end

  def main_melody
    crystal %{
      c5 4 g5 4 e5 4 c6 g5
      a5 4 e5 4 c5 4 g5 4
      f5 4 c6 4 a5 4 f5 e5
      g5 4 e5 4 c5 4 4 4
    }
  end

  def sparkle_accent
    sparkle %{
      4 4 c7 4 4 4 e7 4
      4 4 g6 4 4 4 c7 4
      4 4 a6 4 4 4 f7 4
      4 4 e7 4 4 4 g6 4
    }
  end

  def title_theme
    phrase do
      dream_bass
      gentle_rhythm
    end

    phrase do
      dream_bass
      gentle_rhythm
      main_melody
    end

    phrase do
      dream_bass
      gentle_rhythm
      main_melody
      sparkle_accent
    end
  end

  def peaceful_bridge
    phrase do
      dream_pad %{
        4:c4 4:e4
        4:f4 4:g4
      }
      sparkle " c6 e6 g6 c7 " * 4
    end
  end

  def outro_fade
    phrase do
      dream_bass
      crystal %{
        c6 g5 e5 c5
        4 4 4 4
      }
      sparkle " c7 g6 e6 c6 "
    end
  end

  # The composition
  2.times { title_theme }
  peaceful_bridge
  title_theme
  outro_fade
end

song.play
