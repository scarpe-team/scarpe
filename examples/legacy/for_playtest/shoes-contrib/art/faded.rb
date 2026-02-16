#
# Example from juixe "Running with Shoes - Show me more"
# http://juixe.com/techknow/index.php/2007/10/24/running-with-shoes-show-me-more/
#
Shoes.app :width => 600, :height => 600 do
  nostroke

  def draw_circle(app, color, size)
    r = size/2
    app.fill gray(color)
    app.oval app.width/2 - r, 0, size, size
    draw_circle(app, color - 0.04, 3*size/4) if (color > 0.4)
  end

  draw_circle(self, 0.9, 600)
end

