Shoes.app do
  @b1 = button("First")
  @b2 = button("Hide First") { @b1.hide }
  @b3 = button("Show everybody") { @b1.show; @b2.show; @b3.show; @b4.show }
  @b4 = button("Toggle Hide-First") { @b2.toggle }
end
