# Wheel event example - demonstrates mouse wheel/trackpad scroll handling
#
# Scroll over the window to see the wheel events. The delta value indicates
# scroll direction and magnitude:
#   - Positive delta = scroll up (wheel away from user)
#   - Negative delta = scroll down (wheel toward user)

Shoes.app(title: "Mouse Wheel Demo", width: 400, height: 300) do
  background "#333"
  
  @count = 0
  @total_delta = 0.0
  
  stack margin: 20 do
    title "Mouse Wheel Demo", stroke: white
    para "Scroll your mouse wheel or trackpad over this window.", stroke: "#AAA"
    
    @delta_label = para "Delta: 0", stroke: lime, size: 16
    @total_label = para "Total: 0", stroke: yellow, size: 16
    @count_label = para "Events: 0", stroke: cyan, size: 16
    @pos_label = para "Position: (-, -)", stroke: "#F88", size: 12
  end
  
  wheel do |delta, x, y|
    @count += 1
    @total_delta += delta
    
    direction = delta > 0 ? "⬆ UP" : "⬇ DOWN"
    @delta_label.replace("Delta: #{delta.round(2)} #{direction}")
    @total_label.replace("Total: #{@total_delta.round(2)}")
    @count_label.replace("Events: #{@count}")
    @pos_label.replace("Position: (#{x.round}, #{y.round})")
  end
end
