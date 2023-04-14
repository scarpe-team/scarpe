# spike

# frozen_string_literal: true

# TODO: how I handle boxes and blocks is completely disorganized. Using globals are the least of my worries right now.

require "libui"

UI = LibUI

COLORS = {
  aliceblue: [240, 248, 255],
  antiquewhite: [250, 235, 215],
  aqua: [0, 255, 255],
  aquamarine: [127, 255, 212],
  azure: [240, 255, 255],
  beige: [245, 245, 220],
  bisque: [255, 228, 196],
  black: [0, 0, 0],
  blanchedalmond: [255, 235, 205],
  blue: [0, 0, 255],
  blueviolet: [138, 43, 226],
  brown: [165, 42, 42],
  burlywood: [222, 184, 135],
  cadetblue: [95, 158, 160],
  chartreuse: [127, 255, 0],
  chocolate: [210, 105, 30],
  coral: [255, 127, 80],
  cornflowerblue: [100, 149, 237],
  cornsilk: [255, 248, 220],
  crimson: [220, 20, 60],
  cyan: [0, 255, 255],
  darkblue: [0, 0, 139],
  darkcyan: [0, 139, 139],
  darkgoldenrod: [184, 134, 11],
  darkgray: [169, 169, 169],
  darkgreen: [0, 100, 0],
  darkkhaki: [189, 183, 107],
  darkmagenta: [139, 0, 139],
  darkolivegreen: [85, 107, 47],
  darkorange: [255, 140, 0],
  darkorchid: [153, 50, 204],
  darkred: [139, 0, 0],
  darksalmon: [233, 150, 122],
  darkseagreen: [143, 188, 143],
  darkslateblue: [72, 61, 139],
  darkslategray: [47, 79, 79],
  darkturquoise: [0, 206, 209],
  darkviolet: [148, 0, 211],
  deeppink: [255, 20, 147],
  deepskyblue: [0, 191, 255],
  dimgray: [105, 105, 105],
  dodgerblue: [30, 144, 255],
  firebrick: [178, 34, 34],
  floralwhite: [255, 250, 240],
  forestgreen: [34, 139, 34],
  fuchsia: [255, 0, 255],
  gainsboro: [220, 220, 220],
  ghostwhite: [248, 248, 255],
  gold: [255, 215, 0],
  goldenrod: [218, 165, 32],
  green: [0, 128, 0],
  greenyellow: [173, 255, 47],
  honeydew: [240, 255, 240],
  hotpink: [255, 105, 180],
  indianred: [205, 92, 92],
  indigo: [75, 0, 130],
  ivory: [255, 255, 240],
  khaki: [240, 230, 140],
  lavender: [230, 230, 250],
  lavenderblush: [255, 240, 245],
  lawngreen: [124, 252, 0],
  lemonchiffon: [255, 250, 205],
  lightblue: [173, 216, 230],
  lightcoral: [240, 128, 128],
  lightcyan: [224, 255, 255],
  lightgoldenrodyellow: [250, 250, 210],
  lightgreen: [144, 238, 144],
  lightgrey: [211, 211, 211],
  lightpink: [255, 182, 193],
  lightsalmon: [255, 160, 122],
  lightseagreen: [32, 178, 170],
  lightskyblue: [135, 206, 250],
  lightslategray: [119, 136, 153],
  lightsteelblue: [176, 196, 222],
  lightyellow: [255, 255, 224],
  lime: [0, 255, 0],
  limegreen: [50, 205, 50],
  linen: [250, 240, 230],
  magenta: [255, 0, 255],
  maroon: [128, 0, 0],
  mediumaquamarine: [102, 205, 170],
  mediumblue: [0, 0, 205],
  mediumorchid: [186, 85, 211],
  mediumpurple: [147, 112, 219],
  mediumseagreen: [60, 179, 113],
  mediumslateblue: [123, 104, 238],
  mediumspringgreen: [0, 250, 154],
  mediumturquoise: [72, 209, 204],
  mediumvioletred: [199, 21, 133],
  midnightblue: [25, 25, 112],
  mintcream: [245, 255, 250],
  mistyrose: [255, 228, 225],
  moccasin: [255, 228, 181],
  navajowhite: [255, 222, 173],
  navy: [0, 0, 128],
  oldlace: [253, 245, 230],
  olive: [128, 128, 0],
  olivedrab: [107, 142, 35],
  orange: [255, 165, 0],
  orangered: [255, 69, 0],
  orchid: [218, 112, 214],
  palegoldenrod: [238, 232, 170],
  palegreen: [152, 251, 152],
  paleturquoise: [175, 238, 238],
  palevioletred: [219, 112, 147],
  papayawhip: [255, 239, 213],
  peachpuff: [255, 218, 185],
  peru: [205, 133, 63],
  pink: [255, 192, 203],
  plum: [221, 160, 221],
  powderblue: [176, 224, 230],
  purple: [128, 0, 128],
  red: [255, 0, 0],
  rosybrown: [188, 143, 143],
  royalblue: [65, 105, 225],
  saddlebrown: [139, 69, 19],
  salmon: [250, 128, 114],
  sandybrown: [244, 164, 96],
  seagreen: [46, 139, 87],
  seashell: [255, 245, 238],
  sienna: [160, 82, 45],
  silver: [192, 192, 192],
  skyblue: [135, 206, 235],
  slateblue: [106, 90, 205],
  slategray: [112, 128, 144],
  snow: [255, 250, 250],
  springgreen: [0, 255, 127],
  steelblue: [70, 130, 180],
  tan: [210, 180, 140],
  teal: [0, 128, 128],
  thistle: [216, 191, 216],
  tomato: [255, 99, 71],
  turquoise: [64, 224, 208],
  violet: [238, 130, 238],
  wheat: [245, 222, 179],
  white: [255, 255, 255],
  whitesmoke: [245, 245, 245],
  yellow: [255, 255, 0],
  yellowgreen: [154, 205, 50],
}

