require "scarpe"

Scarpe.app do
  stack width: 0.33 do
    background "purple"
    border "red", strokewidth: 5, curve: 12
    button "a button"
  end
  stack width: 0.34 do
    background "purple"
    border "green", strokewidth: 6
    button "a button"
  end
  stack width: 0.33 do
    background "purple"
    border "yellow", strokewidth: 5, curve: 12
    button "a button"
    flow do
      background "purple"
      button "a button"
      stack width: 0.33 do
        background "purple"
        button "a button"
        button "a button"
      end
      stack width: 0.34 do
        background "purple"
        button "a button"
      end
    end
    flow do
      background "purple"
      button "a button"
    end
    flow do
      background "purple"
      button "a button"
    end
  end
end
