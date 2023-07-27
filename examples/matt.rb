Shoes.app height: 450, width: 1000, title: "Matt" do
  # Main container
  flow do
    stack width: "100%" do

      # Each string
      @notes = []
      ["E", "A", "D", "G", "B", "E"].each do |string|
        flow height: "15%" do
          20.times do |i|
            stack width: "4%" do
              border black, strokewidth: 1
              background linen
              caption string, align: "center"
              @notes << local_pirate_radio = radio("#{string}_#{i}".to_sym)
            end
          end
        end
      end

    end
  end

  flow do
    stack width: "100%" do
      button "GIMME DAT GOOD STUFF" do
        @console.replace @notes.select(&:checked?).map(&:group).inspect
      end
    end
  end

  # Debugging
  flow do
    stack width: "100%" do
      banner "Console stuff here..."
      @console = para "nothin yet"
    end
  end
end
