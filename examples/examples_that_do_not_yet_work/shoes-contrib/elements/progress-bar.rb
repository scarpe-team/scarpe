Shoes.app do
  stack :margin => 0.1 do
    title "Progress example"
    @p = progress :width => 1.0

    animate do |i|
      @p.fraction = (i % 100) / 100.0
    end
  end
end
