      require 'bloops'

    # the bloops o' phone
      b = Bloops.new
      b.tempo = 320

    # melodious
      s1 = b.sound Bloops::SQUARE
      s1.punch = 0.5
      s1.sustain = 0.4
      s1.decay = 0.2
      s1.arp = 0.4
      s1.aspeed = 0.6
      s1.repeat = 0.6
      s1.phase = 0.2
      s1.psweep = 0.2

    # beats
      s2 = b.sound Bloops::NOISE
      s2.punch = 0.5
      s2.sustain = 0.2
      s2.decay = 0.4
      s2.slide = -0.4
      s2.phase = 0.2
      s2.psweep = 0.2

    # the tracks
      b.tune s1, "f#5 c6 e4 b6 g5 d6 4  f#5 e5 c5 b6 c6 d6 4 "
      b.tune s2, "4   c6 4  b5 4  4  e4 4   c6 4  b5 4  4  e4"

    # and away we go
      b.play
      sleep 1 while !b.stopped?

      b.play
      sleep 1 while !b.stopped?
