Shoes.app do
  # A button which takes up the whole page
  @b = button "WAT DO", :width => 1.0, :height => 1.0

  # When clicked, show the styles
  @b.click { alert(@b.style.inspect) }
end
