#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/narration"
total=0
for f in "$DIR"/slide-*.wav; do
  d=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f")
  printf "%-14s %8.2fs\n" "$(basename "$f")" "$d"
  total=$(awk -v a="$total" -v b="$d" 'BEGIN{print a+b}')
done
mins=$(awk -v t="$total" 'BEGIN{print int(t/60)}')
secs=$(awk -v t="$total" 'BEGIN{print int(t)%60}')
printf "\nTotal narration: %.2fs = %d min %d sec\n" "$total" "$mins" "$secs"
