# frozen_string_literal: true

class Shoes
  # A Scarpe-compatible display service can set Shoes::Spec.instance to
  # a ShoesSpec testing class, and use it to run Shoes-Spec code.
  # A Shoes application should never do this. It's intended to be used
  # by display services.
  module Spec
    def self.instance
      @instance
    end

    def self.instance=(spec_inst)
      if @instance && @instance != spec_inst
        raise "Lacci can only use a single ShoesSpec implementation at one time!"
      end

      @instance = spec_inst
    end
  end

  # ShoesSpec testing objects can optionally inherit from this object,
  # which shows the ShoesSpec testing API.
  #
  # @see {Shoes::Spec.instance=}
  class SpecInstance
    # Once a Shoes app has been created, this method can be called to
    # execute Shoes-Spec testing code for that application. Shoes-Spec
    # uses Minitest for most of its APIs, and Minitest generally reports
    # results with a class name and test name. If those aren't passed
    # explicitly, the SpecInstance can choose reasonable defaults.
    #
    # The test code should be set up to run automatically from the
    # display service's existing hooks. For instance, the code might
    # run in response to the first heartbeat, if the display service
    # uses heartbeats.
    #
    # The test code will export assertion data in its native format.
    # Multiple display services choose to use the Scarpe-Component
    # for Minitest data export, which is straightforward to import
    # into the Shoes-Spec test harness.
    #
    # @param code [String] the ShoesSpec code to execute
    # @param class_name [String|NilClass] the Minitest class name for reporting or nil
    # @param test_name [String|NilClass] the Minitest test name for reporting or nil
    # @return [void]
    def run_shoes_spec_test_code(code, class_name: nil, test_name: nil)
      raise "Child class should override this!"
    end
  end

  # ShoesSpec instances support finder methods like button() that return
  # a proxy to the corresponding drawable. Those proxies should support
  # standard Shoes::Drawable methods, including the ones appropriate to
  # the same drawable object. They should also support certain other
  # testing-specific methods like "trigger_click" that are used to
  # simulate display-side events during testing.
  #
  # Keep in mind that a proxy will often be in a different process from
  # the Shoes app. So the proxy can't portably return the object or
  # display object, though it could possibly return another proxy for such
  # a thing.
  class SpecProxy
    # The proxy will have finder methods for all drawables, such as
    # button(), edit_line(), etc. How to document those?

    # Trigger a click on a button or button-like drawable. Not every
    # drawable will support this operation.
    def trigger_click()
      raise "Child class should override this!"
    end

    # Trigger a hover over a hoverable drawable. Not every
    # drawable will support this operation. A drawable that supports
    # hover should support leave and vice-versa.
    def trigger_hover()
      raise "Child class should override this!"
    end

    # Trigger ending hover over a hoverable drawable. Not every
    # drawable will support this operation. A drawable that supports
    # hover should support leave and vice-versa.
    def trigger_leave()
      raise "Child class should override this!"
    end

    # Trigger a change in value for a drawable like a list_box
    # with multiple values.
    def trigger_change(value)
      raise "Child class should override this!"
    end
  end
end
