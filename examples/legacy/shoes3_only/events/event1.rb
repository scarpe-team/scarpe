Shoes.app do

  event do |evt|
    # do not trigger new events here unless you can handle them
    case evt.type
    when :click 
      $stderr.puts "click handler called: #{evt.type} #{evt.button}, #{evt.x} #{evt.y} #{evt.modifiers}"
      evt.accept = @ck1.checked?
    when :btn_activate
      $stderr.puts "button #{evt.object} at #{evt.type} #{evt.button} #{evt.x} #{evt.y} #{evt.width} #{evt.height}"
      evt.accept = @ck1.checked?
    else
      evt.accept = true
    end
  end  

  stack do
    para "Click test 1"
    flow do 
      @ck1 = check checked: true; para "pass clicks to Shoes"
    end
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
  #motion do |x, y, mods| 
  #  @eb.append "modtion #{x},#{y} #{mods} "
  #end
  wheel do |d,x,y,mods|
     @eb.append "wheel #{d} #{mods} at #{x},#{y}\n"
  end
end
