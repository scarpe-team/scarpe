 #!ruby
 Shoes.app do
   para "Choose a fruit:"
   list_box items: ["Grapes", "Pears", "Apricots"],
     width: 120, choose: "Apricots" do |list|
       @fruit.text = list.text
   end

   @fruit = para "No fruit selected"
 end
