# Timmy 1

# Shoes.app do
  # para "You've downloaded a virus!"
# end

# Timmy 2

# Shoes.app title: "Cookies Recipe", height: 1000, width: 1000 do
  # banner "You've downloaded a virus!", :align => "center"
# end

# Timmy 3

# Shoes.app title: "Cookies Recipe", height: 1000, width: 1000 do
#   background "black"
#   @header = banner "You've downloaded a virus!", align: "center", stroke: red

#   flow height: "30%" do
#     stack width: "100%" do
#       background "white"
#       title "You thought this was a recipe for cookies, but it was me, your arch nemesis!\n\n", align: "center"
#       para "I have taken over your computer and will not give it back until you pay me $1,000,000.",
#         align: "center",
#         size: 30
#     end
#   end
#   flow height: "20%" do
#     stack width: "100%" do
#       background "white"
#       para "Pay me now or I will delete all your files!\n",
#         "Courtesy, your friends in the Mafia",
#         align: "center", size: 30
#       banner "💰", align: "center"
#     end
#   end
#   flow height: "45%" do
#     border "black", strokewidth: 10
#     background "black"
#     stack width: "33.33%" do
#       background "green"
#     end
#     stack width: "33.33%" do
#       background "white"
#     end
#     stack width: "33.33%" do
#       background "red"
#     end
#   end
# end

# Timmy 4

# Shoes.app title: "Cookies Recipe", height: 1000, width: 1000 do
#   background "black"
#   @header = banner "You've downloaded a virus!", align: "center", stroke: red

#   flow height: "30%" do
#     stack width: "100%" do
#       background "white"
#       title "You thought this was a recipe for cookies, but it was me, your arch nemesis!\n\n", align: "center"
#       para "I have taken over your computer and will not give it back until you pay me $1,000,000.",
#         align: "center",
#         size: 30
#     end
#   end
#   flow height: "20%" do
#     stack width: "100%" do
#       background "white"
#       para "Pay me now or I will delete all your files!\n",
#         "Courtesy, your friends in the Mafia",
#         align: "center", size: 30
#       banner "💰", align: "center"
#     end
#   end
#   flow height: "45%" do
#     border "black", strokewidth: 10
#     background "black"
#     stack width: "33.33%" do
#       background "green"
#     end
#     stack width: "33.33%" do
#       background "white"
#     end
#     stack width: "33.33%" do
#       background "red"
#     end
#   end
# end

# Timmy 5 (less insensitive, more interactive)

Shoes.app title: "Cookies Recipe", height: 1000, width: 1000 do
  background "black"
  @header = banner "You've downloaded a virus!", align: "center", stroke: red

  flow height: "30%" do
    stack width: "100%" do
      background "white"
      title "You thought this was a recipe for cookies, but it was me, your arch nemesis!\n\n", align: "center"
      para "I have taken over your computer and will not give it back until you pay me $1,000,000.",
        align: "center",
        size: 30
    end
  end
  flow height: "20%" do
    stack width: "33.33%" do
      background "blue"
      star 230, 100, 6, 150, 50
    end
    stack width: "33.33%" do
      background "white"
      para "Pay me now or I will delete all your files!\n",
        "Courtesy, the Pirates of the Highlands 🏴‍☠️",
        align: "center", size: 30
      banner "💰", align: "center"
    end
    stack width: "33.33%" do
      background "blue"
      star 230, 100, 6, 150, 50
    end
  end
  flow height: "40%" do
    stack width: "33.33%" do; end # Negative spacing
    stack width: "33.33%" do
      button "Pay up 💸", width: 300, height: 300, size: 80 do
        @header.replace "Just kidding Grandma! I love you! ❤️"
        @header.style(stroke: black)
      end
    end
  end
end

# Timmy 6 (interactive!)

