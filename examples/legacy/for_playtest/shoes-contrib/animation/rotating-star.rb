#
# Example from juixe "Running with Shoes - Transform"
# http://juixe.com/techknow/index.php/2007/10/23/running-with-shoes-transform/
#
Shoes.app :width => 600, :height => 500 do
  # Move canvas to center of screen
  translate width/2, height/2
  animate(24) do
    clear do
      # Rotate one degree at each frame
      rotate 1
      # Scale the image up or down
      scale((0.8..1.2).rand)
      # draw triangle…
      star 10, 10, 7 
    end
  end
end
