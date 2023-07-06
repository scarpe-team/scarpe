# downloaded from http://github.com/aanand/1901
require_relative 'feepogram'

bloops = Bloops.new
bloops.tempo = 320

song = Feepogram.new(bloops) do
  sound :hihat, Bloops::NOISE do |s|
    s.punch = 0.5
    s.sustain = 0.05
    s.decay = 0.1
  end

  sound :kick, Bloops::SINE do |s|
    s.volume = 0.95
    s.slide = -0.4
  end

  sound :short_kick, Bloops::SINE do |s|
    s.volume = 0.5
    s.slide = -0.4
  end

  sound :snare, Bloops::NOISE do |s|
    s.volume = 0.9
    s.sustain = 0.0
    s.decay = 0.3
  end

  sound :cymbal, Bloops::NOISE do |s|
    s.punch = 0.25
    s.volume = 0.25
  end

  sound :bass, Bloops::SAWTOOTH do |s|
    s.decay = 0.0
  end

  2.times do |i|
    sound "high_guitar_#{i+1}", Bloops::SINE do |s|
      s.sustain = 0.05
      s.decay = 0.35
    end
  end

  5.times do |i|
    sound "guitar_#{i+1}", Bloops::SQUARE do |s|
      s.punch = 0.1
      s.decay = 0.0
    end
  end

  sound :bwoo, Bloops::SQUARE do |s|
    s.volume = 0.4
    s.sustain = 1.0
    s.decay = 0.0
  end

  sound :voice, Bloops::SAWTOOTH do |s|
    s.punch = 0.4
    s.sustain = 0.4
    s.decay = 0.0
  end

  sound :heyyy, Bloops::SAWTOOTH do |s|
    s.volume = 0.7
    s.punch = 0.0
    s.sustain = 0.3
    s.decay = 0.0
  end

  # initialize octaves
  def setup
    @tracks[:snare] << " + "
  end

  def hihat_line
    hihat " e6 " * 8 * 4
  end

  def drum_verse
    kick  " c 4 4 4 c 4 4 4 " * 4
    snare " 4 4 c 4 4 4 c 4 " * 4
  end

  def high_guitar_line_1
    high_guitar_1 " e5 " * 8 * 4

    high_guitar_2 %{
      g5 g5 g5 g5 g5 g5 g5 g5
      g5 a5 a5 a5 a5 a5 a5 a5
      g5 g5 g5 g5 g5 g5 g5 g5
      g5 g5 g5 g5 g5 g5 g5 g5
    }
  end    

  def high_guitar_line_2
    high_guitar_1 " c5 " * 8 * 4

    high_guitar_2 %{
      e5 e5 e5 e5 e5 e5 e5 e5
      e5 g5 g5 g5 g5 g5 g5 g5
      e5 e5 e5 e5 e5 e5 e5 e5
      e5 e5 e5 e5 e5 e5 e5 e5
    }
  end

  def bass_verse
    bass %{
      4 4 4 f2 f2 f2 f2 f2
      4 4 4 a1 a1 a1 a1 a1
      4 4 4 c2 c2 c2 c2 c2
      4 4 4 a1 a1 a1 a1 a1
    }
  end

  def bass_verse_with_leadout
    bass %{
      4 4 4 f2 f2 f2 f2 f2
      4 4 4 a1 a1 a1 a1 a1
      4 4 4 c2 c2 c2 c2 c2
      4 4 4 c2 c2 a1 a1 a1
    }
  end

  def bass_verse_with_chorus_leadout
    bass %{
      4 4 4 f2 f2 f2 f2 f2
      4 4 4 a1 a1 a1 a1 a1
      4 4 4 c2 c2 c2 c2 c2
      4 4 4 c2 c2 c2 c2 c2
    }
  end

  def guitar_verse
    guitar_1 %{
      4 4 4 a4 a4 a4 a4 a4
      4 4 4 g4 g4 g4 g4 g4
      4 4 4 g4 g4 g4 g4 g4
      4 4 4 g4 g4 g4 g4 g4
    }

    guitar_2 %{
      4 4 4 f4 f4 f4 f4 f4
      4 4 4 e4 e4 e4 e4 e4
      4 4 4 e4 e4 e4 e4 e4
      4 4 4 e4 e4 e4 e4 e4
    }

    guitar_3 %{
      4 4 4 d4 d4 d4 d4 d4
      4 4 4 c4 c4 c4 c4 c4
      4 4 4 c4 c4 c4 c4 c4
      4 4 4 c4 c4 c4 c4 c4
    }
  end

  def guitar_chorus_leadout
    guitar_1 %{
      4 4 4 4  4  4  4  4
      4 4 4 4  4  4  4  4
      4 4 4 4  4  4  4  4
      4 4 4 g4 g4 g4 g4 g4
    }

    guitar_2 %{
      4 4 4 4  4  4  4  4
      4 4 4 4  4  4  4  4
      4 4 4 4  4  4  4  4
      4 4 4 e4 e4 e4 e4 e4
    }

    guitar_3 %{
      4 4 4 4  4  4  4  4
      4 4 4 4  4  4  4  4
      4 4 4 4  4  4  4  4
      4 4 4 c4 c4 c4 c4 c4
    }
  end

  def guitar_chorus
    guitar_1 %{
      a4 8:a4 8:a4 a4 g4 g4 g4 a4 8:a4 8:a4
      a4 g4        g4 g4 a4 a4 g4 g4
      a4 8:a4 8:a4 a4 g4 g4 g4 a4 8:a4 8:a4
      a4 g4        g4 g4 a4 a4 g4 g4
    }

    guitar_2 %{
      f4 8:f4 8:f4 f4 e4 e4 e4 f4 8:f4 8:f4
      f4 e4        e4 e4 f4 f4 e4 e4
      f4 8:f4 8:f4 f4 e4 e4 e4 f4 8:f4 8:f4
      f4 e4        e4 e4 f4 f4 e4 e4
    }

    guitar_3 %{
      d4 8:d4 8:d4 d4 c4 c4 c4 d4 8:d4 8:d4
      d4 c4        c4 c4 d4 d4 c4 c4
      d4 8:d4 8:d4 d4 c4 c4 c4 d4 8:d4 8:d4
      d4 c4        c4 c4 d4 d4 c4 c4
    }
  end

  def voice_post_chorus
    voice %{
      4 4              2:g[sustain:1.0] c[sustain:0.3] 4 2:g[sustain:1.0]
      c 4              2:g[sustain:1.0] c[sustain:0.3] 4 2:g[sustain:1.0]
      2:e[sustain:1.0] 2                1
      1                                 1
    }
  end    

  def intro
    phrase do
      hihat_line
      bass_verse
      high_guitar_line_1
    end

    phrase do
      hihat_line
      bass_verse
      high_guitar_line_2
    end
  end

  def verse_phrase_1
    drum_verse
    bass_verse
    guitar_verse
  end

  def verse_phrase_2
    drum_verse
    bass_verse_with_leadout
    guitar_verse
  end

  def verse_phrase_3
    hihat_line
    kick  " c 4 4 4 c 4 4 c " * 4
    snare " 4 4 c 4 4 c 4 4 " * 4
    bass_verse
    high_guitar_line_1
  end

  def verse_phrase_4
    hihat_line
    kick  " c 4 4 4 c 4 4 c " * 4
    snare " 4 4 c 4 4 c 4 4 " * 4
    bass_verse_with_chorus_leadout
    guitar_chorus_leadout
    high_guitar_line_2
  end

  def verse_instrumental
    2.times do
      phrase do
        verse_phrase_1
      end
    end
  end

  def verse_1
    phrase do
      verse_phrase_1

      voice %{
        4  4  4  4  g[sustain:0.3]  4  g  4
        c  c  g  4  g  4  c  c 
        c  g  4  4  4  4  4  4
        4  4  4  4  4  4  4  4
      }     
    end

    phrase do
      verse_phrase_2

      voice %{
        e  4  e  4  e  4  e  d 
        e  e  e  4  e  e  g  a 
        e  4  4  4  4  4  4  4
        4  4  4  4  4  4  4  4
      }     
    end
  end

  def verse_2
    phrase do
      verse_phrase_3

      voice %{
        e  4  e  4  e   e   e  e 
        c  c  d  4  d   d   d  c 
        e  4  e  d  c - g + c  d 
        d  d  d  d  d - a   a  a +
      }
    end

    phrase do
      verse_phrase_4

      voice %{
        4  4  e  4  e  e  e  e 
        c  c  d  4  d  d  g  e 
        e  4  4  4  4  4  4  4
        4  4  4  4  4  4  4  4
      }
    end
  end

  def chorus_phrase_1
    kick       " c 4       4 c 4       4 c 4 " * 4
    short_kick " 4 8:c 8:c c 4 8:c 8:c c 4 c " * 4
    snare %{
      4 4 4 4 4 4 c 4
      4 4 4 4 4 c 4 c
      4 4 4 4 4 4 c 4
      4 4 4 4 4 c 4 c
    }

    bass " c2 " * 32

    guitar_chorus
  end

  def chorus_phrase_2
    kick " c 4 4 4 " * 8
    snare %{
      4 4 c 4 4 4 c 4
      4 4 c 4 4 4 c 4
      4 4 c 4 4 4 c 4
      4 4 c 4 4 c 4 c
    }
    cymbal " 2:c6 " * 16

    bass " g2 " * 32

    guitar_chorus
  end

  def heyyy_chorus
    heyyy %{
      1 1
      1 1
      1 1
      3:g #{ " 24:f 24:f# 4:g " * 5 }
    }
  end

  def chorus_1
    phrase do
      chorus_phrase_1

      voice %{
        4 4 4 4 4 - g + c c
        c c c c c   4 - a g
        4 4 4 4 4   4   2:g[sustain:2.0] +
        1 1
      }

      heyyy_chorus
    end

    phrase do
      chorus_phrase_2

      voice %{
        4 4 4 4 4 4 2:g
        g[sustain:0.4] e e g g e e 4
        4 4 4 4 4 4 e d
        e e e e e f e 4
      }
    end
  end

  def chorus_2
    phrase do
      chorus_phrase_1

      voice %{
        4 4 4 4 4 - g + c c
        c c c c c   4 - a + 2:e[sustain:2.0]
          4 4 4 4   4 - 2:g +
        1 1
      }

      heyyy_chorus
    end

    phrase do
      chorus_phrase_2

      bwoo %{
        16:c 16:c# 8:d 4:d 2:d 1:d
        1:d 1:d +
        16:c 16:c# 8:d 4:d 2:d 1:d
        1:d 1:d[sustain:0.5] -
      }

      voice %{
        4 4 4 4 4 4 2:g[sustain:0.4]
        g[sustain:0.3] e e g g e e 4
        4 4 4 4 4 c c c
        c c c[sustain:0.1] c c[sustain:0.3] 4 2:e
      }
    end
  end

  def post_chorus
    phrase do
      drum_verse
      bass_verse
      guitar_verse
      voice_post_chorus
    end

    phrase do
      drum_verse
      bass_verse_with_chorus_leadout
      guitar_verse
      voice_post_chorus
    end
  end

  def outro_1
    phrase do
      hihat_line
      kick " c 4 4 c 4 4 c 4 " * 4
      bass " c2 " * 32

      guitar_4 %{
        3:c 3:c 3:c 3:c 3:c 3:c
        c c c c c c g g
        3:c 3:c 3:c 3:c 3:c 3:c
        c c c c c g g g
      }
    end
  end

  def outro_2
    phrase do
      drum_verse
      bass " c2 " * 32
      guitar_chorus

      guitar_4 " 3:g " * 24

      guitar_5 %{ +
        c d e 2:d d c d
        e 2:d d c d e d
        c d e 2:d d c d
        e 2:d d c d e d
      }
    end
  end

  def the_end
    phrase do
      bass "c2"
    end
  end

  setup

  intro
  verse_instrumental
  verse_1
  verse_2
  chorus_1
  chorus_2
  post_chorus
  outro_1
  outro_2
  the_end
end

song.play
