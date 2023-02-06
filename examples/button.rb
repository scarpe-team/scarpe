require "scarpe"

Scarpe.app do
  @push = button "Push me", width: 200, height: 50
  @note = para "Nothing pushed so far"
  @push.click {
    @note.replace "Aha! Click!"
  }
end
