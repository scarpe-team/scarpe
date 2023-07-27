Shoes.app height: 450, width: 450, title: "Matt" do
  # Main container
  flow do
    stack width: "100%" do

      # Each string
      ["E", "A", "D", "G", "B", "E"].each do |string|
        flow height: "15%" do
          stack width: "100%" do
            border black, strokewidth: 1
            background linen
            caption string, align: "center"
          end
        end
      end

    end
  end
end
