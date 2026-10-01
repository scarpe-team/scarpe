# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

# say(text, voice:) and voices (Shoes::Speech). The test runs set SCARPE_AUDIO_FILE, the stand-in
# for the speakers, so what would be said lands there as a line and nothing is heard.
class TestSpeech < Minitest::Test
  def setup
    @saved = ENV["SCARPE_AUDIO_FILE"]
    @dir = Dir.mktmpdir("lacci-speech")
    ENV["SCARPE_AUDIO_FILE"] = File.join(@dir, "audio.txt")
  end

  def teardown
    ENV["SCARPE_AUDIO_FILE"] = @saved
    FileUtils.rm_rf(@dir)
  end

  def test_the_stand_in_hears_what_is_said_and_in_which_voice
    first = say("Hello there")
    second = say("Grüezi", voice: "Anna")
    assert_equal ["say Hello there", "say[Anna] Grüezi"], File.readlines(ENV["SCARPE_AUDIO_FILE"], chomp: true)
    refute first.speaking?, "nothing is being said"
    assert_same second, second.stop, "stop is safe when nothing speaks"
    assert_equal "Anna", second.voice
  end

  def test_voices_is_a_list_of_names
    voices = Shoes::Speech.voices
    assert_kind_of Array, voices
    assert voices.all? { |name| name.is_a?(String) && !name.empty? }, voices.inspect
  end

  def test_each_platform_speaks_with_its_own_tool
    command, env = Shoes::Speech.command_for("-hi", "Anna")
    skip "no speech tool on this machine" unless command
    case RbConfig::CONFIG["host_os"]
    when /darwin/
      assert_equal ["say", "-v", "Anna", " -hi"], command, "a leading dash is not an option"
    when /mingw|mswin/
      assert_equal "powershell.exe", command.first
      assert_equal({ "SHOES_SPEECH_TEXT" => "-hi", "SHOES_SPEECH_VOICE" => "Anna" }, env, "the words go through the environment")
    else
      assert_equal "--", command[-2], "a leading dash is not an option"
      assert_equal "-hi", command.last
    end
  end
end
