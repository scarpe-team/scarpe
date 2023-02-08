Shoes.app do
  fill blue(0.1)
  image 300, 300 do
    300.times do |i|
      oval i, i, i * 2
    end
  end
end
