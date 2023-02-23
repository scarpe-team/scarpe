# frozen_string_literal: true

# Scarpe::TextWidget

class Scarpe
  class TextWidget < Scarpe::Widget
    class << self
      # rubocop:disable Lint/MissingSuper
      def inherited(subclass)
        Scarpe::Widget.widget_classes ||= []
        Scarpe::Widget.widget_classes << subclass
      end
      # rubocop:enable Lint/MissingSuper
    end
  end

  class WebviewTextWidget < Scarpe::WebviewWidget
  end

  class << self
    def default_text_widget_with(element)
      class_name = element.capitalize
      webview_class_name = "Webview#{class_name}"

      widget_class = Class.new(Scarpe::TextWidget) do
        display_property :content

        def initialize(content)
          @content = content

          super

          create_display_widget
        end
      end
      Scarpe.const_set class_name, widget_class
      widget_class.class_eval do
        display_property :content
      end

      webview_widget_class = Class.new(Scarpe::WebviewTextWidget) do
        def initialize(properties)
          class_name = self.class.name.split("::")[-1]
          @html_tag = class_name.delete_prefix("Webview").downcase
          super
        end

        def element
          HTML.render do |h|
            h.send(@html_tag) { @content.to_s }
          end
        end
      end
      Scarpe.const_set webview_class_name, webview_widget_class
    end
  end
end

Scarpe.default_text_widget_with(:code)
Scarpe.default_text_widget_with(:em)
Scarpe.default_text_widget_with(:strong)
