class Scarpe
  class Image < Scarpe::Widget
    def initialize(url)
      @url = url
    end

    def element
      HTML.render do |h|
        h.img(id: object_id, src: @url)
      end
    end
  end
end
