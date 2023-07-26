require 'shoes'
require 'bloops'
require_relative './how_music_works/lib/all'

# Sorry folks, there is a prerequisite of installing blackhole
# and creating a new midi setup. it's not hard, but I don't know
# how to package and automate it. but for sound fun I think it's
# good to have!
# Also, this is a MacOnly build. Sorry Windows and Linux folks.
# https://github.com/ExistentialAudio/BlackHole/wiki/Multi-Output-Device
# possible audio quality issue https://github.com/ExistentialAudio/BlackHole/wiki/Multi-Output-Device


Shoes.app height: 450, width: 450, title: "Soundalizer 🔊" do

  # Turn it on and off
  $system_on = false
  flow do
    stack do
      @on_status = banner "OFF"
    end
  end
  flow do
    stack do
      button "Toggle on or off" do
        if $system_on
          @on_status.replace "OFF"
          # Or whatever you wanna go back to
          `SwitchAudioSource -s "MacBook Pro Speakers"`
          $system_on = false
        else
          @on_status.replace "POWERING UP..."
          `brew install switchaudio-osx`
          `SwitchAudioSource -s \"Fancy Recording Device\"`
          $system_on = true
          @on_status.replace("ON")
        end
      end
    end
  end

  flow do
    para "Soundfile to mess with:: "
    @sound = ins "  Nothing to hear yet"
  end

  flow do
    caption "Record a new sound"
  end

  flow do
    @recording = false
    @name = edit_line "Name your sound"
  end

  flow do
    @recording_note = para "Not recording"
  end

  flow do
    @recorder = button "Record a new sound" do
      if @recording
        `q`
        @recording = false
        @recording_note.replace "Not recording"
        @sound.replace @name.text.downcase.tr(" ", "_")
      else
        @recording_note.replace "Recording ..."
        `ffmpeg -f avfoundation -i ":BlackHole 16ch" #{@name.text.downcase.tr(" ", "_")}.wav`
        @recording = true
      end
    end
  end

end

__END__

# wanna record this

b = Bloops.new
b.tempo = 70

s1 = b.sound Bloops::SINE
s1.attack = 0.5
s1.sustain = 0.3
s1.decay = 0.4

pattern1 = "4:e5 4:d5 4:c5 4:d5 2:e5 4:e5 4:d5 4:c5 4:d5 2:e5 4:d5 4:c5 4:b4 4:c5 2:d5"

b.tune s1, pattern1

Thread.new do
  b.play
  sleep 1 while !b.stopped?
end
