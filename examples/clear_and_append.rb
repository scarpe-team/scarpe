Shoes.app do
  stack do
    button("More Stuff!") do
      @slot.append do
        ins "I'm enthused."
        title "Enthused!"
        banner "ENTHUSED!"
      end
    end

    button("No Stuff!") do
      @slot.clear
    end

    button("Different Stuff!") do
      @slot.clear do
        para "I'm so different!"
        title "I'm like a totally different but emo person! Or possibly chicken."
      end
    end

    @slot = stack(width: "100%") { para 'Good Morning' }
  end
end
