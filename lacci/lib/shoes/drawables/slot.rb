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

  # How far the slot can scroll: scroll_height minus the height it shows, and never
  # below zero (manual 2444-2451, Shoes 3 shoes_canvas_get_scroll_max). The slot
  # scrolls inside its margins.
  #
  # @return [Numeric] the largest scroll_top, in pixels
  def scroll_max
    [scroll_height - (border_box_at(:height) || height), 0].max
  end

  # The width of the scrollbar area, one of the slot position methods (manual 2394-2399).
  def gutter
    @app.gutter
  end

  # How far the slot is scrolled down, in pixels: 0 until it scrolls (manual 2455-2458).
  # A flow scrolls as a stack does; Hackety Hack's editor keeps its caret in view in one.
  #
  # @return [Integer]
  def scroll_top
    @scroll_top || 0
  end

  # Scroll the slot to top, which should lie between 0 and scroll_max (manual 2460-2463).
  def scroll_top=(top)
    @scroll_top = top.to_i
    send_self_event(top.to_i, event_name: "scroll_top")
  end

  # We use method_missing for drawable-creating methods like "button".
  # The parent's method_missing will auto-create Shoes style getters and setters.
  # This is similar to the method_missing in Shoes::App, but differs in where
  # the new drawable will appear: in this slot, or where a widget sends it (dsl_target).
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
      # its slot as the current one so that draw context
      # is handled properly.
      @app.with_slot(dsl_target) do
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
    ::Shoes::Drawable.drawable_class_by_name(name.to_s) ? true : super
  end

  # Run the block, handed this slot, the first time the slot is drawn (manual
  # 2286-2289, ledger H8). The display draws before its first heartbeat, so the
  # first heartbeat after this call is the moment. Like every Shoes block but the
  # app's, it keeps the self it was written with (ledger B1), as finish blocks do.
  #
  # @yield [slot] this slot
  # @return [self]
  def start(&block)
    (@start_callbacks ||= []) << block if block
    @waiting_to_start ||= bind_shoes_event(event_name: "heartbeat") { fire_start_callbacks }
    self
  end

  # Run the block, handed this slot, when the slot is removed: by remove, by its
  # parent's clear, or when its app goes (manual 2195-2198, ledger H8). It is not
  # called after initialization; use start for that. Several may be registered.
  #
  # @yield [slot] this slot
  # @return [self]
  def finish(&block)
    @finish_callbacks ||= []
    @finish_callbacks << block if block
    self
  end

  # Fire all registered finish callbacks. Called when the slot is destroyed.
  def fire_finish_callbacks
    return unless @finish_callbacks

    @finish_callbacks.each { |cb| cb.call(self) }
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

  private

  # A dispatch already under way can call this once more after it unsubscribed.
  def fire_start_callbacks
    unsub_shoes_event(@waiting_to_start) if @waiting_to_start
    @waiting_to_start = nil
    callbacks, @start_callbacks = @start_callbacks, []
    callbacks&.each { |cb| cb.call(self) }
  end

  # Where this slot's DSL calls put what they make: here. A widget sends them to the slot
  # it is building instead (Shoes::Widget#dsl_target).
  def dsl_target
    self
  end

  public

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
  # The slot's own event handlers and timers (hover, click, animate...) stay: they
  # belong to the slot, not to its contents. Shoes 3's clear empties the contents
  # only (s3_canvas.c:759-781), and the manual's hover/leave example (2167-2185)
  # clears the slot from inside those handlers.
  #
  # Should only be called on Slots, which can
  # have children. The block keeps its self, as append's does.
  #
  # @yield The block to call to replace the contents of the drawable (optional)
  # @return [self]
  def clear(&block)
    contents.each { |child| child.destroy unless child.is_a?(Shoes::SubscriptionItem) }
    if block_given?
      append(&block)
      # After clear+rebuild, signal a full redraw to collapse all the individual
      # child add/remove DOM operations into one efficient replacement.
      # This is critical for animate { clear do ... end } patterns (Clock, Pong, etc.)
      send_shoes_event(event_name: "full_redraw_request")
    end
    self
  end

  # Call the block to append new children to a Slot.
  #
  # Should only be called on a Slot, since only Slots can have children.
  #
  # The block keeps the caller's self, as in Shoes 3 (manual 322-324, ledger B1),
  # so a class like Hackety Hack's side tabs reaches its own methods and instance
  # variables inside it. A plain object's bare para then needs a way to the app
  # (manual 271-295): its own method_missing, or app { }.
  #
  # @yield the block to call to append children to this Slot
  # @return [self]
  def append(&block)
    raise(Shoes::Errors::InvalidAttributeValueError, "append requires a block!") unless block_given?
    raise(Shoes::Errors::InvalidAttributeValueError, "Don't append to something that isn't a slot!") unless self.is_a?(Shoes::Slot)

    fill_with(block)
    self
  end

  # Call the block to prepend new children to the beginning of a Slot.
  #
  # Should only be called on a Slot, since only Slots can have children.
  # Works like append, but inserts children at the beginning instead of the end,
  # in the order the block creates them.
  #
  # @yield the block to call to prepend children to this Slot
  # @return [self]
  def prepend(&block)
    raise(Shoes::Errors::InvalidAttributeValueError, "prepend requires a block!") unless block_given?
    raise(Shoes::Errors::InvalidAttributeValueError, "Don't prepend to something that isn't a slot!") unless self.is_a?(Shoes::Slot)

    insert_before(contents.first, block)
    self
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
    @app.with_slot(self, &block)
  end
end
