# brew install switchaudio-osx

Shoes.app height: 450, width: 450, title: "Change Audio Source 🔊" do
  flow do
    background beige
    border black, strokewidth: 6
    banner "Change Audio Source", align: "center"
    ins "Requires SwitchAudioSource, install with:"
    ins strong "brew install switchaudio-osx"
  end
  # SwitchAudioSource is a Mac program; anywhere it is missing, say so and offer nothing.
  switch = lambda do |*args|
    IO.popen(["SwitchAudioSource", *args], &:read)
  rescue SystemCallError
    nil
  end
  current = switch.call("-c")&.chomp || "(SwitchAudioSource is not installed)"
  @current_source = tagline "Current audio source: #{current}"
  sources = switch.call("-a").to_s.split("\n").map do |source|
    flow do
      button source do
        switch.call("-s", source.chomp)
        @current_source.replace "Current audio source: #{source.chomp}"
      end
    end
  end
end
