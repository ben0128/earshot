# Decisions

Design decisions from the planning interview (2026-10-29). Each row was put to the owner as a question with a recommendation and answered; "open" rows are still pending.

## Decision log

| # | Topic | Decision | Why |
|---|---|---|---|
| Q1 | Name | **Earshot** | Avoids B&W trademarks (Bowers, Wilkins, Px); brand-neutral, so it survives Sony / Bose support |
| Q2 | Repo | Public, MIT, commits authored with a GitHub noreply address; Bluetooth captures (`*.pklg`, `*.pcap`, `*.btsnoop`, `captures/`) git-ignored | Captures carry device addresses and serials |
| Q3 | Docs | Public design docs live here in `docs/`; private notes (device addresses, personal hardware) stay outside the repo | |
| Q5 | Footprint | Zero third-party dependencies, pure AppKit (no SwiftUI, no Sparkle). Budget: **< 1 MB binary, < 15 MB resident** | Menu prototype measured 169 KB / 12 MB |
| Q6 | Shape | One binary: no arguments → menu bar app; arguments → CLI | Same as Nibble; scriptable from Raycast / shortcuts; testable without a screen |
| Q7 | Menu placement | Do **not** replace the system Sound menu (it hosts AirPods controls third parties cannot reproduce). Earshot shows only device-specific controls; volume, output switching and battery-in-menu stay with macOS. The status item appears **only while a supported headset is connected** | No public API can extend the system Sound menu; injecting into ControlCenter needs SIP disabled |
| Q8 | Fork vs rewrite | **Rewrite.** Reuse only HeadBridge's `BWRPC.swift` + `MessagePack.swift` (MIT, notice kept) and port their exact-frame tests. px8ctl (no license) and Gadgetbridge (AGPL) are used for facts only | HeadBridge's B&W code is coupled to SwiftUI, Sparkle and a 2k-line provider |
| Q9 | Control link | Keep the BLE control link while the headset is connected to this Mac, even when the phone has the audio route | Change noise control from the Mac while listening on the phone; HeadBridge drops the link |
| Q10 | Safety | Compile-time allowlist + denylist (see protocol §6); no raw-send API in release builds; never touch DFU characteristics; verify `08:02` against the connected headset's classic address before writing | The device has no authentication; firmware / reset commands can brick or wipe it |
| Q11 | Battery | Read on menu open and on connect; **superseded in part by Q20** | |
| Q12 | First milestone | **M0 hardware spike, read-only**, before any production code | Several protocol facts are unverified on the S3 |
| Q13 | Auto source switching | **Not doing** — the headsets switch between Mac and phone natively | Owner confirmed on hardware |
| Q14 | Supported devices | Detect by the **RPC Request characteristic**, not by model name. Every B&W device speaking this RPC works automatically | The Music-app generation (Px7 S2/S2e, Px8, Px8 S2, Px7 S3, Pi5 S2, Pi7 S2, Pi6, Pi8) shares it; older models may or may not |
| Q15 | Untested models | README compatibility table: Verified / Community-reported / Untested. Unverified models show an "Untested — report" link | Only the Px7 S3 can be verified by the maintainer |
| Q16 | Extensibility | Five layers, interfaces defined now, **only B&W implemented**. Menu and CLI may only talk to the capability model | Sony / Bose planned later; guessing interfaces with one implementation is the bigger risk |
| Q17 | Stack | Same as Nibble: `swiftc` + Makefile (no SwiftPM / Xcode project), hand-rolled test harness + mutation testing, CoreBluetooth, stable self-signed identity (keeps the Bluetooth TCC grant across rebuilds), Homebrew tap building from source, macOS 14+ | Proven toolchain; building from source avoids quarantine without notarization |
| Q18 | EQ placement | EQ lives **in the menu**; **no settings window** in v1 — rare settings go in a "More" submenu | Sliders in `NSMenuItem.view` work and the menu does not close while dragging |
| Q19 | Scope | Required / optional / not-doing lists below | |
| P1 | Menu layout | **Variant B "Control panel"** from the menu prototype: segmented controls for noise control and True Immersion, horizontal EQ rows, inline switches; the menu stays open while adjusting | Owner's pick after trying variants A / B / C. Prototype kept on branch `prototype/menu` |
| Q20 | Live battery in the status icon | **Yes** — battery is drawn into the status item, like Nibble. Overrides Q11's "read on open only" | Owner's request |
| Q21 | Icon design | **Headband gauge** (the headband arc is the battery gauge, number between the ear cups), drawn at **80%** of the prototype size (24 × 18 pt slot). Template image; red below the low-battery threshold | Owner's pick from three candidates on `prototype/menu` |
| Q22 | Battery refresh cadence | Poll `08:0C` / `08:0B` **every 10 min** over the already-open control link, plus on connect, wake and menu open | Owner's call; the S3 has no documented battery push |
| Q23 | Headset button → custom Mac action (e.g. start ChatGPT voice mode) | **Double-press the Quick button = action; single press = normal noise-control toggle.** Earshot only observes: a single `03:01` push is left alone; two pushes within a window (start at 500 ms, tune at M0) mean double-press → Earshot restores the mode from before the first press and fires the action. `03:01` pushes caused by Earshot's own writes are ignored. Feasibility pending M0 | No public API exposes HFP voice-assistant (`AT+BVRA`) or AVRCP presses to third-party apps; the RPC event is the only clean signal. Trade-offs: noise mode flickers briefly on a double press; pressing twice to step two modes ahead now fires the action instead |
| Q23a | First action | Synthesize a **Right Command** press — the owner's ChatGPT voice-mode hotkey. Lone-modifier synthesis must set the device-dependent right-Command flag, not just ⌘ (Nibble already presses/releases real modifiers; right vs left to be verified). Needs the Accessibility permission | The installed ChatGPT app exposes no App Intents and no voice URL scheme, so a hotkey is the only clean entry point |
| Q25 | Audio during a button-triggered voice session | **Proposed:** when the action fires, Earshot makes the headset the default input and restores the previous input once the microphone goes idle (`kAudioDevicePropertyDeviceIsRunningSomewhere`). Output stays on the headset | Any Bluetooth headset mic on macOS switches A2DP → HFP: audio drops to call quality while the mic is open and recovers afterwards |
| Q24 | Where the button action is edited | **Wanted by owner: inside Earshot.** Proposed: More ▸ Quick Button ▸ action list + "Choose action…" opening a small transient editor (keystroke recorder / app / URL / Shortcut) | Keystroke capture inside an open `NSMenu` is unreliable; a transient sheet is not a settings window |

