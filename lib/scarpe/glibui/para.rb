# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIPara < GlimmerLibUIWidget
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
        # we might need this to extend para in new prs?
        return
      end

      super
    end

    def display
      <<~GLIMMER_CODE
        area {
          text {
            string "Hello World"
          }
        }
      GLIMMER_CODE
    end

    def items_to_display_children(items)
      return [] if items.nil?

      items.map do |item|
        if item.is_a?(String)
          item
        else
          GlimmerLibUIDisplayService.instance.query_display_widget_for(item)
        end
      end
    end

    private

    # hangon for future para prs
    def child_markup
      items_to_display_children(@text_items).map do |child|
        if child.respond_to?(:to_html)
          child.to_html
        else
          child
        end
      end.join
    end

    def options
      @html_attributes.merge(id: html_id, style: style)
    end

    def style
      {
        "color" => @stroke,
        "font-size" => font_size,
      }.compact
    end

    def font_size
      font_size = @size.is_a?(Symbol) ? SIZES[@size] : @size

      Dimensions.length(font_size)
    end
  end
end
