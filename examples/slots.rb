require "scarpe"

Scarpe.app do
  flow do
    button "Click"
    button "Clickaty"
  end
  stack margin: 20 do
    button "Boop"
    button "Bip"
  end
end
