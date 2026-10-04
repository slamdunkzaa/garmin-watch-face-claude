# Starter Face

A pixel-art Garmin Connect IQ watch face for the Forerunner 165 / 165 Music,
starring an animated Claude Code mascot whose mood follows your Body Battery.

```
  [mascot]  12:34
   ⚡85     SAT 4 OCT
  ▬▬▬▬▬▬▬▬▬▬            step goal, one block per 10%
  ▬▬ ▬▬ ▬▬ ▬▬ ▬▬        heart rate zone, lit up to the current zone
 ❤ 72  💢 25  🔋 80%    heart rate, stress, battery
```

## The mascot

While the watch is awake the mascot walks on the spot and blinks. Its mood
follows Body Battery:

| Body Battery | Mascot |
|---|---|
| 70 and up | bounces as it walks |
| 30 to 69 | walks normally |
| below 30 | walks at half speed with heavy eyelids |

In always-on mode it stands still, drawn dimmer and nudged every minute to
protect the AMOLED screen. The thresholds are `ENERGETIC_LEVEL` and
`TIRED_LEVEL` in `source/StarterFaceView.mc`.

## Setup

1. **Connect IQ SDK.** Install the SDK Manager from
   <https://developer.garmin.com/connect-iq/sdk/> (needs a Garmin account),
   install the latest SDK and set it as current. On the Devices tab, download
   only Forerunner 165 and Forerunner 165 Music: clicking an API level header
   queues every device in it.
2. **Developer key.** Builds are signed with
   `~/.config/garmin-connectiq/developer_key.der` (override with
   `DEVELOPER_KEY=...`):

   ```bash
   mkdir -p ~/.config/garmin-connectiq && cd ~/.config/garmin-connectiq
   openssl genrsa -out developer_key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
   ```

   Back the key up and never commit it: store updates must be signed with
   the same key.
3. **libmtp**, for installing over USB: `brew install libmtp`.

## Commands

```bash
make sim       # start the Connect IQ simulator
make run       # build and load the watch face into the running simulator
make build     # build only (make build DEVICE=fr165m for the Music model)
make install   # copy a release build onto a watch connected over USB
make release   # store package bin/StarterFace.iq
```

## Install on a watch

1. On the watch, set **Settings → System → USB Mode** to **MTP**.
2. Connect it over USB and check that `mtp-detect` lists it.
3. Run `make install` (`DEVICE=fr165m` for the Music model). It copies the
   build into the watch's `GARMIN/Apps` folder.
4. Unplug the watch, hold UP, open **Watch Face** and pick Starter Face.

To update, run `make install` again. Switching back to another face is done
from the same menu.

### Troubleshooting

- **"No MTP device found"**: the watch is probably in Garmin's own USB mode,
  which shows up in System Information as a "Vendor-Specific Device". Switch
  it to MTP (step 1). Also quit Garmin Express or Android File Transfer, which
  can hold on to the watch, and try a cable that carries data.
- **"Device ... is UNKNOWN in libmtp"**: harmless; libmtp just has no entry
  for this model yet.

## Layout

- `manifest.xml` – app id, type, supported devices, permissions
  (`SensorHistory` for Body Battery and stress, `UserProfile` for heart rate
  zones)
- `source/StarterFaceView.mc` – layout and data, in `onUpdate`
- `source/PixelFont.mc` – 5x7 pixel font and sprite drawing; sprites are
  lists of rows with the highest bit as the leftmost pixel
- `resources/` – strings and the launcher icon

The bottom row is already as low as the round screen allows: moving it down
clips the widest values (heart rate 185, battery 100%) at the screen's edge.
