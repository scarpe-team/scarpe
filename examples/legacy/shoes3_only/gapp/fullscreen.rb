Shoes.app do 
  stack do
    para "Muliple Monitor Full Screen Test"
    st = Shoes.settings
    @eb = edit_box width: 400, height: 150
  end
  start do
    st = Shoes.settings
    dflt = st.monitor_default
    @eb.append "Default monitor is #{dflt}\n"
    st.monitor_count.times do |mon|
      @eb.append "Monitor #{mon} => #{st.monitor_geometry(mon)}\n"
    end
    button "Tooggle FullScreen #{dflt}" do
      state = app.fullscreen 
      app.fullscreen = (state ? false : true);
    end
    (st.monitor_count - 1).times do |mon|
       flow do 
        newmon = (dflt ^ 1)
        @ck = check
        para "full screen?"
        button "New Window on #{newmon}" do
          window title: "Launched in #{newmon}", monitor: newmon, fullscreen: @ck.checked? do
            stack do
              para "My Monitor is #{app.monitor}"
              button "Fullscreen #{app.monitor}" do
                state = app.fullscreen
                app.fullscreen = (state ? false : true);
              end
              @eb = edit_box width: 300, height: 150
            end
          end
        end
      end
    end
  end
end
