# frozen_string_literal: true

module Scarpe::Webview
  class Border < Drawable

    def initialize(properties)
      super(properties)
    end

    # If the drawable is intended to be overridable, add element and style to Calzini instead
    def element
      render('border')
    end
  end
end
