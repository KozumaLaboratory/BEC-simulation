#!/usr/bin/env bash
# Convert a column_density_movie PNG sequence to MP4.
#
# Usage:
#   scripts/png_to_mp4.sh <frames_dir> [output.mp4] [fps]
#
# Defaults: output = <frames_dir>/movie.mp4, fps = 30. Requires ffmpeg.

set -euo pipefail

FRAMES_DIR="${1:?usage: $0 <frames_dir> [output.mp4] [fps]}"
OUTPUT="${2:-${FRAMES_DIR}/movie.mp4}"
FPS="${3:-30}"

[[ -d "$FRAMES_DIR" ]] || { echo "error: $FRAMES_DIR is not a directory"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "error: ffmpeg not on PATH"; exit 1; }

# column_density_movie writes col_NNNNN.png (5-digit zero pad)
ffmpeg -y -framerate "$FPS" -i "$FRAMES_DIR/col_%05d.png" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -preset fast \
    -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    "$OUTPUT"

echo "wrote $OUTPUT  ($(du -h "$OUTPUT" | cut -f1))"
