# frozen_string_literal: true

# Niente -- Italian for "nothing" -- is a null display service
# that doesn't display anything. It does very little, while
# keeping a certain amount of "mental model" or schema of
# how a real display service should act.
module Niente; end

require "scarpe/components/print_logger"
Shoes::Log.instance = Scarpe::Components::PrintLogImpl.new
if ENV["NIENTE_LOG_LEVEL"]
  pl = Scarpe::Components::PrintLogImpl::PrintLogger
  level = ENV["NIENTE_LOG_LEVEL"].strip.downcase.to_sym
  unless pl::LEVELS.key?(level)
    raise "Unrecognized Niente log level: #{level.inspect}!"
  end
  pl.min_level = pl::LEVELS[level]
end

require_relative "niente/drawable"
require_relative "niente/app"
require_relative "niente/display_service"

require_relative "niente/shoes_spec"
Shoes::Spec.instance = Niente::Test

require "scarpe/components/segmented_file_loader"
loader = Scarpe::Components::SegmentedFileLoader.new
Shoes.add_file_loader loader

Shoes::DisplayService.set_display_service_class(Niente::DisplayService)

