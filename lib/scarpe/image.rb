# frozen_string_literal: true

class Scarpe
  class Image < Scarpe::Widget
    display_properties :url, :width, :height, :top, :left, :click

    def initialize(url, width: nil, height: nil, top: nil, left: nil, click: nil)
      @url = url

      super

      create_display_widget
    end
  end
end
