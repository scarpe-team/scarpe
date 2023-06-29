require("bloops")
require 'singleton'

class PongSounds
  include Singleton
  
  class << self
    def bloops
      @bloops ||= Bloops.new
    end
    
    def sounds
      @sounds ||= begin
        @hit = bloops.sound Bloops::SQUARE
        @hit.volume = 0.4
        @hit.sustain = 0.02
        @hit.attack = 0.02
        @hit.decay = 0.1
        @hit.punch = 0.1

        @score = bloops.sound Bloops::SAWTOOTH
        @score.volume = 0.2
        @score.sustain = 0.25
        @score.attack = 0.02
        @score.decay = 0.1
        @score.punch = 0.5
        @score.arp = 0.1
        @score.phase = 0.1

        @bounce = bloops.sound Bloops::SINE
        @bounce.volume = 0.5
        @bounce.sustain = 0.1
        @bounce.attack = 0.02
        @bounce.decay = 0.1
        @bounce.punch = 0.5
        @bounce.arp = 0.1
        @bounce.phase = 0.1
        
        {:hit => [@hit, "32 + A#"], :score => [@score, "16 - D#"], :bounce => [@bounce, "16 - F#"]}
      end
      
      @sounds
    end
    
    def play(name)
      Thread.new do
        bloops.tune *sounds[name]
        bloops.play
        sleep 0.1 until bloops.stopped?
        bloops.clear
      end
    end
  end
end

Shoes.app do
   button("play 'em all") do
      [:hit, :score, :bounce].each { |n|
         PongSounds.play(n)
         sleep 1
      }
   end
end

