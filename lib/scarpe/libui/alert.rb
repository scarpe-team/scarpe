# frozen_string_literal: true

class Scarpe
  class << self
    def alert(text, title: "Information")
      UI.msg_box($main_window, title, text)
    end
  end
end
