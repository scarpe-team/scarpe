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
  shoes_styles :shoes_api_name, :args, :stopped
  shoes_events :animate, :every, :timer, :hover, :leave, :motion, :click, :release, :keypress, :wheel

  # animate, every and timer make a Shoes::Animation, Shoes::Every or Shoes::Timer
  # (manual 1877, 1989, 2111). Displays still see each as a SubscriptionItem.
  TIMER_CLASS_NAMES = { "animate" => "Animation", "every" => "Every", "timer" => "Timer" }.freeze

  class << self
    def new(*args, shoes_api_name:, **kwargs, &block)
      timer_class = TIMER_CLASS_NAMES[shoes_api_name.to_s]&.then { |name| Shoes.const_get(name) }
      return timer_class.new(*args, shoes_api_name:, **kwargs, &block) if timer_class && timer_class != self

      super
    end

    def display_class_name
      "SubscriptionItem"
    end
  end

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
      # Hover hands over the slot it watches (manual 2200-2205, ledger H5)
      @unsub_id = bind_self_event("hover") do
        @callback&.call(parent)
      end
    when "leave"
      # Leave hands over the slot it watches (manual 2251-2257, ledger H5)
      @unsub_id = bind_self_event("leave") do
        @callback&.call(parent)
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
      # which we convert to Ruby symbols (:left). Regular characters stay as strings,
      # the colon key's own ":" among them.
      @unsub_id = bind_self_event("keypress") do |key|
        if key.is_a?(String) && key.start_with?(":") && key.length > 1
          @callback&.call(key[1..].to_sym)
        else
          @callback&.call(key)
        end
      end
    when "wheel"
      # Wheel event fires on mouse wheel/trackpad scroll.
      # Block params: delta (positive = up/away, negative = down/toward)
      # Also passes x, y coordinates of cursor position.
      @unsub_id = bind_self_event("wheel") do |delta, x, y, **_kwargs|
        @callback&.call(delta, x, y)
      end
    else
      raise "Unknown Shoes event #{shoes_api_name.inspect} passed to SubscriptionItem!"
    end

    # This won't create a visible display drawable, but will turn into
    # an invisible drawable and a stream of events.
    create_display_drawable
  end

  # Stop the animation/timer. In Shoes3, `anim = animate(fps) { ... }; anim.stop`
  # stops the periodic callback from firing. Setting the :stopped style triggers
  # a prop_change event that propagates to the display service.
  #
  # @return [self]
  def stop
    self.stopped = true
    self
  end

  # Restart a stopped animation/timer.
  #
  # @return [self]
  def start
    self.stopped = false
    self
  end

  # Toggle between started and stopped.
  #
  # @return [self]
  def toggle
    self.stopped = !self.stopped
    self
  end

  # Whether this subscription is currently stopped.
  def stopped?
    !!self.stopped
  end

  # Shoes 3 keeps one handler per slot per event (EVENT_HANDLER stores a single proc,
  # s3_canvas.c:934-955), so a slot given a second click or keypress block drops the first
  # (ledger H6). Clear keeps a slot's handlers (H9), so a slot rebuilt with a fresh one,
  # as Hackety Hack's editor is for every program it opens, would otherwise hear each key
  # once per rebuild.
  def replace_earlier_handlers
    Array(parent&.children).dup.each do |sibling|
      next if sibling.equal?(self) || !sibling.is_a?(Shoes::SubscriptionItem)

      sibling.destroy if sibling.shoes_api_name == shoes_api_name
    end
    self
  end

  def destroy
    # TODO: we need a better way to do this automatically. See https://github.com/scarpe-team/scarpe/issues/291
    unsub_shoes_event(@unsub_id) if @unsub_id
    @unsub_id = nil

    super
  end
end

class Shoes
  # What animate returns: its block gets the frame number, from 0 (manual 1877-1897).
  class Animation < Shoes::SubscriptionItem; end

  # What every returns: its block gets the count, from 0 (ledger I1).
  class Every < Shoes::SubscriptionItem; end

  # What timer returns: its block runs once (manual 2111-2114).
  class Timer < Shoes::SubscriptionItem; end
end
