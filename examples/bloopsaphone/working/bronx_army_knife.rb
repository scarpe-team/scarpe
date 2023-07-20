# Bronx Army Knife

# By analogy with "Bronx Cheer."

class SystemConfiguration
  def self.checked_run(cmd, msg: "returned an error")
    system(cmd)
    unless $?.success?
      puts "Command failed: #{cmd.inspect} in #{Dir.pwd}; #{$?.inspect}..."
      raise msg
    end
  end

  def self.basic_install_check
    unless `uname -a`.include?("Darwin")
      raise "Feel free to adjust this app, but right now it's very Mac-specific!"
    end

    unless system("which ffmpeg")
      raise "Please install FFMPEG! On Mac this might be 'brew install ffmpeg'"
    end

    unless system("which basic-pitch")
      puts <<~USAGE_TEXT
        You'll need to install basic-pitch. It can be a bit involved.
        Basic-Pitch requires Python 3.7+, or 3.10+ for Mac M1s.

        See:
          https://github.com/spotify/basic-pitch
          https://basicpitch.spotify.com/
    USAGE_TEXT
      raise "Please install basic-pitch! On Mac this might be 'pip3 install basic_pitch'"
    end
  end

  def self.mic_device_string
    audio_devices_text = `ffmpeg -f avfoundation -list_devices true -i "" 2>&1`

    if audio_devices_text.include?("] MacBook Pro Microphone")
      dev_num = audio_devices_text.split("] MacBook Pro Microphone")[0][-1]
      unless ("0".."5").include?(dev_num)
        raise "Couldn't recognise your audio device as a small number in text:\n#{audio_devices_text}\n\n!!!"
      end
      return ":" + dev_num
    end

    raise "Time to improve the checking to recognise the Mac microphone!"
  end

  def self.record_audio_to_file(path, seconds: 1)
    @mic_dev ||= mic_device_string
    checked_run("ffmpeg -f avfoundation -i \"#{@mic_dev}\" -t #{seconds}s #{path}")
  end
end

SystemConfiguration.basic_install_check

Shoes.app do
  @status_text = para "Right now: nothing recorded"

  @b = button "record" do
    @status_text.replace("...")
    SystemConfiguration.record_audio_to_file("~/Desktop/test_audio.wav")
    @status_text.replace("Recorded: ~/Desktop/test_audio.wav")
  end
end
