# frozen_string_literal: true

require_relative "test_helper"

# image(w, h) { ... } is a canvas (manual 410-426, ledger E9, wire contract (c)): the
# block runs with the image as the current slot, so its shapes and text are the
# image's children and a display paints them inside the image's box.
class TestImageCanvas < NienteTest
  def test_shapes_drawn_in_the_block_belong_to_the_image
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @canvas = image 300, 300 do
          3.times { |i| oval i, i, 10 }
          para "on the image"
        end
        @after = oval 0, 0, 5
      end
    SHOES_APP
      canvas = image("@canvas")
      assert_equal [300, 300], [canvas.width, canvas.height]
      assert_equal %w[Oval Oval Oval Para], canvas.contents.map { |d| d.class.name.split("::").last }
      assert_equal 4, ovals.size, "finders see into the image"
      first = drawable("id:\#{canvas.contents.first.linkable_id}")
      assert_equal canvas.display, first.display.parent, "the display gets them as the image's children"
      refute_includes canvas.contents, oval("@after").obj, "drawing goes back to the slot after the block"
    SHOES_SPEC
  end

  def test_the_block_draws_with_the_slots_pen_and_can_change_its_own
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        fill blue
        image 100, 100 do
          @inherited = oval 0, 0, 10
          fill red
          @own = oval 0, 0, 10
        end
        @outside = oval 0, 0, 10
      end
    SHOES_APP
      assert_equal [0, 0, 255, 255], oval("@inherited").style[:fill]
      assert_equal [255, 0, 0, 255], oval("@own").style[:fill]
      assert_equal [0, 0, 255, 255], oval("@outside").style[:fill], "the image's fill stays in the image"
    SHOES_SPEC
  end

  # simple-sphere.rb nests size-less canvases and blurs them; the effects are an
  # extension (E9) that no display draws yet, so they must not stop the app.
  def test_nested_canvases_and_effects_run
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @outer = image 400, 470, top: 30, left: 50 do
          @inner = image top: 0, left: 0 do
            oval 30, 30, 338, 338
            blur 10
            glow 2
            shadow 4
          end
        end
      end
    SHOES_APP
      assert_equal [image("@inner").obj], image("@outer").contents
      assert_equal 1, image("@inner").contents.size
    SHOES_SPEC
  end

  # Shoes 3: an image made from a file takes its block as the click handler
  # (simple-bounce.rb, mask2.rb: image "icon.png" do alert "quick" end).
  def test_a_file_images_block_is_its_click
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $clicks = 0
        @icon = image "icon.png", left: 100, top: 100 do
          $clicks += 1
        end
      end
    SHOES_APP
      assert_empty image("@icon").contents
      image("@icon").trigger_click
      assert_equal 1, $clicks
    SHOES_SPEC
  end

  def test_removing_the_image_removes_what_was_drawn_on_it
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @canvas = image(50, 50) { oval 0, 0, 10 }
      end
    SHOES_APP
      oval_id = oval.linkable_id
      image("@canvas").remove
      assert_nil Shoes::Drawable.drawable_by_id(oval_id, none_ok: true)
    SHOES_SPEC
  end
end
