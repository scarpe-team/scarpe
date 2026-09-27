# frozen_string_literal: true

class Shoes::Slot < Shoes::Drawable
  # @incompatibility Shoes uses #content, not #children, for this. Scarpe does both.
  attr_reader :children

  shoes_events :full_redraw_request

  # :attach controls positioning anchor. Values:
  # - Window — position relative to window (absolute positioning)
  # - :center — center the slot
  # - another_drawable — position relative to that element
  shoes_styles :attach

  # fill, stroke, rotate, translate... for the shapes drawn in this slot
  include Shoes::DrawContext

  # Do not call directly, use set_parent
  def remove_child(child)
    @children ||= []
    unless @children.include?(child)
      @log.warn("remove_child: no such child(#{child.inspect}) for parent(#{parent.inspect})!")
    end
    @children.delete(child)
  end

  # Do not call directly, use set_parent
  #
  # While prepend/before/after run, new children go in front of the
  # anchor sibling, so several of them keep their source order.
  def add_child(child)
    @children ||= []
    anchor_index = @insertion_anchor && @children.index(@insertion_anchor)
    if anchor_index
      @children.insert(anchor_index, child)
    else
      @children << child
    end
  end

  # Get a list of child drawables
  def contents
    @children ||= []
    @children.dup
  end

  # Override left to default to 0 instead of nil.
  # Many Shoes widgets expect numeric positions.
  def left
    super || 0
  end

  # Override top to default to 0 instead of nil.
  # Many Shoes widgets expect numeric positions.
  def top
    super || 0
  end

  # The height of everything in the slot, including what is scrolled out of view
  # (manual 2440-2442). Without a display reporting layout, that is the slot's height.
  #
  # @return [Numeric] the content height in pixels
  def scroll_height
    laid_out_at(:scroll_height) || height
  end

  # How far the slot can scroll: scroll_height minus height, and never below zero
  # (manual 2444-2451, Shoes 3 shoes_canvas_get_scroll_max).
  #
  # @return [Numeric] the largest scroll_top, in pixels
  def scroll_max
    [scroll_height - height, 0].max
  end

  # The width of the scrollbar area, one of the slot position methods (manual 2394-2399).
  def gutter
    @app.gutter
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

      # Shoes3 compat: when a Hash is passed as the last positional arg,
      # extract it as keyword args for drawable initialization.
      if kwargs.empty? && args.last.is_a?(Hash)
        kwargs = args.pop
      end

      # Look up the Shoes drawable and create it. But first set
      # this slot as the current one so that draw context
      # is handled properly.
      @app.with_slot(self) do
        Shoes::Drawable.with_current_app(self.app) do
          instance = klass.new(*args, **kwargs, &block)
        end
      end

      instance
    end

    # Also apply the same Hash extraction for this first call
    if kwargs.empty? && args.last.is_a?(Hash)
      kwargs = args.pop
    end
    send(name, *args, **kwargs, &block)
  end

  def respond_to_missing?(name, include_private = false)
    return true if ::Shoes::Drawable.drawable_class_by_name(name.to_s)

    false
  end

  # Register a callback to be called when this slot is removed/destroyed.
  # In Shoes3, slot.finish { ... } is called when the slot is removed,
  # NOT after initialization. Use App#start for post-init callbacks.
  # Multiple finish handlers can be registered.
  def finish(&block)
    @finish_callbacks ||= []
    @finish_callbacks << block if block
  end

  # Fire all registered finish callbacks. Called when the slot is destroyed.
  def fire_finish_callbacks
    return unless @finish_callbacks

    @finish_callbacks.each { |cb| @app.instance_eval(&cb) }
  end

  # Override destroy to fire finish callbacks before actual destruction.
  # This matches Shoes3 behavior where finish is a removal/cleanup event.
  #
  # A Slot owns its children, so tearing it down must tear down the whole
  # subtree. The base Drawable#destroy only unhooks self; without cascading,
  # a cleared slot's descendants stay pinned in the class-level registry
  # (Shoes::Drawable @drawables_by_id) and keep their event subscriptions
  # alive — an unbounded leak for apps that rebuild via clear { ... }
  # (Clock, Pong, long-running dashboards). Children destroy first so each
  # detaches its own DOM node before this slot's removal.
  def destroy
    fire_finish_callbacks
    @children&.dup&.each(&:destroy)
    super
  end

  # Force a redraw of this slot and its contents.
  # In Shoes3, this is used after modifying styles that don't automatically
  # trigger a repaint, like gradients on backgrounds.
  #
  # @return [void]
  def refresh_slot
    send_shoes_event(event_name: "full_redraw_request")
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
    if block_given?
      append(&block)
      # After clear+rebuild, signal a full redraw to collapse all the individual
      # child add/remove DOM operations into one efficient replacement.
      # This is critical for animate { clear do ... end } patterns (Clock, Pong, etc.)
      send_shoes_event(event_name: "full_redraw_request")
    end
    nil
  end

  # Call the block to append new children to a Slot.
  #
  # Should only be called on a Slot, since only Slots can have children.
  #
  # In Shoes3 (Classic), append preserves the caller's self — the block
  # is called with block.call, NOT instance_eval. This matters for
  # non-Shoes callers (like HH::SideTab) that define methods and instance
  # variables that need to be reachable inside the block.
  #
  # When the caller is NOT a Shoes drawable, we use block.call to preserve
  # the original self and register the caller as an "external self" on the
  # App so that nested instance_eval'd blocks (inside flow/stack/etc.) can
  # fall back to the caller for unknown methods.
  #
  # @yield the block to call to append children to this Slot
  # @return [void]
  def append(&block)
    raise(Shoes::Errors::InvalidAttributeValueError, "append requires a block!") unless block_given?
    raise(Shoes::Errors::InvalidAttributeValueError, "Don't append to something that isn't a slot!") unless self.is_a?(Shoes::Slot)

    fill_with(block)
  end

  # Call the block to prepend new children to the beginning of a Slot.
  #
  # Should only be called on a Slot, since only Slots can have children.
  # Works like append, but inserts children at the beginning instead of the end,
  # in the order the block creates them.
  #
  # @yield the block to call to prepend children to this Slot
  # @return [void]
  def prepend(&block)
    raise(Shoes::Errors::InvalidAttributeValueError, "prepend requires a block!") unless block_given?
    raise(Shoes::Errors::InvalidAttributeValueError, "Don't prepend to something that isn't a slot!") unless self.is_a?(Shoes::Slot)

    insert_before(contents.first, block)
  end

  # Add the block's new children just before `drawable`, which must be a child of this slot.
  #
  # @param drawable [Shoes::Drawable] an existing child of this slot
  # @yield the block to call to add children
  # @return [Shoes::Slot] self
  def before(drawable, &block)
    raise(Shoes::Errors::InvalidAttributeValueError, "before requires a block!") unless block_given?

    insert_before(contents[index_of_child(drawable)], block)
    self
  end

  # Add the block's new children just after `drawable`, which must be a child of this slot.
  #
  # @param drawable [Shoes::Drawable] an existing child of this slot
  # @yield the block to call to add children
  # @return [Shoes::Slot] self
  def after(drawable, &block)
    raise(Shoes::Errors::InvalidAttributeValueError, "after requires a block!") unless block_given?

    insert_before(contents[index_of_child(drawable) + 1], block)
    self
  end

  private

  def index_of_child(drawable)
    contents.index(drawable) ||
      raise(Shoes::Errors::InvalidAttributeValueError, "#{drawable.inspect} is not a child of this slot!")
  end

  # A nil anchor appends at the end.
  def insert_before(anchor, block)
    outer_anchor = @insertion_anchor
    @insertion_anchor = anchor
    fill_with(block)
  ensure
    @insertion_anchor = outer_anchor
  end

  def fill_with(block)
    # Detect if the caller is external (non-Shoes) by checking the block's binding
    caller_self = begin
      eval("self", block.binding)
    rescue StandardError
      nil
    end

    if caller_self && !caller_self.is_a?(Shoes::Drawable)
      # Shoes3-compatible: preserve the caller's self and register as external
      @app.push_external_self(caller_self)
      @app.push_slot(self)
      begin
        block.call
      ensure
        @app.pop_slot
        @app.pop_external_self
      end
    else
      # Normal Shoes context: use instance_eval as before
      @app.with_slot(self, &block)
    end
  end
end
