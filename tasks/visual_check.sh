#!/bin/bash
# Capture Scarpe app HTML and save to /tmp for browser viewing
# Usage: ./tasks/visual_check.sh path/to/example.rb

set -e
cd "$(dirname "$0")/.."

EXAMPLE="$1"
if [ -z "$EXAMPLE" ]; then
  echo "Usage: $0 <path_to_example.rb>"
  exit 1
fi

BASENAME=$(basename "$EXAMPLE" .rb)
OUTPUT_FILE="/tmp/scarpe_preview_${BASENAME}.html"

echo "Capturing HTML for: $EXAMPLE"

# Run Scarpe and capture output
timeout 8 bundle exec ./exe/scarpe "$EXAMPLE" --dev --debug > /tmp/scarpe_output.txt 2>&1 || true

# Extract innerHTML
HTML=$(grep -o 'innerHTML = `[^`]*`' /tmp/scarpe_output.txt | head -1 | sed 's/innerHTML = `//; s/`$//' | sed 's/\\"/"/g; s/\\\\/\\/g')

if [ -z "$HTML" ]; then
  echo "ERROR: No HTML captured for $EXAMPLE"
  exit 1
fi

# Create full HTML document
cat > "$OUTPUT_FILE" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
  <title>Scarpe: $BASENAME</title>
  <style>
    body { font-family: arial, Helvetica, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    #preview { background: white; border: 1px solid #ccc; padding: 10px; display: inline-block; min-width: 200px; min-height: 100px; }
    h1 { font-size: 14px; color: #666; margin-bottom: 10px; }
  </style>
</head>
<body>
  <h1>$BASENAME</h1>
  <div id="preview">
$HTML
  </div>
</body>
</html>
HTMLEOF

echo "Saved to: $OUTPUT_FILE"
