class Scarpe
  class Para < Scarpe::Widget
    def initialize(text, stroke: nil, **html_attributes)
      @text = Array(text)
      @stroke = stroke
      @html_attributes = html_attributes
    end

    def element
      HTML.render do |h|
        h.p(**options) do
          text.join
        end
      end
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
        color: stroke
      }.compact
    end

    attr_accessor :text
    attr_reader :stroke, :html_attributes
  end
end
