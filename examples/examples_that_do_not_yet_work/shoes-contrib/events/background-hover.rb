Shoes.app do
  s = stack :width => 200, :height => 200 do
    background red
    hover do
      s.clear { background indigo }
    end
    leave do
      s.clear { background red }
    end
  end
end
