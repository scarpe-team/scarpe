# frozen_string_literal: true

class Scarpe
    class WebviewMotion < Scarpe::WebviewWidget
      def initialize(properties)
        super(properties)
  
        bind("mousemove") do |client_x, client_y|
          send_display_event(event_name: "mousemove", target: shoes_linkable_id, client_x: client_x, client_y: client_y)
        end
  
        bind("mousedown") do |client_x, client_y|
          send_display_event(event_name: "mousedown", target: shoes_linkable_id, client_x: client_x, client_y: client_y)
        end
  
        bind("mouseup") do
          send_display_event(event_name: "mouseup", target: shoes_linkable_id)
        end
  
        bind("mouseleave") do
          send_display_event(event_name: "mouseleave", target: shoes_linkable_id)
        end
      end
  
      def element(&block)
        onmousemove = handler_js_code("mousemove", "event.clientX", "event.clientY")
        onmousedown = handler_js_code("mousedown", "event.clientX", "event.clientY")
        onmouseup = handler_js_code("mouseup")
        onmouseleave = handler_js_code("mouseleave")
  
        HTML.render do |h|
          h.div(id: html_id, style: style) do
            h.canvas(
              width: "400",
              height: "500",
              viewBox: "0 0 400 500",
              style: "background-color: gray",
              onmousemove: onmousemove,
              onmousedown: onmousedown,
              onmouseup: onmouseup,
              onmouseleave: onmouseleave,
              oncreate: handler_js_code(draw_script),
            ) do
              block.call if block_given?
            end
          end
        end
      end
  
      private
  
      def style
        {
          #! hm styles
        }
      end
  
      def draw_script
        <<~JS
          const canvas = document.querySelector('canvas');
          const ctx = canvas.getContext('2d');
          let isDrawing = false;
  
          const startDrawing = (x, y) => {
            isDrawing = true;
            ctx.beginPath();
            ctx.moveTo(x, y);
          };
  
          const draw = (x, y) => {
            if (!isDrawing) return;
            ctx.lineTo(x, y);
            ctx.stroke();
          };
  
          const stopDrawing = () => {
            isDrawing = false;
          };
  
          canvas.addEventListener('mousedown', (event) => {
            startDrawing(event.clientX, event.clientY);
          });
  
          canvas.addEventListener('mousemove', (event) => {
            draw(event.clientX, event.clientY);
          });
  
          canvas.addEventListener('mouseup', () => {
            stopDrawing();
          });
  
          canvas.addEventListener('mouseleave', () => {
            stopDrawing();
          });
  
  
        JS
      end
    end
  end
  