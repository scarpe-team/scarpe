# frozen_string_literal: true

module Shoes
  # Weirdly, in Shoes3 Shape is *not* a Slot subclass, it's a normal Type even though it has a block.
  # We need to push the Shape as a slot so that we can correctly direct move_to, line_to, etc. to it.
  class Shape < Shoes::Widget
    display_properties :left, :top, :shape_commands, :draw_context

    def initialize(left: nil, top: nil, &block)
      @left = left
      @top = top
      @shape_commands = []
      @draw_context = Shoes::App.instance.current_draw_context

      super
      create_display_widget

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
