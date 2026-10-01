# frozen_string_literal: true

require "open3"

# The system clipboard, for displays without one of their own (Niente, the webview). The native
# display answers app.clipboard itself, through the clipboard its renderer's text fields use.
#
# Each platform reaches it through a different program:
#
# - macOS: pbpaste and pbcopy, which come with the system.
# - Windows: PowerShell's Get-Clipboard and Set-Clipboard, which come with the system.
# - Linux: wl-paste and wl-copy on Wayland, xclip on X11; a desktop may have neither. Linux keeps
#   no clipboard of its own: the program that copied answers every paste, which is why wl-copy
#   and xclip stay behind in the background after a copy.
#
# SCARPE_CLIPBOARD_FILE names a file that stands in for the system clipboard, so a sandboxed run
# (spec/run, the test suites) never reads or overwrites what someone copied.
module Shoes::Clipboard
  extend self

  # The clipboard's text, or "" when it is empty or cannot be read.
  def read
    if (file = stand_in)
      return File.exist?(file) ? File.read(file, mode: "rb").force_encoding(Encoding::UTF_8).scrub : ""
    end

    text = case platform
    when :macos then capture("pbpaste")
    when :windows then powershell_capture("[Console]::Out.Write((Get-Clipboard -Raw))")
    when :linux
      (capture("wl-paste", "--no-newline") if wayland?) || capture("xclip", "-selection", "clipboard", "-o")
    end
    text.to_s.dup.force_encoding(Encoding::UTF_8).scrub.delete_prefix("\uFEFF")
  end

  # Puts text on the clipboard. Returns whether it got there.
  def write(text)
    text = text.to_s
    if (file = stand_in)
      File.write(file, text, mode: "wb")
      return true
    end

    case platform
    when :macos then feed(text, "pbcopy")
    when :windows then feed(text, *powershell(WINDOWS_SET))
    when :linux
      (wayland? && feed(text, "wl-copy")) || feed(text, "xclip", "-selection", "clipboard")
    else false
    end
  end

  private

  # Reads stdin as UTF-8, whatever the console's code page. Set-Clipboard refuses "", so an
  # empty text clears the clipboard instead.
  WINDOWS_SET = <<~PS
    $s = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8).ReadToEnd()
    if ($s) { Set-Clipboard -Value $s } else { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::Clear() }
  PS

  def stand_in
    file = ENV["SCARPE_CLIPBOARD_FILE"].to_s
    file.empty? ? nil : file
  end

  def platform
    if RUBY_PLATFORM.include?("darwin") then :macos
    elsif Gem.win_platform? then :windows
    else :linux
    end
  end

  def wayland?
    !ENV["WAYLAND_DISPLAY"].to_s.empty?
  end

  # A program's output, or nil when it is missing or fails.
  def capture(*command)
    out, status = Open3.capture2(*command, err: File::NULL)
    status.success? ? out : nil
  rescue SystemCallError, IOError
    nil
  end

  # Writes text to a program's stdin. Its stdout is left alone: xclip and wl-copy leave a
  # process behind to answer pastes, and reading its output would wait for that one too.
  def feed(text, *command)
    IO.popen(command, "wb", err: File::NULL) { |io| io.write(text) }
    $?.success?
  rescue SystemCallError, IOError
    false
  end

  # PowerShell prints UTF-8 when told to, and -EncodedCommand (base64 UTF-16LE) needs no quoting.
  def powershell(script)
    full = "[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false\n#{script}"
    ["powershell.exe", "-NoProfile", "-NonInteractive", "-STA", "-EncodedCommand", [full.encode(Encoding::UTF_16LE)].pack("m0")]
  end

  def powershell_capture(script)
    capture(*powershell(script))
  end
end
