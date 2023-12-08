# Require the WEBrick library
require 'webrick'

# Configuration for the server
configuration = {
  Port: 4567,
  DocumentRoot: File.join(File.dirname(__FILE__), '..', '..', 'examples', 'local_assets')
}

# Create a new instance of WEBrick::HTTPServer with the configuration
server = WEBrick::HTTPServer.new(configuration)

# Define a custom servlet to handle file requests
class FileServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    relative_path = request.path
    path = File.join(@config[:DocumentRoot], relative_path)

    if File.exist?(path) && !File.directory?(path)
      begin
        file_content = File.read(path)

        response.status = 200
        response['Content-Type'] = WEBrick::HTTPUtils.mime_type(path, WEBrick::HTTPUtils::DefaultMimeTypes)
        response['Content-Disposition'] = "inline; filename=#{File.basename(path)}"
        response.body = file_content
      rescue StandardError => e
        response.status = 500
        response.body = 'Internal Server Error'
      end
    else
      response.status = 404
      response.body = 'File not found'
    end
  end
end

# Mount the custom servlet at the root URL
server.mount('/', FileServlet)

# Set up a signal trap to gracefully shut down the server on interrupt (e.g., Ctrl+C)
trap('INT') do
  server.shutdown
end

# Start the server in a separate thread
server_thread = Thread.new { server.start }

# Shoes application to display the file from the local server
Shoes.app do
  stack do
    flow do
      para "Enter the file path: (e.g., sample.gif, sample.mp4)"
      @file_path = edit_line
    end

    button "Display File" do
      file_path = @file_path.text

      begin
        file_extension = File.extname(file_path).downcase

        case file_extension
        when '.png', '.jpg', '.jpeg', '.gif'
          image "http://localhost:4567/#{file_path}"
        when '.mp4', '.mov'
          video "http://localhost:4567/#{file_path}"
        else
          para "Unsupported file type"
        end
      rescue StandardError => e
        para "Error: #{e.message}"
      end
    end
  end

  # Ensure the Shoes application is closed before stopping the server
  at_exit do
    server_thread.join if server_thread.alive?
    server.shutdown
  end
end
