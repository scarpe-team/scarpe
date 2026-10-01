# frozen_string_literal: true

class Shoes
  # A video player (manual "Video"). Scarpe plays no moving pictures, but an audio file in a
  # video (WAV, MP3, Ogg Vorbis, FLAC) plays as the manual promises: play, pause, stop and
  # playing? work, and autoplay: true starts it as it appears. The player itself is drawn as a
  # dark frame; hide it to play the sound with nothing to see.
  class Video < Shoes::Drawable
    shoes_styles :url, :autoplay
    shoes_events # No specific events yet

    init_args :url
    def initialize(*args, **kwargs)
      super

      create_display_drawable
      play if @autoplay
    end

    # Plays the file, from the start or from where pause left it.
    # @return [Shoes::Video] self
    def play
      sound.play
      self
    end

    # @return [Shoes::Video] self
    def pause
      sound.pause
      self
    end

    # @return [Shoes::Video] self
    def stop
      sound.stop
      self
    end

    # @return [Boolean] whether it is playing
    def playing?
      sound.playing?
    end

    # Removing the video stops it (manual: "This will stop the video as well").
    def destroy
      @sound&.stop
      super
    end

    private

    def sound
      @sound ||= Shoes::Audio.new(@url)
    end
  end
end
