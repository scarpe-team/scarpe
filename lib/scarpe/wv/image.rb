# frozen_string_literal: true

require "scarpe/components/base64"

module Scarpe::Webview
  class Image < Drawable
    include Scarpe::Components::Base64

    def initialize(properties)
      super

      unless valid_url?(@url)
        @url = "data:image/png;base64,#{encode_file_to_base64(@url)}"
      end
    end

    def element
      render("image")
    end
  end
end
