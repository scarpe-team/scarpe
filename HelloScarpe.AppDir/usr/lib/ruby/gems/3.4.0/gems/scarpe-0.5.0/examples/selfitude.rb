def printish(msg)
  #$stderr.puts msg
  File.open("/tmp/shoesy_stuff.txt", "a") do |f|
    f.write(msg + "\n")
  end
end

Shoes.app do
  printish "Self top: #{self.inspect}" # It's an instance of Shoes::App, yes
  stack do
    printish "Self in stack: #{self.inspect}" # Yup, here too
  end
  button("Clickity") do
    alert("You clicked me!")
    printish "Self in button handler: #{self.inspect}" # And here too
  end
end

