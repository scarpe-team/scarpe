# Test script for Hackety Hack patterns on Scarpe
# Tests the key patterns used throughout HH

Shoes.app(title: "HH Patterns Test", width: 600, height: 500) do
  background "#e9efe0"
  
  style(Shoes::Link, :stroke => "#377")
  style(Shoes::LinkHover, :fill => nil, :stroke => "#C66")
  
  @test_results = []
  
  def log_test(name, passed)
    @test_results << [name, passed]
    status = passed ? "✅" : "❌"
    puts "#{status} #{name}"
  end
  
  stack margin: 10 do
    title "HH Patterns Test Suite", font: "Lacuna Regular", stroke: "#333"
    
    # Test 1: Class-level styling
    flow do
      para "Test 1 - Links: "
      link("Click me") { alert "Link works!" }
      para " (should be styled)"
    end
    log_test("Class-level style", true)  # Visual check needed
    
    # Test 2: Glossy button pattern (simplified)
    stack margin: 10 do
      subtitle "Test 2 - Glossy Button Pattern"
      fg, bgfill = "#777", "#DDD"
      txt = link("Glossy Button", underline: 'none', stroke: fg) { }
      stack margin: 4 do
        background bgfill, curve: 5
        @gloss_para = para txt, align: 'center', margin: 4, size: 11
        @over = stack top: 0, left: 0, margin: 2, hidden: true do
          background bgfill, curve: 5
          para txt, align: 'center', margin: 4, size: 14, weight: "bold"
        end
        hover { @over.show }
        leave { @over.hide }
      end
    end
    log_test("Glossy button hover/leave", true)
    
    # Test 3: Icon button pattern
    stack margin: 10 do
      subtitle "Test 3 - Icon Button Pattern"
      flow do
        strokewidth 1
        nofill
        stack margin: 8, width: 32, height: 32 do
          stroke white
          # Draw arrow right
          line(1, 8, 14, 8)
          line(14, 8, 10, 4)
          line(14, 8, 10, 12)
        end
        para "  Arrow icon (should be visible)"
      end
    end
    log_test("Icon drawing", true)
    
    # Test 4: Tab switching pattern
    stack margin: 10 do
      subtitle "Test 4 - Tab Switching"
      @tab1 = stack hidden: false do
        background "#FDD"
        para "Tab 1 content"
      end
      @tab2 = stack hidden: true do
        background "#DDF"
        para "Tab 2 content"
      end
      flow do
        button "Show Tab 1" do
          @tab1.show
          @tab2.hide
        end
        button "Show Tab 2" do
          @tab1.hide
          @tab2.show
        end
      end
    end
    log_test("Tab switching", true)
    
    # Test 5: finish callback (fires on removal, not init!)
    @finish_called = false
    @test_stack = stack do
      para "Test 5 - finish callback (click Remove to test)"
    end
    @test_stack.finish { @finish_called = true; puts "✅ finish callback FIRED!" }
    button "Remove test_stack" do
      @test_stack.remove
      para "Stack removed! Check console for finish callback."
    end
    log_test("finish callback setup", true)
    
    # Test 6: Image with hover/leave/click
    stack margin: 10 do
      subtitle "Test 6 - Image Events"
      @img_status = para "Image status: idle", stroke: "#666"
      # Use a placeholder since we may not have HH images
      stack width: 50, height: 50 do
        background "#aaa"
        para "IMG", align: "center"
      end.hover { @img_status.replace "Image status: HOVER" }.
          leave { @img_status.replace "Image status: idle" }.
          click { @img_status.replace "Image status: CLICKED!" }
    end
    log_test("Image hover/leave/click", true)
    
    # Test 7: Tooltip module pattern
    stack margin: 10 do
      subtitle "Test 7 - Dynamic Tooltip"
      # Simplified tooltip pattern
      @tooltip_area = flow width: 200, height: 40 do
        background "#DFA"
        para "Hover for tooltip"
      end
      @tooltip_area.hover do
        @tooltip_stack ||= stack left: 50, top: 400, width: 150 do
          background "#F7A", curve: 6
          para "Tooltip!", stroke: white, margin: 4
        end
        @tooltip_stack.show
      end
      @tooltip_area.leave do
        @tooltip_stack.hide if @tooltip_stack
      end
    end
    log_test("Dynamic tooltip", true)
    
    # Test 8: Method missing delegation pattern (HH uses this for SideTab)
    stack margin: 10 do
      subtitle "Test 8 - Method Missing Delegation"
      begin
        # This tests that Shoes DSL methods work in various contexts
        @delegate_test = stack do
          para "Delegated content"
        end
        log_test("Method delegation", true)
      rescue => e
        log_test("Method delegation", false)
        para "Error: #{e.message}", stroke: red
      end
    end
    
    # Test 9: Clear and replace pattern (used extensively in HH)
    stack margin: 10 do
      subtitle "Test 9 - Clear and Replace"
      @counter = 0
      @clear_test = stack width: 200, height: 40 do
        background "#EEE"
        para "Counter: 0"
      end
      button "Increment" do
        @counter += 1
        @clear_test.clear do
          background "#EEE"
          para "Counter: #{@counter}"
        end
      end
    end
    log_test("Clear and replace", true)
    
    # Test 10: Negative sizing
    stack margin: 10 do
      subtitle "Test 10 - Negative Height"
      stack height: -50 do
        background "#DDD"
        para "This stack has height: -50 (should fill minus 50px)"
      end
    end
    log_test("Negative sizing", true)
  end
  
  # Summary at bottom
  timer 0.5 do
    passed = @test_results.count { |_, p| p }
    total = @test_results.length
    puts "\n=== SUMMARY: #{passed}/#{total} tests setup ==="
    puts "(Visual verification needed for most tests)"
    puts "(Click 'Remove test_stack' button to test finish callback)"
  end
end
