# frozen_string_literal: true

class Scarpe
  module Hooks
    module Click
      def initializer_for_click
        bind("click") do
          puts "bla"
          @block&.call
        end
      end

      def attributes_for_click
        { container: { onclick: handler_js_code("click") } }
      end

      def click(&block)
        @block = block
      end
    end
  end
end
