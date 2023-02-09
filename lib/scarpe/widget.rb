# Scarpe::Widget
#
# Interface:
# A Scarpe::Widget defines the "element" method to indicate that it has custom markup of
# some kind. A Widget with no element method renders as its children's markup, joined.

class Scarpe
  class Widget
    class << self
      attr_accessor :widget_classes

      def set_window(w)
        @@window = w
      end

      def set_document_root(app)
        @@document_root = app
      end

      def inherited(subclass)
        self.widget_classes ||= []
        self.widget_classes << subclass
      end

      def dsl_name
        n = self.name.split("::").last.chomp("Widget")
        n.gsub(/(.)([A-Z])/,'\1_\2').downcase
      end
    end

    def method_missing(name, *args, **kwargs, &block)
      klass = Widget.widget_classes.detect { |k| k.dsl_name == name.to_s }

      super unless klass

      ::Scarpe::Widget.define_method(name) do |*args, **kwargs, &block|
        widget_instance = klass.new(*args, **kwargs, &block)

        unless klass.ancestors.include?(Scarpe::TextWidget)
          @children ||= []
          @children << widget_instance
        end

        widget_instance
      end

      self.send(name, *args, **kwargs, &block)
    end

    def html_id
      object_id.to_s
    end

    def to_html
      @children ||= []
      child_markup = @children.map(&:to_html).join
      if self.respond_to?(:element)
        element { child_markup }
      else
        child_markup
      end
    end

    def bind(handler_function_name, &block)
      @@document_root.bind(html_id + "-" + handler_function_name, &block)
    end

    def inner_text=(new_text)
      @@window.eval("document.getElementById(#{html_id}).innerText = \"#{new_text}\"")
    end

    def value_text=(new_text)
      @@window.eval("document.getElementById(#{html_id}).value = #{new_text}")
    end

    def remove_self
      @@window.eval("document.getElementById(#{html_id}).remove()")
    end

    def handler_js_code(handler_function_name, *args)
      js_args = ["'#{html_id}-#{handler_function_name}'", *args].join(", ")
      "scarpeHandler(#{js_args})"
    end
  end
end
