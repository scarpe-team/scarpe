# frozen_string_literal: true
require 'erb'

class ScarpeGenerator
  def initialize(filename, display_properties)
    @filename = filename
    @display_properties = display_properties
  end

  def generate_files(choice, class_template_choice)
    case choice
    when 'Class'
      generate_class_file(class_template_choice)
    when 'Module'
      generate_module_file
    else
      puts('Invalid choice. Exiting...')
      exit
    end

    generate_webview_file
    generate_example_file
    add_require_relative_to_widgets_file

    puts('Yayyyy! Files generated successfully!')
  end


  def add_require_relative_to_widgets_file
    widgets_file_path = "lib/scarpe/widgets.rb"
    filename = @filename.downcase
    require_line = "require_relative \"#{filename}\""

    File.open(widgets_file_path, "a") do |file|
      file.puts require_line
    end

    puts "Added require_relative to widgets.rb file"
  end

  def generate_class_file(class_template_choice)
    case class_template_choice
    when 'Basic'
      class_template_file = 'templates/basic_class_template.erb'
    when 'Event Bind'
      class_template_file = 'templates/class_template_with_event_bind.erb'
    when 'Shapes'
      class_template_file = 'templates/class_template_with_shapes.erb'
    else
      puts('Invalid class template choice. Exiting...')
      exit
    end

    class_template = File.read(class_template_file)
    class_content = ERB.new(class_template).result(binding_with_argument)

    File.write("lib/scarpe/#{@filename}.rb", class_content)
  end

  def generate_module_file
    module_template = File.read('templates/module_template.erb')
    module_content = ERB.new(module_template).result(binding_with_argument)

    File.write("lib/scarpe/#{@filename}.rb", module_content)
  end

  def generate_webview_file
    webview_template = File.read('templates/webview_template.erb')
    webview_content = ERB.new(webview_template).result(binding_with_argument)

    File.write("lib/scarpe/wv/#{@filename}.rb", webview_content)
    puts "generated webview file"
    add_require_relative_to_wv_file
  end

  def add_require_relative_to_wv_file
    wv_file_path = "lib/scarpe/wv.rb"
    filename = @filename.downcase
    require_line = "require_relative \"wv/#{filename}\""

    File.open(wv_file_path, "a") do |file|
      file.puts require_line
    end

    puts "Added require_relative to wv.rb file"
  end

  def generate_example_file
    example_template = File.read('templates/example_template.erb')
    example_content = ERB.new(example_template).result(binding_with_argument)

    File.write("examples/#{@filename}.rb", example_content)
  end

  def binding_with_argument
    capitalized_argument = @filename.capitalize
    binding.dup.tap do |b|
      b.local_variable_set(:argument, capitalized_argument)
      b.local_variable_set(:display_properties, @display_properties)
    end
  end
end

Shoes.app(title: 'Templates') do
  stack margin: 40 do
    stack width: 400 do
      para 'Enter the filename: '
      $filename_input = edit_line
    end

    stack width: 400 do
      para 'Enter display properties (like :height,:text) '
      $properties_input = edit_line
    end

    stack width: 400 do
      para 'Do you want to generate:'
      $choice_input = list_box items: ['Class', 'Module']
    end

    stack width: 400,margin_bottom:8  do
      para 'Which type of class file template do you want to generate:'
      $class_template_choice_input = list_box items: ['Shapes', 'Event Bind', 'Basic']
    end

    button 'Generate Files!',color:"#FF7116",padding_bottom:"8",padding_top:"8",text_color:"white",font_size:"16" do
      filename = $filename_input.text
      display_properties = $properties_input.text
      choice = $choice_input.selected_item

      generator = ScarpeGenerator.new(filename, display_properties)

      if choice == 'Class'
        generator.generate_files(choice, $class_template_choice_input.selected_item)
      else
        generator.generate_files(choice, nil)
      end
    end
  end
end
