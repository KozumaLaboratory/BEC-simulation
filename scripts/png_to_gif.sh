#!/usr/bin/env bash
# Convert a column_density_movie PNG sequence to high-quality GIF via
# ffmpeg's two-pass palette method (avoids the default 8-bit posterising).
#
# Usage:
#   scripts/png_to_gif.sh <frames_dir> [output.gif] [fps] [width]
#
# Defaults: output = <frames_dir>/movie.gif, fps = 15, width = 480.
# (GIFs balloon fast — 15 fps + 480-px width keeps a 200-frame movie
# under ~10 MB while staying smooth.)

set -euo pipefail

FRAMES_DIR="${1:?usage: $0 <frames_dir> [output.gif] [fps] [width]}"
OUTPUT="${2:-${FRAMES_DIR}/movie.gif}"
FPS="${3:-15}"
WIDTH="${4:-480}"

[[ -d "$FRAMES_DIR" ]] || { echo "error: $FRAMES_DIR is not a directory"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "error: ffmpeg not on PATH"; exit 1; }

PALETTE="$(mktemp --suffix=.png)"
trap 'rm -f "$PALETTE"' EXIT

# Pass 1: build a global palette from the whole sequence.
ffmpeg -y -framerate "$FPS" -i "$FRAMES_DIR/col_%05d.png" \
    -vf "fps=$FPS,scale=$WIDTH:-1:flags=lanczos,palettegen=stats_mode=full" \
    "$PALETTE" 2>/dev/null

# Pass 2: encode the GIF using the palette + Sierra dithering.
ffmpeg -y -framerate "$FPS" -i "$FRAMES_DIR/col_%05d.png" -i "$PALETTE" \
    -filter_complex "fps=$FPS,scale=$WIDTH:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=sierra2_4a" \
    "$OUTPUT" 2>/dev/null

echo "wrote $OUTPUT  ($(du -h "$OUTPUT" | cut -f1))"
