# Scarpe

## _Scarpe Diem: Seize the Shoes_
![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/Schwad/scarpe/ci.yml?branch=main)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-shopify-brightgreen.svg)](https://github.com/Shopify/ruby-style-guide)
[![Discord](https://img.shields.io/discord/1072538177321058377?label=discord)](https://discord.gg/nbhaZJtfVW)

<img src="https://user-images.githubusercontent.com/7865030/217309905-7f25e3cf-1850-481d-811b-dfddea2df54a.png" width="200" height="200">

"Scarpe" means shoes in Italian. "Scarpe" also means [Shoes](https://github.com/shoes/shoes-deprecated) in modern Ruby and webview!

Scarpe isn't feature complete with any version of Shoes (yet?). We're initially targeting Shoes Classic.

## Usage

Note: you'll probably want the [Scarpe in Development](#scarpe-in-development) instructions below in most cases! Scarpe isn't ready for "just install the released version" production usage yet.

Create an hello world application with:

```ruby
Shoes.app do
  para "Hello World"
end
```

More examples can be found in the `examples` folder!

## Screenshots

From the hello world example:

<img width="480" alt="hello_world" src="https://user-images.githubusercontent.com/9624267/158565981-57240f72-fbaf-4b72-b66e-8c0d517a90d7.png">

From the button example:

<img width="480" alt="hello_world" src="https://user-images.githubusercontent.com/9624267/158566011-0372d0c7-fbeb-4ed6-a082-73908f04a0b6.gif">

## Scarpe in Development

### Quickstart

This is where most of the action is happening right now, and to have the full Scarpe experience _today_ this is probably what you want to do.

```
# get it
git clone http://github.com/scarpe-team/scarpe
cd scarpe; bundle install
# run it
./exe/scarpe examples/button.rb --dev
```

### Finer details

First, clone the [main GitHub repository](https://github.com/scarpe-team/scarpe).

`bundle install` dependencies like webview from the cloned directory in your Ruby of choice.

You can run without Scarpe being installed by including its directory. For instance, from the "examples" directory you can run `ruby -I../lib hello_world.rb`. You can also install Scarpe locally (`gem build scarpe.gemspec && gem install scarpe-0.1.0.gem`) or using a Gemfile with the "path" option for local Scarpe.

Most commonly we are all using this command: `./exe/scarpe examples/button.rb --dev`

The `--dev` flag points to your local scarpe rather than an installed Scarpe gem.

It's very early in the development process. If you'd like to help develop Scarpe, great! It would be useful to drop us a message/issue/PR on GitHub early on, so we know you're working in a particular area, and we can warn you if anybody else is currently doing so.

We'd love the help!

## Are we done yet?

Huh. Great question. Right now we have a few key things we want to achieve. The first is passing all of the examples we can get our hands on. The second is passing HacketyHack. We're manually keeping tabs on that here.

🚨 **This is manually checked and not an automation.** 🚨

### Webview Display Service Examples Passing

![](https://geps.dev/progress/16?dangerColor=800000&warningColor=ff9900&successColor=006600)

__40/256__

### GlimmerLibUI Display Service Examples Passing

![](https://geps.dev/progress/2?dangerColor=800000&warningColor=ff9900&successColor=006600)

__4/256__

## Teach me more about Shoes, the DSL, what it is and why it is amazing

1. [Nobody Knows Shoes - _why's Manual](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)
1. [Known examples](examples)
1. [shoes-original manual](docs/static/manual.md)

## Environment Variables

Scarpe allows you to modify the app's behaviour outside of the normal Shoes API with environment variables.

For example, we are working with multiple display services like Webview, Glimmer, and possibly some others.

The SCARPE_DISPLAY_SERVICES environment variable allows you to choose one or more display services, from the default Webview service, to no service at all, to potentially other experimental or incomplete services. This may be important if you're developing a new display method for Scarpe. Normally ScarpeDisplayServices will contain a semicolon-delimited list of class names for display services (which can be just the name of a single display service). For no display service at all, set it to a single dash.

Example usage:

`SCARPE_DISPLAY_SERVICES=Scarpe::GlimmerLibUIDisplayService ./exe/scarpe examples/hello_world.rb --dev`

The SCARPE_TEST_CONTROL environment variable can contain a path to a test-control-interface script for the Webview display service. If you look at test_helper, it gives some examples of how to use it.

## More info

* [Nobody Knows Shoes manual](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)
* [Original shoes (archived)](https://github.com/shoes/shoes-deprecated)
  - For now we are aiming towards _original shoes_, but I believe later can learn from Shoes3.
  - [wiki](https://github.com/shoes/shoes-deprecated/wiki)
* [shoes3](https://github.com/shoes/shoes3)
  - [wiki](https://github.com/shoes/shoes3/wiki)
  * [Blog covering shoes3 history](https://web.archive.org/web/20190731215758/https://walkabout.mvmanila.com/)
* [shoes4 (JRuby, incomplete)](https://github.com/shoes/shoes4)
* [Shoes' native splash app](https://github.com/shoes/shoes-deprecated/blob/develop/lib/shoes.rb#L124-L176)
* [Original Shoes example directory](https://github.com/shoes/shoes-deprecated/tree/develop/samples)
* [Found shoes apps](https://gist.github.com/search?l=Ruby&q=shoes.rb)
* [HacketyHack](https://github.com/whymirror/hacketyhack)

## Core Values

* **Resiliency** - We want Scarpe to be tested and trustworthy to work consistently and predictably.
* **User Experience** - Ruby and this DSL are beautiful for making desktop app authoring easy. We should uphold this standard.
* **Whimsy** - We're not here to make money or be corporate. We're here to have fun! Even if we do end up building something amazing. Also, Chunky Bacon. 🥓
* **Empathy** - Let's help one another, and adhere to good contributor standards while doing so.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scarpe-team/scarpe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/scarpe-team/scarpe/blob/main/CODE_OF_CONDUCT.md) and {CONTRIBUTING.md](https://github.com/scarpe-team/scarpe/blob/main/CONTRIBUTING.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Scarpe project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/scarpe-team/scarpe/blob/main/CODE_OF_CONDUCT.md).
