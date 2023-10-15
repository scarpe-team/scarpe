Shoes.app(width: 400, height: 300) do
    flow do
      stack(width: 0.5) do
        progress fraction: 0.3
        para '30%'
        @progress2 = progress fraction: 0.6
        para '60%'
        @progress3 = progress fraction: 0.8
        para '80%'
      end
    end
  end
