require 'shoes'
require 'bloops'
require 'open3'
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
    @recorder = button "Record a new sound" do
      `rm -rf *.wav`
      @recorder.text = "Recording ..."
      Open3.popen3("ffmpeg -i output.wav -af silenceremove=1:0:-50dB output.wav") do |stdin, stdout, stderr, wait_thr|
        sleep 5
        stdin.puts "q"
        stdin.close
      end
      @recorder.text = "Record a new sound"
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
