# frozen_string_literal: true

class Scarpe
  class Button < Scarpe::Widget
    include Scarpe::Hooks::Click
    include Scarpe::Hooks::State

    def initialize(text, *args, **keywords, &block)
      @text = text
      super
    end

    def element
      HTML.render do |h|
        h.button(**attributes[:container]) { @text }
      end
    end
  end
end
