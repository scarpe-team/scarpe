# frozen_string_literal: true

class Shoes::Slot < Shoes::Widget
  # @incompatibility Shoes uses #content, not #children, for this
  attr_reader :children

  # Do not call directly, use set_parent
  def remove_child(child)
    @children ||= []
    unless @children.include?(child)
      @log.warn("remove_child: no such child(#{child.inspect}) for parent(#{parent.inspect})!")
    end
    @children.delete(child)
  end

  # Do not call directly, use set_parent
  def add_child(child)
    @children ||= []
    @children << child
  end

  # Get a list of child widgets
  def contents
    @children ||= []
    @children.dup
  end

  # Calling stack.app or flow.app will execute the block
  # with the Shoes::App as self, and with that stack or
  # flow as the current slot.
  #
  # @incompatibility Shoes Classic will only change self
  #   via this method, while Scarpe will also change self
  #   with the other Slot Manipulation methods: #clear,
  #   #append, #prepend, #before and #after.
  #
  # @return [Shoes::App] the Shoes app
  # @yield the block to call with the Shoes App as self
  def app(&block)
    Shoes::App.instance.with_slot(self, &block) if block_given?
    Shoes::App.instance
  end

  # Remove all children from this widget. If a block
  # is given, call the block to replace the children with
  # new contents from that block.
  #
  # Should only be called on Slots, which can
  # have children.
  #
  # @incompatibility Shoes Classic calls the clear block with current self, while Scarpe uses the Shoes::App as self
  #
  # @yield The block to call to replace the contents of the widget (optional)
  # @return [void]
  def clear(&block)
    @children.dup.each(&:destroy)
    append(&block) if block_given?
    nil
  end

  # Call the block to append new children to a Slot.
  #
  # Should only be called on a Slot, since only Slots can have children.
  #
  # @incompatibility Shoes Classic calls the append block with current self, while Scarpe uses the Shoes::App as self
  #
  # @yield the block to call to replace children; will be called on the Shoes::App, appending to the called Slot as the current slot
  # @return [void]
  def append(&block)
    raise("append requires a block!") unless block_given?
    raise("Don't append to something that isn't a slot!") unless self.is_a?(Shoes::Slot)

    Shoes::App.instance.with_slot(self, &block)
  end
end
