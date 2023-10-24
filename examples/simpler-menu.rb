# Cut down from a more complicated example widget

class MenuPanel < Shoes::Widget
  @@boxes = []
  def initialize(color, args)
    @@boxes << self
    background color
    para "Box #{@@boxes.length}",
        :margin => 18, :align => "center", :size => 20
  end
end

Shoes.app :width => 400, :height => 130 do
  #style(Link, :underline => nil)
  #style(LinkHover, :fill => nil, :underline => nil)
  menu_panel green,  :width => 175, :height => 120, :margin => 4
  menu_panel blue,   :width => 140, :height => 120, :margin => 4
  menu_panel red,    :width => 135, :height => 120, :margin => 4
  menu_panel purple, :width => 125, :height => 120, :margin => 4
end

