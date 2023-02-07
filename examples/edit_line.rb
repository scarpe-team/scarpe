require "scarpe"

Scarpe.app do
  @name = edit_line("John", width: -100)
  @greeting = para "Hello #{@name.text}!"
  @name.change {
    @greeting.replace("Hello #{@name.text}!")
  }
end
