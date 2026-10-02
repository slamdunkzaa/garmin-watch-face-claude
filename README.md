# Starter Face

A pixel-art Garmin Connect IQ watch face for the Forerunner 165 / 165 Music:
an animated Claude Code mascot, time, date, a step-goal bar, a heart rate zone
bar, heart rate, VO2 max, and battery.

## Commands

```bash
make sim       # start the Connect IQ simulator
make run       # build and load the watch face into the running simulator
make build     # build only (make build DEVICE=fr165m for the Music model)
make install   # copy a release build onto a watch connected over USB
make release   # store package bin/StarterFace.iq
```

Builds are signed with `~/.config/garmin-connectiq/developer_key.der`
(override with `DEVELOPER_KEY=...`). Keep that key: store updates must be
signed with the same one.

## Layout

- `manifest.xml` – app id, type, supported devices, permissions
- `source/StarterFaceView.mc` – layout and data, in `onUpdate`
- `source/PixelFont.mc` – 5x7 pixel font and sprite drawing
- `resources/` – strings and the launcher icon

## Install on a watch

Connect the watch over USB and run `make install` (needs `brew install libmtp`).
It copies the build into the watch's `GARMIN/Apps` folder; unplug the watch and
pick the face from the watch face menu. Use `DEVICE=fr165m` for the Music model.
