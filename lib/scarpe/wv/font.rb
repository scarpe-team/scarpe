# frozen_string_literal: true

require "scarpe/components/base64"

module Scarpe::Webview
  class Font < Widget
    include Scarpe::Components::Base64
    attr_accessor :font

    def initialize(properties)
      @font = properties[:font]
      super
    end

    def font_name
      File.basename(@font, ".*")
    end

    def element
      ::Scarpe::Components::HTML.render do |h|
        h.link(href: @font, rel: "stylesheet")
        h.style do
          <<~CSS
            @font-face {
              font-family: #{font_name};
              src: url("data:font/truetype;base64,#{encode_file_to_base64(@font)}") format('truetype');
            }
            * {
              font-family: #{font_name};
            }
          CSS
        end
      end
    end
  end
end
