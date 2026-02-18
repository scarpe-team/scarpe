# Shoes3-Only Examples

These examples use features that exist only in Shoes3 and will NOT be implemented in Scarpe:

- **plot/**: Shoes3 graphing/charting widget
- **systray/**: System tray integration  
- **terminal/**: Shoes.terminal output console
- **menus/**: Native menu bars
- **gapp/**: Shoes.settings multi-monitor API
- **events/**: ShoeEvent synthetic event system
- **switch/**: Shoes3 switch widget
- **cache/**: Shoes3 app.cache API
- **curl/**: Requires typhoeus gem + external deps

Individual files:
- **spinner.rb**: Shoes3 spinner widget
- **svg.rb, tests_svg.rb**: SVG widget (native SVG parsing)
- **video_vlc.rb, tests_video_vlc.rb**: VLC video integration
- **decoration.rb**: app.decorated= window decoration control
- **tests_color.rb**: Uses Shoes.terminal
- **video-player.rb**: VLC video player with knob widget
- **cardflip.rb**: Uses svghandle widget
- **simple-chipmunk.rb**: Chipmunk physics engine integration

These are preserved for historical reference and to document Shoes3 capabilities
that Scarpe has chosen not to replicate.
