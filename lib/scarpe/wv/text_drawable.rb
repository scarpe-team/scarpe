# frozen_string_literal: true

module Scarpe::Webview
  class TextDrawable < Drawable
    def to_html
      # Do not render TextDrawables with individual wrapper divs.
      element
    end
  end

  class << self
    def default_wv_text_drawable_with(element)
      webview_class_name = element.capitalize
      webview_drawable_class = Class.new(Scarpe::Webview::TextDrawable) do
        def initialize(properties)
          class_name = self.class.name.split("::")[-1]
          @html_tag = class_name.delete_prefix("Webview").downcase
          super
        end

        def element
          render(@html_tag) { @content.to_s }
        end
      end
      Scarpe::Webview.const_set webview_class_name, webview_drawable_class
    end
  end
end

Scarpe::Webview.default_wv_text_drawable_with(:code)
Scarpe::Webview.default_wv_text_drawable_with(:em)
Scarpe::Webview.default_wv_text_drawable_with(:strong)
