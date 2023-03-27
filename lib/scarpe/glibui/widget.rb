# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIWidget < DisplayService::Linkable
    class << self
      def display_class_for(scarpe_class_name)
        scarpe_class = Object.const_get(scarpe_class_name)
        unless scarpe_class.ancestors.include?(Scarpe::DisplayService::Linkable)
          raise "Scarpe GlimmerLibUI can only get display classes for Scarpe linkable widgets, not #{scarpe_class.inspect}!"
        end

        klass = Scarpe.const_get("GlimmerLibUI" + scarpe_class.name.split("::")[-1])
        if klass.nil?
          raise "Couldn't find corresponding Scarpe GlimmerLibUI class for #{scarpe_class.inspect}!"
        end

        klass
      end
    end

    attr_reader :shoes_linkable_id
    attr_reader :parent

    def initialize(properties)
      # Call method, which looks up the parent
      @shoes_linkable_id = properties["shoes_linkable_id"]
      unless @shoes_linkable_id
        raise "Could not find property shoes_linkable_id in #{properties.inspect}!"
      end

      # Set the display properties
      properties.each do |k, v|
        next if k == "shoes_linkable_id"

        instance_variable_set("@" + k, v)
      end

      # The parent field is *almost* simple enough that a typed display property would handle it.
      bind_shoes_event(event_name: "parent", target: shoes_linkable_id) do |new_parent_id|
        display_parent = GlimmerLibUIDisplayService.instance.query_display_widget_for(new_parent_id)
        if @parent != display_parent
          set_parent(display_parent)
        end
      end

      super()
    end

    def set_parent(new_parent)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
    end

    protected

    # Do not call directly, use set_parent
    def remove_child(child)
      @children ||= []
      unless @children.include?(child)
        puts "remove_child: no such child(#{child.inspect}) for parent(#{parent.inspect})!"
      end
      @children.delete(child)
    end

    # Do not call directly, use set_parent
    def add_child(child)
      @children ||= []
      @children << child
    end

    public

    # This binds a Scarpe JS callback, handled via a single dispatch point in the document root
    def bind(event, &block)
      raise("Widget has no linkable_id! #{inspect}") unless linkable_id

      GlimmerLibUIDisplayService.instance.doc_root.bind("#{linkable_id}-#{event}", &block)
    end
  end
end
