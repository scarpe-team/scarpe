# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

# Lacci's own route to the system clipboard (Shoes::Clipboard), for the displays that keep none:
# pbpaste and pbcopy, PowerShell, wl-paste and wl-copy, or xclip, and SCARPE_CLIPBOARD_FILE's
# stand-in in place of all of them.
class TestClipboard < Minitest::Test
  def setup
    @saved = %w[SCARPE_CLIPBOARD_FILE PATH WAYLAND_DISPLAY].to_h { |name| [name, ENV[name]] }
    @dir = Dir.mktmpdir("lacci-clipboard")
  end

  def teardown
    @saved.each { |name, value| ENV[name] = value }
    FileUtils.rm_rf(@dir)
  end

  def test_the_stand_in_file_is_the_clipboard
    board = File.join(@dir, "clipboard.txt")
    ENV["SCARPE_CLIPBOARD_FILE"] = board
    assert_equal "", Shoes::Clipboard.read, "no file yet is an empty clipboard"

    File.write(board, "copied in another program ✓", mode: "wb")
    assert_equal "copied in another program ✓", Shoes::Clipboard.read
    assert_equal Encoding::UTF_8, Shoes::Clipboard.read.encoding

    assert Shoes::Clipboard.write("Shoes was here")
    assert_equal "Shoes was here", File.read(board)
  end

  # No pbpaste, PowerShell, wl-paste or xclip to be found: nothing to read, and nowhere to write.
  def test_a_clipboard_nothing_can_reach_reads_empty
    ENV["SCARPE_CLIPBOARD_FILE"] = nil
    ENV["PATH"] = @dir
    ENV["WAYLAND_DISPLAY"] = "wayland-0"
    assert_equal "", Shoes::Clipboard.read
    refute Shoes::Clipboard.write("lost")
  end
end
