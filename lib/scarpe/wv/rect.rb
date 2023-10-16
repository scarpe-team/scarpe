# frozen_string_literal: true

module Scarpe::Webview
  class Rect < Drawable
    def initialize(properties)
      super(properties)
    end

    def element(&block)
      render("rect", &block)
    end
  end
end
