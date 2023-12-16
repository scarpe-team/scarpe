module Niente
  class Drawable < Shoes::Linkable
    attr_reader :shoes_linkable_id
    attr_reader :parent
    attr_reader :children

    attr_accessor :shoes_type

    def initialize(props)
      @shoes_linkable_id = props.delete("shoes_linkable_id") || props.delete(:shoes_linkable_id)
      @data = props

      super(linkable_id: @shoes_linkable_id)

      # This should only be used for reparenting after a drawable was initially created.
      bind_shoes_event(event_name: "parent", target: shoes_linkable_id) do |new_parent_id|
        display_parent = DisplayService.instance.query_display_drawable_for(new_parent_id)
        if @parent != display_parent
          set_parent(display_parent)
        end
      end

      # When Shoes drawables change properties, we get a change notification here
      bind_shoes_event(event_name: "prop_change", target: shoes_linkable_id) do |prop_changes|
        prop_changes.each do |k, v|
          instance_variable_set("@" + k, v)
        end
        properties_changed(prop_changes) if respond_to?(:properties_changed)
      end

      bind_shoes_event(event_name: "destroy", target: shoes_linkable_id) do
        set_parent(nil)
      end
    end

    def set_parent(new_parent)
      @parent&.remove_child(self)
      new_parent&.add_child(self)
      @parent = new_parent
    end

    # Do not call directly, use set_parent
    def remove_child(child)
      @children ||= []
      unless @children.include?(child)
        STDERR.puts("remove_child: no such child(#{child.inspect}) for"\
          " parent(#{parent.inspect})!")
      end
      @children.delete(child)
    end

    # Do not call directly, use set_parent
    def add_child(child)
      @children ||= []
      @children << child
    end
  end
end

