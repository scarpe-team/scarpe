Shoes.app do
  para "What do you want me to say?"
  @phrase = edit_line("Soon it was a comet and, soon, a blazing monstrosity.", width: "100%")

  all_voices = voices
  @selected_voice = all_voices.first
  @voice = para "🗣 #{@selected_voice}"

  all_voices.each do |voice|
    button voice do
      @voice.replace "🗣 #{voice}"
      @selected_voice = voice
    end
  end

  @push = button "📣"
  @push.click {
    say @phrase.text, voice: @selected_voice
  }
end
