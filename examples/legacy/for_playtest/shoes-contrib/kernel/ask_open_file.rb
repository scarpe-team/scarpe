Shoes.app do
  filename = ask_open_file
  if filename
    para File.read(filename)
  else
    para "No file selected"
  end
end
