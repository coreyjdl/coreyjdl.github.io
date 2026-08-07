#!/usr/bin/env bash
set -euo pipefail

# Generate slide narration audio with Piper voices from index.html.
#
# Inline markers supported inside each slide's `narration` string:
#   {{joe}}        Documentary narrator (Piper en_US-joe-medium), clean treatment.
#   {{amy}}        Interviewee A (Piper en_US-hfc_female-medium), archival tape treatment.
#   {{ryan}}       Interviewee B (Piper en_US-ryan-medium), archival tape treatment.
#   {{norman}}     Interviewee C (Piper en_US-norman-medium), archival tape treatment.
#   {{pause 900}}  Insert 900ms of silence at that point.
#
# Default voice per slide is derived from the eyebrow:
#   Interview -> amy, everything else -> joe.
# Markers override the current voice until the next voice marker.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.tts"
BIN_DIR="$WORK_DIR/bin"
MODEL_DIR="$WORK_DIR/models"
OUTPUT_DIR="$ROOT_DIR/assets/narration"
TMP_DIR="$WORK_DIR/tmp"

PIPER_VERSION="v1.2.0"
PIPER_ARCHIVE_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_amd64.tar.gz"

VOICES_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US"

# name : subdir/quality : filename base
# All Piper voices we ship.
VOICE_IDS=(joe hfc_female ryan norman)

voice_hf_url() {
  # $1 = base name (dir), $2 = quality
  echo "$VOICES_BASE_URL/$1/$2"
}

voice_files() {
  # Prints: <onnx_filename> <config_filename>
  local name="$1"
  local quality="$2"
  printf "en_US-%s-%s.onnx\ten_US-%s-%s.onnx.json\n" "$name" "$quality" "$name" "$quality"
}

mkdir -p "$BIN_DIR" "$MODEL_DIR" "$OUTPUT_DIR" "$TMP_DIR"

PIPER_BIN="$BIN_DIR/piper"

# Map voice id -> model path on disk
declare -A VOICE_MODEL_PATH=(
  [joe]="$MODEL_DIR/en_US-joe-medium.onnx"
  [amy]="$MODEL_DIR/en_US-hfc_female-medium.onnx"
  [ryan]="$MODEL_DIR/en_US-ryan-medium.onnx"
  [norman]="$MODEL_DIR/en_US-norman-medium.onnx"
)

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

download_voice() {
  local name="$1"
  local quality="$2"
  local onnx config
  IFS=$'\t' read -r onnx config < <(voice_files "$name" "$quality")
  download_if_missing "$(voice_hf_url "$name" "$quality")/$onnx"   "$MODEL_DIR/$onnx"
  download_if_missing "$(voice_hf_url "$name" "$quality")/$config" "$MODEL_DIR/$config"
}

prepare_voice_if_needed() {
  download_voice joe        medium
  download_voice hfc_female medium
  download_voice ryan       medium
  download_voice norman     medium
}

# Returns: model_path <TAB> length_scale <TAB> sentence_silence <TAB> preset
voice_profile() {
  local voice="$1"
  local model="${VOICE_MODEL_PATH[$voice]:-${VOICE_MODEL_PATH[joe]}}"
  case "$voice" in
    joe)    printf "%s\t%s\t%s\t%s\n" "$model" "1.22" "0.42" "clean" ;;
    amy)    printf "%s\t%s\t%s\t%s\n" "$model" "1.22" "0.42" "interview" ;;
    ryan)   printf "%s\t%s\t%s\t%s\n" "$model" "1.18" "0.38" "interview" ;;
    norman) printf "%s\t%s\t%s\t%s\n" "$model" "1.20" "0.40" "interview" ;;
    *)      printf "%s\t%s\t%s\t%s\n" "$model" "1.22" "0.42" "clean" ;;
  esac
}

