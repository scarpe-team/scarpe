#
# Example from juixe "Running with Shoes - Show me more"
# http://juixe.com/techknow/index.php/2007/10/24/running-with-shoes-show-me-more/
#
def draw_circle(app, color, size)
  r = size/2
  app.fill red(color)
  app.oval app.width/2 - r, app.height/2 - r, size, size
  draw_circle(app, color + 0.04, 3*size/4) if (color < 0.7)
end
Shoes.app :width => 600, :height => 600 do
  nofill
  draw_circle(self, 0.1, 600)
  mask do
    250.times do
      x = (20..580).rand
      y = (20..580).rand
      s = (20..60).rand
      oval x, y, s, s
    end
  end
end

