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
      super(*args, **kwargs, &block)
      @options = kwargs # Get rid of options?
      create_display_drawable
      __widget_initialize(*args, **kwargs, &block)

      # Do Widgets do this?
      @app.with_slot(self, &block) if block
    end
    @midway_through_adding_initialize = false
  end
end
