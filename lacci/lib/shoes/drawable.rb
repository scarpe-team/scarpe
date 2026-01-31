# frozen_string_literal: true
require_relative 'margin_helper'
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
    @shoes_events = ["parent", "destroy", "prop_change", "hover", "leave", "motion"]

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
        name = name.to_s
        drawable_classes.detect { |k| k.dsl_name == name }
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

        # Pass both the property name and value to the validator block
        h[:validator].call(value,prop_name)
      end

      # Return a list of Shoes events for this class.
      #
      # @return Array[String] the list of event names
      def get_shoes_events
        if @shoes_events.nil?
          raise Shoes::Errors::UnknownEventsForClassError, "Drawable type #{self} hasn't defined its list of Shoes events!"
        end

        @shoes_events
      end

      # Return whether Shoes events have already been registered for this class
      #
      # @return [Boolean] true if events have been registered, false if not
      def registered_shoes_events?
        !@shoes_events.nil?
      end

      # Set the list of Shoes event names that are allowed for this class.
      #
      # @param args [Array] an array of event names, which will be coerced to Strings
      # @return [void]
      def shoes_events(*args)
        if @shoes_events
          raise Shoes::Errors::DoubleRegisteredShoesEventError, "Registering shoes events #{args.inspect} for class #{self} but already registered events as #{@shoes_events.inspect}!"
        end
        @shoes_events = args.map(&:to_s) + self.superclass.get_shoes_events
      end

      # Require supplying these Shoes style values as positional arguments to
      # initialize. Initialize will get the arg list, then set the specified styles
      # if args are given for them. @see opt_init_args for additional non-required
      # init args.
      #
      # @param args [Array<String,Symbol>] an array of Shoes style names
      # @return [void]
      def init_args(*args)
        raise Shoes::Errors::BadArgumentListError, "Positional init args already set for #{self}!" if @required_init_args
        @required_init_args = args.map(&:to_s)
      end

      # Allow supplying these Shoes style values as optional positional arguments to
      # initialize after the mandatory args. @see init_args for setting required
      # init args.
      #
      # @param args [Array<String,Symbol>] an array of Shoes style names
      # @return [void]
      def opt_init_args(*args)
        raise Shoes::Errors::BadArgumentListError, "Positional init args already set for #{self}!" if @opt_init_args
        @opt_init_args = args.map(&:to_s)
      end

      # Return the list of style names for required init args for this class
      #
      # @return [Array<String>] the array of style names as strings
      def required_init_args
        @required_init_args ||= [] # TODO: eventually remove the ||= here
      end

      # Return the list of style names for optional init args for this class
      #
      # @return [Array<String>] the array of style names as strings
      def optional_init_args
        @opt_init_args ||= []
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
      #
      # If feature is non-nil, it's the feature that an app must request in order to see this
      # property.
      #
      # @param name [String,Symbol] the style name
      # @param feature [Symbol,NilClass] the feature that must be defined for an app to request this style, or nil
      # @block if block is given, call it to map the given style value to a valid value, or raise an exception
      def shoes_style(name, feature: nil, &validator)
        name = name.to_s

        return if linkable_properties_hash[name]

        linkable_properties << { name: name, validator:, feature: }
        linkable_properties_hash[name] = true
      end

      # Add these names as Shoes styles with the given validator and feature, if any
      def shoes_styles(*names, feature: nil, &validator)
        names.each { |n| shoes_style(n, feature:, &validator) }
      end

      # Query what feature, if any, is required to use a specific shoes_style.
      # If no specific feature is needed, nil will be returned.
      def feature_for_shoes_style(style_name)
        style_name = style_name.to_s
        lp = linkable_properties.detect { |prop| prop[:name] == style_name }
        return lp[:feature] if lp

        # If we get to the top of the superclass tree and we didn't find it, it's not here
        if self.class == ::Shoes::Drawable
          raise Shoes::Errors::NoSuchStyleError, "Can't find information for style #{style_name.inspect}!"
        end

        super
      end

      # Return a list of shoes_style names with the given features. If with_features is nil,
      # return them with a list of features for the current Shoes::App. For the list of
      # styles available with no features requested, pass nil to with_features.
      def shoes_style_names(with_features: nil)
        # No with_features given? Use the ones requested by this Shoes::App
        with_features ||= (@app&.features || [])
        parent_prop_names = self != Shoes::Drawable ? self.superclass.shoes_style_names(with_features:) : []

        if with_features == :all
          subclass_props = linkable_properties
        else
          subclass_props = linkable_properties.select { |prop| !prop[:feature] || with_features.include?(prop[:feature]) }
        end
        parent_prop_names | subclass_props.map { |prop| prop[:name] }
      end

      def shoes_style_hashes
        parent_hashes = self != Shoes::Drawable ? self.superclass.shoes_style_hashes : []

        parent_hashes + linkable_properties
      end

      def shoes_style_name?(name)
        linkable_properties_hash[name.to_s] ||
          (self != Shoes::Drawable && superclass.shoes_style_name?(name))
      end

      # Current_app is set every time a drawable is created - we don't want to keep a default
      # long because it's possible for apps to alternate who is creating. So make sure it's
      # not kept long, and used up when used once.

      def with_current_app(app)
        old_cur_app = @current_app
        @current_app = app
        ret = yield
        @current_app = old_cur_app
        ret
      end

      def use_current_app
        cur_app = @current_app
        @current_app = nil
        cur_app
      end
    end

    # Every Shoes drawable has positioning properties
    shoes_styles :top, :left, :width, :height

    # Margins around drawable
    shoes_styles :margin, :margin_top, :margin_bottom, :margin_left, :margin_right

    # Padding around drawable
    shoes_styles :padding, :padding_top, :padding_bottom, :padding_left, :padding_right

    # Shoes uses a "hidden" style property for hide/show
    shoes_style :hidden

    # Displace moves the drawable visually without affecting layout
    shoes_styles :displace_left, :displace_top

    # CSS cursor style for this drawable
    shoes_style :cursor

    # Tooltip text shown on hover (HTML title attribute)
    shoes_style :tooltip

    attr_reader :debug_id

    # These styles can be set to a current per-slot value and inherited from parent slots.
    # Their value is set at drawable-create time.
    DRAW_CONTEXT_STYLES = [:fill, :stroke, :strokewidth, :rotate, :transform, :translate]

    include MarginHelper

    def initialize(*args, **kwargs)
      kwargs = margin_parse(kwargs)
      log_init("Shoes::#{self.class.name}") unless @log

      # Grab the current app, mark it as used
      @app = self.is_a?(Shoes::App) ? self : Drawable.use_current_app

      # First, get the list of allowed and disallowed styles for the given features
      # and make sure no disallowed styles were given.

      app_features = @app.features
      this_app_styles = self.class.shoes_style_names(with_features: @app.features).map(&:to_sym)
      not_this_app_styles = self.class.shoes_style_names(with_features: :all).map(&:to_sym) - this_app_styles

      bad_styles = kwargs.keys & not_this_app_styles
      unless bad_styles.empty?
        features_needed = bad_styles.map { |s| self.class.feature_for_shoes_style(s) }.uniq
        raise Shoes::Errors::UnsupportedFeatureError, "The style(s) #{bad_styles.inspect} are only defined for applications that request specific features: #{features_needed.inspect} (you requested #{app_features.inspect})!"
      end

      # Next, check positional arguments and make sure the correct number and type
      # were passed and match positional args with style names.

      supplied_args = kwargs.keys

      req_args = self.class.required_init_args
      opt_args = self.class.optional_init_args
      pos_args = req_args + opt_args
      if req_args != ["any"]
        if args.size > pos_args.size
          raise Shoes::Errors::BadArgumentListError, "Too many arguments given for #{self.class}#initialize! #{args.inspect}"
        end

        if args.size == 0
          # It's fine to use keyword args instead, but we should make sure they're actually there
          needed_args = req_args.map(&:to_sym) - kwargs.keys
          unless needed_args.empty?
            raise Shoes::Errors::BadArgumentListError, "Keyword arguments for #{self.class}#initialize should also supply #{needed_args.inspect}! #{args.inspect}"
          end
        elsif args.size < req_args.size
          raise Shoes::Errors::BadArgumentListError, "Too few arguments given for #{self.class}#initialize! #{args.inspect}"
        end

        # Set each positional argument
        args.each.with_index do |val, idx|
          style_name = pos_args[idx]
          next if style_name.nil? || style_name == "" # It's possible to have non-style positional args

          val = self.class.validate_as(style_name, args[idx])
          instance_variable_set("@#{style_name}", val)
          supplied_args << style_name.to_sym
        end
      end

      this_drawable_styles = self.class.shoes_style_names(with_features: @app.features).map(&:to_sym)
      dc = @app.current_draw_context || {}

      # Styles not passed as arguments can come from the draw context

      # What styles are in the draw context, are used by this drawable, and weren't
      # given as positional or keyword arguments?
      draw_context_styles = (DRAW_CONTEXT_STYLES & this_drawable_styles) - supplied_args
      unless draw_context_styles.empty?
        draw_context_styles.each do |style|
          dc_val = dc[style.to_s]
          next if dc_val.nil?

          val = self.class.validate_as(style, dc[style.to_s])
          instance_variable_set("@#{style}", val)
          supplied_args << style
        end
      end

      # Styles that were *not* passed should be set to defaults

      default_styles = Shoes::Drawable.drawable_default_styles[self.class]

      # No arg specified for a property with a default value? Set it to default.
      (default_styles.keys - supplied_args).each do |key|
        val = self.class.validate_as(key, default_styles[key])
        instance_variable_set("@#{key}", val)
      end

      # If we have a keyword arg for a style, set it as specified.
      (this_drawable_styles & kwargs.keys).each do |key|
        val = self.class.validate_as(key, kwargs[key])
        instance_variable_set("@#{key}", val)
      end

      # We'd like to avoid unexpected keywords. But we're not disciplined enough to
      # raise an error by default yet. Non-style keywords passed to Drawable#initialize
      # are deprecated at this point, but I need to hunt down the last of them
      # and prevent them.
      unexpected = (kwargs.keys - this_drawable_styles)
      unless unexpected.empty?
        STDERR.puts "Unexpected non-style keyword(s) in #{self.class} initialize: #{unexpected.inspect}"
      end

      super(linkable_id: Shoes::Drawable.allocate_drawable_id)
      Shoes::Drawable.register_drawable_id(self.linkable_id, self)

      generate_debug_id

      parent = @app.current_slot
      if self.class.expects_parent?
        set_parent(parent, notify: false)
      end

      unless self.class.registered_shoes_events?
        # No Shoes events declared and we're creating an instance?
        # Default to no class-specific events.
        self.class.shoes_events
      end

      # Binding the motion events here isn't perfect.
      # What about drawables like SubscriptionItem that
      # have no motion events? With the current Lacci
      # implementation, the answer is that those events
      # will never be sent. Calling .hover on one will
      # be useless, harmless, and allowed. If you want
      # to make it disallowed, you can do something like
      # define a SubscriptionItem#hover that raises an
      # exception instead.

      bind_self_event("hover") do
        @hover&.call
      end

      bind_self_event("leave") do
        @leave&.call
      end

      bind_self_event("motion") do |x, y|
        @motion&.call(x, y)
      end
    end

    def self.expects_parent?
      return false if [::Shoes::App, ::Shoes::DocumentRoot].include?(self)
      return false if self < ::Shoes::TextDrawable

      true
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
      @app.with_slot(self, &block) if block_given?
      @app
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
      events = self.class.get_shoes_events
      unless events.include?(event_name.to_s)
        raise Shoes::Errors::UnregisteredShoesEventError, "Drawable #{self.inspect} tried to bind Shoes event #{event_name}, which is not in #{events.inspect}!"
      end
    end

    def bind_self_event(event_name, &block)
      raise(Shoes::Errors::NoSuchLinkableIdError, "Drawable has no linkable_id! #{inspect}") unless linkable_id

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

    def shoes_style_values(with_features: @app.features)
      all_property_names = self.class.shoes_style_names(with_features:)

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
      parent_id = @parent&.linkable_id

      # Should we send an event so this can be discovered from someplace other than
      # the DisplayService?
      ::Shoes::DisplayService.display_service.create_display_drawable_for(klass_name, self.linkable_id, shoes_style_values, parent_id:, is_widget:)
    end

    public

    attr_reader :parent
    attr_reader :destroyed

    # Set the Drawable's parent drawable. Notify the display service
    # that the parent has changed unless instructed not to.
    # We don't notify when first creating the Drawable. The create
    # event that is first sent will include the parent.
    def set_parent(new_parent, notify: true)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
      return unless notify

      send_shoes_event(new_parent&.linkable_id, event_name: "parent", target: linkable_id)
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

    # Move the drawable to an absolute position.
    # In Shoes, move(left, top) repositions an element
    # using absolute coordinates within its parent slot.
    #
    # @param left [Integer] the new left/x coordinate
    # @param top [Integer] the new top/y coordinate
    # @return [self]
    def move(left, top)
      self.left = left
      self.top = top
      self
    end

    # Displace the drawable visually by the given amount.
    # Unlike move(), displace does not affect layout — other
    # elements still behave as if this drawable is in its
    # original position. This is a visual-only offset.
    #
    # @param left [Integer] the horizontal displacement in pixels
    # @param top [Integer] the vertical displacement in pixels
    # @return [self]
    def displace(left, top)
      self.displace_left = left
      self.displace_top = top
      self
    end

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

    # Set the hover handler. Not every drawable may do something useful with this.
    #
    # @yield A block to be called when the cursor moves to be over the drawable.
    def hover(&block)
      @hover = block
    end

    # Set the leave handler. Not every drawable may do something useful with this.
    #
    # @yield A block to be called when the cursor moves to be off of the drawable.
    def leave(&block)
      @leave = block
    end

    # Set the motion handler, called with x and y coordinates as params.
    # Not every drawable may do something useful with this.
    #
    # @yield A block to be called when the cursor moves around over the drawable.
    def motion(&block)
      @motion = block
    end

    # We use method_missing to auto-create Shoes style getters and setters.
    def method_missing(name, *args, **kwargs, &block)
      name_s = name.to_s

      if name_s[-1] == "="
        prop_name = name_s[0..-2]
        if self.class.shoes_style_name?(prop_name)
          self.class.define_method(name) do |new_value|
            raise(Shoes::Errors::NoSuchLinkableIdError, "Trying to set Shoes styles in a #{self.class} with no linkable ID!") unless linkable_id

            new_value = self.class.validate_as(prop_name, new_value)
            instance_variable_set("@" + prop_name, new_value)
            send_shoes_event({ prop_name => new_value }, event_name: "prop_change", target: linkable_id)
          end

          return self.send(name, *args, **kwargs, &block)
        end
      end

      if self.class.shoes_style_name?(name_s)
        self.class.define_method(name) do
          raise(Shoes::Errors::NoSuchLinkableIdError, "Trying to get Shoes styles in an object with no linkable ID! #{inspect}") unless linkable_id

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

    def self.convert_to_integer(value, attribute_name)
      begin
        value = Integer(value)
        raise Shoes::Errors::InvalidAttributeValueError, "Negative number '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise Shoes::Errors::InvalidAttributeValueError, error_message
      end
    end

    def self.convert_to_float(value, attribute_name)
      begin
        value = Float(value)
        raise Shoes::Errors::InvalidAttributeValueError, "Negative number '#{value}' not allowed for attribute '#{attribute_name}'" if value < 0

        value
      rescue ArgumentError
        error_message = "Invalid value '#{value}' provided for attribute '#{attribute_name}'. The value should be a number."
        raise Shoes::Errors::InvalidAttributeValueError, error_message
      end
    end
  end
end
