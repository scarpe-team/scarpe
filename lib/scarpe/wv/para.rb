# frozen_string_literal: true

class Scarpe
  class WebviewPara < WebviewWidget
    SIZES = {
      inscription: 10,
      ins: 10,
      para: 12,
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
      items = changes.delete("text_items")
      if items
        html_element.inner_html = to_html
        return
      end

      # Not deleting, so this will re-render
      if changes["size"] && SIZES[@size.to_sym]
        @size = @size.to_sym
      end

      super
    end

    def items_to_display_children(items)
      return [] if items.nil?

      items.map do |item|
        if item.is_a?(String)
          item
        else
          WebviewDisplayService.instance.query_display_widget_for(item)
        end
      end
    end

    def element(&block)
      HTML.render do |h|
        h.p(**options, &block)
      end
    end

    def to_html
      @children ||= []

      element { child_markup }
    end

    private

    def child_markup
      items_to_display_children(@text_items).map do |child|
        if child.respond_to?(:to_html)
          child.to_html
        else
          child.gsub("\n", "<br>")
        end
      end.join
    end

    def options
      @html_attributes.merge(id: html_id, style: style)
    end

    def style
      {
        "color" => rgb_to_hex(@stroke),
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
