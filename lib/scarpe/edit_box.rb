# frozen_string_literal: true

class Scarpe
  class EditBox < Scarpe::Widget
    attr_reader :text, :height, :width

    def initialize(text = nil, height: nil, width: nil, &block)
      @text = text || block.call
      @height = height
      @width = width

      bind("change") do |text|
        @text = text
        @callback&.call(text)
      end
      super
    end

    def change(&block)
      @callback = block
    end

    def text=(text)
      @text = text
      html_element.inner_text = text
    end

    def element
      oninput = handler_js_code("change", "this.value")

      HTML.render do |h|
        h.textarea(id: html_id, oninput: oninput, style: style) { text }
      end
    end

    private

    def style
      styles = {}

      styles[:height] = Dimensions.length(height)
      styles[:width] = Dimensions.length(width)

      styles.compact
    end
  end
end
