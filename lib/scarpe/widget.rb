# frozen_string_literal: true

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
      def document_root=(wr)
        @@document_root = wr
      end

      def web_wrangler=(wr)
        @@web_wrangler = wr
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

    attr_reader :parent
    attr_reader :children

    def initialize(*args)
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

    attr_writer :parent

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
      @elt_wrangler ||= Scarpe::WebWrangler::ElementWrangler.new(@@web_wrangler, html_id, widget: self)
    end

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

    # This binds a Scarpe callback, handled via a single dispatch point in the document root
    def bind(handler_function_name, &block)
      @@document_root.bind(html_id + "-" + handler_function_name, &block)
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
      @@document_root.request_full_redraw!
    end

    def handler_js_code(handler_function_name, *args)
      js_args = ["'#{html_id}-#{handler_function_name}'", *args].join(", ")
      "scarpeHandler(#{js_args})"
    end
  end
end
