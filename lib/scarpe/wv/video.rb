# frozen_string_literal: true

class Scarpe
  class WebviewVideo < Scarpe::WebviewWidget
    def initialize(properties)
      @url = properties[:url]
      super
    end

    def element
      HTML.render do |h|
        h.video(id: html_id, style: style, controls: true) do
          h.source(src: @url, type: "video/mp4")
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
