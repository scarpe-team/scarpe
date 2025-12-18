Shoes.app(title: 'Advanced URL Routing Example', width: 300, height: 200) do
  style(Shoes::Para, size: 10)
  style(Shoes::Button, width: 80)

  url '/', :index
  url '/about', :about
  url '/contact', :contact
  url '/user/(\d+)', :user
  url '/product/(\w+)', :product

  def index
    background '#f0f0f0'
    title 'Home Page'
    para 'Welcome to the advanced URL routing example!'
    button 'About' do
      visit '/about'
    end
    button 'Contact' do
      visit '/contact'
    end
    button 'User 42' do
      visit '/user/42'
    end
    @user_id = edit_line(1, width: "40%", secret: true)
    button 'Pick a user' do
      visit "/user/#{@user_id.text}"
    end
    button 'Product XYZ' do
      visit '/product/XYZ'
    end
  end

  def about
    background '#DFA5A5'
    title 'About Page'
    para 'This is the About page.'
    home_button
  end

  def contact
    background '#A5DFA5'
    title 'Contact Page'
    para 'This is the Contact page.'
    home_button
  end

  def user(id)
    background '#A5A5DF'
    title 'User Page'
    para "EDIT LINE: #{@user_id&.text}"
    para "This is the page for User #{id}"
    home_button
  end

  def product(name)
    background '#DFDF A5'
    title 'Product Page'
    para "This is the page for Product #{name}"
    home_button
  end

  def home_button
    button 'Home' do
      visit '/'
    end
  end
end
