#!ruby
# The start callback fires after the app has finished initializing.
# It's useful for setting up state that depends on the UI being ready.

Shoes.app(title: "Start Callback Demo", width: 300, height: 200) do
  @label = para "Waiting..."
  @counter = 0
  
  # This callback fires after the app block finishes running
  start do
    @label.replace "App started! Click the button."
    @counter = 1
  end
  
  button "Click me" do
    @counter += 1
    @label.replace "Counter: #{@counter}"
  end
end
