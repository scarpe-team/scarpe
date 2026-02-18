Shoes.app :width => 400, :height => 300 do
  background white
  
  @label = para "Click anywhere!"
  
  click do |button, x, y|
    @label.replace "Clicked! button=#{button} x=#{x} y=#{y}"
    puts "CLICK: button=#{button} x=#{x} y=#{y}"
  end
  
  motion do |x, y|
    puts "MOTION: x=#{x} y=#{y}"
  end
end
