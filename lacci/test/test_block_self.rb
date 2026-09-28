# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

# Slot blocks keep the caller's self (manual 198, 322-324; ledger B1). Shoes 3 runs them with a
# plain call and sends the DSL calls made inside to the slot being built, so a widget or a plain
# object keeps its own instance variables and methods inside its stacks.
class TestBlockSelf < NienteTest
  def test_a_widgets_stack_block_keeps_the_widget
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Nametag < Shoes::Widget
        attr_reader :tag, :inner

        def initialize(name)
          @name = name
          @inner = stack do
            $stack_self = self
            @tag = para @name
          end
        end
      end

      Shoes.app do
        @badge = nametag "Ada"
      end
    SHOES_APP
      badge = drawable(Nametag).obj
      assert_same badge, $stack_self, "the stack block keeps the widget as self"
      assert_equal "Ada", badge.tag.text, "so it reads and sets the widget's own instance variables"
      assert_same badge.inner, badge.tag.parent, "and the para lands in the stack being built"
      assert_equal [badge.inner], badge.contents, "not in the widget itself"
    SHOES_SPEC
  end

  def test_a_widgets_handlers_backgrounds_and_pens_reach_the_slot_being_built
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Shiny < Shoes::Widget
        attr_reader :inner, :bar

        def initialize
          strokewidth 3
          @inner = stack do
            background "#DDD"
            stroke red
            @bar = line 0, 0, 10, 10
            hover { $hovered = self }
          end
        end
      end

      Shoes.app do
        shiny
      end
    SHOES_APP
      shiny = drawable(Shiny).obj
      kinds = shiny.inner.contents.map { |d| d.class.name }
      assert_equal ["Shoes::Background", "Shoes::Line", "Shoes::SubscriptionItem"], kinds,
        "background, the line and the hover handler all go into the inner stack"
      refute_nil shiny.inner.draw_context["stroke"], "stroke in the block sets the inner stack's pen"
      assert_nil shiny.draw_context["stroke"], "not the widget's"
      assert_equal shiny.inner.draw_context["stroke"], shiny.bar.stroke, "so it pens the line"
      assert_equal 3, shiny.bar.strokewidth, "and the widget's own strokewidth still reaches it"

      Shoes::DisplayService.dispatch_event("hover", shiny.inner.contents.last.linkable_id)
      assert_same shiny, $hovered, "the hover block keeps the widget as self too"
    SHOES_SPEC
  end

  def test_a_widget_reaches_app_methods_it_lacks
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Arrowhead < Shoes::Widget
        attr_reader :tip

        def initialize
          stack do
            @tip = shape do
              move_to 0, 0
              line_to 10, 5
              line_to 0, 10
            end
          end
        end
      end

      Shoes.app do
        arrowhead
      end
    SHOES_APP
      tip = drawable(Arrowhead).obj.tip
      assert_equal [["move_to", 0, 0], ["line_to", 10, 5], ["line_to", 0, 10]], tip.shape_commands,
        "move_to and line_to live on the App, and a widget's shape block still reaches them"
    SHOES_SPEC
  end

  # A widget's options are its own, as in Shoes 3: Hackety Hack's glossb "OK", :color => "dark"
  # gets :color in its initialize, and Drawable no longer calls it an unexpected keyword. The
  # options that are styles still place the widget.
  def test_a_widgets_own_options_reach_it_and_its_styles_place_it
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Chip < Shoes::Widget
        attr_reader :opts

        def initialize(name, opts = {})
          @opts = opts
          para name
        end
      end

      $stderr_was = $stderr
      $stderr = StringIO.new
      Shoes.app do
        chip "OK", color: "dark", width: 80, left: 10
      end
      $warned, $stderr = $stderr.string, $stderr_was
    SHOES_APP
      chip = drawable(Chip).obj
      assert_equal({ color: "dark", width: 80, left: 10 }, chip.opts)
      assert_equal [80, 10], [chip.style[:width], chip.style[:left]]
      refute_includes $warned, "Unexpected non-style keyword"
    SHOES_SPEC
  end

  def test_a_widget_method_called_from_above_adds_to_the_widget
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Shelf < Shoes::Widget
        def initialize
          para "shelf"
        end

        def add(label)
          para label
        end
      end

      Shoes.app do
        @shelf = shelf
        @shelf.add "book"
      end
    SHOES_APP
      shelf = drawable(Shelf).obj
      assert_equal ["shelf", "book"], shelf.contents.map(&:text),
        "a widget asked to add something from the slot that holds it adds it to itself"
    SHOES_SPEC
  end

  def test_a_widget_appending_to_another_slot_draws_there
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Pen < Shoes::Widget
        attr_accessor :info

        def initialize
          @colour = "#123456"
          para "pen"
        end

        def show_colour
          @info.append do
            background @colour
            para "ink"
          end
        end
      end

      Shoes.app do
        @info = stack
        @pen = pen
        @pen.info = @info
        button("show") { @pen.show_colour }
      end
    SHOES_APP
      button.trigger_click
      info = stack("@info").obj
      assert_equal ["Shoes::Background", "Shoes::Para"], info.contents.map { |d| d.class.name },
        "what a widget draws inside another slot's append lands in that slot (Hackety Hack's turtle)"
      assert_equal "#123456", info.contents.first.paint, "painted with the widget's own @colour"
      assert_equal ["pen"], drawable(Pen).obj.contents.map(&:text), "not in the widget"
    SHOES_SPEC
  end

  def test_a_plain_object_keeps_its_self_in_nested_slots
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      # Shaped like Hackety Hack's HH::SideTab: a plain class that sends Shoes calls to the app.
      class Tab
        attr_reader :content, :title

        def initialize(slot)
          @slot = slot
          @name = "Editor"
          slot.append do
            @content = flow do
              draw
            end
          end
        end

        def draw
          stack do
            @title = para @name
          end
        end

        def method_missing(name, *args, &blk)
          @slot.app.send(name, *args, &blk)
        end

        def respond_to_missing?(name, include_private = false)
          @slot.app.respond_to?(name, include_private) || super
        end
      end

      Shoes.app do
        @right = stack
        $tab = Tab.new(@right)
      end
    SHOES_APP
      assert_equal "Editor", $tab.title.text, "nested stack blocks still see the object's own instance variables"
      assert_same $tab.content, $tab.title.parent.parent, "and what they draw nests where it was written"
      assert_same stack("@right").obj, $tab.content.parent
    SHOES_SPEC
  end

  def test_the_app_block_and_app_method_still_change_self
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Messenger
        def initialize(stack)
          @stack = stack
        end

        def add(msg)
          stack = @stack
          @stack.app do
            $app_self = self
            stack.append { para msg }
          end
        end
      end

      Shoes.app do
        $body_self = self
        @log = stack { para "Welcome" }
        $messenger = Messenger.new(@log)
      end
    SHOES_APP
      assert_kind_of Shoes::App, $body_self, "the Shoes.app block is run on the App"
      $messenger.add("hi")
      assert_same $body_self, $app_self, "app { } runs its block with the App as self (ledger B2)"
      assert_equal ["Welcome", "hi"], stack.contents.map(&:text)
    SHOES_SPEC
  end
end
