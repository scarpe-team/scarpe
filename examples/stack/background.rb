require "scarpe"

Scarpe.app do
  stack width: 0.33 do
    background "purple"
    button "a button"
  end
  stack width: 0.33 do
    background "red".."green"
    para "Red to green gradient"
  end
  stack width: 0.33 do
    background "purple"
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
