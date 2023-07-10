# CatsCradle and Fiber-Based Testing

We've tried a number of things for testing. We mock extensively in many places. We use promises to handle "assert thing X after the next redraw"-type testing.

Most recently, we have a Fiber-based approach to testing which is a little weird, but (so far) looks pretty good. Here's a representative test of that kind:

```
  def test_html_dom_multiple_update
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        para "Hello World"
      end
    SCARPE_APP
      on_heartbeat do
        p = para()
        assert_include dom_html, "Hello World"
        p.replace("Goodbye World")
        wait fully_updated
        assert_include dom_html, "Goodbye World"
        p.replace("Hello Again")
        wait fully_updated
        assert_include dom_html, "Hello Again"

        test_finished
      end
    TEST_CODE
  end
```

That's fine. There's a very simple Scarpe app with a single para. The test finds it, then makes sure the page HTML includes the right text. Then it changes it, waits for the redraw and makes sure it contains the new right text. Then, basically, does those same things again. So what's interesting here?

Primarily that it waits. You could reasonably think, "waiting is easy - you can use promises or sleeps for that." And normally you'd be right. But in this case, this uses the Webview local display service. It will crash if you don't return control to its main loop within a fraction of a second. And until it gets back to its main loop it can't receive calls from Javascript. Those "dom_html" calls require looping to Webview and back, as (of course) does "wait fully_updated".

But this method appears to run through, line by line, until it's done. How?

Fibers. Specifically, Ruby 3.0 added some nice Fiber capabilities that we can use. You can go look [at the docs](https://ruby-doc.org/core-3.0.0/Fiber.html#method-i-transfer) if you want.

If you check catscradle.rb, you can see us doing a fun little dance where a block like the on_heartbeat above creates a Fiber, and there's a manager Fiber to coordinate them. On every heartbeat and redraw we run the manager Fiber, which in turn runs every other Fiber that's ready, which it tracks via Promises.

A ready Fiber will run until it does something blocking, like a dom_html or wait call. Then it returns a Promise object that will be fulfilled when it's ready to run again, like a Promise for being fully redrawn, or a promise for when a snippet of Javascript finishes.

Once the manager has run every ready Fiber once, it yields control and waits to be called again.

Right now (June 2023) we keep control simple by only being called on heartbeats or redraws, so sometimes a promise *not* involving promises or redraws can wait awhile extra (up to 1/10th of a second or so) before it runs again. It would be possible to run the manager in response to other promises completing, and that would probably be more efficient. I'm just worried about that complicating the flow of control and leading to weird order-dependent bugs. So right now we do the simple thing, which can be slower.