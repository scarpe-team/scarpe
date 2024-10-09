Shoes.app(title: 'URL Routing with Parameters Example', width: 300, height: 200) do
  style(Shoes::Para, size: 10)
  style(Shoes::Button, width: 80)

  url '/', :index
  url '/cats/(\d+)', :cat
  url '/dogs/(\w+)', :dog

  def index
    background '#f0f0f0'
    title 'Home Page'
    para 'Welcome to the URL routing example!'
    button 'Cat 5' do
      visit '/cats/5'
    end
    button 'Dog Rex' do
      visit '/dogs/Rex'
    end
  end

  def cat(id)
    background '#DFA5A5'
    title 'Cat Page'
    para "This is the page for cat #{id}"
    button 'Home' do
      visit '/'
    end
  end

  def dog(name)
    background '#A5DFA5'
    title 'Dog Page'
    para "This is the page for dog #{name}"
    button 'Home' do
      visit '/'
    end
  end

  visit '/'
end
