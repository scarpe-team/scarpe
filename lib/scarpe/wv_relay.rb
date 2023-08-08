# frozen_string_literal: true

require_relative "wv"
require_relative "wv/webview_relay_display"

require "bloops"

Shoes::DisplayService.set_display_service_class(Scarpe::WVRelayDisplayService)

log_config = if ENV["SCARPE_LOG_CONFIG"]
  JSON.load_file(ENV["SCARPE_LOG_CONFIG"])
else
  ENV["SCARPE_DEBUG"] ? Shoes::Log::DEFAULT_DEBUG_LOG_CONFIG : Shoes::Log::DEFAULT_LOG_CONFIG
end

Shoes::Log.instance = Scarpe::LogImpl.new
Shoes::Log.configure_logger(log_config)
