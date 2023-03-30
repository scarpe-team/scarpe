# frozen_string_literal: true

require "fastimage"
require "open-uri"
class Scarpe
  class Image < Scarpe::Widget
    display_properties :url, :width, :height, :top, :left, :click

    def initialize(url, width: nil, height: nil, top: nil, left: nil, click: nil)
      @url = url
      super
      @width, @height = size(url)

      create_display_widget
    end
  end

  class Widget
    def size(url)
      width, height = FastImage.size(url)

      puts "Width is : #{width}"
      puts "Height is : #{height}"
    end
  end
end
