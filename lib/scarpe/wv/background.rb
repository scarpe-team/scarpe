# frozen_string_literal: true

module Scarpe::Webview
  class Background < Drawable

    def initialize(properties)
      super
    end

    # If the drawable is intended to be overridable, add element and style to Calzini instead
    def element
      render("background")
    end

    private
  end
end
