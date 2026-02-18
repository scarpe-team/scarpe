Shoes.app do 
  stack do
    para "Check if we can access shoes.yaml settings"
    button "Check" do
      st = Shoes.settings
      @eb.append "Have settings for #{st}\n"
      @eb.append "Name: #{st.app_name}\n"
      if RUBY_PLATFORM =~ /(linux)|(bsd)/
        @eb.append "Dbus: #{st.dbus}\n"
        @eb.append "RDomain: #{st.rdomain}\n"
      end
      @eb.append "Theme: #{st.theme}\n"
      @eb.append "MDI: #{st.mdi}\n"
      @eb.append "Menus: #{st.use_menus}\n"
      st.monitor_count.times  do |mon|
        @eb.append "Monitor #{mon} => #{st.monitor_geometry(mon)}\n"
      end
      @eb.append "Default monitor: #{st.monitor_default}\n"
    end 
    @eb = edit_box width: 400, height: 300
  end
end