default_voice_for_eyebrow() {
  case "$1" in
    Interview) echo "amy" ;;
    *)         echo "joe" ;;
  esac
}

apply_human_artifacts() {
  local input_file="$1"
  local output_file="$2"
  local preset="$3"

  if ! command -v ffmpeg >/dev/null 2>&1; then
    cp "$input_file" "$output_file"
    return 0
  fi

  local noise_gain click_gain hiss_gain leading_pad_ms filter
  case "$preset" in
    interview)
      noise_gain="0.026"; click_gain="0.044"; hiss_gain="0.012"; leading_pad_ms="200"
      filter="[0:a]adelay=${leading_pad_ms}|${leading_pad_ms},afade=t=in:st=0:d=0.03,highpass=f=90,lowpass=f=7600,compand=attacks=0.02:decays=0.25:points=-80/-80|-28/-22|0/-5,volume=1.03[voice];[1:a]highpass=f=220,lowpass=f=5800,volume=${noise_gain}[bed];[2:a]highpass=f=4200,lowpass=f=11000,volume=${hiss_gain}[hiss];[3:a]highpass=f=2600,lowpass=f=7600,volume=${click_gain}[clicks];[voice][bed][hiss][clicks]amix=inputs=4:duration=first:weights=1 1 1 1,alimiter=limit=0.93[out]"
      ;;
    clean|*)
      noise_gain="0.020"; click_gain="0.036"; hiss_gain="0.004"; leading_pad_ms="160"
      filter="[0:a]adelay=${leading_pad_ms}|${leading_pad_ms},afade=t=in:st=0:d=0.03,highpass=f=90,lowpass=f=7600,compand=attacks=0.02:decays=0.25:points=-80/-80|-28/-22|0/-5,volume=1.03[voice];[1:a]highpass=f=220,lowpass=f=5800,volume=${noise_gain}[bed];[2:a]highpass=f=4200,lowpass=f=11000,volume=${hiss_gain}[hiss];[3:a]highpass=f=2600,lowpass=f=7600,volume=${click_gain}[clicks];[voice][bed][hiss][clicks]amix=inputs=4:duration=first:weights=1 1 1 1,alimiter=limit=0.93[out]"
      ;;
  esac

  if ! ffmpeg -nostdin -hide_banner -loglevel error -y \
    -i "$input_file" \
    -f lavfi -i "anoisesrc=color=pink:amplitude=0.0055:sample_rate=22050" \
    -f lavfi -i "anoisesrc=color=white:amplitude=0.0065:sample_rate=22050" \
    -f lavfi -i "aevalsrc=if(lt(mod(t\,7.3)\,0.0015)\,0.20\,0)+if(lt(mod(t\,11.7)\,0.0012)\,-0.16\,0):s=22050" \
    -filter_complex "$filter" \
    -map "[out]" -ar 22050 -ac 1 -c:a pcm_s16le "$output_file"; then
    cp "$input_file" "$output_file"
  fi
}

generate_silence() {
  local ms="$1"
  local out="$2"
  local secs
  secs=$(awk -v v="$ms" 'BEGIN{printf "%.3f", v/1000.0}')
  ffmpeg -nostdin -hide_banner -loglevel error -y \
    -f lavfi -i "anullsrc=r=22050:cl=mono" -t "$secs" \
    -ar 22050 -ac 1 -c:a pcm_s16le "$out"
}

