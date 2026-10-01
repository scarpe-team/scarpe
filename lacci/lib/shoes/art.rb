# frozen_string_literal: true

class Shoes
  # The drawing methods arc, arrow, line, oval, rect and star are each headed
  # "» Shoes::Shape" in the manual (1665-1826, ledger E11). Their drawables keep their
  # own classes, so a display is still told "Oval" or "Rect", and Shoes::Shape stays
  # the shape { } block, so `Shoes::Shape === drawable` and the shape finder mean only
  # that. They answer is_a?(Shoes::Shape) the way ActiveSupport::Duration answers
  # is_a? for the class of its value.
  module Art
    # Art may be placed by its far edges (manual 1100-1106, 1356-1364, ledger C10):
    # right stands in for left and bottom for top, and naming both edges of an axis
    # stands in for the size along it, since the shape runs from one to the other.
    EDGE_STAND_INS = { left: [:right], top: [:bottom], width: [:left, :right], height: [:top, :bottom] }.freeze

    # @param styles [Hash] the keyword styles a shape was given
    # @return [Array<Symbol>] the placement arguments its edges stand in for
    def self.placed_by_edges(styles)
      EDGE_STAND_INS.select { |_arg, edges| edges.all? { |edge| styles.key?(edge) } }.keys
    end

    def is_a?(klass)
      klass == Shoes::Shape || super
    end
    alias_method :kind_of?, :is_a?
  end
end
