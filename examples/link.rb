require "scarpe"

Scarpe.app do
  @para = para("Knock knock", "</br>", link("Who's there?") { @para.replace "It's me" })
end
