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

## Shoes Parity Roadmap

### `para`
  - [x] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] Support a collection of arguments, joined into one string.
    * e.g. `para 'this', 'is', 'a', 'string'
  - #### Methods to add
    - [ ] `banner`; 48px
    - [ ] `title`; 34px
    - [ ] `subtitle`; 26px;
    - [ ] `tagline`; 18px;
    - [ ] `caption`; 14px;
    - [ ] `para`; 12px;
    - [ ] `inscription`; 10px;
      - [ ] Alias `ins` for `inscription`
  - #### Options
    - [ ] `size`
      * Manually resize this text: e.g. `para 'hi', size: 34`
    * Like their HTML counterparts
    * e.g. `para "hello", strong("dude"), em("how's it going?")`
    - [ ] `strong`
    - [ ] `em`
    - [ ] `code`


### `stack`
  - [x] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] negative width
  - [ ] margin
  - [ ] unit testing
  - [ ] `margin`
  - [ ] `width`
    - [ ] floating point width (1.0 == 100%)
    - [ ] pixel width
    - [ ] negative pixel width (e.g. -80 == 100%-80)
  - [ ] nest inside flow



### `flow`
  - [x] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing
  - [ ] nest inside stack
  - [ ] should flow all the way to the end

### `button`
  - [x] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing


### `image`
  - [x] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing


### `edit_line`
  - [x] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing


### `link`
  - [ ] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing


### `background`
  - [ ] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing


### `Shoes.url`
  - [ ] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing

### `clear`
  - [ ] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing

### Built-in gems, runtime dependencies.
  - Documented [here](https://github.com/shoes/shoes-deprecated/wiki/A-Developer%27s-Tour-Through-Shoes)
  - We may be able to treat these like runtime dependencies _for now_. But if we explore more packaging this up we may need to vendor these directly ala [here](https://github.com/shoes/shoes-deprecated/tree/develop/req).
  - [ ] binject, one-click installer
  - [ ] [bloopsaphone, supports audio and chiptunes](https://github.com/whymirror/bloopsaphone)
  - [ ] chipmunk, [chipmunk physics support](https://github.com/ashbb/shoes_hack_note/blob/master/md/hack029.md)
  - [ ] ftsearch
  - [ ] Nokogiri, HTML parsing
  - [ ] JSON
  - [ ] sqlite3, simple database support


### Misc
  - [ ] `append`
  - [ ] `prepend`
  - [ ] `oval`
      - [ ] `top`, `left`, `radius`
      - [ ] `move`
  - [ ] `motion`

## Larger technical points

* Instead of using raw html we want to utilize [Phlex]() where possible

## Core Values

* **Resiliency** - We want scarpe to be tested and trustworthy to work consistently and predictably.
* **User Experience** - Ruby and this DSL are beautiful for making desktop app authoring easy. We should uphold this standard.
* **Whimsy** - We're not here to make money or be corporate. We're here to have fun! Even if we do end up building something amazing.
* **Empathy** - Let's help one another, and adhere to good contributor standards while doing so.

## Definition of Done

Scarpe is not intended to be a perfect replica of every element of Shoes. It is, however, intended to be functionally Shoes-compliant on mordern tooling. Certain benchmarks for this include:

* [Parity with the Nobody Knows Shoes manual](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)
  * This is our top priority
* Able to run various existing Shoes apps.
  * [Shoes' native splash app](https://github.com/shoes/shoes-deprecated/blob/develop/lib/shoes.rb#L124-L176)
  * [Example directory](https://github.com/shoes/shoes-deprecated/tree/develop/samples)
  * [Found shoes apps](https://gist.github.com/search?l=Ruby&q=shoes.rb)
* The ultimate test would be to run, functionally, [HacketyHack](https://github.com/whymirror/hacketyhack)

## All the shoes

* [Original shoes (archived)](https://github.com/shoes/shoes-deprecated)
  - For now we are aiming towards _original shoes_, but I believe later can learn from Shoes3.
  - [wiki](https://github.com/shoes/shoes-deprecated/wiki)
* [shoes3](https://github.com/shoes/shoes3)
  - [wiki](https://github.com/shoes/shoes3/wiki)
  * [Blog covering shoes3 history](https://web.archive.org/web/20190731215758/https://walkabout.mvmanila.com/)
* [shoes4 (JRuby, incomplete)](https://github.com/shoes/shoes4)

## More reading


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/scarpe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Scarpe project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).
