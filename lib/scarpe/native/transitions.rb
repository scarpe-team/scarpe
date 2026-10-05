# frozen_string_literal: true

module Scarpe::Native
  # Send destinations once; Rust owns interpolation and frame scheduling.
  module Transitions
    PROPERTIES = %w[opacity displace_left displace_top fraction].freeze
    FLOAT32_MAX = 3.4028234663852886e38

    def transition(view, duration:, **values, &complete)
      unless duration.is_a?(Numeric) && duration.real? && duration.to_f.finite? && duration >= 0
        raise ArgumentError, "transition duration must be finite and nonnegative"
      end
      props = values.transform_keys(&:to_s)
      if props.empty? || props.any? { |key, value| !valid_transition_value?(key, value) }
        raise ArgumentError, "transition needs numeric opacity, displacement, or progress fraction properties"
      end

      id = view.linkable_id
      token = (@transition_token += 1)
      reply = child.request(:transition, id: id, token: token, duration: duration.to_f, props: props.transform_values(&:to_f))
      raise ArgumentError, reply["error"] if reply["error"]

      # A predecessor's completion may already be in the inbox. Suppress it too,
      # and synchronize all of that group's properties before returning.
      cancel_transitions_for(id, props.keys)
      handle = Shoes::Transition.new(cancel: -> { cancel_transition(token) }, complete: complete)
      @transitions[token] = { id: id, keys: props.keys, handle: handle }
      handle
    end

    def cancel_transition(token, except: [])
      entry = @transitions.delete(token) or return
      entry[:handle].__finish(false)
      reply = child.request(:cancel_transition, id: entry[:id], token: token)
      raise Scarpe::Error, reply["error"] if reply["error"]

      sync_transition_values(entry[:id], reply.fetch("value").slice(*(entry[:keys] - except)))
    end

    private

    def valid_transition_value?(key, value)
      PROPERTIES.include?(key) && value.is_a?(Numeric) && value.real? && value.to_f.finite? &&
        value.abs <= FLOAT32_MAX && (!%w[opacity fraction].include?(key) || (0.0..1.0).cover?(value))
    end

    def cancel_transitions_for(id, keys, except: [])
      tokens = @transitions.filter_map { |token, entry| token if entry[:id] == id && (entry[:keys] & keys).any? }
      tokens.each { |token| cancel_transition(token, except: except) }
    end

    def forget_transitions(id)
      @transitions.delete_if do |_token, entry|
        entry[:handle].__finish(false) if entry[:id] == id
        entry[:id] == id
      end
    end

    def forget_all_transitions
      @transitions.each_value { |entry| entry[:handle].__finish(false) }
      @transitions.clear
    end

    def transition_ended(message)
      entry = @transitions.delete(message["token"]) or return
      return entry[:handle].__finish(false) unless entry[:id] == message["id"] && display_drawable(entry[:id])

      sync_transition_values(entry[:id], message.fetch("props").slice(*entry[:keys]))
      guarded("transition completion") { entry[:handle].__finish(message["completed"]) }
    end

    # Getters update at completion/cancellation. Echoing through style setters
    # here would cancel a successor or start another Ruby-to-Rust property batch.
    def sync_transition_values(id, props)
      display_drawable(id)&.update(props)
      drawable = lacci_drawable(id)
      props.each { |key, value| drawable&.instance_variable_set("@#{key}", value) }
    end
  end
end
