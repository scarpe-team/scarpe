# frozen_string_literal: true

def generate_docpages_list
  @file_list = true

  # Customise these more?
  @items = options.files.select { |m| m.filename.end_with?(".md") }

  @list_title = "Doc Pages List"
  @list_type = "file"
  generate_list_contents
  @file_list = nil
end
