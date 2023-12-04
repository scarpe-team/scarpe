#!ruby
filename = ask_open_file
Shoes.app do
  para File.read(filename)
end
