Shoes.app do

  # Local file (path relative to this script)
  stack width: 100, height: 100 do
    background "../docs/static/avatar.png"
    border blue, strokewidth: 4
  end

  # Solid color
  stack width: 100, height: 100 do
    background red
  end

  # RGBA string
  stack width: 100, height: 100 do
    background "rgba(255,200,0,255)"
  end

  # Remote URL
  stack width: 100, height: 100 do
    background "http://shoesrb.com/manual/static/shoes-icon.png"
    border green, strokewidth: 4
  end

end
