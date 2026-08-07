# Presentation Narration

This project uses Piper TTS for slide narration audio.

On-screen narration text is hidden in the slide UI. Narration is audio-first.

## Regenerate narration audio

Run this command from PowerShell:

```powershell
wsl bash -lc "cd /home/corey/coreyjdl.github.io/presentation && ./scripts/narrate-with-piper.sh"
```

The script generates WAV files into:

- `assets/narration/slide-01.wav`
- `assets/narration/slide-02.wav`
- ...
- `assets/narration/slide-XX.wav` (one file per non-empty slide narration)

Voices used:

- `en_US-joe-medium` for all standard slides
- `en_US-hfc_female-medium` for slides with eyebrow `Interview`

Humanizing artifacts:

- The generator applies subtle post-processing with `ffmpeg` (light room tone, tiny click texture, gentle dynamics) to make speech feel less synthetic.
- If `ffmpeg` is unavailable, the script falls back to clean Piper output.
