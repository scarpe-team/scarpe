Shoes.app do
  @slot = stack { para 'Good Morning' }
  timer 3 do
    @slot.append do
      title "Breaking News"
      tagline "Astronauts arrested for space shuttle DUI."
    end
  end
end
