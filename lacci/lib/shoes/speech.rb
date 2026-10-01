# frozen_string_literal: true

require "open3"
require "rbconfig"

class Shoes
  # Text spoken aloud: say("Hello") and voices (docs/SCARPE_FEATURES.md). Each platform speaks
  # with what it comes with, one process an utterance, so say returns at once:
  #
  # - macOS: say.
  # - Windows: System.Speech, through PowerShell.
  # - Linux: espeak-ng, espeak or spd-say, whichever is installed; with none, nothing is said.
  #
  # SCARPE_AUDIO_FILE, the stand-in for the speakers (Shoes::Audio), hears it too: each
  # utterance is a line there ("say Hello" or "say[Samantha] Hello") and nothing is said.
  class Speech
    # @return [String] what is said
    attr_reader :text

    # @return [String, nil] the voice it is said in, nil for the system's own
    attr_reader :voice

    # @api private
    def initialize(text, voice)
      @text = text.to_s
      @voice = voice&.to_s
      @pid = nil
    end

    # Starts saying it.
    # @api private
    def start
      if (file = Speech.stand_in)
        File.open(file, "a") { |f| f.puts(@voice ? "say[#{@voice}] #{@text}" : "say #{@text}") }
        return self
      end

      command, env = Speech.command_for(@text, @voice)
      unless command
        Speech.warn_once("No speech on this system (macOS's say, Windows' System.Speech, or espeak-ng, espeak or spd-say on Linux)")
        return self
      end
      @pid = Process.spawn(env, *command, in: File::NULL, out: File::NULL, err: File::NULL)
      Process.detach(@pid)
      self
    rescue SystemCallError => e
      Speech.warn_once("Could not speak: #{e.message}")
      self
    end

    # Stops it mid-sentence.
    # @return [Shoes::Speech] self
    def stop
      Process.kill(Gem.win_platform? ? "KILL" : "TERM", @pid) if speaking?
      self
    rescue SystemCallError
      self
    end

    # @return [Boolean] whether it is still being said
    def speaking?
      return false unless @pid

      if Gem.win_platform?
        `tasklist /FI "PID eq #{@pid}" /FO CSV /NH`.include?(%("#{@pid}"))
      else
        Process.kill(0, @pid)
        true
      end
    rescue SystemCallError
      false
    end

    def inspect
      "#<Shoes::Speech #{@text[0, 30].inspect}#{" (#{@voice})" if @voice}>"
    end

    class << self
      # The voices this system can speak in, by name, for say(text, voice:).
      # @return [Array<String>]
      def voices
        case platform
        when :macos
          # "Albert              en_US    # Hello! My name is Albert." A name may hold spaces.
          lines("say", "-v", "?").filter_map { |line| line[/\A(.+?)\s{2,}\S+\s+#/, 1]&.strip }.uniq
        when :windows then windows_voices
        else
          if (tool = linux_tool)
            tool == "spd-say" ? lines("spd-say", "-L").drop(1).map { |l| l.split.first }.compact : lines(tool, "--voices").drop(1).map { |l| l.split[3] }.compact
          else
            []
          end
        end
      end

      # @api private
      def stand_in
        file = ENV["SCARPE_AUDIO_FILE"].to_s
        file.empty? ? nil : file
      end

      # The command that says text in voice, and its environment, or nil when there is none.
      # @api private
      def command_for(text, voice)
        case platform
        when :macos
          # A leading space keeps words that start with "-" from reading as an option.
          [["say", *(["-v", voice] if voice), text.start_with?("-") ? " #{text}" : text], {}]
        when :windows
          # The words go in through the environment, which Windows keeps as UTF-16, and the
          # script needs no quoting.
          script = "Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; " \
            "if ($env:SHOES_SPEECH_VOICE) { $s.SelectVoice($env:SHOES_SPEECH_VOICE) }; $s.Speak($env:SHOES_SPEECH_TEXT)"
          [powershell(script), { "SHOES_SPEECH_TEXT" => text, "SHOES_SPEECH_VOICE" => voice }]
        else
          tool = linux_tool or return nil
          voice_args = voice ? [tool == "spd-say" ? "-y" : "-v", voice] : []
          [[tool, *voice_args, "--", text], {}]
        end
      end

      # @api private
      def warn_once(message)
        @warned ||= {}
        return if @warned[message]

        @warned[message] = true
        Shoes::Log.logger("Shoes::Speech").warn(message)
      end

      private

      def platform
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then :macos
        when /mingw|mswin/ then :windows
        else :linux
        end
      end

      # The voices System.Speech speaks with, read from where it finds them (each voice's
      # Attributes\Name). Asking System.Speech itself means starting PowerShell and a
      # SpeechSynthesizer, which takes seconds and can wait on an audio device a server lacks;
      # reg.exe answers in a few milliseconds. (win32/registry would need fiddle, a bundled gem
      # on Ruby 4.0 that a bundle may not hold.)
      def windows_voices
        lines("reg", "query", 'HKLM\SOFTWARE\Microsoft\Speech\Voices\Tokens', "/s", "/v", "Name")
          .filter_map { |line| line[/\A\s+Name\s+REG_SZ\s+(.+?)\s*\z/, 1] }.uniq
      end

      def linux_tool
        %w[espeak-ng espeak spd-say].find do |name|
          ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
        end
      end

      def powershell(script)
        full = "[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false\n#{script}"
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand", [full.encode(Encoding::UTF_16LE)].pack("m0")]
      end

      # A program's output lines, or [] when it is missing or fails.
      def lines(*command)
        out, status = Open3.capture2(*command, err: File::NULL)
        status.success? ? out.force_encoding(Encoding::UTF_8).scrub.lines.map(&:chomp).reject(&:empty?) : []
      rescue SystemCallError, IOError
        []
      end
    end
  end
end
