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
      def set_internal_app(app)
        @@internal_app = app
      end
    end

    def self.inherited(subclass)
      self.widget_classes ||= []
      self.widget_classes << subclass
    end

    def method_missing(name, *args, **kwargs, &block)
      klass = Widget.widget_classes.detect do |k|
        n = k.name.split("::").last.chomp("Widget")
        method_name = n.gsub(/(.)([A-Z])/,'\1_\2').downcase
        method_name == name
      end
      # TODO: should this call super instead?
      raise NoMethodError, "no method #{name} for #{self.class.name}" unless klass

      STDERR.puts "Creating widget #{name.inspect}, #{klass.name}, A: #{args.inspect}, K: #{kwargs.inspect}, Block: #{block ? "yes" : "no" }"
      widget_instance = klass.new(*args, **kwargs, &block)

      @children ||= []
      @children << widget_instance

      widget_instance
    end

    def html_id
      object_id.to_s
    end

    def to_html
      @children ||= []
      child_markup = @children.map(&:to_html).join
      if self.respond_to?(:element)
        puts "#{self} - to_html with Element"
        element { child_markup }
      else
        puts "#{self} - to_html no Element"
        child_markup
      end
    end

    def append(el)
      @@window.eval("document.getElementById(#{current_id}).insertAdjacentHTML('beforeend', \`#{el}\`)")
    end

    def remove(id)
      @@window.eval("document.getElementById(#{id}).remove()")
    end

    def bind(handler_function_name, &block)
      @@internal_app.bind(html_id + "-" + handler_function_name, &block)
    end

    def handler_js_code(handler_function_name)
      "scarpeHandler('#{html_id}-#{handler_function_name}')"
    end
  end
end
  