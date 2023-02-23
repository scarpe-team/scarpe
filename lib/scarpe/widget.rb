# frozen_string_literal: true

# Scarpe::Widget
#
# Interface:
# A Scarpe::Widget defines the "element" method to indicate that it has custom markup of
# some kind. A Widget with no element method renders as its children's markup, joined.

class Scarpe
  class Widget < DisplayService::Linkable
    class << self
      attr_accessor :widget_classes, :alias_name, :linkable_properties, :linkable_properties_hash

      def alias_as(name)
        self.alias_name = name
      end

      def inherited(subclass)
        self.widget_classes ||= []
        self.widget_classes << subclass
        super
      end

      def dsl_name
        n = name.split("::").last.chomp("Widget")
        n.gsub(/(.)([A-Z])/, '\1_\2').downcase
      end

      def widget_class_by_name(name)
        widget_classes.detect { |k| k.dsl_name == name.to_s || k.alias_name.to_s == name.to_s }
      end

      # Display properties in Shoes Linkables are automatically sync'd with the display side objects.
      # TODO: do we want types or other modifiers on specific properties?
      def display_property(name)
        name = name.to_s
        @linkable_properties ||=[]
        @linkable_properties << { name: name }
        @linkable_properties_hash ||= {}
        @linkable_properties_hash[name] = true
      end

      def display_properties(*names)
        names.each { |n| display_property(n) }
      end

      def display_property_names
        @linkable_properties.map { |prop| prop[:name] }
      end

      def display_property_name?(name)
        @linkable_properties_hash[name.to_s]
      end
    end

    def initialize(*args, **kwargs)
      self.class.display_property_names.each do |prop|
        if kwargs[prop.to_sym]
          instance_variable_set("@" + prop, kwargs[prop.to_sym])
        end
      end

      super() # Can specify linkable_id, but no reason to
    end

    def bind_self_event(event_name, &block)
      raise("Widget has no linkable_id! #{inspect}") unless linkable_id

      bind_display_event(event_name: event_name, target: linkable_id, &block)
    end

    def bind_no_target_event(event_name, &block)
      bind_display_event(event_name:, &block)
    end

    def display_properties
      properties = {}
      self.class.display_property_names.each do |prop|
        properties[prop] = instance_variable_get("@" + prop)
      end
      properties["shoes_linkable_id"] = self.linkable_id
      properties
    end

    def create_display_widget
      # We want to support multiple, or zero, display services later. Thus, we link via events and
      # DisplayService objects.
      DisplayService.display_services.each do |display_service|
        # We DO NOT save a reference to our display widget(s). If they just disappear later, we'll cheerfully
        # keep ticking along and not complain.
        display_service.create_display_widget_for(self, display_properties)
      end
    end

    attr_reader :parent

    def set_parent(new_parent)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
      send_shoes_event(new_parent.linkable_id, event_name: "parent", target: linkable_id)
    end

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
    end

    # Removes the element from the Scarpe::Widget tree
    def destroy
      @parent&.remove_child(self)
      send_shoes_event(event_name: "destroy", target: linkable_id)
    end

    alias_method :destroy_self, :destroy

    # We use method_missing for widget-creating methods like "button",
    # and also to auto-create display-property getters and setters.
    def method_missing(name, *args, **kwargs, &block)
      name_s = name.to_s

      if name_s[-1] == "="
        prop_name = name_s[0..-2]
        if self.class.display_property_name?(prop_name)
          self.class.define_method(name) do |new_value|
            raise "Trying to set display properties in an object with no linkable ID!" unless linkable_id

            instance_variable_set("@" + prop_name, new_value)
            send_shoes_event({ prop_name => new_value }, event_name: "prop_change", target: linkable_id)
          end

          return self.send(name, *args, **kwargs, &block)
        end
      end

      if self.class.display_property_name?(name_s)
        self.class.define_method(name) do
          raise "Trying to get display properties in an object with no linkable ID!" unless linkable_id

          instance_variable_get("@" + name_s)
        end

        return self.send(name, *args, **kwargs, &block)
      end

      klass = Widget.widget_class_by_name(name)
      return super unless klass

      ::Scarpe::Widget.define_method(name) do |*args, **kwargs, &block|
        # Look up the Shoes widget and create it...
        widget_instance = klass.new(*args, **kwargs, &block)

        unless klass.ancestors.include?(Scarpe::TextWidget)
          widget_instance.set_parent(self)
        end

        widget_instance
      end

      send(name, *args, **kwargs, &block)
    end

    def respond_to_missing?(name, include_private = false)
      name_s = name.to_s
      return true if self.class.display_property_name?(name_s)
      return true if self.class.display_property_name?(name_s[0..-2]) && name_s[-1] == "="
      return true if Widget.widget_class_by_name(name_s)

      super
    end
  end

  class WebviewWidget < DisplayService::Linkable
    class << self
      def display_class_for(scarpe_class)
        unless scarpe_class.ancestors.include?(Scarpe::DisplayService::Linkable)
          raise "Scarpe Webview can only get display classes for Scarpe linkable widgets, not #{scarpe_class.inspect}!"
        end

        klass = Scarpe.const_get("Webview" + scarpe_class.name.split("::")[-1])
        if klass.nil?
          raise "Couldn't find corresponding Scarpe Webview class for #{scarpe_class.inspect}!"
        end

        klass
      end
    end

    attr_reader :shoes_linkable_id
    attr_reader :parent

    def initialize(properties)
      # Call method, which looks up the parent
      @shoes_linkable_id = properties["shoes_linkable_id"]
      unless @shoes_linkable_id
        raise "Could not find property shoes_linkable_id in #{properties.inspect}!"
      end

      # Set the display properties
      properties.each do |k, v|
        next if k == "shoes_linkable_id"

        instance_variable_set("@" + k, v)
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

    # Removes the element from both the Ruby Widget tree and the HTML DOM
    def destroy_self
      html_element.remove
      @parent&.remove_child(self)
    end

    # In theory, this can record which specific widgets need update and only update them.
    # Right now we're not carefully tracking which widget made which changes, so it's not
    # really safe to do limited partial redraws. The performance isn't going to be a
    # problem until we have some larger apps.
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
