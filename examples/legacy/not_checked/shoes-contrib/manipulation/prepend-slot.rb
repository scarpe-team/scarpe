Shoes.app do
  @slot = stack { para 'Good Morning' }
  button "Prepend" do
    @slot.prepend { para "Your car is ready." }
  end
end
