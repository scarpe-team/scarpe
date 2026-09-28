# Return in an edit_line reaches nothing: no finish block, no keypress.
#
# Expected (Shoes 3.2.15 and later): `field.finish = proc { }` runs its proc when Return is
# pressed in the field (s3t_edit_line.c:15 defines finish=, and :42-49 stores it as the
# field's "donekey" block), so a one-line form can be sent with Return.
# Actual (Lacci + native): EditLine has no finish=, so the line below raises NoMethodError
# and is rescued here; and Return in a focused field is not a keypress either, since keypress
# skips unmodified keys while a field has focus (DESIGN 4.3). Apps fall back to an edit_box,
# whose change hears the "\n", or to Cmd-Return, which does reach keypress.
Shoes.app(width: 360, height: 140) do
  @field = edit_line width: 320, margin: 16
  @said = para "Type, then press Return", margin: [16, 0, 0, 0]
  begin
    @field.finish = proc { @said.replace "finish ran: #{@field.text}" }
  rescue NoMethodError => e
    @said.replace "no finish=: #{e.message[0, 60]}"
  end
  keypress { |key| @said.replace "keypress #{key.inspect}" }
end
