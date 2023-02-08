Shoes.app do
  stack do
    title "Searching Google", :size => 16
    @status = para "One moment..."

    download "http://www.google.com/search?q=shoes" do |goog|
      @status.text = "Headers: " + goog.response.body
    end
  end
end
