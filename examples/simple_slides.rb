
Shoes.app(title: 'Shoes Slides', width: 800, height: 600) do
  $slides = [
    {
      title: 'Welcome to Shoes!',
      content: 'Ah, yeah, Shoes!
      Who said nobody knows Shoes? Well, let me introduce you to a feline expert in the art of Ruby Desktop GUI Libs.

      Meet Professor Whiskers the renowned programmer cat! Not only does he know Shoes, but he\'s also a master of all things Ruby and desktop GUI!

      if you\'re ready to learn Ruby Desktop GUI Libs with a touch of feline finesse, come join us on this whimsical adventure! Professor Whiskers guarantees a purr-fectly entertaining and enlightening experience, where every step forward is as delightful as a cat chasing a laser pointer.

      Remember, in the world of programming, there\'s always room for humor, and Professor Whiskers is here to remind us that even the most serious tasks can be approached with a playful attitude. So, put on your coding slippers and let this extraordinary cat guide you through the marvelous world of Shoes Desktop GUI Libs!

      Meow! join the discord server for more meows!
      ',
      image: "https://img.freepik.com/premium-photo/funny-smart-cat-professor-with-glasses-illustration-generative-ai_845977-709.jpg?w=700&h=300"
    },
    {
      title: 'Behold the teachings of Professor Whiskers! here\'s a shoes for you!',
      content: 'Meow!',
      image: "http://shoesrb.com/manual/static/shoes-icon.png"
    },
    {
      title: 'Path to englightenment',
      content: 'Meowww meow meow meow meow meow meow meow meow meow meow meow meow meow meow meow meow!',
    }
  ]

  stack do
    $slides.each_with_index do |slide, index|
      border black, strokewidth: 2 do
        flow(margin: 10) do
          para strong("Slide #{index + 1}: #{slide[:title]}"), margin_bottom: 10
          para slide[:content]
          image slide[:image]
        end
      end
    end
  end

  button 'Previous Slide' do
    prev_slide = self.slide_index - 1
    prev_slide = $slides.length - 1 if prev_slide < 0
    self.slide_index = prev_slide
  end

  button 'Next Slide' do
    next_slide = self.slide_index + 1
    next_slide = 0 if next_slide >= $slides.length
    self.slide_index = next_slide
  end

  def slide_index
    @slide_index ||= 0
  end

  def slide_index=(value)
    @slide_index = value
    update_slide
  end

  def update_slide
    current_slide = $slides[self.slide_index]
    @title.replace "Slide #{self.slide_index + 1}: #{current_slide[:title]}"
    @content.replace current_slide[:content]
    @image.replace  current_slide[:image]
  end

  @title = para strong("Slide 1: #{$slides[0][:title]}"), margin_bottom: 10
  @content = para $slides[0][:content]
  @image = image($slides[0][:image])
end
