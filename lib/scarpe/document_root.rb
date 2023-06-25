# frozen_string_literal: true

class Scarpe
  class DocumentRoot < Scarpe::Widget
    include Scarpe::Background

    def initialize
      super

      create_display_widget
    end

    # This can be absolutely huge in console output, and it's frequently printed.
    def inspect
      "<Scarpe::DocumentRoot>"
    end

    alias_method :info, :puts

    def all_widgets
      out = []

      to_add = self.children
      until to_add.empty?
        out.concat(to_add)
        to_add = to_add.flat_map(&:children).compact
      end

      out
    end

    # We can add various ways to find widgets here.
    # These are sort of like Shoes selectors, used for testing.
    def find_widgets_by(*specs)
      widgets = all_widgets
      app = Scarpe::App.instance
      specs.each do |spec|
        if spec.is_a?(Class)
          widgets.select! { |w| spec === w }
        elsif spec.is_a?(Symbol)
          s = spec.to_s
          case s[0]
          when "$"
            begin
              # I'm not finding a global_variable_get or similar...
              global_value = eval s
              widgets = [global_value]
            rescue
              raise "Error getting global variable: #{spec.inspect}"
            end
          when "@"
            if app.instance_variables.include?(spec)
              widgets = [app.instance_variable_get(spec)]
            else
              raise "Can't find top-level instance variable: #{spec.inspect}!"
            end
          else
          end
        else
          raise("Don't know how to find widgets by #{spec.inspect}!")
        end
      end
      widgets
    end
  end
end
