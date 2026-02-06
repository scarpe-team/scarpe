Shoes.app do
  style Shoes::Para, stroke: :red
  para "This text should be red\n"
  para "But this text should be green\n", stroke: :green
  button "OK"
end
