Shoes.app do
  stack do
    para "10 fps"
    p = para "-"
    animate do |frame|
      p.replace(frame.to_s)
    end
    para "20 fps"
    p2 = para "-"
    animate(20) do |frame|
      p2.replace(frame.to_s)
    end
    para "3spf"
    p3 = para "-"
    every(3) do |count|
      p3.replace(count.to_s)
    end
  end
end

