require 'webrick'
require 'thread'

font_file_url = "http://localhost:8000/fonts/Pacifico.ttf"

Thread.new do
  server = WEBrick::HTTPServer.new(Port: 8000)
  font_directory = File.join(Dir.pwd, 'fonts')

  server.mount_proc('/fonts') do |req, res|
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'GET'
    res['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept'
    WEBrick::HTTPServlet::FileHandler.new(server, font_directory).service(req, res)
  end

  server.start
end

Shoes.app do
  puts font_file_url
  font font_file_url
  para "hi"

end
