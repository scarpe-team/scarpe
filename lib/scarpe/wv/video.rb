# frozen_string_literal: true

class Scarpe
  class WebviewVideo < Scarpe::WebviewWidget
    SUPPORTED_FORMATS = {
      "video/mp4" => [".mp4"],
      "video/webp" => [".webp"],
      "video/quicktime" => [".mov"],
      "video/x-matroska" => [".mkv"],
      # Add more formats and their associated file extensions if needed
    }.freeze

    def initialize(properties)
      @url = properties[:url]
      super
    end

    def element
      HTML.render do |h|
        h.video(id: html_id, style: style, controls: true) do
          supported_formats.each do |format|
            h.source(src: @url, type: format)
          end
        end
      end
    end

    private

    def supported_formats
      SUPPORTED_FORMATS.select { |_format, extensions| extensions.include?(File.extname(@url)) }.keys
    end

    def style
      styles = {}

      # ADD YOUR STYLES HERE

      styles.compact
    end
  end
end
