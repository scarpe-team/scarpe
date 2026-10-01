# webview_ruby, as vendored by Scarpe

This is [webview_ruby](https://github.com/Maaarcocr/webview_ruby) 0.1.2 as published on
rubygems.org, with two changes:

- **Windows support.** The published gem cannot be built on Windows: its `ext/webview/webview.h`
  reaches EdgeHTML through C++/WinRT, which MinGW cannot compile. On Windows, `ext/Rakefile`
  builds `ext/webview-win/` instead: the single-header
  [webview 0.12.0](https://github.com/webview/webview/tree/0.12.0) (`core/include/webview/webview.h`,
  unmodified, MIT), which drives Edge through WebView2. Its built-in loader means no
  `WebView2Loader.dll` is needed, and the C++ runtime is linked statically, so `webview-ext.dll`
  depends only on system DLLs. The WebView2 SDK header is downloaded from NuGet at build time
  (pinned to 1.0.1150.38, the version webview 0.12.0 tests against); set `WEBVIEW2_INCLUDE` to a
  directory holding `WebView2.h` to build offline. At run time the WebView2 Runtime is needed; it
  ships with Windows 11 and is on most Windows 10 systems.
- **Built on first use.** Bundler does not compile the native extensions of `path:` gems, so
  `require "webview_ruby"` compiles `ext/` the first time if the library is missing
  (`lib/webview_ruby/build.rb`). To build ahead of time: `cd vendor/webview_ruby/ext && rake`.

The macOS and Linux builds compile exactly the same sources with the same flags as the
published gem. The Ruby API is unchanged on every platform.

---

# WebviewRuby

WebViewRuby is a library that provide bindings for [webview/webview](https://github.com/webview/webview) a tiny tiny cross-platform webview library to build modern cross-platform GUIs. Webview uses Cocoa/WebKit on macOS, gtk-webkit2 on Linux and Edge on Windows 10.

IMPORTANT: Compilation may not work on windows right now. Follow the progress [here](https://github.com/Maaarcocr/webview_ruby/issues/1)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'webview_ruby'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install webview_ruby

## Usage

### Hello World

Create a new Webview instance 

```ruby
webview = WebviewRuby::Webview.new
```

Set the size and the title of the window

```ruby
webview.set_title("Example")
webview.set_size(480, 360)
```

Navigate to a specific webpage

```ruby
webview.navigate("https://en.m.wikipedia.org/wiki/Main_Page")
```

Then run the main loop till its terminated (remember to always destroy the webview after it stops running)

```ruby
webview.run
webview.destroy
```

### Run ruby code from JS

You can bind a ruby function to a JavaScript one before the webview is in running state. To do so use the `bind` method like:

```ruby
webview.bind("exampleFunc") do
  print("got called by js")
end
```

Now you can use `exampleFunc` as any other JS function, you can call it from the javascript that has been loaded in the webview or
from the html. If you want to make a function take some parameters, just add parameters to the `do` block like so: 

```ruby
webview.bind("exampleFunc") do |arg1, arg2|
  print("got called by js with #{arg1} and #{arg2}")
end
```

You can only use positional arguments, keyword ones wouldn't work.

### Run JS code from ruby

You can invoke JS code to be run asynchrounously (the result of the execution won't be returned to you) by running

```ruby
webview.eval("console.log('Called from ruby')")
```

### Terminate the main loop

```
webview.terminate
```

### Run JS code at initialisation

If you want to inject JavaScript code at the initialization of the new page, such that every time the webview will open a the new page - this initialization code will be executed, then you can use

```ruby
webview.init("console.log('running at initialisation')")
```

It is guaranteed that code is executed before window.onload.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Maaarcocr/webview_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/webview_ruby/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the WebviewRuby project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/webview_ruby/blob/master/CODE_OF_CONDUCT.md).
