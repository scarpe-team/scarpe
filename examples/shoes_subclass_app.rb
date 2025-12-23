# Test for class MyApp < Shoes inheritance pattern
# This is the classic Shoes pattern that _why designed

class MyBook < Shoes
  url '/', :index
  url '/about', :about

  def index
    stack margin: 20 do
      title "Welcome to My Book"
      para "This is the index page using the classic Shoes inheritance pattern!"
      para link("Go to About", click: "/about")
    end
  end

  def about
    stack margin: 20 do
      title "About"
      para "This page shows that URL routing works with class inheritance!"
      para link("Back to Index", click: "/")
    end
  end
end

Shoes.app width: 400, height: 300, title: "Shoes Subclass Test"
