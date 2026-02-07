# frozen_string_literal: true

module Scarpe::Webview
  class Background < Drawable
    def initialize(properties)
      super(properties)
    end

    def element
      render('background')
    end
  end
end
