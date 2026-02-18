#!ruby
filename = ask_open_file
Shoes.app do
  if filename
    para File.read(filename)
  else
    para "No file selected"
  end
end
