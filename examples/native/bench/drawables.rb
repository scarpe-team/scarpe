# 2000 drawables (1000 paras and 1000 rects): the memory benchmark in native/PERF.md.
Shoes.app(title: "2000 drawables", width: 600, height: 500) do
  stack do
    1000.times { |i| para "Para number #{i} with a little text in it" }
  end
  1000.times { |i| rect(i % 600, (i * 7) % 500, 12, 12, fill: rgb(i % 255, 90, 160, 0.5)) }
end
