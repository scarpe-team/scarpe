# frozen_string_literal: true

module Scarpe::Webview
  # The Webview::Drawable parent class helps connect a Webview drawable with
  # its Shoes equivalent, render itself to the Webview DOM, handle
  # Javascript events and generally keep things working in Webview.
  class Drawable < Shoes::Linkable
    # This will pick up the log implementation from wv.rb
    include Shoes::Log

    class << self
      # Return the corresponding Webview class for a particular Shoes class name
      def display_class_for(scarpe_class_name)
        scarpe_class = Shoes.const_get(scarpe_class_name)
        unless scarpe_class.ancestors.include?(Shoes::Linkable)
          raise Scarpe::InvalidClassError, "Scarpe Webview can only get display classes for Shoes " +
            "linkable drawables, not #{scarpe_class_name.inspect}!"
        end

        klass = Scarpe::Webview.const_get(scarpe_class_name.split("::")[-1])
        if klass.nil?
          raise Scarpe::MissingClassError, "Couldn't find corresponding Scarpe Webview class for #{scarpe_class_name.inspect}!"
        end

        klass
      end
    end

    # The Shoes ID corresponding to the Shoes drawable for this Webview drawable
    attr_reader :shoes_linkable_id

    # The Webview::Drawable parent of this drawable
    attr_reader :parent

    # An array of Webview::Drawable children (possibly empty) of this drawable
    attr_reader :children

    # Set instance variables for the Shoes styles of this drawable. Bind Shoes
    # events for changes of parent drawable and changes of property values.
    def initialize(properties)
      log_init("Webview::Drawable")

      @shoes_style_names = properties.keys.map(&:to_s) - ["shoes_linkable_id"]

      @shoes_linkable_id = properties["shoes_linkable_id"] || properties[:shoes_linkable_id]
      unless @shoes_linkable_id
        raise Scarpe::MissingAttributeError, "Could not find property shoes_linkable_id in #{properties.inspect}!"
      end

      # Set the Shoes styles as instance variables
      properties.each do |k, v|
        next if k == "shoes_linkable_id"

        instance_variable_set("@" + k.to_s, v)
      end

      # Must call this before bind
      super(linkable_id: @shoes_linkable_id)

      # This will only be used if moving a drawable from one parent to another.
      # Shoes doesn't normally do that.
      bind_shoes_event(event_name: "parent", target: shoes_linkable_id) do |new_parent_id|
        display_parent = DisplayService.instance.query_display_drawable_for(new_parent_id)
        if @parent != display_parent
          set_parent(display_parent)
        end
      end

      # When Shoes drawables change properties, we get a change notification here
      bind_shoes_event(event_name: "prop_change", target: shoes_linkable_id) do |prop_changes|
        prop_changes.each do |k, v|
          instance_variable_set("@" + k, v)
        end
        properties_changed(prop_changes)
      end

      bind_shoes_event(event_name: "destroy", target: shoes_linkable_id) do
        destroy_self
      end
    end

    def shoes_styles
      p = {}
      @shoes_style_names.each do |prop_name|
        p[prop_name] = instance_variable_get("@#{prop_name}")
      end
      p
    end

    # Properties_changed will be called automatically when properties change.
    # The drawable should delete any changes from the Hash that it knows how
    # to incrementally handle, and pass the rest to super. If any changes
    # go entirely un-handled, a full redraw will be scheduled.
    # This exists to be overridden by children watching for changes.
    #
    # @param changes [Hash] a Hash of new values for properties that have changed
    def properties_changed(changes)
      # If a drawable does something really nonstandard with its html_id or element, it will
      # need to override to prevent this from happening. That's easy enough, though.
      if changes.key?("hidden")
        hidden = changes.delete("hidden")
        if hidden
          html_element.set_style("display", "none")
        else
          # With Calzini we can't easily tell what the display property should be.
          # Could be flex or inline, not only block or none. Re-render this drawable.
          needs_update!
        end
      end

      needs_update! unless changes.empty?
    end

    # Give this drawable a new parent, including managing the appropriate child lists for parent drawables.
    def set_parent(new_parent)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
    end

    # A shorter inspect text for prettier irb output
    def inspect
      "#<#{self.class}:#{self.object_id} @shoes_linkable_id=#{@shoes_linkable_id} @children=#{@children.inspect}>"
    end

    protected

    # Do not call directly, use set_parent
    def remove_child(child)
      @children ||= []
      unless @children.include?(child)
        @log.error("remove_child: no such child(#{child.inspect}) for"\
          " parent(#{parent.inspect})!")
      end
      @children.delete(child)
    end

    # Do not call directly, use set_parent
    def add_child(child)
      @children ||= []
      @children << child

      # If we add a child, we should redraw ourselves
      needs_update!
    end

    public

    # This gets an accessor for just this element's HTML ID.
    # It is normally called by the drawable itself to do its DOM management.
    # Drawables are required to use their html_id for their outermost element,
    # to make sure that remove(), hidden() etc. affect every part of the drawable.
    #
    # @return [Scarpe::WebWrangler::ElementWrangler] a DOM object manager
    def html_element
      @elt_wrangler ||= Scarpe::Webview::WebWrangler::ElementWrangler.new(html_id:)
    end

    # Return a promise that guarantees all currently-requested changes have completed
    #
    # @return [Scarpe::Promise] a promise that will be fulfilled when all pending changes have finished
    def promise_update
      # Doesn't matter what ElementWrangler we use -- they all return an update promise
      # that includes all pending updates, no matter who they're for.
      html_element.promise_update
    end

    # Get the object's HTML ID
    #
    # @return [String] the HTML ID
    def html_id
      @linkable_id.to_s
    end

    # to_html is intended to get the HTML DOM rendering of this object and its children.
    # Calling it should be side-effect-free and NOT update the webview.
    #
    # @return [String] the rendered HTML
    def to_html
      @children ||= []
      child_markup = @children.map(&:to_html).join
      element { child_markup }
    end

    # This binds a Scarpe JS callback, handled via a single dispatch point in the app
    #
    # @param event [String] the Scarpe drawable event name
    # @yield the block to call when the event occurs
    def bind(event, &block)
      raise(Scarpe::MissingAttributeError, "Drawable has no linkable_id! #{inspect}") unless linkable_id

      DisplayService.instance.app.bind("#{linkable_id}-#{event}", &block)
    end

    # Removes the element from both the Ruby Drawable tree and the HTML DOM.
    # Unsubscribe from all Shoes events.
    # Return a promise for when that HTML change will be visible.
    #
    # @return [Scarpe::Promise] a promise that is fulfilled when the HTML change is complete
    def destroy_self
      @parent&.remove_child(self)
      unsub_all_shoes_events
      html_element.remove
    end

    # Request a full redraw of the entire window, including the entire tree of
    # drawables and the outer "empty page" frame.
    #
    # @return [void]
    def full_window_redraw!
      DisplayService.instance.app.request_redraw!
    end

    # Request a full redraw of this drawable, including all its children.
    # Can be overridden in drawable subclasses if needed. An override would normally
    # only be needed if re-rendering the element with the given html_id
    # wasn't enough (and then remove would also need to be overridden.)
    #
    # This occurs by default if a property is changed and the drawable
    # doesn't remove its change in property_changed.
    #
    # @return [void]
    def needs_update!
      html_element.outer_html = to_html
    end

    # Generate JS code to trigger a specific event name on this drawable with the supplies arguments.
    #
    # @param handler_function_name [String] the event name - @see #bind
    # @param args [Array] additional arguments that will be passed to the event in the generated JS
    # @return [String] the generated JS code
    def handler_js_code(handler_function_name, *args)
      raise(Scarpe::MissingAttributeError, "Drawable has no linkable_id! #{inspect}") unless linkable_id

      js_args = ["'#{linkable_id}-#{handler_function_name}'", *args].join(", ")
      "scarpeHandler(#{js_args})"
    end
  end
end
