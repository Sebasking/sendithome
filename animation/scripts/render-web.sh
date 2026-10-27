#!/usr/bin/env bash
# Renders the homepage hero video variants into priv/static/videos/.
# Run from animation/ (npm run render:web). Pass extra Remotion flags, e.g.
# --browser-executable=/path/to/chrome, as arguments. The 720 scale is an exact
# 2/3: Remotion rejects a rounded 0.6667 because 1080 * 0.6667 isn't an integer.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=../priv/static/videos
mkdir -p "$OUT"

npx remotion render SendItHomeJourney "$OUT/journey-1080.webm" --codec=vp9 --crf=32 "$@"
npx remotion render SendItHomeJourney "$OUT/journey-1080.mp4" --codec=h264 --crf=20 --pixel-format=yuv420p "$@"
npx remotion render SendItHomeJourney "$OUT/journey-720.webm" --codec=vp9 --crf=34 --scale=0.6666666666666666 "$@"
npx remotion render SendItHomeJourney "$OUT/journey-720.mp4" --codec=h264 --crf=23 --scale=0.6666666666666666 --pixel-format=yuv420p "$@"
npx remotion still SendItHomeJourney "$OUT/journey-poster.jpg" --frame=245 --image-format=jpeg --jpeg-quality=80 "$@"
