require_relative 'feepogram'

bloops = Bloops.new
bloops.tempo = 360  # Fast and furious!

song = Feepogram.new(bloops) do
  # The mighty kick of rebellion
  sound :boss_kick, Bloops::SQUARE do |s|
    s.volume = 0.8
    s.punch = 0.8
    s.sustain = 0.2
    s.decay = 0.1
    s.phase = 0.2
  end

  # The snare of defiance
  sound :battle_snare, Bloops::NOISE do |s|
    s.volume = 0.7
    s.punch = 0.6
    s.sustain = 0.1
    s.decay = 0.2
    s.freq = 0.5
  end

  # The relentless type checker
  sound :type_checker, Bloops::SAWTOOTH do |s|
    s.volume = 0.6
    s.punch = 0.4
    s.sustain = 0.2
    s.decay = 0.1
    s.slide = -0.3  # Menacing downward slide
  end

  # The sword of dynamic typing
  sound :ruby_sword, Bloops::SQUARE do |s|
    s.volume = 0.6
    s.punch = 0.5
    s.sustain = 0.15
    s.decay = 0.2
    s.phase = 0.3
    s.freq = 0.8
  end

  # Duck typing power-up
  sound :duck_power, Bloops::SAWTOOTH do |s|
    s.volume = 0.5
    s.punch = 0.3
    s.sustain = 0.4
    s.decay = 0.2
    s.slide = 0.2
  end

  # The battle cry
  sound :battle_cry, Bloops::SQUARE do |s|
    s.volume = 0.7
    s.punch = 0.5
    s.sustain = 0.3
    s.decay = 0.2
    s.phase = 0.4
  end

  def intense_beat
    boss_kick " c 4 c 4 c c 4 c " * 4
    battle_snare " 4 c 4 c 4 c c c " * 4
  end

  def type_checker_attack
    type_checker %{
      c4 c4 g3 g3 c4 c4 g3 g3
      a3 a3 e3 e3 a3 a3 e3 e3
      f3 f3 c3 c3 f3 f3 c3 c3
      g3 g3 d3 d3 g3 g3 d3 d3
    }
  end

  def ruby_counter_attack
    ruby_sword %{
      c5 g5 c6 g5 c5 g5 c6 g5
      a5 e6 a6 e6 a5 e6 a6 e6
      f5 c6 f6 c6 f5 c6 f6 c6
      g5 d6 g6 d6 g5 d6 g6 d6
    }
  end

  def duck_typing_combo
    duck_power %{
      8:c6 8:d6 8:e6 8:f6 8:g6 8:a6 8:b6 c7
      8:c7 8:b6 8:a6 8:g6 8:f6 8:e6 8:d6 c6
      8:a5 8:b5 8:c6 8:d6 8:e6 8:f6 8:g6 a6
      8:a6 8:g6 8:f6 8:e6 8:d6 8:c6 8:b5 a5
    }
  end

  def battle_cry_melody
    battle_cry %{
      c5 4 g5 4 c6 4 g5 c5
      a5 4 e5 4 a5 4 e5 a4
      f5 4 c6 4 f6 4 c6 f5
      g5 4 d6 4 g6 4 d6 g5
    }
  end

  def intro_phase
    2.times do
      phrase do
        intense_beat
        type_checker_attack
      end
    end
  end

  def battle_phase
    2.times do
      phrase do
        intense_beat
        type_checker_attack
        ruby_counter_attack
      end
    end
  end

  def power_up_phase
    phrase do
      intense_beat
      duck_typing_combo
      battle_cry_melody
    end
  end

  def final_stand
    phrase do
      intense_beat
      type_checker_attack
      ruby_counter_attack
      duck_typing_combo
      battle_cry_melody
    end
  end

  def victory_outro
    phrase do
      boss_kick " c 4 4 4 "
      ruby_sword " c6 e6 g6 c7 "
      battle_cry " 1:c6 "
    end
  end

  # The epic battle unfolds!
  intro_phase
  battle_phase
  power_up_phase
  battle_phase
  final_stand
  victory_outro
end

song.play
