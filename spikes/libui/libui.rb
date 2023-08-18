# spike

# frozen_string_literal: true

require "libui"
require "debug"

# Breakup
require_relative "colors"
require_relative "stack"
require_relative "flow"
require_relative "alert"
require_relative "button"
require_relative "para"
require_relative "core"

UI = LibUI

Shoes = Scarpe

Shoes.app(title: "Hello world!", height: 1000, width: 1000) do
  title "Hello world!"
  para "This is a paragraph", size: 10
  flow do
    stack do
      inscription "Check out this paragraph",
        stroke: red,
        weight: "ultralight",
        fill: yellow
      banner "I'm just a fish though",
        underline: "single",
        italic: true,
        weight: "bold",
        stroke: darkred,
        fill: aquamarine
    end
  end
  stack do
    flow do
      button("Flimflam") do
        alert "You clicked the button"
      end
    end
  end
end
