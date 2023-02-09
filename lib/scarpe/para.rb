# frozen_string_literal: true

class Scarpe
  class Para < Scarpe::Widget
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

    class << self
      def inherited(subclass)
        Scarpe::Widget.widget_classes ||= []
        Scarpe::Widget.widget_classes << subclass
        super
      end
    end

    def initialize(*args, stroke: nil, size: :para, **html_attributes)
      @text_children = args || []
      @stroke = stroke
      @size = size
      @html_attributes = html_attributes
      super
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

    def replace(*args)
      @text_children = args || []
      self.inner_html = child_markup
    end

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

    attr_accessor :text
    attr_reader :stroke, :size, :html_attributes
  end
end
