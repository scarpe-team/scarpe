# frozen_string_literal: true

class Shoes::Slot < Shoes::Drawable
  # @incompatibility Shoes uses #content, not #children, for this. Scarpe does both.
  attr_reader :children

  # This only shows this specific slot's settings, not its parent's.
  # Use current_draw_context to allow inheritance.
  attr_reader :draw_context

  shoes_events # No Slot-specific events

  def initialize(...)
    # The draw context tracks current settings like fill and stroke,
    # plus potentially other current state that changes from drawable
    # to drawable and slot to slot.
    @draw_context = {
      "fill" => nil,
      "stroke" => nil,
      "strokewidth" => nil,
      "rotate" => nil,
      # "transform" => nil, # "corner",
      # "translate" => nil, # [0, 0],
    }

    super
  end

  # Do not call directly, use set_parent
  def remove_child(child)
    @children ||= []
    unless @children.include?(child)
      @log.warn("remove_child: no such child(#{child.inspect}) for parent(#{parent.inspect})!")
    end
    @children.delete(child)
  end

  # Do not call directly, use set_parent
  def add_child(child)
    @children ||= []
    @children << child
  end

  # Get a list of child drawables
  def contents
    @children ||= []
    @children.dup
  end

  # We use method_missing for drawable-creating methods like "button".
  # The parent's method_missing will auto-create Shoes style getters and setters.
  # This is similar to the method_missing in Shoes::App, but differs in where
  # the new drawable will appear.
  def method_missing(name, *args, **kwargs, &block)
    klass = ::Shoes::Drawable.drawable_class_by_name(name)
    return super unless klass

    ::Shoes::Slot.define_method(name) do |*args, **kwargs, &block|
      instance = nil

      # Look up the Shoes drawable and create it. But first set
      # this slot as the current one so that draw context
      # is handled properly.
      Shoes::App.instance.with_slot(self) do
        instance = klass.new(*args, **kwargs, &block)
      end

      instance
    end

    send(name, *args, **kwargs, &block)
  end

  def respond_to_missing?(name, include_private = false)
    return true if ::Shoes::Drawable.drawable_class_by_name(name.to_s)

    false
  end

  # Draw context methods

  # Set the default fill color in this slot and child slots.
  # Pass nil for "no setting", so that it can inherit defaults.
  #
  # @param color [Nil,Color] a Shoes color for the fill color or nil to use parent setting
  # @return [void]
  def fill(color)
    @draw_context["fill"] = color
  end

  # Set the default fill in this slot and child slots to transparent.
  #
  # @return [void]
  def nofill
    @draw_context["fill"] = rgb(0, 0, 0, 0)
  end

  # Set the default stroke color in this slot and child slots.
  # Pass nil for "no setting" so it can inherit defaults.
  #
  # @param color [Nil,Color] a Shoes color for the stroke color or nil to use parent setting
  # @return [void]
  def stroke(color)
    @draw_context["stroke"] = color
  end

  # Set the default strokewidth in this slot and child slots.
  # Pass nil for "no setting".
  #
  # @param width [Numeric,Nil] the new width, or nil to use parent setting
  # @return [void]
  def strokewidth(width)
    @draw_context["strokewidth"] = width
  end

  # Set the default stroke in this slot and child slots
  # to transparent.
  #
  # @return [void]
  def nostroke
    @draw_context["stroke"] = rgb(0, 0, 0, 0)
  end

  # Set the current rotation in this slot and any child slots.
  # Pass nil to reset the angle to default.
  #
  # @param angle [Numeric,Nil] the new default rotation for shapes or nil to use parent setting
  # @return [void]
  def rotate(angle)
    @draw_context["rotate"] = angle
  end

  # Get the current draw context styles, based on this slot and its parent slots.
  #
  # @return [Hash] a hash of Shoes styles for the context
  def current_draw_context
    s = @parent ? @parent.current_draw_context : {}
    @draw_context.each { |k, v| s[k] = v unless v.nil? }

    s
  end

  # Methods to add or remove children

  # Remove all children from this drawable. If a block
  # is given, call the block to replace the children with
  # new contents from that block.
  #
  # Should only be called on Slots, which can
  # have children.
  #
  # @incompatibility Shoes Classic calls the clear block with current self, while Scarpe uses the Shoes::App as self
  #
  # @yield The block to call to replace the contents of the drawable (optional)
  # @return [void]
  def clear(&block)
    @children ||= []
    @children.dup.each(&:destroy)
    append(&block) if block_given?
    nil
  end

  # Call the block to append new children to a Slot.
  #
  # Should only be called on a Slot, since only Slots can have children.
  #
  # @incompatibility Shoes Classic calls the append block with current self, while Scarpe uses the Shoes::App as self
  #
  # @yield the block to call to replace children; will be called on the Shoes::App, appending to the called Slot as the current slot
  # @return [void]
  def append(&block)
    raise(Shoes::Errors::InvalidAttributeValueError, "append requires a block!") unless block_given?
    raise(Shoes::Errors::InvalidAttributeValueError, "Don't append to something that isn't a slot!") unless self.is_a?(Shoes::Slot)

    Shoes::App.instance.with_slot(self, &block)
  end
end
