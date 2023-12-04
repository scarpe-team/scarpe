# frozen_string_literal: true

class Shoes
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

    # All Drawables have these so they go in Shoes::Drawable and are inherited
    @shoes_events = ["parent", "destroy", "prop_change"]

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
        !!Shoes::Drawable.widget_classes.intersect?([name.to_s])
      end

      def validate_as(prop_name, value)
        prop_name = prop_name.to_s
        hashes = shoes_style_hashes

        h = hashes.detect { |hash| hash[:name] == prop_name }
        raise(Shoes::Errors::NoSuchStyleError, "Can't find property #{prop_name.inspect} in #{self} property list: #{hashes.inspect}!") unless h

        return value if h[:validator].nil?

        h[:validator].call(value)
      end

      # Return a list of Shoes events for this class.
      #
      # @return Array[String] the list of event names
      def get_shoes_events
        if @shoes_events.nil?
          raise UnknownEventsForClass, "Drawable type #{self.class} hasn't defined its list of Shoes events!"
        end

        @shoes_events
      end

      # Set the list of Shoes event names that are allowed for this class.
      #
      # @param args [Array] an array of event names, which will be coerced to Strings
      # @return [void]
      def shoes_events(*args)
        @shoes_events ||= args.map(&:to_s) + self.superclass.get_shoes_events
      end

      # Assign a new Shoes Drawable ID number, starting from 1.
      # This allows non-overlapping small integer IDs for Shoes
      # linkable IDs - the number part of making it clear what
      # widget you're talking about.
      def allocate_drawable_id
        @drawable_id_counter ||= 0
        @drawable_id_counter += 1
        @drawable_id_counter
      end

      def register_drawable_id(id, drawable)
        @drawables_by_id ||= {}
        @drawables_by_id[id] = drawable
      end

      def unregister_drawable_id(id)
        @drawables_by_id ||= {}
        @drawables_by_id.delete(id)
      end

      def drawable_by_id(id, none_ok: false)
        val = @drawables_by_id[id]
        unless val || none_ok
          raise "No Drawable Found! #{@drawables_by_id.inspect}"
        end

        val
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

    attr_reader :debug_id

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

      super(linkable_id: Shoes::Drawable.allocate_drawable_id)
      Shoes::Drawable.register_drawable_id(self.linkable_id, self)

      generate_debug_id
    end

    # Calling stack.app or drawable.app will execute the block
    # with the Shoes::App as self, and with that stack or
    # flow as the current slot.
    #
    # @incompatibility In Shoes Classic this is the only way
    #   to change self, while Scarpe will also change self
    #   with the other Slot Manipulation methods: #clear,
    #   #append, #prepend, #before and #after.
    #
    # @return [Shoes::App] the Shoes app
    # @yield the block to call with the Shoes App as self
    def app(&block)
      Shoes::App.instance.with_slot(self, &block) if block_given?
      Shoes::App.instance
    end

    private

    def generate_debug_id
      cl = caller_locations(3)
      da = cl.detect { |loc| !loc.path.include?("lacci/lib/shoes") }
      @drawable_defined_at = "#{File.basename(da.path)}:#{da.lineno}"

      class_name = self.class.name.split("::")[-1]

      @debug_id = "#{class_name}##{@linkable_id}(#{@drawable_defined_at})"
    end

    public

    def inspect
      "#<#{debug_id} " +
        " @parent=#{@parent ? @parent.debug_id : "(none)"} " +
        "@children=#{@children ? @children.map(&:debug_id) : "(none)"} properties=#{shoes_style_values.inspect}>"
    end

    private

    def validate_event_name(event_name)
      unless self.class.get_shoes_events.include?(event_name.to_s)
        raise Shoes::UnregisteredShoesEvent, "Drawable #{self.inspect} tried to bind Shoes event #{event_name}, which is not in #{evetns.inspect}!"
      end
    end

    def bind_self_event(event_name, &block)
      raise(Shoes::Errors::NoLinkableIdError, "Drawable has no linkable_id! #{inspect}") unless linkable_id

      validate_event_name(event_name)

      bind_shoes_event(event_name: event_name, target: linkable_id, &block)
    end

    def bind_no_target_event(event_name, &block)
      validate_event_name(event_name)

      bind_shoes_event(event_name:, &block)
    end

    public

    def event(event_name, *args, **kwargs)
      validate_event_name(event_name)

      send_shoes_event(*args, **kwargs, event_name:, target: linkable_id)
    end

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
          raise Shoes::Errors::NoSuchStyleError, "Unknown styles for drawable type #{self.class.name}: #{unknown_styles.join(", ")}"
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
        raise Shoes::Errors::InvalidAttributeValueError, "Unexpected arguments to style! args: #{args.inspect}, keyword args: #{kwargs.inspect}"
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
    attr_reader :destroyed

    def set_parent(new_parent)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
      send_shoes_event(new_parent.linkable_id, event_name: "parent", target: linkable_id)
    end

    # Removes the element from the Shoes::Drawable tree and removes all event subscriptions
    def destroy
      @parent&.remove_child(self)
      @parent = nil
      @destroyed = true
      unsub_all_shoes_events
      send_shoes_event(event_name: "destroy", target: linkable_id)
      Shoes::Drawable.unregister_drawable_id(linkable_id)
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
            raise(Shoes::Errors::NoLinkableIdError, "Trying to set Shoes styles in an object with no linkable ID! #{inspect}") unless linkable_id

            new_value = self.class.validate_as(prop_name, new_value)
            instance_variable_set("@" + prop_name, new_value)
            send_shoes_event({ prop_name => new_value }, event_name: "prop_change", target: linkable_id)
          end

          return self.send(name, *args, **kwargs, &block)
        end
      end

      if self.class.shoes_style_name?(name_s)
        self.class.define_method(name) do
          raise(Shoes::Errors::NoLinkableIdError, "Trying to get Shoes styles in an object with no linkable ID! #{inspect}") unless linkable_id

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
