# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

# Shoes::Audio (audio("pop.wav").play) and a video of an audio file, on a display that plays
# nothing itself, so Lacci's player has them (Shoes::AudioPlayer). The test runs set
# SCARPE_AUDIO_FILE, so each command lands there as a line and nothing is heard.
class TestAudioPlayer < Minitest::Test
  def setup
    @saved = ENV["SCARPE_AUDIO_FILE"]
    @dir = Dir.mktmpdir("lacci-audio")
    ENV["SCARPE_AUDIO_FILE"] = File.join(@dir, "audio.txt")
  end

  def teardown
    ENV["SCARPE_AUDIO_FILE"] = @saved
    FileUtils.rm_rf(@dir)
  end

  def heard
    File.readlines(ENV["SCARPE_AUDIO_FILE"], chomp: true)
  end

  def test_the_stand_in_file_hears_every_command
    sound = Shoes::Audio.new(File.join(@dir, "pop.wav"))
    Shoes::AudioPlayer.play(sound)
    Shoes::AudioPlayer.pause(sound)
    Shoes::AudioPlayer.resume(sound)
    Shoes::AudioPlayer.stop(sound)
    path = File.join(@dir, "pop.wav")
    assert_equal ["play #{path}", "pause #{path}", "resume #{path}", "stop #{path}"], heard
  end

  def test_a_path_is_made_absolute_and_a_url_kept
    Dir.chdir(@dir) { assert_equal File.expand_path("pop.wav"), Shoes::Audio.new("pop.wav").path }
    assert_equal "https://example.com/pop.mp3", Shoes::Audio.new("https://example.com/pop.mp3").path
  end
end

class TestAudio < NienteTest
  def test_audio_plays_and_its_end_is_heard
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app { para "quiet" }
    SHOES_APP
      sound = audio("pop.wav")
      refute sound.playing?, "not before play"
      assert_same sound, sound.play
      refute sound.playing?, "a sound with no speakers to play to ends at once"
      sound.stop
      assert_match(/\\Aplay .*pop\\.wav\\z/, File.readlines(ENV["SCARPE_AUDIO_FILE"], chomp: true).first)
    SHOES_SPEC
    lines = File.readlines(audio_file, chomp: true)
    assert_equal 2, lines.size, lines.inspect
    assert_match(%r{\Aplay /.*pop\.wav\z|\Aplay [A-Za-z]:/.*pop\.wav\z}, lines[0], "an absolute path")
    assert_match(/\Astop .*pop\.wav\z/, lines[1])
  end

  # A helper object, not the app, makes the noises: audio is a built-in, callable anywhere.
  def test_audio_is_callable_from_any_object
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Chimes
        def ring = audio("bell.wav").play
      end
      Shoes.app { Chimes.new.ring }
    SHOES_APP
      assert_match(/\\Aplay .*bell\\.wav\\z/, File.read(ENV["SCARPE_AUDIO_FILE"]).strip)
    SHOES_SPEC
    assert_match(/\Aplay .*bell\.wav\z/, File.read(audio_file).strip)
  end

  def test_a_video_of_an_audio_file_plays_pauses_and_stops
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @song = video("song.mp3", autoplay: true)
        @quiet = video("quiet.ogg")
      end
    SHOES_APP
      app = Shoes.APPS.first
      song = app.instance_variable_get(:@song)
      quiet = app.instance_variable_get(:@quiet)
      refute quiet.playing?, "no autoplay, no sound"
      quiet.play
      quiet.pause
      quiet.stop
      song.remove
    SHOES_SPEC
    lines = File.readlines(audio_file, chomp: true).map { |line| line.sub(/ .*\//, " ") }
    assert_equal ["play song.mp3", "play quiet.ogg", "stop quiet.ogg", "stop song.mp3"], lines,
      "autoplay plays at once; a sound that has ended does not pause; remove stops"
  end
end
