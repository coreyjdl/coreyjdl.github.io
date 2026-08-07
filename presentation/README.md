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

Voices used (Piper models, all `medium` quality):

- `en_US-joe-medium` — default narrator (clean documentary treatment)
- `en_US-hfc_female-medium` — Amy (archival tape treatment); also the default for any slide whose eyebrow is `Interview`
- `en_US-ryan-medium` — Ryan (archival tape treatment)
- `en_US-norman-medium` — Norman (archival tape treatment)

Models are downloaded on first run into `.tts/models/` (ignored by git). Delete that folder to force a re-download.

## Multi-voice narration markers

You can mix voices, insert timed pauses, and stage tape-quote clips inside a single slide's `narration` string using inline markers.

| Marker | Effect |
| --- | --- |
| `{{joe}}` | Switch to Joe (clean narrator) |
| `{{amy}}` | Switch to Amy — `hfc_female`, archival tape treatment |
| `{{ryan}}` | Switch to Ryan, archival tape treatment |
| `{{norman}}` | Switch to Norman, archival tape treatment |
| `{{quote}}` | Joe voice bandpassed and cracklier — for period quotes |
| `{{pause 900}}` | Insert 900ms of silence |

Rules:

- A voice marker stays in effect until the next voice marker.
- Default voice is derived from the slide's `eyebrow`: `Interview` starts on `{{amy}}`; everything else starts on `{{joe}}`.
- No marker at all? The whole slide renders with the default voice — existing single-voice slides keep working.
- Pauses are exact; use them for beats between speakers or for dramatic timing that Piper punctuation can't hit.
- The same interviewee (e.g., Amy) can appear more than once in a slide — just drop `{{amy}}` in again before their next line.

Example (Amy intro + interview + Joe closes):

```js
narration:
  "{{joe}}Our next voice has been in the scene since the first arena chorus. She isn't nostalgic — she's suspicious. {{pause 900}} " +
  "{{amy}}I mean… I thought we were just getting back to something honest. And then… looking back now, that was kind of the point. It felt harmless, while it was teaching us how to move together on cue. {{pause 700}} " +
  "{{joe}}She isn't wrong about the feeling. What she calls harmless was, in fact, a rehearsal for something bigger.",
```

Under the hood: each speech chunk is rendered separately by Piper with the correct model and cadence, textured with the voice's humanization preset, and then all chunks + silences are concatenated into the slide's final `slide-XX.wav`.

Humanizing artifacts:

- The generator applies subtle post-processing with `ffmpeg` (light room tone, tiny click texture, gentle dynamics) per segment.
- Interview voices get an archival tape treatment; period quotes get a narrower bandpass with more crackle.
- If `ffmpeg` or `python3` is unavailable, the script exits with an error at startup.
