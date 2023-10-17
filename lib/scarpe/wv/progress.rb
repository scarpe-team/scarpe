# frozen_string_literal: true

module Scarpe::Webview
  class Progress < Drawable
    def initialize(properties)
      super
    end

    def element
      HTML.render do |h|
        h.progress(id: html_id, style: style, max: 1, value: @fraction) do
        end
      end
    end

    private

    def style
      styles = {}

      #ADD YOUR STYLES HERE

      styles.compact
    end
  end
end
