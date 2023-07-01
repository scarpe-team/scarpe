#!/usr/bin/env ruby

# It's cool to be able to visualise the Shoes API -- where are various methods available?

# Future plan: this would be a *great* opportunity for a Shoes::Widget so that we could
# have a "show all the methods by category" thing and put it inside various other widgets
# to see how they all react.

# What methods should Shoes have? You can do worse than to check Shoes4 Shoes-core:
# https://github.com/shoes/shoes4/tree/main/shoes-core/lib/shoes/dsl
SHOES_API_CATEGORIES = {
  animate: {
    animate: {},
    every: {},
    timer: {},
  },

  art: {
    arrow: {},
    arc: {},
    line: {},
    oval: {},
    rect: {},
    star: {},
    shape: {},
    mask: {},
  },

  element: {
    border: {},
    background: {},
    edit_line: {},
    edit_box: {},
    progress: {},
    check: {},
    radio: {},
    list_box: {},
    flow: {},
    stack: {},
    button: {},
  },

  interaction: {
    mouse: {},
    motion: {},
    resize: {},
    hover: {},
    leave: {},
    keypress: {},
    keyrelease: {},
    append: {},
    visit: {},
    scroll_top: {},
    #"scroll_top=": {},
    clipboard: {},
    #"clipboard=": {},
    download: {},
    gutter: {},
  },

  media: {
    image: {},
    video: {},
    sound: {},
  },

  setup: {
    # This is deprecated in recent Shoes, but was once how to install gems
    setup: {},
  },

  style: {
    style: {},
    fill: {},
    stroke: {},
    cap: {},
    rotate: {},
    strokewidth: {},
    transform: {},
    translate: {},
    nostroke: {},
    nofill: {},
  },

  text: {
    # Text widgets and similar
    banner: {},
    title: {},
    subtitle: {},
    tagline: {},
    caption: {},
    para: {},
    inscription: {},

    code: {},
    del: {},
    em: {},
    ins: {},
    sub: {},
    sup: {},
    strong: {},

    fg: {},
    bg: {},
    link: {},
    span: {},
  },
}

def shoes_api_reactivity(instance)
  reactivity = {}

  SHOES_API_CATEGORIES.each do |category_name, category|
    cat_data = category.map do |method_name, data| # For now ignore data
      [method_name, instance.respond_to?(method_name)]
    end

    if cat_data.none? { |_name, reacts| reacts }
      reactivity[category_name] = false
    elsif cat_data.all? { |_name, reacts| reacts }
      reactivity[category_name] = true
    else
      out = {}
      cat_data.each do |name, reacts|
        out[name] = reacts
      end
      reactivity[category_name] = out
    end
  end

  reactivity
end

Shoes.app(title: "Shoes-splorer!") do
  para "What Shoes methods are available?"

  shoes_api_reactivity(self).flat_map do |category, cat_reacts|
    if cat_reacts.respond_to?(:each)
      para *(cat_reacts.flat_map do |name, reacts|
        [reacts ? "o" : "x", code(name), " "]
      end), stroke: :orange
    elsif cat_reacts
      # Whole category is true
      para strong(" #{category}[Woot!] "), stroke: :green
    else
      # Whole category is false
      para em(" xxx"), category.to_s, em("xxx "), stroke: :red
    end
  end
end
