# frozen_string_literal: true

class Shoes
  # A sound with no picture of its own: audio("pop.wav").play (docs/SCARPE_FEATURES.md). The
  # display plays it, the native one through its renderer; a display that leaves it unanswered
  # (Niente, the webview) has Lacci play it (Shoes::AudioPlayer). Shoes::Video plays an audio
  # file the same way.
  #
  # SCARPE_AUDIO_FILE names a file that stands in for the speakers: every play, pause and stop
  # is written there as a line ("play /path/to/pop.wav") and nothing is heard, so a test can
  # check what was played. A sound played that way ends at once.
  class Audio
    # Each sound that is playing or paused, by id, so a display's news that one has ended
    # reaches it. Only those: an app may make a new sound for every key press.
    @sounds = {}
    @next_id = 0
    @lock = Mutex.new

    class << self
      # @api private
      def next_id
        @lock.synchronize { "audio-#{@next_id += 1}" }
      end

      # @api private
      def active(sound)
        @lock.synchronize { @sounds[sound.id] = sound }
      end

      # @api private
      def inactive(sound)
        @lock.synchronize { @sounds.delete(sound.id) }
      end

      # The sound with this id, if it is still about.
      # @api private
      def [](id)
        @sounds[id]
      end

      # A display's word that the sound with this id has played to its end.
      # @api private
      def ended(id)
        @sounds[id]&.send(:finished)
      end

      # @api private
      def level(volume)
        Float(volume).clamp(0.0, 1.0)
      end

      # The displays report an ended sound as an "audio_ended" event; listen once.
      # @api private
      def listen
        return if @listening

        @listening = true
        Shoes::DisplayService.subscribe_to_event("audio_ended", nil) { |id| ended(id) }
      end
    end

    # @return [String] the file (an absolute path) or URL this plays
    attr_reader :path

    # @return [String] what the display knows this sound by
    attr_reader :id

    # @return [Float] how loud it plays, from 0.0 (silent) to 1.0 (as recorded)
    attr_reader :volume

    # @param path [String] a sound file: WAV, MP3, Ogg Vorbis or FLAC
    # @param volume [Numeric] from 0.0 (silent) to 1.0 (as recorded)
    def initialize(path, volume: 1.0)
      @path = path.to_s.match?(%r{\Ahttps?://}i) ? path.to_s : File.expand_path(path.to_s)
      @id = Audio.next_id
      @volume = Audio.level(volume)
      @playing = false
      @paused = false
    end

    # Changes how loud it plays, at once if it is playing.
    # @param level [Numeric] from 0.0 (silent) to 1.0 (as recorded)
    def volume=(level)
      @volume = Audio.level(level)
      tell("volume") if @playing
    end

    # Plays the sound from the start, or from where pause left it. Playing a sound that is
    # already playing starts it again from the beginning, as Shoes' video#play does.
    #
    # @return [Shoes::Audio] self
    def play
      Audio.listen
      Audio.active(self)
      @playing = true
      tell(@paused ? "resume" : "play")
      @paused = false
      self
    end

    # Pauses the sound; play carries on from here.
    #
    # @return [Shoes::Audio] self
    def pause
      return self unless @playing

      @playing = false
      @paused = true
      tell("pause")
      self
    end

    # Stops the sound; play starts it from the beginning.
    #
    # @return [Shoes::Audio] self
    def stop
      @playing = false
      @paused = false
      tell("stop")
      Audio.inactive(self)
      self
    end

    # @return [Boolean] true while it plays: not before play, after stop or pause, or once it
    #   has played to its end
    def playing?
      @playing
    end

    def inspect
      "#<Shoes::Audio #{File.basename(@path)}#{" playing" if @playing}>"
    end

    private

    # Asks the display; one that does not answer leaves it to Lacci's player.
    def tell(op)
      Shoes::DisplayService.clear_builtin_response
      Shoes::DisplayService.dispatch_event("builtin", nil, "audio", [op, @id, @path, @volume])
      return if Shoes::DisplayService.builtin_response?

      Shoes::AudioPlayer.public_send(op, self)
    end

    def finished
      @playing = false
      @paused = false
      Audio.inactive(self)
    end
  end
end
