Shoes.app(title: "Hello Scarpe", width: 300, height: 200) do
  stack do
    para "Hello from packaged Scarpe!"
    button("Click me") { alert("It works!") }
  end
end
