# frozen_string_literal: true

# Shoes has a number of built-in methods that are intended to be available everywhere,
# in every Shoes and non-Shoes class, for every Shoes app.
class Shoes::Builtins
  # Register the given font with Shoes so that text that wants it can use it.
  # Also add it to the FONTS constant.
  #
  # @param font_file_or_url [String] the filename or URL for the font
  # @return [void]
  def font(font_file_or_url)
    shoes_builtin("font", font_file_or_url)

    font_name = File.basename(font_file_or_url, ".*")
    Shoes::FONTS << font_name
  end

  def ask(message_string)
    shoes_builtin("ask", message_string)
  end

  def alert(message)
    shoes_builtin("alert", message)
  end

  def ask_color(title_bar)
    shoes_builtin("ask_color", title_bar)
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

  # TO ADD: debug, error, info, warn
  # TO VERIFY OR ADD: gradient, gray, rgb

  private

  def shoes_builtin(cmd_name, *args)
    Shoes::DisplayService.dispatch_event("builtin", nil, cmd_name, args)
    nil
  end
end

module Kernel
  include Shoes::Builtins
end
