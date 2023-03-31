# frozen_string_literal: true

Shoes.app(title: "Flow example") do
  flow do
    %w[One Two Three Four Five Six Seven Eight].each do |num|
      stack width: 100 do
        para num, size: 32
      end
    end
  end
end
