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
        def initialize(content)
          @content = content

          super(content)

          display_widget_properties(content)
        end
      end
      Scarpe.const_set class_name, widget_class

      webview_widget_class = Class.new(Scarpe::WebviewTextWidget) do
        def initialize(content, shoes_linkable_id:)
          @content = content
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
