Shoes.app width: 600, height: 600 do
  stack do
    para "Events and Menus"
    flow do
      @btn1 = button "button 1", width: 75 do
        @eb.append "button 1 clicked\n"
      end
      click do
        @eb.append "flow click\n"
      end
      hover do
        @eb.append "flow hover\n"
      end
    end
    @eb = edit_box width: 500, height: 350
  end
  motion do |x, y, mods|
    @eb.append "motion #{x},#{y} #{mods} "
  end
end
