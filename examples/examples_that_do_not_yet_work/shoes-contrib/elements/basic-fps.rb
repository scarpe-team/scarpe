Shoes.app do
  @counter = para "STARTING"
  animate(24) do |frame|
    @counter.replace "FRAME #{frame}"
  end
end
