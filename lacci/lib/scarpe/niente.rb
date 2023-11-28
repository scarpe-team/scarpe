# frozen_string_literal: true

# Niente -- Italian for "nothing" -- is a null display service
# that doesn't display anything. It does very little, while
# keeping a certain amount of "mental model" or schema of
# how a real display service should act.
module Niente; end

require_relative "niente/logger"
Shoes::Log.instance = Niente::LogImpl.new

require_relative "niente/drawable"
require_relative "niente/app"
require_relative "niente/display_service"

require_relative "niente/shoes_spec"
Shoes::Spec.instance = Niente::Test

require "scarpe/components/segmented_file_loader"
loader = Scarpe::Components::SegmentedFileLoader.new
Shoes.add_file_loader loader

Shoes::DisplayService.set_display_service_class(Niente::DisplayService)

