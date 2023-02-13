# frozen_string_literal: true

class Scarpe
  class EditLine < Scarpe::Widget
    attr_reader :text

    def initialize(text = "", width: nil, &block)
      @block = block
      @text = text
      @width = width

      bind("change") do |text|
        @text = text
        @block&.call(text)
      end
      super
    end

    def change(&block)
      @block = block
    end

    def text=(text)
      @text = text

      html_element.value = text
      # Note: text= can't return random objects, so we can't do html_element.promise_update here :-(
    end

    def element
      oninput = handler_js_code("change", "this.value")

      HTML.render do |h|
        h.input(id: html_id, oninput: oninput, value: @text, style: style)
      end
    end

    private

    def style
      styles = {}

      styles[:width] = Dimensions.length(@width) if @width

      styles
    end
  end
end
