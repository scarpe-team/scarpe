# frozen_string_literal: true

class Scarpe
  class WebviewRadio < Scarpe::WebviewWidget
    attr_reader :text

    def initialize(properties)
      super(properties)
    end

    def element
      HTML.render do |h|
        h.input(type: :radio, id: html_id, name: group_name, value: "hmm #{text}")
      end
    end

    private

    def group_name
      @group || @parent
    end
  end
end
