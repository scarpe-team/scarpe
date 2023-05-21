Shoes.app do
  @banner = banner "This is a big banner!", hidden: true
  para link("Hide banner") {
    @banner.hide
  }
  para link("Show banner") {
    @banner.show
  }
end
