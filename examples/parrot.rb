require "scarpe"

Scarpe.app do
  para "What do you want me to say?"
  @phrase = edit_line("Soon it was a comet and, soon, a blazing monstrosity.", width: "100%")

  all_voices = `say -v '?'`.lines.map(&:split).map(&:first).uniq.compact
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
    `say -v '#{@selected_voice}' #{@phrase.text}`
  }
end
