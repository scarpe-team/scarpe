# Demo: ask() and confirm() with return values
# These now use native macOS dialogs and return actual values!
Shoes.app :width => 400, :height => 300, :title => "Ask & Confirm Demo" do
  background "#444"

  stack :margin => 15 do
    title "Ask & Confirm Demo", :stroke => white

    @result = para "Click a button to test dialogs.", :stroke => "#DFA"

    flow :margin_top => 10 do
      button "ask()" do
        name = ask("What is your name?")
        if name
          @result.replace "You said: #{name}"
        else
          @result.replace "You cancelled the ask dialog."
        end
      end

      button "confirm()" do
        answer = confirm("Do you like Ruby?")
        if answer
          @result.replace "You confirmed: Yes!"
        else
          @result.replace "You declined (or cancelled)."
        end
      end
    end

    flow :margin_top => 10 do
      button "Clipboard write" do
        self.clipboard = "Hello from Scarpe!"
        @result.replace "Wrote 'Hello from Scarpe!' to clipboard."
      end

      button "Clipboard read" do
        text = self.clipboard
        @result.replace "Clipboard: #{text}"
      end
    end
  end
end
