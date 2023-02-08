class Scarpe
    class Flow < Scarpe::Widget
      def element
        "<div style='display: flex; flex-direction: row' id='#{html_id}'></div>"
      end
    end
  end
