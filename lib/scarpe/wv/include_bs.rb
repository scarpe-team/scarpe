# frozen_string_literal: true

class Scarpe
  class WebviewIncludeBs < WebviewWidget
    def initialize(properties)
      super
    end

    def properties_changed(changes)
      super
    end

    def element(&block)
      HTML.render do |h|
        h.link(
          rel: "stylesheet",
          href: "https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css",
          integrity: "sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC",
          crossorigin: "anonymous",
        )
      end
    end

    def to_html
      @children ||= []

      element { child_markup }
    end
  end
end
