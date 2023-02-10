#
# From the original Shoes announcement: "Okay, well... Shoes"
# http://github.com/shoes/shoes/wiki/%E2%80%9COkay,-Well...-Shoes%E2%80%9D
# 
#   had to change "text" to "para" to match shoes 3 api
#
label, time = nil, Time.now
Shoes.app :height => 150, :width => 250 do
  background "rgb(240, 250, 208)"
  stack :margin => 10 do
    start = button "Start" do
      time = Time.now
      label.replace "Stop watch started at #{time}"
    end
    stop = button "Stop" do
      label.replace "Stopped, #{Time.now - time} seconds elapsed."
    end
    label = para "Press start to begin timing."
  end
end
