Shoes.app do
  para "てすと (te-su-to)", font: case RUBY_PLATFORM
  when /mingw/; "MS UI Gothic"
  when /darwin/; "AppleGothic, Arial"
  else "Arial"
  end
end
