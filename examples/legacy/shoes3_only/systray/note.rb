Shoes.app do
  #app.set_window_title "Blitz"
  stack do
    para "Press button and look in your system's notification area"
    ctr = 0;
    button "Notify" do
      ctr += 1
      icp = ''
      if ctr % 3 != 0
        icp = "#{DIR}/static/shoes-icon.png"
      else
        icp = "#{DIR}/static/shoes-icon-red.png"
      end
      systray title: "#{app.name} Notify Test", message: "message ##{ctr}", icon: icp
    end
  end 
end
