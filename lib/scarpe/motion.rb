# frozen_string_literal: true

class Scarpe
    class Motion < Scarpe::Widget
  
      def initialize
        super()
        create_display_widget
        bind_self_event("mousemove") { |event| handle_mousemove(event) }
        bind_self_event("mouseup") { |event| handle_mouseup(event) }
        bind_self_event("mousedown") { |event| handle_mousedown(event) }
      end
  
      def handle_mousemove(event)
        puts "Mouse moved: #{event.inspect}"
      end
  
      def handle_mouseup(event)
        puts "Mouse button released: #{event.inspect}"
      end
  
      def handle_mousedown(event)
        puts "Mouse button pressed: #{event.inspect}"
      end
    end
  end
  