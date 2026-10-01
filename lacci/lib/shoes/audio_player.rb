# frozen_string_literal: true

require "rbconfig"

# Plays a Shoes::Audio for a display that plays nothing itself (Niente, the webview). The
# native display plays sounds in its renderer and never asks.
#
# With SCARPE_AUDIO_FILE set, each request is written there as a line instead ("play
# /path/pop.wav", "pause ...", "resume ...", "stop ..."), nothing is heard, and a played sound
# ends at once. Otherwise each platform's own player is used, one process a sound:
#
# - macOS: afplay, which plays WAV, MP3, AAC and more.
# - Windows: PowerShell's System.Media.SoundPlayer, which plays WAV only.
# - Linux: paplay (PulseAudio and PipeWire), else aplay (ALSA), which play WAV.
#
# Pause stops the player and resume starts it again from the beginning: a player process cannot
# be paused. A sound no player here can play is skipped with a warning.
module Shoes::AudioPlayer
  extend self

  def play(sound)
    stop_player(sound) # playing again starts again
    if (file = stand_in)
      record(file, "play", sound)
      return Shoes::Audio.ended(sound.id)
    end
    return warn_once(sound, "is a URL; this display plays only files") if sound.path.match?(%r{\Ahttps?://}i)

    command = player_for(sound.path, sound.volume) or return warn_once(sound, "has no player on this system")
    pid = Process.spawn(*command, in: File::NULL, out: File::NULL, err: File::NULL)
    players[sound.id] = pid
    Thread.new do
      Process.wait(pid)
    rescue SystemCallError
      nil
    ensure
      if players[sound.id] == pid
        players.delete(sound.id)
        Shoes::Audio.ended(sound.id)
      end
    end
  rescue SystemCallError => e
    warn_once(sound, "could not be played: #{e.message}")
  end

  # A player process keeps the volume it started with; the next play uses the new one.
  def volume(_sound)
    nil
  end

  def resume(sound)
    return record(stand_in, "resume", sound) if stand_in

    play(sound)
  end

  def pause(sound)
    return record(stand_in, "pause", sound) if stand_in

    stop_player(sound)
  end

  def stop(sound)
    return record(stand_in, "stop", sound) if stand_in

    stop_player(sound)
  end

  private

  def players
    @players ||= {}
  end

  def stop_player(sound)
    pid = players.delete(sound.id) or return
    Process.kill(Gem.win_platform? ? "KILL" : "TERM", pid)
  rescue SystemCallError
    nil
  end

  def stand_in
    file = ENV["SCARPE_AUDIO_FILE"].to_s
    file.empty? ? nil : file
  end

  def record(file, op, sound)
    File.open(file, "a") { |f| f.puts("#{op} #{sound.path}") }
    nil
  end

  def player_for(path, volume)
    case RbConfig::CONFIG["host_os"]
    when /darwin/ then ["afplay", "-v", volume.round(2).to_s, path]
    when /mingw|mswin/
      return nil unless File.extname(path).casecmp?(".wav")

      # -EncodedCommand needs no quoting, whatever the path holds.
      script = "(New-Object System.Media.SoundPlayer #{ps_quote(path)}).PlaySync()"
      ["powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand", [script.encode(Encoding::UTF_16LE)].pack("m0")]
    else
      return nil unless File.extname(path).casecmp?(".wav")

      tool = %w[paplay aplay].find { |name| on_path?(name) } or return nil
      tool == "aplay" ? ["aplay", "-q", path] : ["paplay", path]
    end
  end

  def ps_quote(text)
    "'#{text.gsub("'", "''")}'"
  end

  def on_path?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
  end

  def warn_once(sound, why)
    @warned ||= {}
    key = [sound.path, why]
    return if @warned[key]

    @warned[key] = true
    Shoes::Log.logger("Shoes::Audio").warn("#{File.basename(sound.path)} #{why}, so it is not heard")
    nil
  end
end
