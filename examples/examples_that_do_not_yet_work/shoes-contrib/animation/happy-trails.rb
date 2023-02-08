#
# Example from Getting Started with Shoes on OS X blog post found here:
# http://lethain.com/entry/2007/oct/15/getting-started-shoes-os-x/
#
trails = [[0,0]] * 60
shape = 0
Shoes.app do
  keypress do |k|
    case k
      when " "
        shape += 1
    end
  end
  nostroke
  fill rgb(0x30, 0xFF, 0xFF, 0.6)
  animate(24) do 
    trails.shift
    trails << self.mouse[1,2]
    clear do
      trails.each_with_index do |(x, y), i|
        i += 1
        case shape%2
        when 0
          rect :left => x, :top => y, :width => i, :height => i
        else
          oval :left => x, :top => y, :radius => i, :center => true
        end
      end
    end
  end
end
