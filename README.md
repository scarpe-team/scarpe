# Scarpe

## _Scarpe Diem: Seize the Shoes_
![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/Schwad/scarpe/ci.yml?branch=main)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
![Discord](https://img.shields.io/discord/1072538177321058377?label=discord)

<img src="https://user-images.githubusercontent.com/7865030/217309905-7f25e3cf-1850-481d-811b-dfddea2df54a.png" width="200" height="200">

"Scarpe" means shoes in Italian. "Scarpe" also means [Shoes](https://github.com/shoes/shoes-deprecated) in modern Ruby and webview!

Scarpe isn't feature complete with any version of Shoes (yet?). We're initially targetting Shoes Classic.

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

Note: you'll probably want the "Scarpe in Development" instructions below in most cases! Scarpe isn't ready for "just install the released version" production usage yet.

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

## Scarpe in Development

First, clone the [main GitHub repository](https://github.com/schwad/scarpe).

`bundle install` dependencies like webview from the cloned directory in your Ruby of choice.

You can run without Scarpe being installed by including its directory. For instance, from the "examples" directory you can run `ruby -I../lib hello_world.rb`. You can also install Scarpe locally (`gem build scarpe.gemspec && gem install scarpe-0.1.0.gem`) or using a Gemfile with the "path" option for local Scarpe.

If you want to be really slick we have a helper development command, for example:

`./exe/scarpe examples/button.rb --dev`

The `--dev` flag points to your local scarpe. Also, it has a helper that allows it to _attempt_ to run existing `Shoes.rb` apps. If you want to turn this off add the flag `--no-shoes`.

It's very early in the development process (as of February 2023, as I write this.) If you'd like to help develop Scarpe, great! It would be useful to drop us a message/issue/PR on GitHub early on, so we know you're working in a particular area, and we can warn you if anybody else is currently doing so.

We'd love the help!

## Shoes DSL Parity Tracker

### Core DSL

| Syntax  | Status |
| ------- | ------ |
| [para](https://github.com/Schwad/scarpe/issues/1) |  🛠️  |
| [stack](https://github.com/Schwad/scarpe/issues/2) |  🛠️ |
| [flow](https://github.com/Schwad/scarpe/issues/3) |    |
| [button](https://github.com/Schwad/scarpe/issues/4) | 🛠️ |
| [image](https://github.com/Schwad/scarpe/issues/5) |  🛠️  |
| [edit_line](https://github.com/Schwad/scarpe/issues/6) | 🛠️ |
| [edit_box](https://github.com/Schwad/scarpe/issues/7) |   🛠️ |
| [link](https://github.com/Schwad/scarpe/issues/8) |   🛠️ |
| [background](https://github.com/Schwad/scarpe/issues/9) |    |
| [Shoes.url](https://github.com/Schwad/scarpe/issues/10) |    |
| [visibility](https://github.com/Schwad/scarpe/issues/11) |    |
| [Scarpe.app methods](https://github.com/Schwad/scarpe/issues/13) |    |
| [Widgets](https://github.com/Schwad/scarpe/issues/43) | 🛠️   |

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

## Documentation

We have a collection of primary and secondary sources currently serving as documentation. Long-term we would like to compose a "pickaxe-book"-style specification for Shoes that collates this knowledge into one place.

1. [Nobody Knows Shoes - _why's Manual](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)
1. [Known examples](examples)
1. [shoes-original manual](docs/static/manual.md)

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
