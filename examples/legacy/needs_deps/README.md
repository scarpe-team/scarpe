# Examples Needing External Dependencies

These examples require gems or APIs that are incompatible with modern Ruby (3.4+):

- **custom-list-box.rb**: Requires `observer` gem (extracted from stdlib in Ruby 3.4)
- **expert-funnies.rb**: Requires `hpricot` gem (dead project, unmaintained)
- **expert-irb.rb**: Uses irb/ruby-lex API that changed in Ruby 3.x
- **info.rb**: Requires `bigdecimal` gem (extracted from stdlib in Ruby 3.4)
- **simple-rubygems.rb**: Uses Shoes.setup which works, but bundler blocks external gems
- **superleg.rb**: Has `require 'CSV'` (wrong case) and needs data file

These could potentially work with dependency fixes or running outside bundler.
