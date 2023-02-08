Shoes.app do
  @slot = stack { para "Old text" }
  button "Update" do
    @slot.clear { para "brand new text" }
  end
end
