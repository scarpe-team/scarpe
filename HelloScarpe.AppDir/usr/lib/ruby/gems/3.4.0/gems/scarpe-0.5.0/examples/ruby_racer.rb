require "benchmark"
require "stringio"

Shoes.app(title: "Ruby Racer") do
  racer1 = nil
  racer2 = nil

  flow do
    stack width: 0.45, margin: 5 do
      para "Racer 1", size: :caption
      code1 = <<~RUBY
        for i in 1..10
          a = "1"
        end
      RUBY
      racer1 = edit_box(code1, width: "100%", height: 100)
    end
    stack width: 0.45, margin: 5 do
      para "Racer 2", size: :caption
      code2 = <<~RUBY
        10.times do
          a = "1"
        end
      RUBY
      racer2 = edit_box(code2, width: "100%", height: 100)
    end
  end

  stack margin: 10 do
    @push = button "Race!"
    @results = para ""
    @push.click {
      @results.replace "And they're off!"
      run = run_benchmark(racer1.text, racer2.text)
      @results.replace "<pre>Results:<br/>#{run}</pre>"
    }

    def run_benchmark(code1, code2)
      current_stdout = $stdout
      $stdout = StringIO.new
      Benchmark.bmbm do |x|
        x.report("Code 1") { eval(code1) }
        x.report("Code 2") { eval(code2) }
      end
      $stdout.string.gsub("\n", "<br />")
    ensure
      $stdout = current_stdout
    end
  end
end
