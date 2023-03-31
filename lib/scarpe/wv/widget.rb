# frozen_string_literal: true

class Scarpe
  class WebviewWidget < DisplayService::Linkable
    class << self
      def display_class_for(scarpe_class_name)
        scarpe_class = Scarpe.const_get(scarpe_class_name)
        unless scarpe_class.ancestors.include?(Scarpe::DisplayService::Linkable)
          raise "Scarpe Webview can only get display classes for Scarpe " +
            "linkable widgets, not #{scarpe_class_name.inspect}!"
        end

        klass = Scarpe.const_get("Webview" + scarpe_class_name.split("::")[-1])
        if klass.nil?
          raise "Couldn't find corresponding Scarpe Webview class for #{scarpe_class_name.inspect}!"
        end

        klass
      end
    end

    attr_reader :shoes_linkable_id
    attr_reader :parent
    attr_reader :children

    def initialize(properties)
      # Call method, which looks up the parent
      @shoes_linkable_id = properties["shoes_linkable_id"] || properties[:shoes_linkable_id]
      unless @shoes_linkable_id
        raise "Could not find property shoes_linkable_id in #{properties.inspect}!"
      end

      # Set the display properties
      properties.each do |k, v|
        next if k == "shoes_linkable_id"

        instance_variable_set("@" + k.to_s, v)
      end

      # The parent field is *almost* simple enough that a typed display property would handle it.
      bind_shoes_event(event_name: "parent", target: shoes_linkable_id) do |new_parent_id|
        display_parent = WebviewDisplayService.instance.query_display_widget_for(new_parent_id)
        if @parent != display_parent
          set_parent(display_parent)
        end
      end

      # When Shoes widgets change properties, we get a change notification here
      bind_shoes_event(event_name: "prop_change", target: shoes_linkable_id) do |prop_changes|
        prop_changes.each do |k, v|
          instance_variable_set("@" + k, v)
        end
        properties_changed(prop_changes)
      end

      bind_shoes_event(event_name: "destroy", target: shoes_linkable_id) do
        destroy_self
      end

      super()
    end

    # This exists to be overridden by children watching for changes
    def properties_changed(changes)
      needs_update! unless changes.empty?
    end

    def set_parent(new_parent)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
    end

    protected

    # Do not call directly, use set_parent
    def remove_child(child)
      @children ||= []
      unless @children.include?(child)
        puts "remove_child: no such child(#{child.inspect}) for parent(#{parent.inspect})!"
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

    # This gets a mini-webview for just this element and its children, if any
    def html_element
      @elt_wrangler ||= WebviewDisplayService.instance.doc_root.get_element_wrangler(html_id)
    end

    # Return a promise that guarantees all currently-requested changes have completed
    def promise_update
      html_element.promise_update
    end

    def html_id
      object_id.to_s
    end

    # to_html is intended to get the HTML DOM rendering of this object and its children.
    # Calling it should be side-effect-free and NOT update the webview.
    def to_html
      @children ||= []
      child_markup = @children.map(&:to_html).join
      if respond_to?(:element)
        element { child_markup }
      else
        child_markup
      end
    end

    # This binds a Scarpe JS callback, handled via a single dispatch point in the document root
    def bind(event, &block)
      raise("Widget has no linkable_id! #{inspect}") unless linkable_id

      WebviewDisplayService.instance.doc_root.bind("#{linkable_id}-#{event}", &block)
    end

    # Removes the element from both the Ruby Widget tree and the HTML DOM.
    # Return a promise for when that HTML change will be visible.
    def destroy_self
      @parent&.remove_child(self)
      html_element.remove
    end

    # It's really hard to do dirty-tracking here because the redraws are fully asynchronous.
    # And so we can't easily cancel one "in flight," and we can't easily pick up the latest
    # changes... And we probably don't want to, because we may be halfway through a batch.
    def needs_update!
      return if @dirty # Already dirty - nothing changed, so do nothing

      @dirty = true
      WebviewDisplayService.instance.doc_root.request_redraw!
    end

    # When we do an update, we need to not redraw until we see another change
    def clear_needs_update!
      @dirty = false
      @children.each(&:clear_needs_update!)
    end

    def handler_js_code(handler_function_name, *args)
      raise("Widget has no linkable_id! #{inspect}") unless linkable_id

      js_args = ["'#{linkable_id}-#{handler_function_name}'", *args].join(", ")
      "scarpeHandler(#{js_args})"
    end
  end
end