## Architecture

```
Menu bar / CLI      reads and writes the capability model only — never vendor code
Capability model    noise modes = vendor-labelled list; EQ = bands + range, or bass/treble
Vendor driver       BWDriver (v1) · SonyDriver / BoseDriver later — allowlist, value mapping, capability probing
Protocol codec      B&W RPC + MessagePack
Transport           BLE GATT (v1) · RFCOMM later (interface only)
```

Borrowed from HeadBridge: capabilities from successful reads; setter → reply → debounced read-back; bounded coalescing write queue; generation tokens against stale callbacks; scan only while a matching audio route exists. Slider writes fire on `.leftMouseUp` only and identical consecutive writes are dropped — the prototype's first version wrote on press *and* release (found in its write log). Fixed relative to it: reply timeouts, UI updates only after device confirmation, user-visible "asleep" state, reconnect via `retrievePeripherals`, no `system_profiler` spawning, Bluetooth-denied state that links to System Settings.

## Scope

### v1 — required
| Area | Contents |
|---|---|
| Status item | Shown only while a supported headset is connected; live battery in the icon (Q20, design Q21) |
| Menu (variant B) | Header (name, battery; L / R / case for earbuds) · Noise control · True Immersion · EQ (True Sound, reset, write on release) · Wear sensor · Voice prompts · More ▸ (wear sensitivity, auto standby, quick button, connected devices read-only, rename, info) · Start at Login · Quit |
| CLI | `status`, `anc`, `eq`, `immersion`, `wear`, `doctor`; `--json` everywhere; exit codes 0 / 1 / 2 / 64 |
| Login | `SMAppService` login item |
| Safety | Q10 |
| Robustness | Reply timeouts, confirm-then-render, asleep state, `retrievePeripherals` reconnect |
| Single device | With two supported headsets connected, control the most recently connected |
| Distribution | Homebrew tap, compatibility table, codec frame tests + mutation testing |

### Optional — in priority order
0. Quick button → custom Mac action, editable in the app (Q23 / Q24) — position pending owner's call
1. Global hotkeys (cycle noise control)
2. Manual multipoint source switching — only if M0 confirms the commands on the S3
3. Noise control by frontmost app (e.g. pass-through while Zoom is frontmost)
4. Restore a saved profile on connect
5. macOS 26 Control Center control (noise control toggle)
6. Low-battery notification
7. Multiple headsets at once
8. Sony and Bose drivers

### Not doing
Firmware update, factory reset, editing the pairing list, DFU · automatic source switching (native) · replacing the system Sound menu, volume or output switching · battery history · streaming services · Sparkle auto-update · accounts.

## Milestones

| | Goal |
|---|---|
| M0 | Read-only hardware spike on a Px7 S3 — answers the checklist below |
| M1 | Transport + codec + tests + `earshot status` |
| M2 | Writes with the safety layer (allowlist, address check, confirm-then-render) |
| M3 | Menu bar app (variant B) + live battery icon |
| M4 | Packaging: `.app`, stable signing, login item, Homebrew tap, release |

## M0 hardware checklist

All reads; no writes.

- [ ] Advertised BLE name of a renamed Px7 S3; manufacturer data product code
- [ ] `08:02` equals the classic Bluetooth address
- [ ] EQ value units and band centre frequencies
- [ ] Does pressing the Quick button (set to noise control) push `03:01`, and how fast? (gates Q23)
- [ ] Fast double press: are both presses registered and both pushed (or does the second hit "busy")? Gap between the two events? Any native double-press behaviour? (gates Q23)
- [ ] Which `08:2A` values does the S3 accept (read the current one only)
- [ ] Without headphones: does a synthesized Right Command open ChatGPT voice mode? (gates Q23a)
- [ ] Does a source change push `04:16` / anything readable via `05:14`?
- [ ] Paired-list (`05:04`) key type: string or int
- [ ] Is `03:03` (pass-through level) present on the S3?
- [ ] Is there any battery push, or is polling required?
- [ ] Coexistence with the phone app connected at the same time
- [ ] Manual: does the Quick button's "voice assistant" trigger Siri on the Mac?
- [ ] Look for commands behind "preferred device at power-on" / "auto-connect last device" in sources (do not probe unknown ids)
