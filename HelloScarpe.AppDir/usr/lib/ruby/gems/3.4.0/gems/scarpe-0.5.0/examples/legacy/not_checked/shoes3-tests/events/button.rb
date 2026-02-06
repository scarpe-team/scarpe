Shoes.app do
 
  stack do
    para "Native button test"
    flow do 
      @btn1 = button "button 1", width: 75 do
        @eb.append "button 1 clicked\n"
      end
      @btn2 = button "button 2" do
        @eb.append "button 2 clicked\n"
      end
      flow do
        @ck2 = check checked: true do
          @eb.append "Happy: "
          @eb.append "feeling good\n" if @r1.checked?
          @eb.append "feeling something\n" if @r2.checked?
          @eb.append "feeling low\n" if @r3.checked?
        end
        para "Happy?"
      end
      stack do
        flow {@r1 = radio :happy; para "Estatic"}
        flow {@r2 = radio :happy; para "So-So"}
        flow {@r3 = radio :happy; para "Not really"}
      end
    end
    @eb = edit_box width: 500, height: 350
  end
  click do |btn,x,y,mods|
    @eb.append "click #{btn}, x: #{x}, y: #{y}. mods: #{mods}\n"
  end
end
