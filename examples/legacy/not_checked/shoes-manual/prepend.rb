 #!ruby
 Shoes.app do
   @slot = stack { para 'Good Morning' }
   timer 3 do
     @slot.prepend { para "Your car is ready." }
   end
 end
