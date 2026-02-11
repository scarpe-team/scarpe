#
# This is from juixe "Running with Shoes - 2D Examples" 
# http://juixe.com/techknow/index.php/2007/10/19/running-with-shoes-2d-examples/ 
# 
# This sample application follows the mouse when it hovers around the
# application window and draws growing bubbles. The bubbles have scan lines
# thanks to the mask method. 
#
# Array of x,y coordinates for bubbles
bubbles = [[0, 0]] * 30

# Bubbles Shoes application
Shoes.app :width => 537, :height => 500 do
  # 24 frames/second
  animate(24) do
    bubbles.shift
    bubbles << self.mouse[1, 2]
    clear do
      # Create pinkish linescan
      (500/5).times do |i|
        strokewidth 2
        stroke rgb(1.0, 0.5, 1.0, 1.0)
        line 0, i * 5, 537, i * 5
      end
      # Mask is expensive
      mask do
        # Create an oval bubble
        bubbles.each_with_index do |(x, y), i|
          oval x, y, 120 - (i * 5), 120 - (i * 5)
        end
      end
    end
  end
end
