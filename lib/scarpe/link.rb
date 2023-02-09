class Scarpe
  class Link < Scarpe::TextWidget
    def initialize(text, &block)
      @text = text
      @block = block

      bind("click") do
        @block.call if @block
      end
    end

    def element
      HTML.render do |h|
        h.u(
          id: html_id,
          style: { color: "blue" },
          onmouseover: "this.style.color='darkblue'",
          onmouseout: "this.style.color='blue';",
          onclick: handler_js_code("click")
        ) do
          @text
        end
      end
    end
  end
end
