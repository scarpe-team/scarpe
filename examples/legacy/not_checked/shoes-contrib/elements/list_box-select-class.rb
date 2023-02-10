Shoes.app do
  para "Choose your class:"
  list_box :items => ["Wizard", "Warrior", "Rogue"],
    :width => 120, :choose => "Rogue" do |list|
      if list.text == "Wizard"
        @player.text = "I put on my robe and wizard hat."
      else
        @player.text = list.text
      end 
  end

  @player = para "No class selected."
end
