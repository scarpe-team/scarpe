Shoes.app do 
  stack do
    para "Muliple Monitor Test"
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
    (st.monitor_count- 1).times do |mon|
       flow do 
        newmon = (dflt ^ 1)
        button "New Window on #{newmon}" do
          window title: "Launched in #{newmon}", monitor: newmon do
            stack do
              para "My Monitor is #{app.monitor}"
              button "Dialog" do
                alert "Which Window?"
              end
              button "move down right" do
                x = self.left
                y = self.top
                @eb.append "from: #{x}, #{y}\n"
                self.move x+20, y+20
                x = self.left
                y = self.top
                @eb.append "to:   #{x}, #{y}\n"
              end
              @eb = edit_box width: 300, height: 150
            end
          end
        end
        button "Move This to #{newmon}" do
          app.monitor = newmon
        end
        button "Restore this to #{dflt}" do
         app.monitor = dflt
        end
      end
    end
  end
end
