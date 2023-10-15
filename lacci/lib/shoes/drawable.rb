# frozen_string_literal: true

module Shoes
  # Shoes::Drawable
  #
  # This is the display-service portable Shoes Drawable interface. Visible Shoes
  # drawables like buttons inherit from this. Compound drawables made of multiple
  # different smaller Drawables inherit from it in their various apps or libraries.
  # The Shoes Drawable helps build a Shoes-side drawable tree, with parents and
  # children. Any API that applies to all drawables (e.g. remove) should be
  # defined here.
  #
  class Drawable < Shoes::Linkable
    include Shoes::Log
    include Shoes::Colors

    class << self
      attr_accessor :drawable_classes
      attr_accessor :drawable_default_styles
      attr_accessor :widget_classes

      def inherited(subclass)
        Shoes::Drawable.drawable_classes ||= []
        Shoes::Drawable.drawable_classes << subclass

        Shoes::Drawable.drawable_default_styles ||= {}
        Shoes::Drawable.drawable_default_styles[subclass] = {}

        Shoes::Drawable.widget_classes ||= []
        if subclass < Shoes::Widget
          Shoes::Drawable.widget_classes << subclass.name
        end

        super
      end

      def dsl_name
        n = name.split("::").last.chomp("Drawable")
        n.gsub(/(.)([A-Z])/, '\1_\2').downcase
      end

      def drawable_class_by_name(name)
        drawable_classes.detect { |k| k.dsl_name == name.to_s }
      end

      def is_widget_class?(name)
        !(Shoes::Drawable.widget_classes & [name.to_s]).empty?
      end

      def validate_as(prop_name, value)
        prop_name = prop_name.to_s
        hashes = shoes_style_hashes

        h = hashes.detect { |hash| hash[:name] == prop_name }
        raise(Shoes::NoSuchStyleError, "Can't find property #{prop_name.inspect} in #{self} property list: #{hashes.inspect}!") unless h

        return value if h[:validator].nil?
        h[:validator].call(value)
      end

      private

      def linkable_properties
        @linkable_properties ||= []
      end

      def linkable_properties_hash
        @linkable_properties_hash ||= {}
      end

      public

      # Shoes styles in Shoes Linkables are automatically sync'd with the display side objects.
      # If a block is passed to shoes_style, that's the validation for the property. It should
      # convert a given value to a valid value for the property or throw an exception.
      def shoes_style(name, &validator)
        name = name.to_s

        return if linkable_properties_hash[name]

        linkable_properties << { name: name, validator: }
        linkable_properties_hash[name] = true
      end

      # Add these names as Shoes styles
      def shoes_styles(*names)
        names.each { |n| shoes_style(n) }
      end

      def shoes_style_names
        parent_prop_names = self != Shoes::Drawable ? self.superclass.shoes_style_names : []

        parent_prop_names | linkable_properties.map { |prop| prop[:name] }
      end

      def shoes_style_hashes
        parent_hashes = self != Shoes::Drawable ? self.superclass.shoes_style_hashes : []

        parent_hashes + linkable_properties
      end

      def shoes_style_name?(name)
        linkable_properties_hash[name.to_s] ||
          (self != Shoes::Drawable && superclass.shoes_style_name?(name))
      end
    end

    # Shoes uses a "hidden" style property for hide/show
    shoes_style :hidden

    def initialize(*args, **kwargs)
      log_init("Shoes::#{self.class.name}")

      default_styles = Shoes::Drawable.drawable_default_styles[self.class]

      self.class.shoes_style_names.each do |prop|
        prop_sym = prop.to_sym
        if kwargs.key?(prop_sym)
          val = self.class.validate_as(prop, kwargs[prop_sym])
          instance_variable_set("@" + prop, val)
        elsif default_styles.key?(prop_sym)
          val = self.class.validate_as(prop, default_styles[prop_sym])
          instance_variable_set("@" + prop, val)
        end
      end

      super() # linkable_id defaults to object_id
    end

    def inspect
      "#<#{self.class}:#{self.object_id} " +
        "@linkable_id=#{@linkable_id.inspect} @parent=#{@parent.inspect} " +
        "@children=#{@children.inspect} properties=#{shoes_style_values.inspect}>"
    end

    private

    def bind_self_event(event_name, &block)
      raise(Shoes::NoLinkableIdError, "Drawable has no linkable_id! #{inspect}") unless linkable_id

      bind_shoes_event(event_name: event_name, target: linkable_id, &block)
    end

    def bind_no_target_event(event_name, &block)
      bind_shoes_event(event_name:, &block)
    end

    public

    def shoes_style_values
      all_property_names = self.class.shoes_style_names

      properties = {}
      all_property_names.each do |prop|
        properties[prop] = instance_variable_get("@" + prop)
      end
      properties["shoes_linkable_id"] = self.linkable_id
      properties
    end

    def style(*args, **kwargs)
      if args.empty? && kwargs.empty?
        # Just called as .style()
        shoes_style_values
      elsif args.empty?
        # This is called to set one or more Shoes styles
        prop_names = self.class.shoes_style_names
        unknown_styles = kwargs.keys.select { |k| !prop_names.include?(k.to_s) }
        unless unknown_styles.empty?
          raise Shoes::NoSuchStyleError, "Unknown styles for drawable type #{self.class.name}: #{unknown_styles.join(", ")}"
        end

        kwargs.each do |name, val|
          instance_variable_set("@#{name}", val)
        end
      elsif args.length == 1 && args[0] < Shoes::Drawable
        # Shoes supports calling .style with a Shoes class, e.g. .style(Shoes::Button, displace_left: 5)
        kwargs.each do |name, val|
          Shoes::Drawable.drawable_default_styles[args[0]][name.to_sym] = val
        end
      else
        raise Shoes::InvalidAttributeValueError, "Unexpected arguments to style! args: #{args.inspect}, keyword args: #{kwargs.inspect}"
      end
    end

    private

    def create_display_drawable
      klass_name = self.class.name.delete_prefix("Scarpe::").delete_prefix("Shoes::")

      is_widget = Shoes::Drawable.is_widget_class?(klass_name)

      # Should we send an event so this can be discovered from someplace other than
      # the DisplayService?
      ::Shoes::DisplayService.display_service.create_display_drawable_for(klass_name, self.linkable_id, shoes_style_values, is_widget:)
    end

    public

    attr_reader :parent

    def set_parent(new_parent)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
      send_shoes_event(new_parent.linkable_id, event_name: "parent", target: linkable_id)
    end

    # Removes the element from the Shoes::Drawable tree
    def destroy
      @parent&.remove_child(self)
      send_shoes_event(event_name: "destroy", target: linkable_id)
    end
    alias_method :remove, :destroy

    # Hide the drawable.
    def hide
      self.hidden = true
    end

    # Show the drawable.
    def show
      self.hidden = false
    end

    # Hide the drawable if it is currently shown. Show it if it is currently hidden.
    def toggle
      self.hidden = !self.hidden
    end

    # We use method_missing to auto-create Shoes style getters and setters.
    def method_missing(name, *args, **kwargs, &block)
      name_s = name.to_s

      if name_s[-1] == "="
        prop_name = name_s[0..-2]
        if self.class.shoes_style_name?(prop_name)
          self.class.define_method(name) do |new_value|
            raise(Shoes::NoLinkableIdError, "Trying to set Shoes styles in an object with no linkable ID! #{inspect}") unless linkable_id

            new_value = self.class.validate_as(prop_name, new_value)
            instance_variable_set("@" + prop_name, new_value)
            send_shoes_event({ prop_name => new_value }, event_name: "prop_change", target: linkable_id)
          end

          return self.send(name, *args, **kwargs, &block)
        end
      end

      if self.class.shoes_style_name?(name_s)
        self.class.define_method(name) do
          raise(Shoes::NoLinkableIdError, "Trying to get Shoes styles in an object with no linkable ID! #{inspect}") unless linkable_id

          instance_variable_get("@" + name_s)
        end

        return self.send(name, *args, **kwargs, &block)
      end

      super(name, *args, **kwargs, &block)
    end

    def respond_to_missing?(name, include_private = false)
      name_s = name.to_s
      return true if self.class.shoes_style_name?(name_s)
      return true if self.class.shoes_style_name?(name_s[0..-2]) && name_s[-1] == "="
      return true if Drawable.drawable_class_by_name(name_s)

      super
    end
  end
end
