module Scarpe
  module Container
    def append(&block)
      prev_id = @app.current_id
      @app.current_id = object_id
      @app.instance_eval &block
      @app.current_id = prev_id
    end
  end
end