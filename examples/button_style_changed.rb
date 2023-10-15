Shoes.app do
  @p = para "This text will start red\n", stroke: :red
  button "OK" do
    @p.replace("... but turn green when you click it.")
    @p.stroke = :green
  end
end
