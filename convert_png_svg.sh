#!/bin/bash

INPUT_PNG="$1"
if [ -z "$INPUT_PNG" ]; then 
    echo "Usage: $0 <image.png>"
    exit 1
fi

if [ ! -f "$INPUT_PNG" ]; then
    echo "Error: File '$INPUT_PNG' not found!"
    exit 1
fi

BASENAME=$(basename "${INPUT_PNG%.*}")
TEMP_PBM="${BASENAME}.pbm" # Intermediate black/white file
OUTPUT_SVG="${BASENAME}.svg"

echo "Step 1: Converting PNG to Black/White Bitmap..."

# Convert PNG to PBM (Portable Bitmap - pure black/white)
# -threshold 50% adjusts sensitivity (try 40% or 60% if needed)
convert "$INPUT_PNG" -colorspace Gray -threshold 50% "$TEMP_PBM"

if [ ! -f "$TEMP_PBM" ]; then
    echo "✗ Error: Conversion to PBM failed."
    exit 1
fi

echo "Step 2: Tracing Bitmap to SVG..."

# Trace the PBM to SVG using Potrace
potrace -s -o "$OUTPUT_SVG" "$TEMP_PBM"

if [ $? -eq 0 ] && [ -f "$OUTPUT_SVG" ]; then
    SIZE=$(ls -lh "$OUTPUT_SVG" | awk '{print $5}')
    echo "✓ Success! Created: $OUTPUT_SVG (Size: $SIZE)"
    
    # Verify content
    head -n 2 "$OUTPUT_SVG"
else
    echo "✗ Error: Potrace failed to create SVG."
    rm -f "$TEMP_PBM"
    exit 1
fi

# Cleanup intermediate file
rm -f "$TEMP_PBM"
echo "Done."
