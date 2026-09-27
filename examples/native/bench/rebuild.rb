# 2000 paras in a slot, cleared and rebuilt on demand: the rebuild benchmark in native/PERF.md.
# Press "rebuild" (the bench driver clicks it) to clear the slot and fill it again.
Shoes.app(title: "Rebuild", width: 600, height: 500) do
  COUNT = 2000
  fill_list = lambda do |round|
    COUNT.times { |i| para "Round #{round}, line #{i}: the quick brown fox jumps over the lazy dog" }
  end

  @round = 0
  button("rebuild") do
    @round += 1
    @list.clear { fill_list.(@round) }
  end
  @list = stack { fill_list.(@round) }
end
