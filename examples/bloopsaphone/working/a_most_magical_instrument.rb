require 'shoes'

Shoes.app title: "Cool Soundboard", width: 300, height: 250 do
  background white
  stack(margin: 12) do
    title "Cool Soundboard", align: "center"

    ["C", "D", "E", "F", "G", "A", "B"].each do |note|
      button note do
        bloops_command = %{ruby -e 'require "bloops"; b = Bloops.new; sound = b.sound Bloops::SQUARE; b.tune sound, "#{note}"; b.play; sleep 1'}
        system(bloops_command)
      end
    end
  end
end
