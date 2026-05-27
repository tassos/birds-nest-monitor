# birdsnest-timelapse

A motion-aware timelapse system for a wildlife webcam (or any MJPEG stream).
Captures frames from a live stream, detects motion via frame differencing, and
compiles daily timelapse videos — all driven by systemd user services.

## Features

- **Motion-aware capture** — polls the stream at a fast, fixed interval
  (`INTERVAL_MOTION`); saves frames when motion is detected, discards them
  when the scene is static.
- **Adaptive static fallback** — even during quiet periods a frame is saved
  every `INTERVAL_STATIC` seconds, so the timelapse never has a black gap.
- **Smooth ramp** — after motion stops, the static save interval ramps linearly
  from `INTERVAL_MOTION` up to `INTERVAL_STATIC` over `RAMP_DURATION` seconds,
  avoiding a hard jump in frame density.
- **Accumulated-change detection** — the reference frame only advances when a
  frame is saved, so slow motion (a bird gradually settling) accumulates across
  polls and triggers detection reliably.
- **Active-hours gating** — no frames are captured outside a configurable time
  window (`ACTIVE_START` / `ACTIVE_END`); the service sleeps until the next
  window rather than busy-looping.
- **Daily auto-compile** — a systemd timer runs `timelapse-compile-daily` at
  00:15 each night, compiling yesterday's frames into an MP4 and deleting the
  source JPEGs on success.
- **On-stop compile** — stopping `timelapse-capture.service` also triggers a
  full compile of whatever frames are on disk.

## Dependencies

| Tool | Purpose |
|------|---------|
| `ffmpeg` | Stream capture and video encoding |
| `magick` (ImageMagick) | Frame-difference metric (`RMSE`) |
| `bc` | Floating-point arithmetic for the ramp calculation |

`make install` checks for these and fails early if any are missing.

## Installation

```sh
# 1. Install dependencies (Arch example):
sudo pacman -S ffmpeg imagemagick bc

# 2. Install scripts, systemd units, and sample config:
make install

# 3. Edit the config:
$EDITOR ~/.config/timelapse/config

# 4. Enable and start the services:
make enable
```

To allow the service to start at boot without an active login session:

```sh
loginctl enable-linger
```

## Uninstall

```sh
make disable    # stop and disable services
make uninstall  # remove scripts and unit files
```

## Configuration

The config file lives at `~/.config/timelapse/config` (created from
`timelapse.conf.sample` on first install). All variables are optional —
the scripts fall back to sensible defaults.

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAM_URL` | *(required)* | MJPEG stream URL |
| `FRAMES_DIR` | `~/Videos/birdsnest-timelapse/frames` | Where captured frames are stored |
| `OUTPUT_DIR` | `~/Videos/birdsnest-timelapse/output` | Where compiled videos are saved |
| `INTERVAL_MOTION` | `5` | Seconds between capture attempts; also the motion detection resolution |
| `INTERVAL_STATIC` | `60` | Seconds between saves when the scene is static |
| `RAMP_DURATION` | `300` | Seconds to ramp from `INTERVAL_MOTION` to `INTERVAL_STATIC` after motion stops |
| `MOTION_THRESHOLD` | `0.02` | Normalized RMSE cutoff `[0,1]`; lower = more sensitive |
| `TIMELAPSE_FPS` | `24` | Frames per second in the compiled video |
| `ACTIVE_START` | `06:00` | Start of the capture window |
| `ACTIVE_END` | `21:00` | End of the capture window |

### Tuning `MOTION_THRESHOLD`

The right value depends on your stream's noise floor. A quick way to find it:

```sh
journalctl --user -u timelapse-capture -f | grep "no motion"
```

The `diff=` values in those lines are the measured RMSE for truly static frames.
Set `MOTION_THRESHOLD` a little above the highest value you see there.
Typical range: `0.01` (very sensitive) – `0.05` (coarse).

## Scripts

| Script | Description |
|--------|-------------|
| `timelapse-capture` | Main capture loop (run via systemd service) |
| `timelapse-compile` | Compile frames into an MP4; accepts `--date YYYYMMDD` to filter by day |
| `timelapse-compile-daily` | Compile yesterday's frames and delete the source JPEGs on success |

### Manual compilation

```sh
# Compile all frames on disk:
timelapse-compile

# Compile a specific day:
timelapse-compile --date 20250527

# Merge several MP4s into one (using ffmpeg concat):
ffmpeg -f concat -safe 0 \
  -i <(printf "file '%s'\n" ~/Videos/birdsnest-timelapse/output/timelapse_*.mp4) \
  -c copy merged.mp4
```

## File layout

```
birdsnest-timelapse/
├── Makefile
├── README.md
├── timelapse.conf.sample
├── timelapse-capture
├── timelapse-compile
├── timelapse-compile-daily
└── systemd/
    ├── timelapse-capture.service
    ├── timelapse-compile-daily.service
    └── timelapse-compile-daily.timer
```

Installed paths (with default `PREFIX=~/.local`):

```
~/.local/bin/             timelapse-{capture,compile,compile-daily}
~/.config/systemd/user/   timelapse-*.service / *.timer
~/.config/timelapse/      config
~/Videos/birdsnest-timelapse/
    frames/               frame_YYYYMMDD_HHMMSS_mmm.jpg  (live, deleted after compile)
    output/               timelapse_YYYYMMDD_HHMMSS.mp4
```
