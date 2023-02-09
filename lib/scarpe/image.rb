class Scarpe
  class Image < Scarpe::Widget
    def initialize(url, width: nil, height: nil, top: nil, left: nil)
      @url = url
      @width = width
      @height = height
      @top = top
      @left = left
    end

    def element
      HTML.render do |h|
        h.img(id: html_id, src: @url, style: style)
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
