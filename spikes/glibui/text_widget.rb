# frozen_string_literal: true

class Scarpe
  class GlimmerLibUITextWidget < Scarpe::GlimmerLibUIWidget
  end

  class << self
    def default_glibui_text_widget_with(element)
      class_name = "GlimmerLibUI#{element.capitalize}"
      widget_class = Class.new(Scarpe::GlimmerLibUITextWidget) do
        def initialize(properties)
          class_name = self.class.name.split("::")[-1]
          @html_tag = class_name.delete_prefix("GlimmerLibUI").downcase
          super
        end

        def element
          HTML.render do |h|
            h.send(@html_tag) { @content.to_s }
          end
        end
      end
      Scarpe.const_set class_name, widget_class
    end
  end
end

Scarpe.default_glibui_text_widget_with(:code)
Scarpe.default_glibui_text_widget_with(:em)
Scarpe.default_glibui_text_widget_with(:strong)
