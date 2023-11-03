Shoes.app(
  title: "Schwad's unbelievable desktop application that renders an oval",
  height: 700
) do
  flow do
    para "Positional arguments:"
    oval 30, 30, 80, 200, center: true
  end
  flow do
    para "As a circle"
    oval 30, 30, 80, center: true
  end
  flow do
    para "Keyword arguments:"
    oval top: 20, left: 20, height: 160, width: 90, center: true, stroke: red, strokewidth: 5
  end
end
