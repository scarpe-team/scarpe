Shoes.app do
  stack do
    # background, text and a button: both are elements!
    @back = background blue
    @text = banner "This quick brown fox"
    @press = button "Jumps over the lazy dog"

    # And so, both can be styled.
    @text.style :size => 24, :stroke => red, :margin => 10
    @press.style :width => 400
    @back.style :height => 10
  end
end
