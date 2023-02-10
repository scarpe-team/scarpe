Shoes.app :title => "MAIN" do
  para self
  button "Spawn" do
    window :title => "CHILD" do
      para self
    end
  end
end
