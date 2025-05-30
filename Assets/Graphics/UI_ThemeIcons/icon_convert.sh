#!/bin/bash

# SVG White to Green Converter
# Replaces all white color variants with bright green (#00ff00)
# Preserves opacity and all other attributes

INPUT_DIR="original_icons"
OUTPUT_DIR="green_icons"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Process all SVG files
for file in "$INPUT_DIR"/*.svg; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "Processing: $filename"
        
        # Replace all white variants with green
        sed -e 's/fill="#fff"/fill="#00ff00"/g' \
            -e 's/fill="#ffffff"/fill="#00ff00"/g' \
            -e 's/fill="#FFFFFF"/fill="#00ff00"/g' \
            -e 's/fill="white"/fill="#00ff00"/g' \
            -e 's/fill="#fefefe"/fill="#00ff00"/g' \
            -e 's/fill="#fdfdfd"/fill="#00ff00"/g' \
            -e 's/fill="#fcfcfc"/fill="#00ff00"/g' \
            -e 's/stroke="#fff"/stroke="#00ff00"/g' \
            -e 's/stroke="#ffffff"/stroke="#00ff00"/g' \
            -e 's/stroke="#FFFFFF"/stroke="#00ff00"/g' \
            -e 's/stroke="white"/stroke="#00ff00"/g' \
            "$file" > "$OUTPUT_DIR/$filename"
    fi
done

echo "Conversion complete! Check $OUTPUT_DIR/"

# Single file example:
# sed -e 's/fill="#fff"/fill="#00ff00"/g' input.svg > output.svg