COLORS.each do |color, rgb|
  define_method(color) do |alpha = 1.0|
    rgb + [alpha]
  end
end

def gray(darkness = 128, alpha = 1.0)
  [darkness, darkness, darkness, alpha]
end

def rgb(r, g, b, a = 1.0)
  [r, g, b, a]
end

class Scarpe
  class << self
    def app(title: "Scarpe app", height: 400, width: 400)
      setup(title, height, width)
      yield
      closing_stuff
    end

    def setup(title, height, width)
      UI.init

      $main_window = UI.new_window(title, height, width, 1)
      $vbox = UI.new_vertical_box
    end

    def closing_stuff
      UI.window_on_closing($main_window) do
        puts "Bye Bye"
        UI.control_destroy($main_window)
        UI.quit
        0
      end

      UI.control_show($main_window)

      # Add main box to main window, close everything out
      UI.window_set_child($main_window, $vbox)
      UI.main
      UI.quit
    end

    # Top-level Shoes API methods
    def alert(text, title: "Information")
      UI.msg_box($main_window, title, text)
    end

    def button(text)
      @button = UI.new_button(text)

      UI.button_on_clicked(@button) do
        puts "herpderpin in the dark"
        yield
      end

      # We're appending this to the top level box. (Note, may want to apply to "parent" long term)
      UI.box_append($vbox, @button, 0)
    end

    # Sure we can showcase the defaults here so folks can avoid the insanity.
    def para(text, size: 12.0, stroke: black, weight: nil, fill: nil, underline: nil, italic: nil)
      Para.new(text, size: size, stroke: stroke, weight: weight, fill: fill, underline: underline, italic: italic)
    end
  end

  class Para
    def initialize(text, size:, stroke:, weight:, fill:, underline:, italic:)
      # old flow for label
      # UI.box_append($vbox, UI.new_label(text), 0)

      @handler = UI::FFI::AreaHandler.malloc
      @handler.to_ptr.free = Fiddle::RUBY_FREE
      @area = UI.new_area(@handler)

      str = ""
      @attr_str = UI.new_attributed_string(str)

      font_weight = case weight
      when "ultralight"
        UI::TextWeightUltraLight
      when "light"
        UI::TextWeightLight
      when "book"
        UI::TextWeightBook
      when "strong"
        UI::TextWeightBold
      when "bold"
        UI::TextWeightBold
      when "ultrabold"
        UI::TextWeightUltraBold
      else
        nil
      end
      stroke2 = stroke.dup
      attr_builder = []
      attr_builder << UI.new_weight_attribute(font_weight) if font_weight
      attr_builder << UI.new_size_attribute(size) if size
      attr_builder << UI.new_color_attribute(stroke[0].to_f / 255.0, stroke[1].to_f / 255.0, stroke[2].to_f / 255.0, stroke[3].to_f || 1.0) if stroke
      attr_builder << UI.new_background_attribute(fill[0].to_f / 255.0, fill[1].to_f / 255.0, fill[2].to_f / 255.0, fill[3].to_f || 1.0) if fill
      attr_builder << UI.new_underline_attribute(UI::UnderlineSingle) if underline == "single"
      attr_builder << UI.new_underline_attribute(UI::UnderlineDouble) if underline == "double"
      attr_builder << UI.new_italic_attribute(UI::TextItalicNormal) if italic == true # NOTE- this is a boolean, not a string. and not part of core scarpe api. we set this internally.
      attr_builder << UI.new_italic_attribute(UI::TextItalicItalic) if italic == "double"
      attr_builder << UI.new_underline_color_attribute(
        UI::UnderlineColorCustom,
        stroke2[0].to_f / 255.0,
        stroke2[1].to_f / 255.0,
        stroke2[2].to_f / 255.0,
        stroke2[3].to_f || 1.0,
      ) if underline == "single" && stroke
      # # UI.new_stretch_attribute(UI::TextStretchCondensed),stretch not implemented
      append_with_attribute(
        text,
        *attr_builder,
      )
      attach_text
    end

    private

    def draw_text
      Fiddle::Closure::BlockCaller.new(0, [1, 1, 1]) do |_, _, adp|
        area_draw_params = UI::FFI::AreaDrawParams.new(adp)
        default_font = UI::FFI::FontDescriptor.malloc
        default_font.to_ptr.free = Fiddle::RUBY_FREE
        default_font.Family = "Georgia"
        default_font.Size = 13
        # default_font.Weight = 500
        default_font.Italic = 0
        default_font.Stretch = 4
        params = UI::FFI::DrawTextLayoutParams.malloc
        params.to_ptr.free = Fiddle::RUBY_FREE

        # UI.font_button_font(font_button, default_font)
        params.String = @attr_str
        params.DefaultFont = default_font
        params.Width = area_draw_params.AreaWidth
        params.Align = 0
        text_layout = UI.draw_new_text_layout(params)
        UI.draw_text(area_draw_params.Context, text_layout, 0, 0)
        UI.draw_free_text_layout(text_layout)
      end
    end

    def attach_text
      @handler.Draw = draw_text

      # Assigning to local variables
      # This is intended to protect Fiddle::Closure from garbage collection.
      do_nothing = Fiddle::Closure::BlockCaller.new(0, [0]) {}
      key_event  = Fiddle::Closure::BlockCaller.new(1, [0]) { 0 }
      @handler.MouseEvent   = do_nothing
      @handler.MouseCrossed = do_nothing
      @handler.DragBroken   = do_nothing
      @handler.KeyEvent     = key_event

      # do i shove it in vbox or para_box?
      # @para_box = UI.new_vertical_box
      # UI.box_set_padded(@para_box, 1)
      UI.box_append($vbox, @area, 1)

      # I have absolutely no idea what is going on with boxes so need to look into this next
      # probably with stacks and flows
      # UI.window_set_margined($main_window, 1)
      UI.window_set_child($main_window, $vbox)
    end

    def append_with_attribute(what, *args)
      start_pos = UI.attributed_string_len(@attr_str)
      end_pos = start_pos + what.length
      UI.attributed_string_append_unattributed(@attr_str, what)
      args.each do |attr|
        # puts "*" * 80
        # puts "attr: #{attr}"
        # puts "*" * 80
        # sleep 1
        UI.attributed_string_set_attribute(@attr_str, attr, start_pos, end_pos)
      end
    end
  end
end

def method_missing(method, ...)
  case method.to_s
  when "para"
    Scarpe.para(...)
  when "alert"
    Scarpe.alert(...)
  when "button"
    Scarpe.button(...)
  else
    super
  end
end

def respond_to_missing?(method_name, include_private = false)
  [
    "para",
    "alert",
    "button",
  ].include?(method_name.to_s) || super
end

Shoes = Scarpe

Shoes.app(title: "Hello world!", height: 1000, width: 1000) do
  para "Check out this paragraph",
    size: 50,
    stroke: red,
    weight: "ultralight",
    fill: yellow
  para "I'm just a fish though",
    size: 99,
    underline: "single",
    italic: true,
    weight: "bold",
    stroke: darkred,
    fill: aquamarine
  button("Flimflam") do
    alert "You clicked the button"
  end
end
