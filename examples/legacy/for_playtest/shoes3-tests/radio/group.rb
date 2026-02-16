# group
  Shoes.app do
   stack do
     para "Among these films, which do you prefer?"
     flow do
       radio :films
       para "The Taste of Tea by Katsuhito Ishii"
     end
     flow do
       radio :films
       para "Kin-Dza-Dza by Georgi Danelia"
     end
     flow do
       radio :films
       para "Children of Heaven by Majid Majidi"
     end
   end
 end
