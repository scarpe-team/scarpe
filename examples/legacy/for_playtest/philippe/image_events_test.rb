# Exact HH sidetab pattern test — verifies Image event chaining
# Run: cd ~/Progrumms/scarpe && bundle exec ruby exe/scarpe --dev /tmp/image_events_test.rb

Shoes.app(title: "Image Event Test", width: 400, height: 300) do
  background "#333"
  
  @log = []
  
  # Status display
  @status = para "Waiting for events...", stroke: white, margin: 10
  @event_log = para "", stroke: "#8CF", size: 9, margin: 10, margin_top: 0
  
  def log_event(msg)
    @log << msg
    @log.shift if @log.size > 8
    @event_log.replace @log.join("\n")
  end
  
  # This is the EXACT pattern from HH sidetabs.rb:
  # image(icon_path, :margin => 4).hover { ... }.leave { ... }.click &onclick
  
  stack top: 60, left: 20, width: 60, margin: 4 do
    @bg1 = background "#DFA", height: 50, curve: 6, hidden: true
    
    # Using a URL image to simulate HH pattern
    img = image("#{HH::STATIC rescue "https://via.placeholder.com/32"}/tab-home.png", margin: 8)
    
    # If we can't load HH, use a placeholder
    if img.url.include?("placeholder")
      img.hide
      # Fallback: create a visible box
      stack(width: 32, height: 32, margin: 8) do
        background "#666", curve: 4
        para "🏠", align: "center", margin_top: 4
      end.hover {
        @bg1.show
        @status.replace "HOVER on Home"
        log_event "[#{Time.now.strftime('%H:%M:%S')}] hover: Home"
      }.leave {
        @bg1.hide
        @status.replace "LEAVE from Home"
        log_event "[#{Time.now.strftime('%H:%M:%S')}] leave: Home"
      }.click {
        @status.replace "CLICK: Home!"
        log_event "[#{Time.now.strftime('%H:%M:%S')}] CLICK: Home"
      }
    else
      img.hover {
        @bg1.show
        @status.replace "HOVER on Home"
        log_event "[#{Time.now.strftime('%H:%M:%S')}] hover: Home"
      }.leave {
        @bg1.hide
        @status.replace "LEAVE from Home"
        log_event "[#{Time.now.strftime('%H:%M:%S')}] leave: Home"
      }.click {
        @status.replace "CLICK: Home!"
        log_event "[#{Time.now.strftime('%H:%M:%S')}] CLICK: Home"
      }
    end
  end
  
  # Second tab
  stack top: 120, left: 20, width: 60, margin: 4 do
    @bg2 = background "#DFA", height: 50, curve: 6, hidden: true
    
    stack(width: 32, height: 32, margin: 8) do
      background "#666", curve: 4
      para "✏️", align: "center", margin_top: 4
    end.hover {
      @bg2.show
      @status.replace "HOVER on Editor"
      log_event "[#{Time.now.strftime('%H:%M:%S')}] hover: Editor"
    }.leave {
      @bg2.hide
      @status.replace "LEAVE from Editor"
      log_event "[#{Time.now.strftime('%H:%M:%S')}] leave: Editor"
    }.click {
      @status.replace "CLICK: Editor!"
      log_event "[#{Time.now.strftime('%H:%M:%S')}] CLICK: Editor"
    }
  end
  
  # Third tab with direct image (no fallback)
  stack top: 180, left: 20, width: 60, margin: 4 do
    @bg3 = background "#DFA", height: 50, curve: 6, hidden: true
    
    stack(width: 32, height: 32, margin: 8) do
      background "#888", curve: 4
      para "📚", align: "center", margin_top: 4
    end.hover {
      @bg3.show
      @status.replace "HOVER on Lessons"
      log_event "[#{Time.now.strftime('%H:%M:%S')}] hover: Lessons"
    }.leave {
      @bg3.hide
      @status.replace "LEAVE from Lessons"
      log_event "[#{Time.now.strftime('%H:%M:%S')}] leave: Lessons"
    }.click {
      @status.replace "CLICK: Lessons!"
      log_event "[#{Time.now.strftime('%H:%M:%S')}] CLICK: Lessons"
    }
  end
  
  para "\nHover and click the icons on the left", stroke: "#888", size: 10, margin: 100, margin_left: 100
  
  # Log initial state
  log_event "[#{Time.now.strftime('%H:%M:%S')}] App started. Test hover/leave/click."
end
