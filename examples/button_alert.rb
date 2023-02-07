require "scarpe"

Scarpe.app do
  @push = button "Push me"
  @push.click {
    alert "Aha! Click!"
  }
end
