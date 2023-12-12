# html_ci: false
# This is due to a button rendering issue

require 'nokogiri'
require 'open-uri'
require 'tempfile'

class Comic
  attr_reader :rss, :title

  def initialize(file_path)
    @rss = Nokogiri::XML(File.open(file_path))
    @title = @rss.at("//channel/title").text
  end

  def items
    @rss.search("//channel/item")
  end

  def latest_image
    item = @rss.at("//channel/item[1]")
    description = item.at("description").text
    image_url = description.match(/src="([^"]+\.\w+)"/)[1]
    title = item.at("title").text
    [title, image_url]
  end
end

Shoes.app width: 800, height: 600 do
  background "#555"
  @title = "Web Funnies"

  stack margin: 10 do
    title strong(@title), align: "center", stroke: "#DFA", margin: 0
    para "(loaded from RSS feeds)", align: "center", stroke: "#DFA", margin: 0

    url = "https://xkcd.com/rss.xml"
    rss_string = URI.open(url).read

    file = Tempfile.new('download')
    file.write(rss_string)
    file.close
    file_path = file.path

    c = Comic.new(file_path)

    stack width: "100%", margin: 10, border: 1 do
      stack  do
        background "#333", curve: 4
        caption c.title, stroke: "#CD9", margin: 4
      end

      title, image_url = c.latest_image

      flow do
        image image_url
        para strong(title), margin: 8, stroke: white
      end
    end
  end
end
