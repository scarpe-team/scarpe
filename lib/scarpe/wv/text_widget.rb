# frozen_string_literal: true

class Scarpe
  class WebviewTextWidget < Scarpe::WebviewWidget
  end

  class << self
    def default_wv_text_widget_with(element)
      webview_class_name = "Webview#{element.capitalize}"
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

Scarpe.default_wv_text_widget_with(:code)
Scarpe.default_wv_text_widget_with(:em)
Scarpe.default_wv_text_widget_with(:strong)
