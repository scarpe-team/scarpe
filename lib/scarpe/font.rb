# frozen_string_literal: true

class Scarpe
  class Font < Scarpe::Widget
    display_properties :file_path

    def initialize(file_path)
      @file_path = file_path
      super

      create_display_widget
    end
  end
end
