 Shoes.app do
    stack do
      para "Among these films, which do you prefer?"
      flow { radio; para "The Taste of Tea by Katsuhito Ishii" }
      flow { radio "a"; para "Kin-Dza-Dza by Georgi Danelia" }
      flow { radio; para "Children of Heaven by Majid Majidi" }
      @btn = radio; para "The White Balloon by Jafar Panahi"
      button "Mark me" do
        @btn.checked = true
      end
      button "unmark me" do
        @btn.checked = false
      end
    end
  end
