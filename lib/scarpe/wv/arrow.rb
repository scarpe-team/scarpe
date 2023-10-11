# frozen_string_literal: true

module Scarpe::Webview
  class Arrow < Drawable
    def initialize(properties)
      super(properties)
    end

    def element
      render("arrow")
    end
  end
end
