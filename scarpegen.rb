# frozen_string_literal: true

require "erb"

class ScarpeGenerator
  def initialize(argument)
    @argument = argument
  end

  def generate_files
    generate_class_file
    # generate_webview_file
    # generate_example_file

    puts "Yayyyy! Files generated successfully! "
  end

  private

  def generate_class_file
    class_template = File.read("templates/class_template.erb")
    class_content = ERB.new(class_template).result(binding_with_argument)

    File.write("lib/scarpe/#{@argument}.rb", class_content)
  end

  def generate_webview_file
    webview_template = File.read("templates/webview_template.erb")
    webview_content = ERB.new(webview_template).result(binding_with_argument)

    FileUtils.mkdir_p("lib/scarpe/wv")
    File.write("lib/scarpe/wv/#{@argument}.rb", webview_content)
  end

  def generate_example_file
    example_template = File.read("templates/example_template.erb")
    example_content = ERB.new(example_template).result(binding_with_argument)

    File.write("examples/#{@argument}.rb", example_content)
  end

  def binding_with_argument
    capitalized_argument = @argument.capitalize
    binding.dup.tap { |b| b.local_variable_set(:argument, capitalized_argument) }
  end
end

def validate_argument
  if ARGV.empty?
    puts "Ah! hm Please provide file name as a argument."
    exit
  end
end

argument = ARGV[0]
validate_argument

generator = ScarpeGenerator.new(argument)
generator.generate_files
