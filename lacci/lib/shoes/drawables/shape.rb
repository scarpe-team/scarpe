# frozen_string_literal: true

module Shoes
  # A Shape acts as a sort of union type for drawn shapes. In Shoes you can use it to merge multiple
  # ovals, arcs, stars, etc. into a single drawn shape.
  #
  # In Shoes3, a Shape isn't really a Slot. It's a kind of DSL with drawing commands that happen
  # to have the same name as the Art drawables like star, arc, etc. Here we're treating it as
  # a slot containing those drawables, which is wrong but not *too* wrong.
  #
  # @incompatibility A Shoes3 Shape is *not* a slot; Scarpe does *not* do union shapes
  class Shape < Shoes::Slot
    display_properties :left, :top, :shape_commands, :draw_context

    def initialize(left: nil, top: nil, &block)
      @shape_commands = []
      @draw_context = Shoes::App.instance.current_draw_context

      super
      create_display_drawable

      Shoes::App.instance.with_slot(self, &block) if block_given?
    end

    # The cmd should be an array of the form:
    #
    #     [cmd_name, *args]
    #
    # such as ["move_to", 50, 50]. Note that these must
    # be JSON-serializable.
    def add_shape_command(cmd)
      @shape_commands << cmd
    end
  end
end
