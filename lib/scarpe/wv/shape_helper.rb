# frozen_string_literal: true

module ShapeHelper
  def path_commands
    $path_commands ||= []
  end

  def move_to(x, y)
    validate_coordinates(x, y)
    path_commands << "M #{x} #{y}"
  end

  def line_to(x, y)
    validate_coordinates(x, y)
    path_commands << "L #{x} #{y}"
  end

  def shape_path
    path_commands_str = path_commands.join(" ")
    path_commands_str
  end

  def colors
    $colors ||= []
  end

  def fill(color)
    $current_color = color
  end

  def color_for_fill
    $current_color || "black"
  end

  private

  def validate_coordinates(x, y)
    raise ArgumentError, "Invalid coordinates: x=#{x}, y=#{y}" unless valid_coordinate?(x) && valid_coordinate?(y)
  end

  def valid_coordinate?(coordinate)
    coordinate.is_a?(Numeric)
  end
end
