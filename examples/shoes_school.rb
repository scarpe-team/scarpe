Shoes.app(title: "Shoes School", height: 700, width: 1000) do
  CHAPTERS = [
    [
      %(
        Shoes.app do
          para "Hello World"
        end
      ),
      %(
        Welcome! To the wide, wild, wonderful world of Shoes. I am your Shoes School instructor, Professor Flopsicle. Shoes lets you
        write nifty desktop apps. In pure Ruby! Don't believe me? Here's one right here!
        Click "run" to run it. You can even play with the code a bit if you want!

        When you are done, proceed to your next lecture by clicking "Next" below me!
      )
    ],
    [
      %(
        Shoes.app do
          @push = button "Push me"
          @push.click {
            alert "Aha! Click!"
          }
        end
      ),
      %(
        Oh wow, you made it to the second lesson! Umm, well this is _embarrassing_. I never
        thought you would get this far! Give me a bit and we'll have something really nice
        whipped up for you. I swear!
      )
    ]
  ]

  current_chapter = 0
  stack do
    banner "Shoes School!"
  end
  stack do
    flow do
      IDE = edit_box(height: 300, width: "100%") do
        CHAPTERS[current_chapter][0]
      end
    end
    flow do
      LECTURE = para CHAPTERS[current_chapter][1], size: 30
    end
    flow do
      stack do
        @run = button "Run 🏃", width: 200, height: 50#, top: 109, left: 132
        @run.click {
          puts "I got clicked!"
          # System code to kick this off
          # we'll have a loading splash page on first fireup to run bin setup
        }
      end
      stack do
        @next = button "Next ✅", width: 200, height: 50#, top: 109, left: 132
        @next.click {
          current_chapter += 1
          # not working yet
          # IDE.text = CHAPTERS[current_chapter][0]
          # yeah, I dunno, ivars and local vars giving me trouble. annoying!
          LECTURE.replace(CHAPTERS[current_chapter][1])
        }
      end
    end
  end
end
