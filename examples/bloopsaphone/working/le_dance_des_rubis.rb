require_relative 'feepogram'

bloops = Bloops.new
bloops.tempo = 280

song = Feepogram.new(bloops) do
  # Define our instruments
  sound :kick, Bloops::SINE do |s|
    s.volume = 0.9
    s.punch = 0.4
    s.sustain = 0.1
    s.decay = 0.2
  end

  sound :snare, Bloops::NOISE do |s|
    s.volume = 0.8
    s.punch = 0.2
    s.sustain = 0.05
    s.decay = 0.25
  end

  sound :hat, Bloops::NOISE do |s|
    s.volume = 0.4
    s.punch = 0.1
    s.sustain = 0.02
    s.decay = 0.1
  end

  sound :synth_bass, Bloops::SAWTOOTH do |s|
    s.volume = 0.7
    s.sustain = 0.3
    s.decay = 0.1
    s.slide = 0.2
  end

  sound :lead, Bloops::SQUARE do |s|
    s.volume = 0.6
    s.punch = 0.3
    s.sustain = 0.4
    s.decay = 0.2
  end

  sound :pad, Bloops::SINE do |s|
    s.volume = 0.5
    s.sustain = 1.0
    s.decay = 0.5
  end

  # Helper methods for our patterns
  def basic_beat
    kick " c 4 4 c 4 4 c 4 " * 4
    snare " 4 4 c 4 4 4 c 4 " * 4
    hat " c5 " * 32
  end

  def bass_line_a
    synth_bass %{
      c2 4 e2 4 f2 4 g2 4
      c2 4 e2 4 f2 4 g2 4
      a1 4 c2 4 d2 4 e2 4
      f2 4 e2 4 d2 4 c2 4
    }
  end

  def lead_melody_a
    lead %{
      4 c4 e4 g4 4 c5 g4 e4
      4 c4 f4 a4 4 c5 a4 f4
      4 e4 g4 c5 4 e5 c5 g4
      4 d4 f4 a4 4 d5 a4 f4
    }
  end

  def ambient_pad
    pad %{
      1:c4 1:c4
      1:f4 1:f4
      1:g4 1:g4
      1:e4 1:e4
    }
  end

  # Structure our song
  def intro
    2.times do
      phrase do
        basic_beat
        bass_line_a
      end
    end
  end

  def verse
    2.times do
      phrase do
        basic_beat
        bass_line_a
        lead_melody_a
      end
    end
  end

  def bridge
    phrase do
      kick " c 4 4 4 " * 8
      snare " 4 4 c 4 " * 8
      hat " c5 " * 16
      ambient_pad
    end
  end

  def outro
    phrase do
      basic_beat
      bass_line_a
      lead_melody_a
      ambient_pad
    end

    phrase do
      kick "c"
      synth_bass "c2"
      pad "1:c4"
    end
  end

  # Play the composition
  intro
  verse
  bridge
  verse
  outro
end

song.play
