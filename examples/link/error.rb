require "scarpe"

Scarpe.app do
  link = link("Knock knock") { para "Who's there?" }
  append(link.render(self))
end
