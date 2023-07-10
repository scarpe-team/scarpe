# frozen_string_literal: true

class Scarpe
  class Fill < Shoes::Widget
    display_properties :color

    def initialize(color)
      @color = color
      super
      create_display_widget
    end

    def element
      HTML.render do |h|
        h.style(<<~CSS)
          ##{html_id} {
            background-color: #{@color};
          }
        CSS
      end
    end
  end
end
