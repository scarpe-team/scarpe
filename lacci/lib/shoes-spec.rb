# frozen_string_literal: true

class Shoes
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
end
