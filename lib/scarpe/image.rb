class Scarpe
  class Image < Scarpe::Widget
    def initialize(url, width: nil, height: nil, top: nil, left: nil, click: nil)
      @url = url
      @width = width
      @height = height
      @top = top
      @left = left
      @click = click
    end

    def element
      if @click
        HTML.render do |h|
          h.a(id: html_id, href: @click) { h.img(id: html_id, src: @url, style: style) }
        end
      else
        HTML.render do |h|
          h.img(id: html_id, src: @url, style: style)
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
