# frozen_string_literal: true

require "scarpe/components/asset_server"

module Scarpe::Webview
  def self.asset_server
    return @asset_server if @asset_server

    @asset_server = Scarpe::Components::AssetServer.new

    # at_exit doesn't work reliably under webview. Give this a try.
    ::Scarpe::Webview::DisplayService.instance.control_interface.on_event(:shutdown) do
      @asset_server&.kill_server
    end

    @asset_server
  end
end

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
