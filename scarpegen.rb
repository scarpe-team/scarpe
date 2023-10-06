# frozen_string_literal: true

require "erb"

class ScarpeGenerator
  def initialize
    @filename = ""
    @shoes_styles = ""
  end

  def generate
    show_welcome_message
    get_filename
    choice = get_choice
    if choice == "1"
      class_template_choice = get_class_template_choice
      get_shoes_styles if class_template_choice != "1"
    end
    generate_files(choice, class_template_choice)
  end

  private

  def show_welcome_message
    welcome_line1 = "Welcome to SCARPE! Let's build something cool!"

    puts "    \e[1;32m"
    puts "    ╔ SCARPE ────────────────────────────────────────────────────────╗"
    puts "    ║                                                                ║"
    puts "    ║      #{welcome_line1}            ║"
    puts "    ║                                                                ║"
    puts "    ╚────────────────────────────────────────────────────────────────╝"
    puts "    \e[0m\n"
  end

  def get_filename
    print "\n\e[33mEnter the filename: \e[0m"
    @filename = gets.chomp
  end

  def get_choice
    loop do
      puts "    \e[32m\e[1m╭──────────────────────────────────────────────────────────────────────────────────╮"
      puts "    │     Do you want to generate:                                                     │"
      puts "    │                                                                                  │"
      puts "    │    1. Class                                                                      │"
      puts "    │    2. Module                                                                     │"
      puts "    │                                                                                  │"
      print "    ╰──────────────────────────────────────────────────────────────────────────────────╯\e[0m\n\n\e[33mEnter your choice:\e[0m "
      choice = gets.chomp

      if choice == "1" || choice == "2"
        return choice
      else
        puts "\e[31m
      ╭─ error ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
      │                                                                                                                                          │
      │                                         Invalid choice. Please enter 1 or 2.                                                               │
      │                                                                                                                                          │
      ╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
      \e[0m"
      end
    end
  end

  def get_class_template_choice
    loop do
      puts "    \e[32m\e[1m╭──────────────────────────────────────────────────────────────────────────────────╮"
      puts "    │     Which type of class file template do you want to generate?                   │"
      puts "    │                                                                                  │"
      puts "    │    1. Basic class template                                                       │"
      puts "    │    2. Class template with basic event bind (button)                              |"
      puts "    │    3. Class template with shapes (e.g., star)                                    |"
      puts "    │                                                                                  │"
      puts "    ╰──────────────────────────────────────────────────────────────────────────────────╯\e[0m\n\n\e[33mEnter your choice:\e[0m "
      choice = gets.chomp

      if ["1", "2", "3"].include?(choice)
        return choice
      else
        puts "\e[31m
        ╭─ error ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
        │                                                                                                                                          │
        │                                         Invalid choice. Please enter 1, 2, or 3.                                                         │
        │                                                                                                                                          │
        ╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
        \e[0m"
      end
    end
  end

  def get_shoes_styles
    print "\n\e[33mDo you want to enter Shoes styles? (y/n):\e[0m "
    response = gets.chomp.downcase
    @shoes_styles = response == "y" || response == "yes" ? get_properties_input : ":dummy"
  end

  def get_properties_input
    print "\e[33mEnter the Shoes styles:(enter like :width,:height)\e[0m  "
    gets.chomp
  end

  def generate_files(choice, class_template_choice)
    case choice
    when "1"
      generate_class_file(class_template_choice)
    when "2"
      generate_module_file
    else
      puts "\e[31mInvalid choice. Exiting...\e[0m"
      exit
    end
    generate_webview_file
    generate_example_file
    add_require_relative_to_drawables_file
    puts "\n\e[1;32mYayyyy! Files generated successfully!\e[0m\n"
  end

  def add_require_relative_to_drawables_file
    drawables_file_path = "lacci/lib/shoes/drawables.rb"
    filename = @filename.downcase
    require_line = "require \"shoes/drawables/#{filename}\""

    File.open(drawables_file_path, "a") do |file|
      file.puts require_line
    end

    puts "Added require_relative to drawables.rb file"
  end

  def generate_webview_file
    webview_template = File.read("templates/webview_template.erb")
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
    example_template = File.read("templates/example_template.erb")
    example_content = ERB.new(example_template).result(binding_with_argument)

    File.write("examples/#{@filename}.rb", example_content)
  end

  def generate_class_file(class_template_choice)
    case class_template_choice
    when "1"
      class_template_file = "templates/basic_class_template.erb"
    when "2"
      class_template_file = "templates/class_template_with_event_bind.erb"
    when "3"
      class_template_file = "templates/class_template_with_shapes.erb"
    end

    class_template = File.read(class_template_file)
    class_content = ERB.new(class_template).result(binding_with_argument(class_template_choice))

    File.write("lacci/lib/shoes/drawables/#{@filename}.rb", class_content)
  end

  def generate_module_file
    module_template = File.read("templates/module_template.erb")
    module_content = ERB.new(module_template).result(binding_with_argument(""))

    File.write("lib/scarpe/#{@filename}.rb", module_content)
  end

  def binding_with_argument(class_template_choice = nil)
    capitalized_argument = @filename.capitalize
    binding.dup.tap do |b|
      b.local_variable_set(:argument, capitalized_argument)
      b.local_variable_set(:shoes_styles, @shoes_styles)
      b.local_variable_set(:class_template_choice, class_template_choice) unless class_template_choice.nil?
    end
  end
end

generator = ScarpeGenerator.new
generator.generate
