# Scarpe

## _Scarpe Diem: Seize the Shoes_
![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/Schwad/scarpe/ci.yml?branch=main)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-shopify-brightgreen.svg)](https://github.com/Shopify/ruby-style-guide)
[![Discord](https://img.shields.io/discord/1072538177321058377?label=discord)](https://discord.gg/Ca5EHSsGYp)

<img src="https://user-images.githubusercontent.com/7865030/217309905-7f25e3cf-1850-481d-811b-dfddea2df54a.png" width="200" height="200">

"Scarpe" means shoes in Italian. "Scarpe" also means [Shoes](https://github.com/shoes/shoes-deprecated) in modern Ruby and webview!

Scarpe isn't feature complete with any version of Shoes (yet?). We're initially targeting Shoes Classic.

## Wait, What's A Shoes?

Shoes is an old library (really several different ones) that let you build little local desktop computer programs, package them up and give copies to people. Imagine if you can write a tiny little Ruby program (e.g. sneak a peek at the next section) and then it would make a runnable app, opening a window in Ruby, where you could click buttons and play sounds and stuff.

Scarpe is a rewrite of Shoes, because old Shoes doesn't really work any more. There have been a surprising number of rewrites of Shoes over the years -- people love it and miss having it around. This one is ours. Also it uses Webview.

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

Scarpe requires [Ruby 3.2](https://www.ruby-lang.org/en/downloads/) or higher! use `rvm` or `rbenv` for version control

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

If you want to quickly add a feature, you can use the `ruby scarpegen.rb` command. This command will generate the necessary files for you, along with a simple template and a set of questions to guide you through the process. By following these steps, you will be good to go!

By leveraging the `ruby scarpegen.rb` command and the provided resources, you can expedite the feature addition process and ensure a smoother development experience.

## Are we done yet?

Huh. Great question. Right now we have a few key things we want to achieve. The first is passing all of the examples we can get our hands on. The second is passing HacketyHack. We're manually keeping tabs on that here.

🚨 **This is manually checked and not an automation.** 🚨

### Webview Display Service Examples Passing

![](https://geps.dev/progress/16?dangerColor=800000&warningColor=ff9900&successColor=006600)

__41/288__

### GlimmerLibUI Display Service Examples Passing

![](https://geps.dev/progress/2?dangerColor=800000&warningColor=ff9900&successColor=006600)

__4/288__

## Teach me more about Shoes, the DSL, what it is and why it is amazing

1. [Nobody Knows Shoes - _why's Manual](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)
1. [Known examples](examples)
1. [shoes-original manual](docs/static/manual.md)

## Environment Variables

Scarpe allows you to modify the app's behaviour outside of the normal Shoes API with environment variables.

For example, we are working with multiple display services like Webview, Glimmer, and possibly some others.

The SCARPE_DISPLAY_SERVICE environment variable allows you to choose one or more display services, from the default Webview service to potentially other experimental or incomplete services. This may be important if you're developing a new display method for Scarpe. The display service variable will contain a name like "wv_local" or "wv_remote" or "glibui" which corresponds to a require-able Ruby file under lib/scarpe, either in the Scarpe gem or another gem your app requires.

Example usage:

`SCARPE_DISPLAY_SERVICE=glibui ./exe/scarpe examples/hello_world.rb`

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

## Logging

You can set SCARPE_LOG_CONFIG to an appropriate YAML file to set log levels per-component. You can find sample log configs under the logger directory. Scarpe has a number of component names that log data, set per-class. So you can set what components log at what sensitivity.

```
{
    "default": "warn",
    "WV::WebWrangler": ["logger/web_wrangler.log", "debug"]
}
```

## Documentation

Scarpe uses [YARD](https://yardoc.org/) for basic API documentation. You can run "yard doc" to generate documentation
locally, and then view it with "yard server". Point your browser at "http://localhost:8808" for local viewing.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scarpe-team/scarpe. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/scarpe-team/scarpe/blob/main/CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](https://github.com/scarpe-team/scarpe/blob/main/CONTRIBUTING.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Scarpe project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/scarpe-team/scarpe/blob/main/CODE_OF_CONDUCT.md).
