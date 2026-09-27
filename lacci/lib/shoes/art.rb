# frozen_string_literal: true

class Shoes
  # The drawing methods arc, arrow, line, oval, rect and star are each headed
  # "» Shoes::Shape" in the manual (1665-1826, ledger E11). Their drawables keep their
  # own classes, so a display is still told "Oval" or "Rect", and Shoes::Shape stays
  # the shape { } block, so `Shoes::Shape === drawable` and the shape finder mean only
  # that. They answer is_a?(Shoes::Shape) the way ActiveSupport::Duration answers
  # is_a? for the class of its value.
  module Art
    def is_a?(klass)
      klass == Shoes::Shape || super
    end
    alias_method :kind_of?, :is_a?
  end
end
