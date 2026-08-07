#!/usr/bin/env bash
set -euo pipefail

# Generate slide narration audio with Piper (en_US-joe-medium) from index.html.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.tts"
BIN_DIR="$WORK_DIR/bin"
MODEL_DIR="$WORK_DIR/models"
OUTPUT_DIR="$ROOT_DIR/assets/narration"
TMP_DIR="$WORK_DIR/tmp"

PIPER_VERSION="v1.2.0"
PIPER_ARCHIVE_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_amd64.tar.gz"
VOICE_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/joe/medium"
VOICE_MODEL="en_US-joe-medium.onnx"
VOICE_CONFIG="en_US-joe-medium.onnx.json"

mkdir -p "$BIN_DIR" "$MODEL_DIR" "$OUTPUT_DIR" "$TMP_DIR"

PIPER_BIN="$BIN_DIR/piper"
MODEL_PATH="$MODEL_DIR/$VOICE_MODEL"
MODEL_CONFIG_PATH="$MODEL_DIR/$VOICE_CONFIG"

download_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "$dst" ]]; then
    echo "Downloading: $src"
    curl -fL "$src" -o "$dst"
  fi
}

install_piper_if_needed() {
  if [[ -x "$PIPER_BIN" && -f "$BIN_DIR/libpiper_phonemize.so.1" ]]; then
    return 0
  fi

  local archive_path="$TMP_DIR/piper_amd64.tar.gz"
  download_if_missing "$PIPER_ARCHIVE_URL" "$archive_path"

  local extract_dir="$TMP_DIR/piper_extract"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  tar -xzf "$archive_path" -C "$extract_dir"

  if [[ -d "$extract_dir/piper" ]]; then
    cp -a "$extract_dir/piper/." "$BIN_DIR/"
  elif [[ -f "$extract_dir/piper" ]]; then
    cp "$extract_dir/piper" "$PIPER_BIN"
  else
    echo "Could not find Piper binary after extraction." >&2
    exit 1
  fi

  chmod +x "$PIPER_BIN"
}

prepare_voice_if_needed() {
  download_if_missing "$VOICE_BASE_URL/$VOICE_MODEL" "$MODEL_PATH"
  download_if_missing "$VOICE_BASE_URL/$VOICE_CONFIG" "$MODEL_CONFIG_PATH"
}

extract_narration_lines() {
  local source_file="$1"
  grep -E '^[[:space:]]*narration:' "$source_file" \
    | sed -E 's/^[[:space:]]*narration:[[:space:]]*"(.*)",[[:space:]]*$/\1/'
}

main() {
  command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
  command -v tar >/dev/null 2>&1 || { echo "tar is required" >&2; exit 1; }

  local source_file="$ROOT_DIR/index.html"
  if [[ ! -f "$source_file" ]]; then
    echo "Could not find $source_file" >&2
    exit 1
  fi

  install_piper_if_needed
  prepare_voice_if_needed

  local i=0
  while IFS= read -r line; do
    # Skip empty narration blocks.
    if [[ -z "${line// }" ]]; then
      continue
    fi
    i=$((i + 1))
    local out_file
    out_file=$(printf "%s/slide-%02d.wav" "$OUTPUT_DIR" "$i")
    printf "%s\n" "$line" | LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}" "$PIPER_BIN" --model "$MODEL_PATH" --output_file "$out_file" >/dev/null
    echo "Generated $out_file"
  done < <(extract_narration_lines "$source_file")

  if [[ "$i" -eq 0 ]]; then
    echo "No narration lines found in $source_file" >&2
    exit 1
  fi

  echo "Done. Generated $i narration files in $OUTPUT_DIR"
}

main "$@"
