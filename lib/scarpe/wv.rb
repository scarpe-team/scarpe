# frozen_string_literal: true

# Scarpe Webview Display Services

# This file is for everything that should be included by *both* wv_local and wv_relay

require "securerandom"
require "json"

require "bloops"
require "scarpe/components/html" # HTML renderer
require "scarpe/components/modular_logger"
require "scarpe/components/promises"
require "scarpe/components/string_helpers"

# Module to contain the various Scarpe Webview classes
module Scarpe::Webview
  HTML = Scarpe::Components::HTML
end

# Set up Scarpe-Webview's HTML renderer
ren = ENV["SCARPE_HTML_RENDERER"] || "calzini"
# This should *not* be require_relative so that other gems can implement HTML renderers.
require "scarpe/components/#{ren}"
class Scarpe::Webview::Drawable < Shoes::Linkable
  # By default it's Scarpe::Components::Calzini
  comp = Scarpe::Components::StringHelpers.camelize(ENV["SCARPE_HTML_RENDERER"] || "calzini")
  mod = Scarpe::Components.const_get(comp)
  include mod
end

# Set up hierarchical logging using the SCARPE_LOG_CONFIG var for configuration
log_config = if ENV["SCARPE_LOG_CONFIG"]
  JSON.load_file(ENV["SCARPE_LOG_CONFIG"])
else
  ENV["SCARPE_DEBUG"] ? Shoes::Log::DEFAULT_DEBUG_LOG_CONFIG : Shoes::Log::DEFAULT_LOG_CONFIG
end

Shoes::Log.instance = Scarpe::Components::ModularLogImpl.new
Shoes::Log.configure_logger(log_config)

require "scarpe/components/segmented_file_loader"
loader = Scarpe::Components::SegmentedFileLoader.new
Shoes.add_file_loader loader

# Fun trivia: listing the full set of available fonts is a fingerprinting attack, so it's not
# available from JS. These are all commonly available web fonts, though.
Shoes::FONTS.push(
  "Helvetica",
  "Arial",
  "Arial Black",
  "Verdana",
  "Tahoma",
  "Trebuchet MS",
  "Impact",
  "Gill Sans",
  "Times New Roman",
  "Georgia",
  "Palatino",
  "Baskerville",
  "Courier",
  "Lucida",
  "Monaco",
)

require_relative "shoes_spec"
Shoes::Spec.instance = Scarpe::Test

require_relative "wv/web_wrangler"
require_relative "wv/control_interface"

require_relative "wv/drawable"

require_relative "wv/star"
require_relative "wv/radio"

require_relative "wv/arc"

require_relative "wv/app"
require_relative "wv/para"
require_relative "wv/slot"
require_relative "wv/stack"
require_relative "wv/flow"
require_relative "wv/document_root"
require_relative "wv/subscription_item"
require_relative "wv/button"
require_relative "wv/image"
require_relative "wv/edit_box"
require_relative "wv/edit_line"
require_relative "wv/list_box"
require_relative "wv/shape"

require_relative "wv/text_drawable"
require_relative "wv/span"
require_relative "wv/link"
require_relative "wv/line"
require_relative "wv/rect"
require_relative "wv/video"
require_relative "wv/check"
require_relative "wv/progress"
require_relative "wv/arrow"
