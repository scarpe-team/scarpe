# frozen_string_literal: true

#TODO: Support color methods as argument
#TODO: Allow strokewidth to go wider than container?
#TODO: Support strokewidth draw context

Shoes.app(
  title: "Schwad's unbelievable desktop application that renders an oval",
  height: 700,
) do
  flow(height: 200) do
    para "Positional arguments:"
    oval 30, 30, 80, 200, center: true
  end
  flow(height: 200) do
    para "As a circle"
    stroke "blue"
    fill "pink"
    oval 30, 30, 80, center: true
  end
  flow(height: 200) do
    para "Keyword arguments:"
    fill "green"
    oval top: 20, left: 20, height: 160, width: 90, center: true, stroke: "red", strokewidth: 4
  end
end
