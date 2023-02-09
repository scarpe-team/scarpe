require "scarpe"

Shoes.app do
  para "Name:"
  @name = edit_line("John", width: "100%")
  @greeting = para "Hello #{@name.text}!"
  @name.change {
    @greeting.replace("Hello #{@name.text}!")
  }
end
