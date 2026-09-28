# frozen_string_literal: true

module Scarpe::Native
  # What Rust was told about one drawable: its kind, its place in the tree and its latest props.
  # Lacci pairs it with the drawable (set_drawable_pairing) and Shoes-Spec proxies expose it as
  # `display`, so tests can check what crossed the wire without asking Rust.
  #
  # Props are mirrored as instance variables too, the way Niente's display drawables keep them,
  # so Lacci's own tests (display.instance_variable_get(:@chosen)) run against either service.
  class DisplayDrawable
    OWN_STATE = %w[id kind app_id parent children props data].freeze

    attr_reader :id, :kind, :app_id, :parent, :children, :props
    alias_method :shoes_type, :kind

    def initialize(id, kind, app_id, props)
      @id = id
      @kind = kind
      @app_id = app_id
      @children = []
      @props = {}
      @data = @props
      update(props)
    end

    def update(changes)
      changes.each do |key, value|
        @props[key] = value
        instance_variable_set("@#{key}", value) if key.match?(/\A[a-z_]\w*\z/) && !OWN_STATE.include?(key)
      end
    end

    # A nil index appends, as it does on the wire.
    def attach_to(new_parent, index)
      detach
      @parent = new_parent
      return unless new_parent

      siblings = new_parent.children
      index && index < siblings.size ? siblings.insert(index, self) : siblings << self
    end

    def detach
      @parent&.children&.delete(self)
      @parent = nil
    end

    def subtree
      [self, *children.flat_map(&:subtree)]
    end

    def inspect
      "#<#{self.class.name} #{kind}##{id}>"
    end
  end
end
