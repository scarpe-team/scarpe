
class Range
  def rand
    conv = (Integer === self.end && Integer === self.begin ? :to_i : :to_f)
    ((Kernel.rand * (self.end - self.begin)) + self.begin).send(conv)
  end
end

unless Time.respond_to? :today
  def Time.today
    t = Time.now
    t - (t.to_i % 86_400)
  end
end

