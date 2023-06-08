# frozen_string_literal: true

require_relative "wv/shape_helper"
class Scarpe
  class Shape < Scarpe::Widget
    include ShapeHelper
    display_properties :left, :top

    def initialize(left: nil, top: nil, path_commands: nil, &block)
      @left = left
      @top = top

      super()
      create_display_widget
      instance_eval(&block)
    end
  end
end
