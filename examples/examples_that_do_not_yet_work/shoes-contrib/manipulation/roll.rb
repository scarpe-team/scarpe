Shoes.app do
  @to_roll = flow :height => 100, :margin => 5 do
    background lightyellow, :curve => 10
    para link('Roll me up!').click{ roll_up(@to_roll) }, :margin => 35
  end
  def roll_up(slot, speed = 30, step = 8)
    animate speed do
      if slot.height <= step
        slot.hide
        stop
      else
        slot.height -= step
      end
    end
  end
end

