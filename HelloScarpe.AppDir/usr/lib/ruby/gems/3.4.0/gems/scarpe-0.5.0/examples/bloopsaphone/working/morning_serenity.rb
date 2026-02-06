Shoes.app height: 200, width: 200, title: "Morning Serenity" do
  @sleepy_person = para "😴"

  button "Good Morning!" do
    @sleepy_person.replace "😀"
    b = Bloops.new
    b.tempo = 70

    s1 = b.sound Bloops::SINE
    s1.attack = 0.5
    s1.sustain = 0.3
    s1.decay = 0.4

    pattern1 = "4:e5 4:d5 4:c5 4:d5 2:e5 4:e5 4:d5 4:c5 4:d5 2:e5 4:d5 4:c5 4:b4 4:c5 2:d5"

    b.tune s1, pattern1

    b.play
  end

end
