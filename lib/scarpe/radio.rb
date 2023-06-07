# frozen_string_literal: true

class Scarpe
  class Radio < Scarpe::Widget
    display_properties :text

    def initialize(text, &block)
      @text = text.content
      super
      create_display_widget
    end
  end
end
