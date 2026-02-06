# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIDocumentRoot < Scarpe::GlimmerLibUIWidget
    include Scarpe::GlimmerLibUIBackground

    attr_reader :debug

    def initialize(properties)
      @callbacks = {}
      super
    end

    def display(properties = {})
      <<~GTEXT
        window("#{properties["title"] || "Scarpe with GlimmerLibUI"}", #{properties["width"] || 640}, #{properties["height"] || 480}) {
          horizontal_box {
            #{@children.map(&:display).join}
          }
        }.show
      GTEXT
    end

    def element(&blck)
      window(&blck).show
    end

    # Bind a Scarpe callback name; see Scarpe::Widget for how the naming is set up
    def bind(name, &block)
      @callbacks[name] = block
    end
  end
end
