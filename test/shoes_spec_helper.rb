# frozen_string_literal: true

# This is intended to be required from inside a Shoes-Spec test, which allows writing test
# helper code for them.

module TextDrawableHelper
  def trim_html_ids(s)
    s.gsub(/ class="id_\d+"/, "")
  end
end
