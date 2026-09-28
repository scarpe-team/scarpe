# Repro: an app's own @slots breaks every slot made after it.
#
# Lacci keeps the stack of slots being built in the App's @slots, and a Shoes
# app's block runs with that App as self, so an app that names its own list
# @slots (a row of star slots, say) replaces Lacci's. The next stack then dies
# inside Lacci:
#
#   lacci/lib/shoes/app.rb:260:in 'Shoes::App#current_draw_context':
#     undefined method 'current_draw_context' for an instance of Hash (NoMethodError)
#
# Expected: the app's instance variables are its own, or at least a clear error
# naming the clash. Only @slots is checked here; Lacci keeps other state in App
# instance variables too (@document_root, @draw_context, @started, @pages and
# more in lacci/lib/shoes/app.rb), which an app could clash with the same way.
#
#   bundle exec ruby exe/scarpe peek examples/native/kids/_repros/peekaboo_moles_1.rb
Shoes.app(width: 300, height: 120) do
  @slots = [{ x: 10 }, { x: 60 }] # where the stars go
  stack(left: 10, top: 10, width: 100, height: 40) { para "hello" }
end
