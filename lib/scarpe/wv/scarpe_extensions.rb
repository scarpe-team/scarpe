# frozen_string_literal: true

# This may or may not stay. It's basically an example extension. It can be done
# better, and there's no reason it should be specific to button.
Shoes::Button.shoes_style :html_class, feature: :html

# We have a number of real Scarpe extensions that need to be properly marked as such
# and moved in here. Padding is a great example, as is html_attributes.