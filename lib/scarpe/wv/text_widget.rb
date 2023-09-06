# frozen_string_literal: true

module Scarpe::Webview
  class TextWidget < Widget
  end

  class << self
    def default_wv_text_widget_with(element)
      webview_class_name = element.capitalize
      webview_widget_class = Class.new(Scarpe::Webview::TextWidget) do
        def initialize(properties)
          class_name = self.class.name.split("::")[-1]
          @html_tag = class_name.delete_prefix("Webview").downcase
          super
        end

        def element
          Scarpe::Components::HTML.render do |h|
            h.send(@html_tag) { @content.to_s }
          end
        end
      end
      Scarpe::Webview.const_set webview_class_name, webview_widget_class
    end
  end
end

Scarpe::Webview.default_wv_text_widget_with(:code)
Scarpe::Webview.default_wv_text_widget_with(:em)
Scarpe::Webview.default_wv_text_widget_with(:strong)
