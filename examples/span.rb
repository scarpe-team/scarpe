Shoes.app :height => 500, :width => 500 do
  stack :margin => 10 do
    para span("TEXT EDITOR", :stroke => blue, :fill => green), " * USE ALT-Q TO QUIT", :stroke => red
  end
  para "Various ", del("text"), " in ", sub("various"), " ", sup("styles"), " can be ", ins("hard to read"), "...\n"

  para "A ", span("wide", underline: "single", undercolor: blue), " ", span("variety", underline: "error", undercolor: green), " ", span("of", underline: "double"), " ", span("underlines", underline: "low", undercolor: darkgreen)
end
