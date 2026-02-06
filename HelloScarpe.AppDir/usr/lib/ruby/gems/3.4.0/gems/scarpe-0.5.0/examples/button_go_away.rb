Shoes.app do
  @b = button "Go away, button"
  @b.click {
    @b.destroy
  }
end
