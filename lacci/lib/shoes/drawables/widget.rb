# frozen_string_literal: true

# A Shoes::Widget is mostly a Slot (related to the
# old Shoes concepts of Canvas) that creates drawables
# inside itself. When a subclass of Widget is created,
# it adds a method to create new objects of that type
# on Shoes::App and all Shoes slots.
#
# The hardest part with a Shoes::Widget is that it
# should work fine even if initialize() doesn't call
# super, which would make it hard to set up a Shoes
# linkable_id, create a display widget, etc.
#
# It would be possible to add an extra method to set
# these up and call it on every created drawable
# in case a Widget's initialize method doesn't call
# super, which happens quite often. But then we wouldn't
# support automatic setting of styles (e.g. padding)
# for the widget object itself, which is mostly a Flow.
# We also couldn't support default styles -- I can't tell
# whether Shoes supports these things either.
#
# But there's another way to do all of this. When a
# subclass of Widget defines an initialize method,
# we can catch the method_added hook, save a copy of
# that initialize method, and substitute our own
# initialize that calls super. We have to be a little
# careful -- if the widget's initialize *does* call
# super that shouldn't be an error. But that's
# workable by defining an extra method with the
# copied-method name that does nothing.

##### TODO: when this is subclassed, grab :initialize out
# of the subclass, put it into :initialize_widget, and
# replace with an initialize that creates the display
# widget propertly, sets the linkable_id, etc.

class Shoes::Widget < Shoes::Slot
  include Shoes::HasBackground

  shoes_events

  def self.inherited(subclass)
    super

    # Widgets are special - we can't know in advance what sort of initialize args they take
    subclass.init_args :any
  end

  def self.method_added(name)
    # We're only looking for the initialize() method, and only on subclasses
    # of Shoes::Widget, not Shoes::Widget itself.
    return if self == ::Shoes::Widget || name != :initialize

    # Need to avoid infinite adding of initialize() if we're re-adding the default initialize
    return if @midway_through_adding_initialize

    # Take the user-provided initialize method and save a copy named __widget_initialize
    alias_method :__widget_initialize, :initialize

    # And add the default initialize back where it belongs
    @midway_through_adding_initialize = true
    define_method(:initialize) do |*args, **kwargs, &block|
      # A widget's options are its own, as a Shoes 3 widget's were: the ones that are styles
      # (left, width, margin...) place it, and the rest (Hackety Hack's Glossb takes :color)
      # are for its initialize alone, not an "unexpected keyword" for Drawable.
      styles = kwargs.select { |key, _| self.class.shoes_style_name?(key) }
      super(*args, **styles, &block)
      @options = kwargs # Get rid of options?
      create_display_drawable
      __widget_initialize(*args, **kwargs, &block)

      # Note: We intentionally do NOT call @app.with_slot(self, &block) here.
      # Widget subclasses that want to use the block as slot content should
      # call @app.with_slot(self, &block) in their own initialize.
      # Many widgets (like Glossb, IconButton) use the block as a click handler
      # via `click &blk`, not as slot content. Auto-evaluating the block would
      # incorrectly execute click handlers during initialization.
    end
    @midway_through_adding_initialize = false
  end

  # A widget's slot blocks keep the widget as self (ledger B1), so inside them its pens,
  # start and finish, like its drawables, go to the slot being built (dsl_target).
  (Shoes::DrawContext::SETTINGS.map(&:to_sym) + %i[nofill nostroke start finish]).each do |name|
    define_method(name) do |*args, &blk|
      target = dsl_target
      if target.equal?(self) || !target.respond_to?(name)
        super(*args, &blk)
      else
        target.public_send(name, *args, &blk)
      end
    end
  end

  # What a widget lacks, its app may have: the shape commands (move_to, line_to...), mouse,
  # clipboard, window, visit. Shoes 3's widgets are canvases with the app's methods, and
  # Shoes 4's send what they miss to their app (s4_widget.rb).
  def method_missing(name, *args, **kwargs, &block)
    return super unless reaches_app?(name)

    @app.public_send(name, *args, **kwargs, &block)
  end

  def respond_to_missing?(name, include_private = false)
    super || reaches_app?(name)
  end

  private

  # Shoes 3 sends a widget's DSL calls to the slot being built while a slot block runs
  # (FUNC_M, s3_ruby.h:195-213): a stack the widget is building inside itself, or another
  # slot a widget method appends to, as Hackety Hack's turtle does. From the slot that holds
  # the widget, and between events, they land in the widget itself, where Shoes 3 would send
  # calls made during the app block to the app's top slot.
  def dsl_target
    slot = @app.current_slot
    return self if @app.editing_depth.zero? || slot.nil? || slot.equal?(self) || inside?(slot)

    slot
  end

  # Whether this widget sits somewhere in slot.
  def inside?(slot)
    holder = parent
    holder = holder.parent until holder.nil? || holder.equal?(slot)
    !holder.nil?
  end

  def reaches_app?(name)
    return false if Shoes::Drawable.drawable_class_by_name(name)
    return false if self.class.shoes_style_name?(name.to_s.delete_suffix("="))

    @app ? @app.respond_to?(name) : false
  end
end