# Reads narration text on stdin. Emits ordered lines to stdout:
#   SPEAK<TAB>voice<TAB>text
#   PAUSE<TAB>ms
NARRATION_PARSER_PY=$(cat <<'PY'
import sys, re
default_voice = sys.argv[1]
text = sys.stdin.read()
pattern = re.compile(
    r'\{\{\s*(joe|amy|ryan|norman|pause)(?:\s+(\d+))?\s*\}\}',
    re.IGNORECASE,
)
pos = 0
current = default_voice
def emit_speak(v, t):
    t = t.strip()
    if not t:
        return
    t = re.sub(r'\s+', ' ', t)
    print(f"SPEAK\t{v}\t{t}")
for m in pattern.finditer(text):
    before = text[pos:m.start()]
    if before.strip():
        emit_speak(current, before)
    tag = m.group(1).lower()
    arg = m.group(2)
    if tag == 'pause':
        ms = int(arg) if arg else 500
        print(f"PAUSE\t{ms}")
    else:
        current = tag
    pos = m.end()
tail = text[pos:]
if tail.strip():
    emit_speak(current, tail)
PY
)

parse_narration_segments() {
  local default_voice="$1"
  python3 -c "$NARRATION_PARSER_PY" "$default_voice"
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

render_slide() {
  local slide_index="$1"
  local eyebrow="$2"
  local narration="$3"

  local out_file concat_list default_voice seg
  out_file=$(printf "%s/slide-%02d.wav" "$OUTPUT_DIR" "$slide_index")
  concat_list=$(printf "%s/slide-%02d.concat" "$TMP_DIR" "$slide_index")
  : > "$concat_list"
  default_voice=$(default_voice_for_eyebrow "$eyebrow")
  seg=0

  while IFS=$'\t' read -r kind field_a field_b; do
    seg=$((seg + 1))
    local seg_file
    seg_file=$(printf "%s/slide-%02d-seg-%03d.wav" "$TMP_DIR" "$slide_index" "$seg")

    if [[ "$kind" == "PAUSE" ]]; then
      generate_silence "$field_a" "$seg_file"
    elif [[ "$kind" == "SPEAK" ]]; then
      local voice="$field_a"
      local text="$field_b"
      local model length_scale sentence_silence preset
      IFS=$'\t' read -r model length_scale sentence_silence preset < <(voice_profile "$voice")

      local piper_wav
      piper_wav=$(printf "%s/slide-%02d-piper-%03d.wav" "$TMP_DIR" "$slide_index" "$seg")
      printf "%s\n" "$text" | LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}" "$PIPER_BIN" \
        --model "$model" \
        --length_scale "$length_scale" \
        --sentence_silence "$sentence_silence" \
        --output_file "$piper_wav" >/dev/null

      apply_human_artifacts "$piper_wav" "$seg_file" "$preset"
    else
      continue
    fi

    printf "file '%s'\n" "$seg_file" >> "$concat_list"
  done < <(printf "%s\n" "$narration" | parse_narration_segments "$default_voice")

  if [[ ! -s "$concat_list" ]]; then
    echo "Warning: no segments produced for slide $slide_index" >&2
    return 1
  fi

  ffmpeg -nostdin -hide_banner -loglevel error -y \
    -f concat -safe 0 -i "$concat_list" \
    -ar 22050 -ac 1 -c:a pcm_s16le "$out_file"
  echo "Generated $out_file (${eyebrow:-Unknown})"
}

main() {
  command -v curl    >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
  command -v tar     >/dev/null 2>&1 || { echo "tar is required" >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }
  command -v ffmpeg  >/dev/null 2>&1 || { echo "ffmpeg is required (for silence + concat)" >&2; exit 1; }

  local source_file="$ROOT_DIR/index.html"
  if [[ ! -f "$source_file" ]]; then
    echo "Could not find $source_file" >&2
    exit 1
  fi

  install_piper_if_needed
  prepare_voice_if_needed

  local i=0
  while IFS=$'\t' read -r eyebrow line; do
    if [[ -z "${line// }" ]]; then
      continue
    fi
    i=$((i + 1))
    render_slide "$i" "$eyebrow" "$line"
  done < <(extract_slide_audio_data "$source_file")

  if [[ "$i" -eq 0 ]]; then
    echo "No narration lines found in $source_file" >&2
    exit 1
  fi

  echo "Done. Generated $i narration files in $OUTPUT_DIR"
}

main "$@"
