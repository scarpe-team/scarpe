# frozen_string_literal: true

class Scarpe
  class WebviewSpan < Scarpe::WebviewWidget
    SIZES = {
      inscription: 10,
      ins: 10,
      span: 12,
      caption: 14,
      tagline: 18,
      subtitle: 26,
      title: 34,
      banner: 48,
    }.freeze
    private_constant :SIZES

    def initialize(properties)
      super
    end

    def properties_changed(changes)
      text = changes.delete("text")
      if text
        html_element.inner_html = text
        return
      end

      # Not deleting, so this will re-render
      if changes["size"] && SIZES[@size.to_sym]
        @size = @size.to_sym
      end

      super
    end

    def element(&block)
      HTML.render do |h|
        h.span(**options, &block)
      end
    end

    def to_html
      element { @text }
    end

    private

    def options
      @html_attributes.merge(id: html_id, style: style)
    end

    def style
      {
        "color" => @stroke,
        "font-size" => font_size,
        "font-family" => @font,
      }.compact
    end

    def font_size
      font_size = @size.is_a?(Symbol) ? SIZES[@size] : @size

      Dimensions.length(font_size)
    end
  end
end
