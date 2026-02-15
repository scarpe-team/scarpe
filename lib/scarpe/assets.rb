# frozen_string_literal: true

# Choose asset server based on environment
# SCARPE_MINI_ASSET_SERVER=1 → lightweight server (no WEBrick dependency)
# SCARPE_PACKAGED=1 → lightweight server (packaged apps use mini by default)
if ENV['SCARPE_MINI_ASSET_SERVER'] == '1' || ENV['SCARPE_PACKAGED'] == '1'
  require "scarpe/components/mini_asset_server"
  SCARPE_ASSET_SERVER_CLASS = Scarpe::Components::MiniAssetServer
else
  require "scarpe/components/asset_server"
  SCARPE_ASSET_SERVER_CLASS = Scarpe::Components::AssetServer
end

module Scarpe::Webview
  def self.asset_server
    return @asset_server if @asset_server

    # A Scarpe Webview application can have only a single Shoes::App instance.
    @asset_server = SCARPE_ASSET_SERVER_CLASS.new app_dir: Shoes.APPS[0].dir

    # at_exit doesn't work reliably under webview. Give this a try.
    ::Scarpe::Webview::DisplayService.instance.control_interface.on_event(:shutdown) do
      @asset_server&.kill_server
    end

    @asset_server
  end
end
