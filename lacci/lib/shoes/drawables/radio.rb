# frozen_string_literal: true

class Shoes
  # A Radio button drawable. Only a single radio button may be checked in each
  # group. If no group is specified, or the group is nil, default to all
  # radio buttons in the same slot being treated as being in the same group.
  class Radio < Shoes::Drawable
    shoes_styles :group, :checked
    shoes_events :click

    # Track radio groups for mutual exclusion
    @groups = Hash.new { |h, k| h[k] = [] }

    class << self
      attr_reader :groups
    end

    init_args
    opt_init_args :group
    def initialize(*args, **kwargs, &block)
      @block = block

      super

      self.class.groups[effective_group] << self

      bind_self_event("click") do
        # Uncheck other radios in the same group
        self.class.groups[effective_group].each do |r|
          next if r == self
          r.checked = false if r.checked?
        end
        # Radio buttons always check on click (never toggle)
        self.checked = true
        @block&.call(self)
      end
      create_display_drawable
    end

    def click(&block)
      @block = block
      self
    end

    def checked?
      @checked ? true : false
    end

    def checked(value)
      self.checked = value
    end

    private

    def effective_group
      @group || @parent&.linkable_id || "default"
    end
  end
end
