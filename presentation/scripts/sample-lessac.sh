#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="$ROOT_DIR/.tts/models"
BIN_DIR="$ROOT_DIR/.tts/bin"
BASE="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium"

mkdir -p "$MODEL_DIR"

[ -f "$MODEL_DIR/en_US-lessac-medium.onnx" ] || \
  curl -fL "$BASE/en_US-lessac-medium.onnx" -o "$MODEL_DIR/en_US-lessac-medium.onnx"
[ -f "$MODEL_DIR/en_US-lessac-medium.onnx.json" ] || \
  curl -fL "$BASE/en_US-lessac-medium.onnx.json" -o "$MODEL_DIR/en_US-lessac-medium.onnx.json"

SAMPLE_TEXT="Behind the banjos, the beards, and the folksy swagger, something quieter was taking hold. Not quite a decade into the new century, the financial crisis had knocked the varnish off the American promise. The new folk music suited that mood. It was earnest, loud, and easy to join."

printf "%s\n" "$SAMPLE_TEXT" | LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}" "$BIN_DIR/piper" \
  --model "$MODEL_DIR/en_US-lessac-medium.onnx" \
  --length_scale 1.24 \
  --sentence_silence 0.65 \
  --output_file "$ROOT_DIR/assets/voice-sample-lessac.wav" >/dev/null

ls -la "$ROOT_DIR/assets/voice-sample-lessac.wav"
