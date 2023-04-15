```ruby
class Object
  def parent_caller
    caller[0].match(/`(.*)'/)[1]
  end
  def all_callers
    caller.map{|x| x.match(/`(.*)'/)[1] if self.respond_to? x.match(/`(.*)'/)[1].to_sym}.compact
  end

  def caller_key
    caller[0].hash
  end
end
all_callers
class Hi
  def fish
    yield
  end
  def flop
    fish do
      all_callers
    end
  end
end
Hi.new.flop
```
