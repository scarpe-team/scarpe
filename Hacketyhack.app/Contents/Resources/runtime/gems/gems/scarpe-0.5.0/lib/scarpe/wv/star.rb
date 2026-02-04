# frozen_string_literal: true

module Scarpe::Webview
  class Star < Drawable
    def initialize(properties)
      super(properties)
    end

    def element(&block)
      render("star", &block)
    end
  end
end
