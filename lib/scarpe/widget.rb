# frozen_string_literal: true

require "deep_merge"

# Scarpe::Widget
#
# Interface:
# A Scarpe::Widget defines the "element" method to indicate that it has custom markup of
# some kind. A Widget with no element method renders as its children's markup, joined.

class Scarpe
  class Widget
    class << self
      attr_accessor :widget_classes, :alias_name

      def alias_as(name)
        self.alias_name = name
      end

      # rubocop:disable Style/ClassVars
      def document_root=(app)
        @@document_root = app
      end
      # rubocop:enable Style/ClassVars

      def inherited(subclass)
        self.widget_classes ||= []
        self.widget_classes << subclass
        super
      end

      def dsl_name
        n = name.split("::").last.chomp("Widget")
        n.gsub(/(.)([A-Z])/, '\1_\2').downcase
      end

      def find_by_name(name)
        widget_classes.detect { |k| k.dsl_name == name.to_s || k.alias_name.to_s == name.to_s }
      end
    end

    include Scarpe::Hooks::Width
    include Scarpe::Hooks::Height

    include Scarpe::Hooks::Top
    include Scarpe::Hooks::Left
    include Scarpe::Hooks::Bottom
    include Scarpe::Hooks::Right

    include Scarpe::Hooks::Margin # todo
    include Scarpe::Hooks::MarginBottom # todo
    include Scarpe::Hooks::MarginLeft # todo
    include Scarpe::Hooks::MarginRight # todo
    include Scarpe::Hooks::MarginTop # todo

    include Scarpe::Hooks::DisplaceLeft # todo
    include Scarpe::Hooks::DisplaceTop # todo

    include Scarpe::Hooks::Hidden # todo

    attr_accessor :parent

    def initialize(*args, **keywords, &block)
      @args = args
      @keywords = keywords
      @block = block

      @attribute_hooks = []
      @style_hooks = []

      initializer_methods = methods.select { |m| m.start_with?("initializer_for") }
      initializer_methods.each { |initializer_method| send(initializer_method) }

      # Once everything is converted to hooks we could enable this
      # return if keywords.keys.none?
      # raise ArgumentError, "Argument #{keywords.keys.first} is not supported by #{self.class}"
    end

    def method_missing(name, *args, **kwargs, &block)
      klass = Widget.find_by_name(name.to_s)

      super unless klass

      ::Scarpe::Widget.define_method(name) do |*args, **kwargs, &block|
        widget_instance = klass.new(*args, **kwargs, &block)

        unless klass.ancestors.include?(Scarpe::TextWidget)
          add_child(widget_instance)
          # If we add a child, we need to redraw ourselves
          needs_update!
        end

        widget_instance
      end

      send(name, *args, **kwargs, &block)
    end

    def respond_to_missing?(name, include_all = false)
      klass = Widget.find_by_name(name.to_s)

      !klass.nil? || super(name, include_all)
    end

    def styles
      style_hash = { container: {} }

      style_methods = methods.select { |m| m.start_with?("styles_for") }

      style_methods.each do |style_method|
        result = send(style_method) || {}
        style_hash.deep_merge!(result)
      end

      style_hash
    end

    def attributes
      attribute_hash = { container: { id: html_id, style: styles[:container] } }

      atttribute_methods = methods.select { |m| m.start_with?("attributes_for") }

      atttribute_methods.each do |attribute_method|
        result = send(attribute_method) || {}
        attribute_hash.deep_merge!(result)
      end

      puts attribute_hash

      attribute_hash
    end

    def remove_child(child)
      unless @children.include?(child)
        puts "remove_child: no such child(#{child.inspect}) for parent(#{parent.inspect})!"
      end
      @children.delete(child)
      child.parent = nil
    end

    def add_child(child)
      @children ||= []
      @children << child
      child.parent = self
    end

    # This gets a mini-webview for just this element and its children, if any
    def html_element
      @elt_wrangler ||= @@document_root.get_element_wrangler(html_id)
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

    # This binds a Scarpe callback, handled via a single dispatch point in the document root
    def bind(handler_function_name, &block)
      @@document_root.bind(html_id + "-" + handler_function_name, &block)
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
      @@document_root.request_redraw!
    end

    # When we do an update, we need to not redraw until we see another change
    def clear_needs_update!
      @dirty = false
      @children.each(&:clear_needs_update!)
    end

    def handler_js_code(handler_function_name, *args)
      js_args = ["'#{html_id}-#{handler_function_name}'", *args].join(", ")
      "scarpeHandler(#{js_args})"
    end
  end
end
