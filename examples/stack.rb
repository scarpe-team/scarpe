require "scarpe"

Scarpe.app do
  stack margin: 50 do
    button "with 50px margin"
  end
  stack width: 0.5 do
    button "50% width"
  end
  stack width: 80 do
    button "80px width"
  end
  stack width: -80 do
    button "100% - 80px width"
  end
  flow do
    stack width: 0.33 do
      button "inside flow left 1/3"
    end
    stack width: 0.67 do
      button "inside flow right 2/3"
    end
  end
end
