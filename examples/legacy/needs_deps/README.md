# Examples Needing External Dependencies

These examples require gems or APIs that are dead or fundamentally incompatible:

- **expert-funnies.rb**: Requires `hpricot` gem (dead project, unmaintained since 2011)
- **expert-irb.rb**: Uses irb/ruby-lex API that changed in Ruby 3.x (set_input removed)
- **simple-rubygems.rb**: Uses Shoes.setup to install `bluecloth` gem (dead project)

Previously fixed (moved to working/):
- info.rb: Fixed by adding `bigdecimal` gem to Scarpe deps (Ruby 3.4 stdlib extraction)
- custom-list-box.rb: Fixed by adding `observer` gem to Scarpe deps + Slot Hash-to-kwargs
- superleg.rb: Fixed by adding `csv` gem to Scarpe deps + case-insensitive require shim
