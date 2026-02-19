# CHECKED BY SCHWAD

Shoes.app do
  background red

  stack do
    para "Click the button to reduce opacity to 90%"
    @status = text "Opacity is 1.0\n"
    button "reduce" do
     app.opacity =  0.90
     @status.replace("Opacity is #{app.opacity}\n")
    end
    button "normal" do
     app.opacity = 1.0
     @status.replace("Opacity is #{app.opacity}\n")
    end
  end
end
