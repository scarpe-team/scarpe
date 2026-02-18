Shoes.app menus: true do
  stack do
    para "Menu Command Key Test"
    flow do
      @ctl = check; para "ctl/cmd"
      @shf = check; para "shift"
      @alt = check; para "alt"
      @el = edit_line width: 40    
      button "Add Test item/key to Shoes menu" do
        mb = menubar
        mn = mb[0] # shoes menu
        keystr = ""
        keystr << "control_" if @ctl.checked?
        keystr << "shift_" if @shf.checked? 
        keystr << "alt_" if @alt.checked?
        keystr << @el.text
        mi = menuitem "Test", key: keystr do
          confirm "you pressed #{mi.key}"
        end
        mn.append mi
      end
    end
    flow do
      @ctl2 = check; para "ctl/cmd"
      @shf2 = check; para "shift"
      @alt2 = check; para "alt"
      @el2 = edit_line width: 40    
      button "Change Test key" do
        mb = menubar
        mn = mb[0] # shoes menu
        mi = mn["Test"]
        keystr = ""
        keystr << "control_" if @ctl2.checked?
        keystr << "shift_" if @shf2.checked? 
        keystr << "alt_" if @alt2.checked?
        keystr << @el2.text
        mi.key = keystr    
      end
    end
  end
end
