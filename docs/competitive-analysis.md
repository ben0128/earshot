# Competitive analysis

As of 2026-10-29. Method borrowed from Nibble: take what each competitor does well, find the gap nobody fills.

## 1. Official B&W Music app — iOS / Android only

No macOS or Windows version ([RTINGS](https://www.rtings.com/headphones/tools/compare/bowers-wilkins-px7-s2-wireless-bowers-wilkins-px8-wireless/34000/35268)).

| Area | Features (Px7 S3) |
|---|---|
| Noise | ANC / Pass-Through / Off; Quick Action button cycles them or calls the voice assistant |
| Sound | 5-band EQ, True Sound (bypass), True Immersion (3 presets) |
| Sensors / power | Wear sensor on/off + sensitivity, auto standby |
| Multipoint | 2 devices; paired-device list, remove, preferred device, reconnect, auto-connect |
| Other | Rename, firmware update, streaming hub (TIDAL, Qobuz, …), account required |

Common complaints ([App Store](https://apps.apple.com/us/app/bowers-wilkins-music/id1551992219), [Android Central](https://www.androidcentral.com/accessories/headphones/bowers-and-wilkins-px7-s3-review)): login and network required just to change a setting, barebones, failing firmware updates, connection problems, no desktop app.

## 2. HeadBridge — the direct competitor

[herenickname/HeadBridge](https://github.com/herenickname/HeadBridge): MIT, SwiftUI `MenuBarExtra(.window)` + Sparkle, B&W + Sony. Created 2026-08-15, one release (v0.1.7, 4.38 MB zip, 57 downloads), one maintainer. Hardware-validated on Px7 S3 and original Px8 only. Self-signed, not notarized, installed by a `curl | bash` script that strips quarantine. No CLI, no hotkeys.

| Borrow | Fix |
|---|---|
| Dependency-free RPC + MessagePack codec with exact-frame tests | 2,000-line provider class doing scan, GATT, state, restore and logging |
| Capabilities derived from successful reads, not model names | No reply timeout; UI updates before the device confirms; "asleep" invisible |
| Setter → reply → debounced read-back | Reconnect gives up after 2 tries; never uses `retrievePeripherals` |
| Bounded, coalescing write queue with 4 s timeout | Drops control when the phone takes the audio route |
| Generation tokens discard stale callbacks | Spawns `system_profiler` on every audio-route change |
| Scans only while a matching audio route exists | Battery history rewrites a 90-day plist per sample |
| Single-instance lock; capped, opt-in protocol log | Safety by omission: no denylist, unrestricted `sendRaw` |
| | Bluetooth denial reported as "unavailable", no path to System Settings |
| | Control Center widget triggered via unauthenticated distributed notifications |

## 3. Other projects

| Project | Scope | Notable |
|---|---|---|
| [omarchy-bw-headphones](https://github.com/DominicBoettger/omarchy-bw-headphones) | B&W, Linux | CLI `hpctl`, ANC hotkey, multipoint source control; verified on Px7 S2 |
| [px8ctl](https://github.com/tamashi095/px8ctl) | B&W, Rust CLI | Experimental, no license; EQ writes verified on Px8 S2 |
| [sound-connect](https://github.com/aecca/sound-connect) | Sony / Bose, Mac + Linux | 1.5 MB, CLI, global shortcuts, Raycast, ambient during calls |
| [Open Sound Connect](https://opensoundconnect.app) | Sony, Mac | Scenes by frontmost app / schedule / connection, shortcuts |
| [Fader](https://github.com/pantafive/fader) | Generic, Mac | Output switching; notarized Homebrew cask |
| [AirBattery](https://github.com/lihaoyun6/AirBattery), [ToothFairy](https://c-command.com/toothfairy/) | Generic, Mac | Battery widgets, per-device connect hotkeys |

Since ~September 2026 single-brand Mac menu-bar apps have appeared for Nothing, Sony, Bose, Soundcore and Dyson.

**Correction to an early draft:** macOS *does* show Px7 S3 battery — in the system Sound menu, under the connected device. `system_profiler` lacking a battery field does not mean the OS cannot read it. Battery display is therefore not a differentiator.

## 4. Gap

| Dimension | B&W on Mac today | Gap |
|---|---|---|
| Notarized / Homebrew install | nobody | **open** → Homebrew tap, built from source |
| Lightweight | HeadBridge 4.4 MB, SwiftUI popover | medium → < 1 MB binary, < 15 MB resident, measured |
| Stays controllable when the phone has the audio | HeadBridge drops the link | **open** → decision Q9 |
| Keyboard shortcuts | none | **open** → optional #1 |
| CLI | dev-only tools | **open** → same binary |
| Per-app noise control | restore-on-connect only | **open** → optional #3 |
| Battery | system Sound menu already shows it | none |
| Auto source switching | the headsets do it natively | none — not doing |

**Positioning:** easy install > reliability > lightness (with measured numbers). "No SwiftUI / no Sparkle" is how lightness is achieved, not the pitch.
