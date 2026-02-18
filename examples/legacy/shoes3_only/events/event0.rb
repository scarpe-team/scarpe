Shoes.app do
  stack do 
    @ev = shoesevent type: :click, button: 1, x: 222, y: 333
    para "Event #{@ev.type} #{@ev.button} #{@ev.x} #{@ev.y} will use: #{@ev.accept}"
    @ev.accept = false
    para "Event #{@ev.type} #{@ev.button} #{@ev.x} #{@ev.y} will use: #{@ev.accept}"
  end
end
