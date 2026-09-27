# A clock that ticks once a second: the timer-idle benchmark in native/PERF.md.
Shoes.app(title: "Clock", width: 600, height: 500) do
  background "#fbfbfd"
  stack(margin: 20) do
    title "The time is"
    @time = banner Time.now.strftime("%H:%M:%S")
  end
  every(1) { @time.text = Time.now.strftime("%H:%M:%S") }
end
