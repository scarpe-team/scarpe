# frozen_string_literal: true

class Scarpe
  class WebviewRadio < Scarpe::WebviewWidget
    attr_reader :text

    def initialize(properties)
      super(properties)
    end

    def element
      HTML.render do |h|
        h.input(type: :radio, id: html_id, name: "html_id", value: "hmm #{text}")
        h.label(for: html_id) { @text }
      end
    end
  end
end
