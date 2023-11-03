# frozen_string_literal: true

module Scarpe::Webview
  class Span < TextDrawable
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
      render("span", &block)
    end

    def to_html
      element { @text }
    end
  end
end
