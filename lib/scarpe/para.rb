# frozen_string_literal: true

class Scarpe
  class Para < Scarpe::Widget
    class << self
      def inherited(subclass)
        Scarpe::Widget.widget_classes ||= []
        Scarpe::Widget.widget_classes << subclass
        super
      end
    end

    display_properties :text_items, :stroke, :size, :html_attributes

    def initialize(*args, stroke: nil, size: :para, **html_attributes)
      @text_children = args || []
      # Text_children alternates strings and TextWidgets, so we can't just pass it as a display property. It won't serialize.
      @text_items = text_children_to_items(@text_children)

      @html_attributes = html_attributes || {}

      super

      create_display_widget
    end

    def text_children_to_items(text_children)
      text_children.map { |arg| arg.is_a?(String) ? arg : arg.linkable_id }
    end

    def replace(*children)
      @text_children = children

      # This should signal the display widget to change
      self.text_items = text_children_to_items(@text_children)
    end
  end

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

  class Widget
    def banner(*args, **kwargs)
      para(*args, **{ size: :banner }.merge(kwargs))
    end

    def title(*args, **kwargs)
      para(*args, **{ size: :title }.merge(kwargs))
    end

    def subtitle(*args, **kwargs)
      para(*args, **{ size: :subtitle }.merge(kwargs))
    end

    def tagline(*args, **kwargs)
      para(*args, **{ size: :tagline }.merge(kwargs))
    end

    def caption(*args, **kwargs)
      para(*args, **{ size: :caption }.merge(kwargs))
    end

    def inscription(*args, **kwargs)
      para(*args, **{ size: :inscription }.merge(kwargs))
    end

    alias_method :ins, :inscription
  end
end
