# frozen_string_literal: true

require "scarpe/components/asset_server"

module Scarpe::Webview
  def self.asset_server
    return @asset_server if @asset_server

    @asset_server = Scarpe::Components::AssetServer.new app_dir: Shoes::App.instance.dir

    # at_exit doesn't work reliably under webview. Give this a try.
    ::Scarpe::Webview::DisplayService.instance.control_interface.on_event(:shutdown) do
      @asset_server&.kill_server
    end

    @asset_server
  end
end
