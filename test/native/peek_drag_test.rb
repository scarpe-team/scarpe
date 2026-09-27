# frozen_string_literal: true

require_relative "helper"

# `scarpe peek --drag` presses at the first point, moves through the rest a frame apart and
# releases at the last, so an app that draws while the button is down (scribble.rb reads
# `mouse` in an animate block) shows its drawing in a smoke run.
class PeekDragTest < Minitest::Test
  include NativeTestHelpers

  def setup
    skip_without_real_binary
  end

  def test_peek_drags_through_its_points_with_the_button_down
    run = run_real(<<~APP, argv: ->(app) { ["peek", app, "--drag", "10,10,60,40,110,70", "--layout"] })
      Shoes.app(width: 200, height: 100) do
        seen = []
        moves = 0
        @log = para ""
        motion { moves += 1 }
        animate(24) do
          button, x, y = mouse
          seen << "\#{x},\#{y}" if button == 1 && !seen.include?("\#{x},\#{y}")
          @log.replace("\#{seen.join(" ")} moves=\#{moves}")
        end
      end
    APP
    assert_clean_exit(run)
    assert_match(/^drag 10,10 -> 60,40 -> 110,70$/, run.stdout)
    text = run.stdout[/Para .* "(.*)"$/, 1].to_s
    assert_equal ["10,10", "60,40", "110,70"], text.split(" moves=").first.to_s.split, "every point was seen with the button down"
    assert_operator text[/moves=(\d+)/, 1].to_i, :>=, 3, "and the pointer moved through them"
  end

  def test_peek_wants_two_points_to_drag
    run = run_real("Shoes.app { para 'hi' }", argv: ->(app) { ["peek", app, "--drag", "10,10"] })
    refute run.status.success?
    assert_match(/--drag needs two or more X,Y points/, run.stderr)
  end
end
