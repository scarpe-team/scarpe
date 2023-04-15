# frozen_string_literal: true

def method_missing(method, ...)
  case method.to_s
  when "alert"
    Scarpe.alert(...)
  when "button"
    Scarpe.button(...)
  when "stack"
    Scarpe.stack(...)
  else
    super
  end
end

def respond_to_missing?(method_name, include_private = false)
  [
    "alert",
    "button",
    "stack",
  ].include?(method_name.to_s) || super
end

def para(*args, **kwargs)
  Scarpe.para(*args, **kwargs)
end

class Scarpe
  class << self
    def app(title: "Scarpe app", height: 400, width: 400)
      setup(title, height, width)
      yield
      closing_stuff
    end

    def setup(title, height, width)
      UI.init

      $main_window = UI.new_window(title, height, width, 1)
      $vbox = UI.new_vertical_box
      UI.window_set_child($main_window, $vbox)
    end

    def closing_stuff
      UI.window_on_closing($main_window) do
        puts "Bye Bye"
        UI.control_destroy($main_window)
        UI.quit
        0
      end

      UI.control_show($main_window)

      # Add main box to main window, close everything out
      UI.main
      UI.quit
    end
  end
end
