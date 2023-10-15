Shoes.app(width: 400, height: 300) do
    flow do
      stack(width: 0.5) do
        para "this is initally at 30%"
        @progress1 = progress fraction: 0.3

        para "this is initally at 60%"
        @progress2 = progress fraction: 0.6

        para "this is initally at 80%"
        @progress3 = progress fraction: 0.8

        para "this is a normal progress bar with no initial value"
        @progress4 = progress
      end

      stack(width: 0.5) do
        @start = button "Start"
        @start.click { start_progress }
      end
    end

    def start_progress
      animate do
        @progress1.fraction += 0.01
        @progress2.fraction += 0.015
        @progress3.fraction += 0.02
      end
    end

  end
