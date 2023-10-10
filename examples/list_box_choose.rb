Shoes.app(title: "Guessing secret word", width: 500, height: 450) do
  secret_word = "apple"
  guess_label = para "Guess the secret word:"
  guess_input = list_box items: ["apple", "banana", "orange"], choose: "orange"

  button "Guess" do
    guess = guess_input.selected_item

    if guess == secret_word
      alert("Yayyy! that's right.")
    else
      alert("No, better luck next time😕")
    end

    guess_input.selected_item = ""
  end
end
