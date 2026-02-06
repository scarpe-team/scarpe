 #!ruby
 Shoes.app do
   # A button which take up the whole page
   @b = button "All of it", width: 1.0, height: 1.0

   # When clicked, show the styles
   @b.click { alert(@b.style.inspect) }
 end
