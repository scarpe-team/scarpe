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
      banner: 48
    }.freeze
    private_constant :SIZES

    def self.inherited(subclass)
      Scarpe::Widget.widget_classes ||= []
      Scarpe::Widget.widget_classes << subclass
    end

    def initialize(*args, stroke: nil, size: :para, **html_attributes)
      @text_children = args || []
      @stroke = stroke
      @size = size
      @html_attributes = html_attributes
    end

    def element
      HTML.render do |h|
        h.p(**options) { yield }
      end
    end

    def to_html
      @children ||= []

      child_markup = @text_children.map do |child|
        if child.respond_to?(:to_html)
          child.to_html
        else
          child
        end
      end.join

      element { child_markup }
    end

    def replace(new_text)
      text = new_text
      self.inner_text = new_text
    end

    private

    def options
      html_attributes.merge(id: html_id, style: style)
    end

    def style
      {
        "color" => stroke,
        "font-size" => font_size
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
