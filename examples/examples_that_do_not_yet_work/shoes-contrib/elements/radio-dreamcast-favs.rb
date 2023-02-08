Shoes.app do
  stack do
    para "Among these dreamcast games, which do you prefer?"
    flow do
      radio :dreamcast
      para "Shenmue"
    end
    flow do
      radio :dreamcast
      para "Phantasy Star Online"
    end
    flow do
      radio :dreamcast
      para "Marvel Vs. Capcom II"
    end
  end
end
