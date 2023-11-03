#
#        -)= Cheeky Drat (=-
#       composed by freQvibez
#         [within TextMate]
# exclusively for _why's BloopSaphone
#
#      from Farbrausch with ♥
#

b = Bloops.new
b.tempo = 172

bass = b.sound Bloops::SQUARE
bass.volume = 0.4
bass.sustain = 0.1
bass.attack = 0.1
bass.decay = 0.3

base = b.sound Bloops::SQUARE
base.volume = 0.35
base.punch = 0.3
base.sustain = 0.1
base.decay = 0.3
base.phase = 0.2
base.lpf = 0.115
base.resonance = 0.55
base.slide = -0.4

snare = b.sound Bloops::NOISE
snare.attack = 0.075
snare.sustain = 0.01
snare.decay = 0.33
snare.hpf = 0.55
snare.resonance = 0.44
snare.dslide = -0.452

chord = b.sound Bloops::SQUARE
chord.volume = 0.275
chord.attack = 0.05
chord.sustain = 0.6
chord.decay = 0.9
chord.phase = 0.35
chord.psweep = -0.25
chord.vibe = 0.0455
chord.vspeed = 0.255

lead = b.sound Bloops::SINE
lead.volume = 0.45
lead.attack = 0.3
lead.sustain = 0.15
lead.decay = 0.8
lead.vibe = 0.035
lead.vspeed = 0.345
lead.vdelay = -0.5
lead.hpf = 0.2
lead.hsweep = -0.05
lead.resonance = 0.55
lead.phase = 0.4
lead.psweep = -0.05

b.tune bass, %q^
  8 4a1 8a 8a 4a 4a 4c2 9c 7c 4c 8e
  8 4g2 8g 8 4g 4g 4d2 8 8c3 4b2 8e
  8 4d2 8c 8c 4c 4 4a2 9a 7a 4a 8a
  8 4g2 8g 8 4g 4d 4d2 9e3 7c2 8 4b1

  8 4a2 8a 8d 4 4d 4a1 8a 8a 4d 8d
  8 4g2 8g 8 4g 4g 4c2 8c 8c2 4g 8c
  8 4d2 8d 8d 4d 4d 4a1 8a 8a 4a 8a
  8 4g2 8g 8 4g 4g 4c2 8c 8c 4c 8b1

  8 4a1 8a 8a 4a 4a 4c2 9c 7c 4c 8e
  8 4g2 8g 8 4g 4g 4d2 8 8c3 4b2 8e
  8 4d2 8c 8c 4c 4 4a2 9a 7a 4a 8a
  8 4g2 8g 8 4g 4d 4d2 9e3 7c2 8 4b1

  8 4a2 8a 8d 4 4d 4a1 8a 8a 4d 8d
  8 4g2 8g 8 4g 4g 4c2 8c 8c2 4g 8c
  8 4d2 8d 8d 4d 4d 4a1 8a 8a 4a 8a
  8 4g2 8g 8 4g 4g 4c2 8c 8c 4c 8b1
  ^

b.tune base, %q^
  4a2 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 8a 4 4a 4 4a 8 8a
  4a 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 4 8a 4a 4 8a 4 8a

  4a2 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 8a 4 4a 4 4a 8 8a
  4a 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 4 8a 4a 4 8a 4 8a

  4a2 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 8a 4 4a 4 4a 8 8a
  4a 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 4 8a 4a 4 8a 4 8a

  4a2 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 8a 4 4a 4 4a 8 8a
  4a 4 8a 8a 4 4a 4 8a 8a 4
  4a 4 8a 4 8a 4a 4 8a 4 8a
  ^

b.tune snare, %q^
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 8a2 8a2

  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 8a2 8a2

  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 8a2 8a2

  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 4a2
  4 4a2 4 4a2 4 4a2 4 8a2 8a2
  ^

b.tune chord, %q^
      1
   1 1
  1 1 1
   1 1

  1a2 2a3 2 1g2 2d3 2
  1a2 2a3 2 1d2 4g3 4g2 2e3

  1a2 2a3 2 1g2 2d3 2
  1a2 2a3 2 1d2 2g3 2

  1a2 2a3 2 1g2 2d3 2
  1a2 2a3 2 1d2 2g3 2

  1a2 2a3 2 1g2 2d3 2
  1a2 2a3 2 1d2 2g3 2
  ^

b.tune chord, %q^
      1
   1 1
  1 1 1
   1 1

  2 2c4 2 1 2b4 2
  1 2c4 4 2g3 2b4 1

  2 2c4 2 1 2b4 2
  1 2c4 2 1 2b4 1

  2 2c4 2 1 2b4 2
  1 2c4 2 1 2b4 1

  2 2c4 2 1 2b4 2
  1 2c4 2 1 2b4 1
  ^

b.tune chord, %q^
      1
   1 1
  1 1 1
   1 1

  2 1 2e4 2 1 2d4
  2 1 2e4 2 1 2d4

  2 1 2e4 2 1 2d4
  2 1 2e4 2 1 2d4

  2 1 2e4 2 1 2d4
  2 1 2e4 2 1 2d4

  2 1 2e4 2 1 2d4
  2 1 2e4 2 1 2d4
  ^

b.tune lead, %q^
      1      4
   1 1    1 1
  1 1 1  1 1 1
   1 1    1 1

  2g3 1a4 2
  2c5 1e4 2 1
  1a4 2 4 2e4 1d4 2

  2a3 1b4 2
  2d5 2g4 1c5
  1a4 1e5
  1b4 2 4 8 8d4

  2g3 1a4 2
  2c5 1e4 3d4 5g4
  1a4 1e4
  1d4 1
  ^

while true do
  b.play
  sleep 0.5 while not b.stopped?
end
