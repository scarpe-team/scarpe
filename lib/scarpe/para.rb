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

    attr_reader :stroke, :size, :html_attributes

    def initialize(*args, stroke: nil, size: :para, **html_attributes)
      @text_children = args || []
      @stroke = stroke
      @size = size
      @html_attributes = html_attributes

      super

      display_widget_properties(text_children_to_items(args), stroke:, size:, **html_attributes)
    end

    def text_children_to_items(text_children)
      text_children.map { |arg| arg.is_a?(String) ? arg : arg.linkable_id }
    end

    def replace(*children)
      send_shoes_event(text_children_to_items(children), event_name: "replace", target: linkable_id)
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

    def initialize(items, stroke:, size:, shoes_linkable_id:, **html_attributes)
      @text_children = items_to_display_children(items)
      @stroke = stroke
      @size = size
      @html_attributes = html_attributes

      super

      bind_shoes_event(event_name: "replace", target: shoes_linkable_id) do |items|
        @text_children = items_to_display_children(items)
        html_element.inner_html = child_markup
      end
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
      @text_children.map do |child|
        if child.respond_to?(:to_html)
          child.to_html
        else
          child
        end
      end.join
    end

    def options
      html_attributes.merge(id: html_id, style: style)
    end

    def style
      {
        "color" => stroke,
        "font-size" => font_size,
      }.compact
    end

    def font_size
      font_size = size.is_a?(Symbol) ? SIZES[size] : size

      Dimensions.length(font_size)
    end

    attr_reader :stroke, :size, :html_attributes
  end

  class Widget
    def banner(*args, **kwargs)
      para(*args, **({size: :banner}.merge(kwargs)))
    end

    def title(*args, **kwargs)
      para(*args, **({size: :title}.merge(kwargs)))
    end

    def subtitle(*args, **kwargs)
      para(*args, **({size: :subtitle}.merge(kwargs)))
    end

    def tagline(*args, **kwargs)
      para(*args, **({size: :tagline}.merge(kwargs)))
    end

    def caption(*args, **kwargs)
      para(*args, **({size: :caption}.merge(kwargs)))
    end

    def inscription(*args, **kwargs)
      para(*args, **({size: :inscription}.merge(kwargs)))
    end

    alias ins inscription
  end
end
