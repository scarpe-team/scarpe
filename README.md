# Scarpe

Scarpe is me trying to rebuild shoes using ruby but also new web technology, like using HTML and your browser as the UI backend. The name `scarpe` just means shoes in
italian, so I thought it would be a fitting name. This is REALLY incomplete and it's not close to be feature complete with shoes (any version) in any way. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'scarpe'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install scarpe

## Usage

Create an hello world application with: 

```ruby
require "scarpe"

Scarpe.app do
  para "Hello World"
end
```

More examples can be found in the `examples` folder!

## Screenshots

From the hello world example: 

<img width="480" alt="hello_world" src="https://user-images.githubusercontent.com/9624267/158565981-57240f72-fbaf-4b72-b66e-8c0d517a90d7.png">

From the button example:

![button](https://user-images.githubusercontent.com/9624267/158566011-0372d0c7-fbeb-4ed6-a082-73908f04a0b6.gif)


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/scarpe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Scarpe project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).
