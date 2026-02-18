 #!ruby
 Shoes.app do
   @b1 = button "OK!"
   @b1.click { para "Well okay then." }
   @b2 = button "Are you sure?"
   @b2.click { para "Your confidence is inspiring." }
 end
