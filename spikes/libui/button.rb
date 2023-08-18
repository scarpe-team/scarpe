# frozen_string_literal: true

class Scarpe
  class << self
    def button(text)
      @button = UI.new_button(text)

      UI.button_on_clicked(@button) do
        puts "herpderpin in the dark"
        yield
      end

      # We're appending this to the top level box. (Note, may want to apply to "parent" long term)
      hbox = $parent_box ? $parent_box : $vbox
      UI.box_append(hbox, @button, 0)
    end
  end
end
