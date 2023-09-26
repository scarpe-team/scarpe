# frozen_string_literal: true

module Scarpe::Webview
  class Arc < Widget
    def initialize(properties)
      super(properties)
    end

    def element
      render("arc")
    end
  end
end
