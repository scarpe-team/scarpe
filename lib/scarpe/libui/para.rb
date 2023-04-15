# frozen_string_literal: true

class Scarpe
  class << self
    # Sure we can showcase the defaults here so folks can avoid the insanity.
    def para(text, size: 12.0, stroke: black, weight: nil, fill: nil, underline: nil, italic: nil, hbox: nil)
      Para.new(
        text,
        size: size,
        stroke: stroke,
        weight: weight,
        fill: fill,
        underline: underline,
        italic: italic,
        hbox: hbox,
      )
    end
  end

  class Para
    def initialize(text, size:, stroke:, weight:, fill:, underline:, italic:, hbox:)
      # old flow for label
      # UI.box_append($vbox, UI.new_label(text), 0)
      @hbox = hbox
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
      attr_builder << UI.new_color_attribute(
        stroke[0].to_f / 255.0, stroke[1].to_f / 255.0, stroke[2].to_f / 255.0, stroke[3].to_f || 1.0
      ) if stroke
      attr_builder << UI.new_background_attribute(
        fill[0].to_f / 255.0, fill[1].to_f / 255.0, fill[2].to_f / 255.0, fill[3].to_f || 1.0
      ) if fill
      attr_builder << UI.new_underline_attribute(UI::UnderlineSingle) if underline == "single"
      attr_builder << UI.new_underline_attribute(UI::UnderlineDouble) if underline == "double"
      # NOTE- this is a boolean, not a string. and not part of core scarpe api. we set this internally.
      attr_builder << UI.new_italic_attribute(UI::TextItalicNormal) if italic == true
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
      UI.box_append(@hbox, @area, 1)

      # I have absolutely no idea what is going on with boxes so need to look into this next
      # probably with stacks and flows
      # UI.window_set_margined($main_window, 1)
      UI.window_set_child($main_window, @hbox)
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
