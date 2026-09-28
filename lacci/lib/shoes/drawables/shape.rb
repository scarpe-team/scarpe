# frozen_string_literal: true

class Shoes
  # A Shape acts as a sort of union type for drawn shapes. In Shoes you can use it to merge multiple
  # ovals, arcs, stars, etc. into a single drawn shape.
  #
  # In Shoes3, a Shape isn't really a Slot. It's a kind of DSL with drawing commands that happen
  # to have the same name as the Art drawables like star, arc, etc. Here we're treating it as
  # a slot containing those drawables, which is wrong but not *too* wrong.
  #
  # @incompatibility A Shoes3 Shape is *not* a slot; Scarpe does *not* do union shapes
  class Shape < Shoes::Slot
    uses_draw_context
    shoes_styles :left, :top, :shape_commands, :draw_context
    shoes_styles :stroke, :fill, :strokewidth # the pens it is given (manual 1202-1210, 1453-1468)
    shoes_events # No Shape-specific events yet

    init_args # No positional args
    def initialize(*args, **kwargs, &block)
      # Shoes3 supports shape(left, top) { } with positional coordinates
      if args.length >= 2 && args[0].is_a?(Numeric) && args[1].is_a?(Numeric)
        kwargs[:left] = args[0]
        kwargs[:top] = args[1]
        args = args[2..] || []
      end

      @shape_commands = []

      super(**kwargs)
      keep_only_given_pens(kwargs.keys)
      @draw_context = @app.current_draw_context
      create_display_drawable

      draw(&block) if block_given?
    end

    # The cmd should be an array of the form:
    #
    #     [cmd_name, *args]
    #
    # such as ["move_to", 50, 50]. Note that these must
    # be JSON-serializable.
    def add_shape_command(cmd)
      @shape_commands << cmd
      send_changes("shape_commands" => @shape_commands.dup) unless @drawing
    end

    private

    # A pen the shape was not given comes from the draw context sent once its block has
    # run (see #draw), so `stroke red` inside the block still strokes it.
    def keep_only_given_pens(given)
      (%i[stroke fill strokewidth cap] - given).each { |pen| instance_variable_set("@#{pen}", nil) }
    end

    # The display was created with an empty command list, so the whole path goes
    # out in one prop_change once the block has built it, with the pens the block
    # set. Shoes 3 makes the shape after its block and copies the pens then
    # (s3t_shape.c:290-315), so `stroke red` inside the block strokes this shape.
    def draw(&block)
      @drawing = true
      @app.with_slot(self, &block)
    ensure
      @drawing = false
      send_changes("shape_commands" => @shape_commands.dup, "draw_context" => draw_context.dup)
    end

    def send_changes(changes)
      send_shoes_event(changes, event_name: "prop_change", target: linkable_id)
    end
  end
end
