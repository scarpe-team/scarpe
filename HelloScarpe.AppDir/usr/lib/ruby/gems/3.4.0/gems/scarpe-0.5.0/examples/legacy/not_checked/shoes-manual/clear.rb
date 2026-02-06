 #!ruby
 Shoes.app do
   @slot = stack { para "Old text" }
   timer 3 do
     @slot.clear { para "Brand new text" }
   end
 end
