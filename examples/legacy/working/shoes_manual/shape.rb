 #!ruby
 Shoes.app do
   fill red(0.2)
   shape do
     move_to(90, 55)
     arc_to(50, 55, 50, 50, 0, PI/2)
     arc_to(50, 55, 60, 60, PI/2, PI)
     arc_to(50, 55, 70, 70, PI, TWO_PI-PI/2)
     arc_to(50, 55, 80, 80, TWO_PI-PI/2, TWO_PI)
   end
 end
