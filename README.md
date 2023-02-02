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

### distribution
  - [ ] Should ship with a splash page scarpe app that lets you see all of your shoes apps

### `para`
  - [x] Initialize within the gem
  - [ ] Migrate `def render` to phlex
  - [ ] Support a collection of arguments, joined into one string.
    * e.g. `para 'this', 'is', 'a', 'string'
  - [ ] `stroke` kwarg to add color
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
  - [ ] `contents`, returns an array of what's inside



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
  - [ ] `alert`
  - [x] accepts and runs a block of ruby code
  - [ ] coordinates
    - [ ] `top`
    - [ ] `left`
  - [ ] size
    - [ ] `width`
    - [ ] `height`


### `image`
  - [x] Initialize within the gem
  - [ ] Accepts path to render the image
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing
  - [ ] size
    - [ ] `top`
    - [ ] `left`
    - [ ] `width`
    - [ ] `height`
  - [ ] `image.size`
    - [ ] Returns an array with original size. e.g. `w,h=image.size`
  - [ ] Is clickable `:click` can send to a url


### `edit_line`
  - [x] Initialize within the gem
  - [ ] Accept text argument for default pre-filled data
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing
  - [ ] `width`
  - [ ] returns an object with a text property, like so:
    * `@e = edit_line width: 400; @e.text #=> 'huzzah!'`
    * This object can be used elsewhere and reset with `@e.text =`

### `edit_box`
  * Similar to `edit_line` but with height and a scrollbar it might deploy.
  - [ ] Accept text argument for default pre-filled data
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] `width`
  - [ ] `height`
  - [ ] returns an object with a text property, like so:
    * `@e = edit_line width: 400; @e.text #=> 'huzzah!'`
    * This object can be used elsewhere and reset with `@e.text =`



### `link`
  - [ ] Initialize within the gem
  - [ ] Accept text argument for link name
  - [ ] must _only_ work inside of a text block (`para`, `banner`, etc.)
  - [ ] Accepts and runs a block
  - [ ] `:click` kwarg navigates to a web page or a shoes link
  - [ ] Migrate `def render` to phlex
  - [ ] unit testing

### `style`
  - [ ] Initialize within the gem
  - [ ] This isn't entirely clear, but support styling against objects like `Link` and `LinkHover`, e.g. `style(Link, underline: false, stroke: green); style(LinkHover, underline: true, stroke: red)` for styling links and linkhovers
  - [ ] I think it might be okay to support style generally.


### `background`
  * Instead of inheriting from HTML background this might be able to inherit from image
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] can fit many within a shoes box
  - [ ] can be a color, gradiant or an image
  - [ ] `background('image.png'), background('#FF9900'), background(rgb(192,128,0)), background(red)`
  - [ ] `radius: x` (rounded corners. good for rounding stacks and flows)
  - [ ] size and location
     - [ ] `top, right, bottom, left`
     - [ ] `width, height`

### `border`
  - [ ] first argument optionally color
  - [ ] `strokewidth: x` pixels
  * There is an option referring to passing an image file link instead of a color that I don't quite understand


### `Shoes.url`
  * This is the key magic of shoes. Instead of having one flat page for folks to see we can have _many_
  * It may help to look at example usages to put this together
  - [ ] Initialize within the gem
  - [ ] `def render` to phlex
  - [ ] unit testing
  - [ ] invoked multiple times
  - [ ] first arg is a path, second is a symbol linking to the method name
  - [ ] supports regex and passes along to method ala `url '/(\w+)', :my_method; def my_method(string)= para(string)`
  - [ ] `visit` takes you to these urls


### `clear`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] wipes a box. e.g. `@box = stack { ... }; @box.clear`
  - [ ] you can specify what you want to replace it with `@box.clear { para "hello rats!" }`
  * do not use this to hide and show boxes! You do that with the following methods:

### `hide`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] hides the box with `@box.hide`

### `show`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] shows the box with `@box.show`

### `append`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] adds to the end of the box

### `prepend`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] adds to the beginning of the box

### `before`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] adds to the beginning of a box before its child element `@box.before(element) { ... }`

### `after`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] adds to the beginning of a box immediately after its child element `@box.after(element) { ... }`

### `remove`
  - [ ] Initialize within the gem
  - [ ] unit testing
  - [ ] Removes any element that isn't cleared. Alias for `clear` (I think!)

### parents and children
  - [ ] elements should have access to their parents and children. e.g. `para 'hi', link("delete) { x.parent.remove }`


### ivars
  - [ ] Should be accessible anywhere within `app`

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
  - [ ] `oval`
      - [ ] `top`, `left`, `radius`
      - [ ] `move`
  - [ ] `motion`
  * The following can be found referenced [here](http://shoesrb.com/manual/Progress.html)
    - [ ] `check`
    - [ ] `list_box`
    - [ ] `progress`
    - [ ] `radio`
    - [ ] `shape`
    - [ ] `text_block`
    - [ ] `timers`
    - [ ] `video`
    - [ ] `mouse`
    - [ ] `clipboard`
    - [ ] `exit`

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
* Most of our measurement will come from manually running the `examples/examples/examples_that_do_not_yet_work` directory, and moving them out into working as we pass them.
* Able to run various external existing Shoes apps.
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

* Great cheatsheet on pages 48-50 of [Nobody Knows Shoes](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/scarpe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Scarpe project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).
