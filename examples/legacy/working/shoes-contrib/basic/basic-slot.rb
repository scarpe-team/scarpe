Shoes.app do
  stack :width => 200, :height => 200, :scroll => true do
    background "#2F2F2F"
    60.times do |i|
      para "Paragraph No. #{i}"
    end
  end
end
