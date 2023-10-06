# frozen_string_literal: true

module Scarpe::Webview
  class Arc < Drawable
    def initialize(properties)
      super(properties)
    end

    def element
      render("arc")
    end
  end
end
