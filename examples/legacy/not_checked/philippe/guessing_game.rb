# Guessing Game — based on the Hackety Hack sample.
# This was previously blocked because ask() didn't return values.
# Now it works with native macOS dialogs!
Shoes.app :width => 350, :height => 300, :title => "Guessing Game" do
  background "#336"

  stack :margin => 15 do
    title "Number Guessing Game", :stroke => white
    @info = para "I'm thinking of a number between 1 and 100.", :stroke => "#ADF"
    @secret = rand(100) + 1
    @guesses = 0

    button "Make a guess!" do
      input = ask("Guess a number between 1 and 100:")
      if input.nil? || input.strip.empty?
        @info.replace "You didn't guess anything!"
      else
        guess = input.to_i
        @guesses += 1
        if guess < @secret
          @info.replace "#{guess} is too LOW! (#{@guesses} guesses)"
        elsif guess > @secret
          @info.replace "#{guess} is too HIGH! (#{@guesses} guesses)"
        else
          @info.replace "YOU GOT IT! #{@secret} in #{@guesses} guesses!"
          if confirm("Play again?")
            @secret = rand(100) + 1
            @guesses = 0
            @info.replace "New game! Guess a number between 1 and 100."
          end
        end
      end
    end
  end
end
