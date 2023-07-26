Shoes.app height: 450, width: 450, title: "Change Audio Source 🔊" do
  flow do
    background beige
    border black, strokewidth: 6
    banner "Change Audio Source", align: "center"
    ins "Requires SwitchAudioSource, install with:"
    ins strong "brew install switchaudio-osx"
  end
  current = `SwitchAudioSource -c`.chomp
  @current_source = tagline "Current audio source: #{current}"
  sources = `SwitchAudioSource -a`.split("\n").map do |source|
    flow do
      button source do
        `SwitchAudioSource -s "#{source.chomp}"`
        @current_source.replace "Current audio source: #{source.chomp}"
      end
    end
  end
end
