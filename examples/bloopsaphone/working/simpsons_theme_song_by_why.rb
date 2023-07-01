
  b = Bloops.new
  b.tempo = 180
  
  
  sound = b.sound Bloops::SQUARE
  sound.volume = 0.4
  sound.sustain = 0.3
  sound.attack = 0.1
  sound.decay = 0.3
  
  b.tune sound, "32 + C E F# 8:A G E C - 8:A 8:F# 8:F# 8:F# 2:G"
  
  b.play
