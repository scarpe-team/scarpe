# frozen_string_literal: true

module Scarpe::Webview
  class Oval < Drawable
    def initialize(properties)
      super(properties)
    end

    def element(&block)
      render("oval", &block)
    end
  end
end
