# frozen_string_literal: true

# Certain Shoes calls like motion and keydown are basically an
# event subscription, with no other visible presence. However,
# they have a place in the drawable tree and can be deleted.
#
# Depending on the display library they may not have any
# direct visual (or similar) presence there either.
#
# Inheriting from Drawable gives these a parent slot and a
# linkable_id automatically.
#
# Events not yet implemented: start, finish events for slots -
# start is first draw, finish is drawable destroyed
class Shoes::SubscriptionItem < Shoes::Drawable
  shoes_styles :shoes_api_name, :args
  shoes_events :animate, :every, :timer, :hover, :leave, :motion, :click, :release, :keypress

  def initialize(args: [], shoes_api_name:, &block)
    super

    @callback = block

    case shoes_api_name
    when "animate"
      @unsub_id = bind_self_event("animate") do |frame|
        @callback.call(frame)
      end
    when "every"
      @unsub_id = bind_self_event("every") do |count|
        @callback.call(count)
      end
    when "timer"
      @unsub_id = bind_self_event("timer") do
        @callback.call
      end
    when "hover"
      # Hover passes the Shoes drawable as the block param
      @unsub_id = bind_self_event("hover") do
        @callback&.call(self)
      end
    when "leave"
      # Leave passes the Shoes drawable as the block param
      @unsub_id = bind_self_event("leave") do
        @callback&.call(self)
      end
    when "motion"
      # Shoes sends back x, y, mods as the args.
      # Shoes3 uses the strings "control" "shift" and
      # "control_shift" as the mods arg.
      @unsub_id = bind_self_event("motion") do |x, y, ctrl_key, shift_key, **_kwargs|
        mods = [ctrl_key ? "control" : nil, shift_key ? "shift" : nil].compact.join("_")
        @callback&.call(x, y, mods)
      end
    when "click"
      # Click has block params button, left, top
      # button is the button number, left and top are coords
      @unsub_id = bind_self_event("click") do |button, x, y, **_kwargs|
        @callback&.call(button, x, y)
      end
    when "release"
      # Click has block params button, left, top
      # button is the button number, left and top are coords
      @unsub_id = bind_self_event("release") do |button, x, y, **_kwargs|
        @callback&.call(button, x, y)
      end
    when "keypress"
      # Keypress passes the key string or symbol to the handler.
      # The display service sends special keys prefixed with ":" (e.g. ":left"),
      # which we convert to Ruby symbols (:left). Regular characters stay as strings.
      @unsub_id = bind_self_event("keypress") do |key|
        if key.is_a?(String) && key.start_with?(":")
          @callback&.call(key[1..].to_sym)
        else
          @callback&.call(key)
        end
      end
    else
      raise "Unknown Shoes event #{shoes_api_name.inspect} passed to SubscriptionItem!"
    end

    @unsub_id = bind_self_event(shoes_api_name) do |*args|
      @callback&.call(*args)
    end

    # This won't create a visible display drawable, but will turn into
    # an invisible drawable and a stream of events.
    create_display_drawable
  end

  def destroy
    # TODO: we need a better way to do this automatically. See https://github.com/scarpe-team/scarpe/issues/291
    unsub_shoes_event(@unsub_id) if @unsub_id
    @unsub_id = nil

    super
  end
end
