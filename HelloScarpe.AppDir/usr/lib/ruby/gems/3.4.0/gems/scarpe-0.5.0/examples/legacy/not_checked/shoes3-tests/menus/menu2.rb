Shoes.app menus: true, width: 300, height: 200 do  
  mb = menubar
  helpmenu = menu "Help"
  @aboutitem =  menuitem "About", key: "control_h" do
    alert "This is a menu test", title: "About"
  end
  helpmenu << @aboutitem
  cobbleritem = menuitem "Cobbler" do Shoes.cobbler end
  helpmenu << cobbleritem
  mb << helpmenu
  button "new app" do
    Shoes.app menus: true, width: 300, height: 200 do 
      para "Shared menus"
    end
  end
  button "change About" do
    @aboutitem.title = "Info"
    @aboutitem.block = proc {
      if confirm "The block is changed, disable menuitem?"
        @aboutitem.enable = false
      end
    }
  end
end

