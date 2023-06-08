Shoes.app width: 600, height: 600 do
  stack do
    para "Events and Menus"
    flow do 
      @btn1 = button "button 1", width: 75 do
        @eb.append "button 1 clicked\n"
      end
      @btn2 = button "button 2" do
        @eb.append "button 2 clicked\n"
      end
      click do
         @eb.append "flow click\n"
      end 
    end
    @eb = edit_box width: 500, height: 350
  end
  click do |btn, x, y, mods|
    @eb.append "app click: #{btn} x: #{x} y: #{y} mods: #{mods}\n" 
  end
  release do |btn, x, y, mods| 
    @eb.append "app unclick: #{btn} x: #{x} y: #{y} mods: #{mods}\n"
  end
  keypress do |key|
    $stderr.puts key
    @eb.append "#{key} "
  end
  motion do |x, y, mods| 
    @eb.append "modtion #{x},#{y} #{mods} "
  end
  wheel do |d,x,y,mods|
     @eb.append "wheel #{d} #{mods} at #{x},#{y}\n"
  end
end
