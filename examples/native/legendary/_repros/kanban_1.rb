# A text field's font: string keeps its family and size but loses its weight.
#
# Expected: both fields and the para below them draw "bold 16px" in bold, the way the
# para does; the font string parses to weight 700 (native/src/style/font.rs parse_font).
# Actual (native): the edit_line and the edit_box draw regular weight at 16 px (Georgia
# is honoured in the box), while the para with the same string is bold.
Shoes.app(width: 420, height: 200) do
  stack margin: 16 do
    edit_line text: "edit_line, bold 16px", font: "bold 16px", width: 380
    edit_box text: "edit_box, Georgia bold 16px", font: "Georgia bold 16px", width: 380, height: 40
    para "para, bold 16px", font: "bold 16px"
  end
end
