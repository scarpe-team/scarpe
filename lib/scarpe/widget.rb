# frozen_string_literal: true

# Scarpe::Widget
#
# Interface:
# A Scarpe::Widget defines the "element" method to indicate that it has custom markup of
# some kind. A Widget with no element method renders as its children's markup, joined.

class Scarpe
  class Widget < DisplayService::Linkable
    include Scarpe::Log
    include Scarpe::Colors

    class << self
      attr_accessor :widget_classes, :alias_name

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

      private

      def linkable_properties
        @linkable_properties ||= []
      end

      def linkable_properties_hash
        @linkable_properties_hash ||= {}
      end

      public

      # Display properties in Shoes Linkables are automatically sync'd with the display side objects.
      # TODO: do we want types or other modifiers on specific properties?
      def display_property(name)
        name = name.to_s

        return if linkable_properties_hash[name]

        linkable_properties << { name: name }
        linkable_properties_hash[name] = true
      end

      def display_properties(*names)
        names.each { |n| display_property(n) }
      end

      def display_property_names
        linkable_properties.map { |prop| prop[:name] }
      end

      def display_property_name?(name)
        linkable_properties_hash[name.to_s]
      end
    end

    def initialize(*args, **kwargs)
      log_init("Widget")

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
      klass_name = self.class.name.delete_prefix("Scarpe::").delete_prefix("Shoes::")
      DisplayService.display_services.each do |display_service|
        # We SHOULD NOT save a reference to our display widget(s). If they just disappear later, we'll cheerfully
        # keep ticking along and not complain.
        display_service.create_display_widget_for(klass_name, self.linkable_id, display_properties)
      end
    end

    attr_reader :parent
    attr_reader :children

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
        @log.warn("remove_child: no such child(#{child.inspect}) for parent(#{parent.inspect})!")
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
end
