require "scarpe"

Scarpe.app do
  link = link("Knock knock") { para "Who's there?" }
  para "Click this: ", link
end
