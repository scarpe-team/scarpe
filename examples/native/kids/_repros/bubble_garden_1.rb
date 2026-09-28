# Repro: timer(0) waits a whole second.
#
# lib/scarpe/native/timers.rb reads a delay that is not positive as no delay at
# all and uses the default, one second (positive(value, DEFAULT_SECONDS) in
# schedule_for). So in a run of timers where the first is timer(0), such as
#
#   5.times { |i| timer(i * 0.12) { blow_bubble(i) } }
#
# the first one comes last, a second after it was asked for. Shoes 3 runs a
# zero-second timer on the next turn of the loop. Here, after 0.3 seconds:
#
#   expected  fired: [0, 0.0, 0.01, 0.1]
#   actual    fired: [0.01, 0.1]            (0 and 0.0 follow at one second)
#
#   bundle exec ruby exe/scarpe peek examples/native/kids/_repros/bubble_garden_1.rb --wait 0.3 --layout
Shoes.app(width: 300, height: 100) do
  @fired = []
  [0, 0.0, 0.01, 0.1].each { |delay| timer(delay) { @fired << delay } }
  @label = para "waiting"
  every(0.05) { @label.replace "fired: #{@fired.inspect}" }
end
