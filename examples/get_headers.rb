Shoes.app do
  stack do
    title "Searching", :size => 16
    @status = para "One moment..."

    download "http://www.google.com/search?q=shoes" do |goog|
      @status.replace "Headers: " + goog.response.headers.inspect
    end
  end
end
