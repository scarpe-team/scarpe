# frozen_string_literal: true

class Scarpe
  class DocumentRoot < Scarpe::Widget
    include Scarpe::Background

    display_property :debug

    def initialize(debug: false)
      super

      create_display_widget
    end

    alias_method :info, :puts
  end
end
