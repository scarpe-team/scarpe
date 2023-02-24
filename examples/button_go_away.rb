Shoes.app(debug: true) do
  @b = button "Go away, button"
  @b.click {
    @b.destroy
  }
end
