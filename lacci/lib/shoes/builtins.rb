# frozen_string_literal: true

require "open3"

# Shoes has a number of built-in methods that are intended to be available everywhere,
# in every Shoes and non-Shoes class, for every Shoes app.
module Shoes::Builtins
  # Register the given font with Shoes so that text that wants it can use it.
  # Also add its families to the FONTS constant.
  #
  # A URL cannot be read here before the display fetches it, so its file name
  # stands in for its family.
  #
  # @param font_file_or_url [String] the filename or URL for the font
  # @return [Array<String>, nil] the family names in the file, or nil if it holds
  #   no fonts (manual 766-767, ledger K4)
  def font(font_file_or_url)
    families = if font_file_or_url.to_s.match?(%r{\Ahttps?://}i)
      [File.basename(font_file_or_url, ".*")]
    else
      Shoes::FontFile.families(font_file_or_url) or return nil
    end

    shoes_builtin("font", font_file_or_url)
    families.each { |family| Shoes::FONTS << family unless Shoes::FONTS.include?(family) }
    families
  end

  def ask(message_string)
    shoes_builtin("ask", message_string)
  end

  def alert(message)
    shoes_builtin("alert", message)
  end

  # @return [Shoes::Color, nil] the colour picked, or nil on Cancel (manual 643-655)
  def ask_color(title_bar)
    Shoes::Color.from(shoes_builtin("ask_color", title_bar))
  end

  def ask_open_file()
    shoes_builtin("ask_open_file")
  end

  def ask_save_file()
    shoes_builtin("ask_save_file")
  end

  def ask_open_folder()
    shoes_builtin("ask_open_folder")
  end

  def ask_save_folder()
    shoes_builtin("ask_save_folder")
  end

  def confirm(question)
    shoes_builtin("confirm", question)
  end

  # The [width, height] stored in an image file, read without showing or caching the
  # image (manual 2017-2023).
  #
  # @param path [String] a local image file
  # @return [Array(Integer, Integer), nil] nil if the file is not a picture
  def imagesize(path)
    require "fastimage"
    FastImage.size(path)
  end

  # Shoes logging builtins — these output to the Shoes console/debug log.
  # In Scarpe, they simply print to stdout since there's no Shoes console.
  def debug(msg)
    puts "[DEBUG] #{msg}"
  end

  def info(msg)
    puts "[INFO] #{msg}"
  end

  # rgb, gray and gradient are built-ins too, callable from any object (manual
  # 785-834, ledger D4). Drawables keep their own Shoes::Colors copies, and the named
  # colours (red, blue...) stay on drawables.
  def rgb(...) = Shoes.rgb(...)
  def gray(...) = Shoes.gray(...)
  def gradient(...) = Shoes.gradient(...)

  private

  def shoes_builtin(cmd_name, *args)
    Shoes::DisplayService.clear_builtin_response
    Shoes::DisplayService.dispatch_event("builtin", nil, cmd_name, args)
    return Shoes::DisplayService.consume_builtin_response if Shoes::DisplayService.builtin_response?

    # No display service handled this (e.g. called before Shoes.app).
    # Fall back to native OS dialogs for commands that support it.
    native_builtin_fallback(cmd_name, *args)
  end

  # Native OS fallback for builtins called before the display service starts.
  # Classic Shoes allowed ask_open_file etc. before Shoes.app — we honor that.
  def native_builtin_fallback(cmd_name, *args)
    case cmd_name
    when "ask_open_file"
      osascript('POSIX path of (choose file with prompt "Open")')
    when "ask_save_file"
      osascript('POSIX path of (choose file name with prompt "Save as")')
    when "ask_open_folder", "ask_save_folder"
      osascript('POSIX path of (choose folder with prompt "Choose a folder")')
    when "ask"
      escaped = args[0].to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
      result = osascript(%Q{display dialog "#{escaped}" default answer "" buttons {"Cancel", "OK"} default button "OK"})
      return nil unless result
      match = result.match(/text returned:(.*)/)
      match ? match[1].strip : ""
    when "confirm"
      escaped = args[0].to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
      result = osascript(%Q{display dialog "#{escaped}" buttons {"Cancel", "OK"} default button "OK"})
      !result.nil?
    end
  end

  def osascript(script)
    stdout, status = Open3.capture2("osascript", "-e", script)
    status.success? ? stdout.strip : nil
  rescue
    nil
  end
end

module Kernel
  include Shoes::Builtins

  # Top-level window method: creates a new Shoes app, just like Shoes.app.
  # In classic Shoes, `window` sets the child's `owner` to the launching app.
  # At the top level (no existing app), it behaves identically to Shoes.app.
  def window(**opts, &block)
    Shoes.app(**opts, &block)
  end

  # Top-level dialog method: creates a dialog-style Shoes app.
  # For now, aliases to Shoes.app.
  def dialog(**opts, &block)
    Shoes.app(**opts, &block)
  end
end

# Top-level constants are defined in shoes.rb after all drawables are loaded.
