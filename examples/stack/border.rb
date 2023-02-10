require "scarpe"

Scarpe.app do
  stack do
    border "red", strokewidth: 5, curve: 12
    para "Curved Red"
  end

  stack do
    border "#DDD".."#AAA", strokewidth: 10
    para "Gradient!"
  end
end
