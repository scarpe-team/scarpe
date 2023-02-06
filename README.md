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

## Shoes DSL Parity Tracker

### Core DSL

| Syntax  | Status | PRs   |
| ------- | ------ | ------- |
| [para](https://github.com/Schwad/scarpe/issues/1) |    |       |
| [stack](https://github.com/Schwad/scarpe/issues/2) |    |       |
| [flow](https://github.com/Schwad/scarpe/issues/3) |    |       |
| [button](https://github.com/Schwad/scarpe/issues/4) |    |  [#21](https://github.com/Schwad/scarpe/pull/21)     |
| [image](https://github.com/Schwad/scarpe/issues/5) |    |       |
| [edit_line](https://github.com/Schwad/scarpe/issues/6) |    |       |
| [edit_box](https://github.com/Schwad/scarpe/issues/7) |    |       |
| [link](https://github.com/Schwad/scarpe/issues/8) |    |       |
| [background](https://github.com/Schwad/scarpe/issues/9) |    |       |
| [Shoes.url](https://github.com/Schwad/scarpe/issues/10) |    |       |
| [visibility](https://github.com/Schwad/scarpe/issues/11) |    |       |
| [Scarpe.app methods](https://github.com/Schwad/scarpe/issues/13) |    |       |
| [para](https://github.com/Schwad/scarpe/issues/1) |    |       |


### Secondary DSL && Functionality

| Subject | Status | PRs   |
| ------- | ------ | ------- |
| [Misc Meta Issue](https://github.com/Schwad/scarpe/issues/14) |    |       |
| [style](https://github.com/Schwad/scarpe/issues/15) |    |       |
| [parents and children](https://github.com/Schwad/scarpe/issues/16) |    |       |

### Future

| Subject | Status | PRs   |
| ------- | ------ | ------- |
| [Splash App](https://github.com/Schwad/scarpe/issues/19) |    |       |
| [Packaging](https://github.com/Schwad/scarpe/issues/20) |    |       |

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

## More info

* Great cheatsheet on pages 48-50 of [Nobody Knows Shoes](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)
* [Original shoes (archived)](https://github.com/shoes/shoes-deprecated)
  - For now we are aiming towards _original shoes_, but I believe later can learn from Shoes3.
  - [wiki](https://github.com/shoes/shoes-deprecated/wiki)
* [shoes3](https://github.com/shoes/shoes3)
  - [wiki](https://github.com/shoes/shoes3/wiki)
  * [Blog covering shoes3 history](https://web.archive.org/web/20190731215758/https://walkabout.mvmanila.com/)
* [shoes4 (JRuby, incomplete)](https://github.com/shoes/shoes4)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/scarpe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Scarpe project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/scarpe/blob/master/CODE_OF_CONDUCT.md).
