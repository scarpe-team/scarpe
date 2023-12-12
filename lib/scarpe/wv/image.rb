# frozen_string_literal: true

module Scarpe::Webview
  class Image < Drawable
    def initialize(properties)
      super

      unless valid_url?(@url)
        # It's assumed to be a file path.
        @url = Scarpe::Webview.asset_server.asset_url(File.expand_path @url)
      end
    end

    def element
      render("image")
    end
  end
end
