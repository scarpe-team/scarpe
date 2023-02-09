require "scarpe"

Shoes.app do
  para "Manuscript:"
  @manuscript = edit_box(width: "100%") do
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim."
  end
  @char_count = para "#{@manuscript.text.length} characters"
  @manuscript.change { |text|
    @char_count.replace("#{text.length} characters")
  }
end
