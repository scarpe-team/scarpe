module Scarpe
  class InternalApp
    attr_reader :window
    attr_accessor :current_id
    def initialize(window)
      @window = window
      @current_id = object_id
      @callbacks = {}
    end

    def bind(name, &block)
      @callbacks[name] = block
    end

    def handle_callback(name, *args)
      @callbacks[name].call(*args)
    end

    def render(&block)
      instance_eval &block
    end

    def append(el)
      @window.eval("document.getElementById(#{current_id}).insertAdjacentHTML('beforeend', \"#{el}\")")
    end

    def para(text)
      Scarpe::Para.new(self, text)
    end
    def stack(&block)
      Scarpe::Stack.new(self, &block)
    end
    def flow(&block)
      Scarpe::Flow.new(self, &block)
    end
    def button(text, width: nil, height: nil, &block)
      Scarpe::Button.new(self, text, width:, height:, &block)
    end
    def image(url)
      Scarpe::Image.new(self, url)
    end
    def edit_line(&block)
      Scarpe::EditLine.new(self, &block)
    end
  end
end
