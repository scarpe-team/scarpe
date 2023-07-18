#!/usr/bin/env scarpe

# Check the examples directory for duplicate files

require "digest"

Dir.chdir __dir__ # Run the script with this as the current dir

BOTTOM_DISPLAY_INSTRUCTIONS = "(Click on a list item for details)"
DIVIDER = " --- "

def all_duplicate_files
  checked_files = Dir["**/*"].select { |f| !File.directory?(f) }.to_a
  hash_digests = {}

  checked_files.each do |file|
    digest = Digest::SHA256.digest File.read(file)
    hash_digests[digest] ||= []
    hash_digests[digest] << file
  end

  # If a checksum has more than one file matching, they're dups
  hash_digests.values.select { |file_set| file_set.size > 1 }
end

def update_dup_list
  $top_text.replace "Loading..."
  all_dups = all_duplicate_files
  list_items = []
  all_dups.each do |file_set|
    list_items << file_set.join(DIVIDER)
  end
  $top_text.replace "Found #{all_dups.size} likely duplicates."
  $dup_list.items = list_items
end

def highlander_the_selected_item
  selected = $dup_list.selected_item
  if !selected || selected == "" || !selected.include?(DIVIDER)
    $bottom_display.replace("Select an item first!")
    return
  end

  files = selected.split(DIVIDER)
  first_content = File.read files[0]
  files[1..-1].each do |sean_connery|
    if File.read(sean_connery) != first_content
      $bottom_display.replace("File #{sean_connery} wasn't actually a duplicate! Oops!")
      return
    end

    # This would fail if, for instance, the file wasn't in Git. You can change this example
    # for your own needs, but I'm doing git-rm for me.
    system("git rm #{sean_connery}")
    unless $?.success?
      $bottom_display.replace("Got an error while git-removing #{sean_connery.inspect}: #{$?.inspect}")
      return
    end
  end

  $dup_list.selected_item = nil
  $bottom_display.replace BOTTOM_DISPLAY_INSTRUCTIONS
  update_dup_list
end

Shoes.app(title: "Highlander") do
  stack :margin => 40 do
    $top_text = para "Loading..."
    $dup_list = list_box(:items => []).change do
      $bottom_display.replace "Selected duplicates: #{$dup_list.selected_item.inspect}"
    end

    update_dup_list

    button "Refresh the list!" do
      $top_text.replace "Refreshing..."
      $bottom_display.replace BOTTOM_DISPLAY_INSTRUCTIONS
      update_dup_list
    end

    $bottom_display = para BOTTOM_DISPLAY_INSTRUCTIONS
    $delete_button = button "There Can Be Only One!" do
      highlander_the_selected_item
    end
  end
end

# And code down here doesn't get run.
#update_dup_list
