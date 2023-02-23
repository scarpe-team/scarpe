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

  class WebviewImage < WebviewWidget
    def initialize(properties)
      super
    end

    def element
      if @click
        HTML.render do |h|
          h.a(id: html_id, href: @click) { h.img(id: html_id, src: @url, style:) }
        end
      else
        HTML.render do |h|
          h.img(id: html_id, src: @url, style:)
        end
      end
    end

    private

    def style
      styles = {}

      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles[:top] = Dimensions.length(@top) if @top
      styles[:left] = Dimensions.length(@left) if @left
      styles[:position] = "absolute" if @top || @left

      styles
    end
  end
end
