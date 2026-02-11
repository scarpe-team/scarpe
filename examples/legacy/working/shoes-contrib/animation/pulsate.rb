#
# From ashbb's shoes_hack_note #003
# http://github.com/ashbb/shoes_hack_note/blob/master/md/hack003.md
#
Shoes.app :width => 200, :height => 200, :title => 'Pulse!' do
  pulse = stack
  logo = image "shoes-icon-blue.png", :top => 30, :left => 30

  animate 10 do |i|
    i %= 10
    pulse.clear do
      fill black(0.2 - (i * 0.02))
      strokewidth(3.0 - (i * 0.2))
      stroke rgb(0.7, 0.7, 0.9, 1.0 - (i * 0.1))
      oval(logo.left - i, logo.top - i, logo.width + (i * 2)) 
    end
  end
end
