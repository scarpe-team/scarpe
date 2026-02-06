#
# Example from Getting Started with Shoes on OS X blog post found here:
# http://lethain.com/entry/2007/oct/15/getting-started-shoes-os-x/
#
shape = nil
Shoes.app do
  stack :width => 400, :height => 200, :margin => 50 do
    shape = list_box :items => ["Square", "Oval", "Rectangle"]
    button "Report" do
      para [shape.text]
    end
    para "Just some filler text"
  end
  flow :margin => 10 do
    para "Text"
    para "More"
    para "Less"
  end
end
