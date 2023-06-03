Shoes.app do
  stack margin:5,width: 50,height:50 do
    fill "cyan"
    border "blue", strokewidth: 2
  end

  stack margin:10, width: 50,height:50 do
    fill "linear-gradient(cyan, red)"
  end

  stack margin:10 ,width: 50,height:50 do
    fill "radial-gradient(red, orange)"
  end

  stack margin:10 ,width: 50,height:50 do
    fill "radial-gradient(red, green)"
  end

  flow do
    stack margin:10, width: 50,height:50 do
      fill "linear-gradient(green, cyan)"
    end
  end
end

