#!/usr/bin/env bash
set -euo pipefail

# Generate slide narration audio with Piper voices from index.html.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.tts"
BIN_DIR="$WORK_DIR/bin"
MODEL_DIR="$WORK_DIR/models"
OUTPUT_DIR="$ROOT_DIR/assets/narration"
TMP_DIR="$WORK_DIR/tmp"

PIPER_VERSION="v1.2.0"
PIPER_ARCHIVE_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_amd64.tar.gz"

JOE_VOICE_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/joe/medium"
JOE_VOICE_MODEL="en_US-joe-medium.onnx"
JOE_VOICE_CONFIG="en_US-joe-medium.onnx.json"

HFC_FEMALE_VOICE_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_female/medium"
HFC_FEMALE_VOICE_MODEL="en_US-hfc_female-medium.onnx"
HFC_FEMALE_VOICE_CONFIG="en_US-hfc_female-medium.onnx.json"

mkdir -p "$BIN_DIR" "$MODEL_DIR" "$OUTPUT_DIR" "$TMP_DIR"

PIPER_BIN="$BIN_DIR/piper"
JOE_MODEL_PATH="$MODEL_DIR/$JOE_VOICE_MODEL"
JOE_MODEL_CONFIG_PATH="$MODEL_DIR/$JOE_VOICE_CONFIG"
HFC_FEMALE_MODEL_PATH="$MODEL_DIR/$HFC_FEMALE_VOICE_MODEL"
HFC_FEMALE_MODEL_CONFIG_PATH="$MODEL_DIR/$HFC_FEMALE_VOICE_CONFIG"

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
  download_if_missing "$JOE_VOICE_BASE_URL/$JOE_VOICE_MODEL" "$JOE_MODEL_PATH"
  download_if_missing "$JOE_VOICE_BASE_URL/$JOE_VOICE_CONFIG" "$JOE_MODEL_CONFIG_PATH"
  download_if_missing "$HFC_FEMALE_VOICE_BASE_URL/$HFC_FEMALE_VOICE_MODEL" "$HFC_FEMALE_MODEL_PATH"
  download_if_missing "$HFC_FEMALE_VOICE_BASE_URL/$HFC_FEMALE_VOICE_CONFIG" "$HFC_FEMALE_MODEL_CONFIG_PATH"
}

apply_human_artifacts() {
  local input_file="$1"
  local output_file="$2"
  local eyebrow="$3"

  if ! command -v ffmpeg >/dev/null 2>&1; then
    cp "$input_file" "$output_file"
    return 0
  fi

  local noise_gain="0.020"
  local click_gain="0.036"
  local hiss_gain="0.004"
  local leading_pad_ms="160"
  if [[ "$eyebrow" == "Interview" ]]; then
    # Slightly stronger texture for interview tape feel.
    noise_gain="0.026"
    click_gain="0.044"
    hiss_gain="0.012"
    leading_pad_ms="200"
  fi

  if ! ffmpeg -nostdin -hide_banner -loglevel error -y \
    -i "$input_file" \
    -f lavfi -i "anoisesrc=color=pink:amplitude=0.0055:sample_rate=22050" \
    -f lavfi -i "anoisesrc=color=white:amplitude=0.0065:sample_rate=22050" \
    -f lavfi -i "aevalsrc=if(lt(mod(t\,7.3)\,0.0015)\,0.20\,0)+if(lt(mod(t\,11.7)\,0.0012)\,-0.16\,0):s=22050" \
    -filter_complex "[0:a]adelay=${leading_pad_ms}|${leading_pad_ms},afade=t=in:st=0:d=0.03,highpass=f=90,lowpass=f=7600,compand=attacks=0.02:decays=0.25:points=-80/-80|-28/-22|0/-5,volume=1.03[voice];[1:a]highpass=f=220,lowpass=f=5800,volume=${noise_gain}[bed];[2:a]highpass=f=4200,lowpass=f=11000,volume=${hiss_gain}[hiss];[3:a]highpass=f=2600,lowpass=f=7600,volume=${click_gain}[clicks];[voice][bed][hiss][clicks]amix=inputs=4:duration=first:weights=1 1 1 1,alimiter=limit=0.93[out]" \
    -map "[out]" "$output_file"; then
    cp "$input_file" "$output_file"
  fi
}

voice_timing_for_slide() {
  local eyebrow="$1"
  local length_scale="1.16"
  local sentence_silence="0.34"

  if [[ "$eyebrow" == "Interview" ]]; then
    # Give interview clips extra breathing room.
    length_scale="1.22"
    sentence_silence="0.42"
  fi

  echo "$length_scale"$'\t'"$sentence_silence"
}

extract_slide_audio_data() {
  local source_file="$1"
  awk '
    /^[[:space:]]*eyebrow:[[:space:]]*".*",[[:space:]]*$/ {
      eyebrow = $0
      sub(/^[[:space:]]*eyebrow:[[:space:]]*"/, "", eyebrow)
      sub(/",[[:space:]]*$/, "", eyebrow)
      next
    }
    /^[[:space:]]*narration:[[:space:]]*".*",[[:space:]]*$/ {
      narration = $0
      sub(/^[[:space:]]*narration:[[:space:]]*"/, "", narration)
      sub(/",[[:space:]]*$/, "", narration)
      print eyebrow "\t" narration
    }
  ' "$source_file"
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
  while IFS=$'\t' read -r eyebrow line; do
    # Skip empty narration blocks.
    if [[ -z "${line// }" ]]; then
      continue
    fi
    i=$((i + 1))
    local out_file
    local raw_file
    local model_path
    local length_scale
    local sentence_silence
    out_file=$(printf "%s/slide-%02d.wav" "$OUTPUT_DIR" "$i")
    raw_file=$(printf "%s/raw-slide-%02d.wav" "$TMP_DIR" "$i")

    if [[ "$eyebrow" == "Interview" ]]; then
      model_path="$HFC_FEMALE_MODEL_PATH"
    else
      model_path="$JOE_MODEL_PATH"
    fi

    IFS=$'\t' read -r length_scale sentence_silence < <(voice_timing_for_slide "$eyebrow")

    printf "%s\n" "$line" | LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}" "$PIPER_BIN" --model "$model_path" --length_scale "$length_scale" --sentence_silence "$sentence_silence" --output_file "$raw_file" >/dev/null
    apply_human_artifacts "$raw_file" "$out_file" "$eyebrow"
    echo "Generated $out_file (${eyebrow:-Unknown})"
  done < <(extract_slide_audio_data "$source_file")

  if [[ "$i" -eq 0 ]]; then
    echo "No narration lines found in $source_file" >&2
    exit 1
  fi

  echo "Done. Generated $i narration files in $OUTPUT_DIR"
}

main "$@"
