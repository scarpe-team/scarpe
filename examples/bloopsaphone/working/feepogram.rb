# downloaded from http://github.com/aanand/feepogram
class Feepogram
  attr_reader :bloops, :length

  def initialize(bloops, &block)
    @bloops = bloops
    @length = 0

    @sounds        = {}
    @tracks        = {}
    @track_lengths = {}

    instance_eval(&block)
  end

  def metaclass
    class << self; self; end
  end

  def metaclass_eval(&block)
    metaclass.class_eval(&block)
  end

  def sound(name, base, &block)
    name = name.to_sym

    sound = bloops.sound(base)

    @sounds[name]        = sound
    @tracks[name]        = ""
    @track_lengths[name] = 0

    block.call(sound)

    instance_variable_set("@#{name}", sound)

    metaclass_eval do
      define_method(name) do |notes|
        dub(name, notes)
      end
    end
  end

  def phrase(&block)
    instance_eval(&block)
    @length += 32
  end

  def dub sound_name, notes
    catchup = @length - @track_lengths[sound_name]

    @tracks[sound_name] << ("4 " * catchup)
    @tracks[sound_name] << notes
    @track_lengths[sound_name] = length+32
  end

  def play
    @tracks.each do |sound_name, notes|
      bloops.tune @sounds[sound_name], notes

      #puts "#{sound_name}: #{notes.gsub(/\s+/, ' ')}"
    end

    bloops.play
    sleep 1 while !bloops.stopped?
  end
end
