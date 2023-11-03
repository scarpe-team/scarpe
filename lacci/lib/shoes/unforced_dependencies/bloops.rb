# frozen_string_literal: true

class Bloops
  # SAW, SINE, SQUARE and friends
  def const_missing(name)
    begin
      require "bloops"
      Bloops.const_get(name)
    rescue LoadError
      raise "\n\n== You need to install Bloops! ==\n\n== If you want to jam to sweet tunes ==\n\n"
    end
  end

  def initialize
    begin
      require "bloops"
      Bloops.new
    rescue LoadError
      raise "\n\n== You need to install Bloops! ==\n\n== If you want to jam to sweet tunes ==\n\n"
    end
  end
end
