# spike

# frozen_string_literal: true

# TODO: how I handle boxes and blocks is completely disorganized. Using globals are the least of my worries right now.

require "libui"

# Breakup
require_relative "colors"
require_relative "core"
require_relative "alert"
require_relative "button"
require_relative "para"

UI = LibUI

Shoes = Scarpe

Shoes.app(title: "Hello world!", height: 1000, width: 1000) do
  para "Check out this paragraph",
    size: 50,
    stroke: red,
    weight: "ultralight",
    fill: yellow
  para "I'm just a fish though",
    size: 99,
    underline: "single",
    italic: true,
    weight: "bold",
    stroke: darkred,
    fill: aquamarine
  button("Flimflam") do
    alert "You clicked the button"
  end
end
