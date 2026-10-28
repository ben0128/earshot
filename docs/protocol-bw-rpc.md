# Bowers & Wilkins RPC protocol — cheat sheet

Control protocol of current Bowers & Wilkins headphones and earbuds (the generation driven by the B&W Music app). Compiled 2026-10-29 from public sources; **nothing here has been verified by Earshot on hardware yet** — that is milestone M0 (see [decisions.md](decisions.md#m0-hardware-checklist)).

| Tag | Meaning |
|---|---|
| **[V]** | Verified in HeadBridge source, its captured frames, or its hardware notes |
| **[O]** | From another project (OM / PX / GB below) |
| **[I]** | Inference, unverified |

## Sources

| Key | Project | License | Use |
|---|---|---|---|
| HB | [herenickname/HeadBridge](https://github.com/herenickname/HeadBridge/blob/940e7e797bf4f75eeefce8d99fb3883ec23b0a39/docs/BowersWilkinsRPC.md) @ `940e7e7` — validated on Px7 S3 fw 3.17.4.17 and original Px8 | MIT | Facts + codec may be reused with notice |
| OM | [DominicBoettger/omarchy-bw-headphones](https://github.com/DominicBoettger/omarchy-bw-headphones/blob/b04ffb861c9127a9e6cf3f53482718bffbf769e0/bin/protocol.py) @ `b04ffb8` — verified on Px7 S2 | MIT | Facts |
| PX | [tamashi095/px8ctl](https://github.com/tamashi095/px8ctl) @ `2b76ae0` — Px8 S2 | none | **Facts only, no code** |
| GB | Gadgetbridge `bandwpseries` — Pi-series earbuds | AGPL-3.0 | **Facts only, no code** |

## 1. Transport — BLE GATT

Not RFCOMM / SPP / iAP2. The control link is a separate LE connection with its own address; `system_profiler` shows only the classic HFP/AVRCP/A2DP entry until an app connects over LE.

| Item | UUID / value |
|---|---|
| Service | `85ba93a5-09ac-439a-8cc4-1c3f0cb4f29f` [O] (HB matches characteristics, not the service) |
| Request (write) | `ada50ce9-67b8-4a97-9d8e-37e1d083156c` [V] — also used by GB for Pi earbuds |
| Response (notify, required) | `cb909093-3559-4b0c-9a7f-3f1773122fdc` [V] |
| Event (notify, optional) | `df55d475-9a32-457a-9e20-38cf14e853fb` [V] |
| DFU — **never touch** | `b4a53e25-6ec8-42d7-a7ab-63bf9a3ef8ba`, `b99b5002-2914-4d48-bde0-56deba8a3bd9` [O] |
| Write type | with response if the characteristic supports `.write`, else without [V] |
| Handshake / auth | **none** — enable notify on Response, then send GETs [V]. Anyone in range can write [O] |
| Pairing / bonding | not required [I/O] |

**Discovery.** Px7 S3 advertises its model name; original Px8 and Px7 S2/S2e advertise `LE_BWHP` (Px8 rotates its identifier per connection). Manufacturer data carries the product code `FPxxxxx` (Px7 S3: FP45330 / FP45349 / FP45357 / FP46604 / FP46612) [O]. Whether a user-renamed device advertises the custom name is unknown [I]. **Earshot identifies devices by the presence of the Request characteristic, not by name** (decision Q14).

**macOS.** CoreBluetooth (`CBCentralManager`); `NSBluetoothAlwaysUsageDescription` in Info.plist; `com.apple.security.device.bluetooth` if sandboxed. The Bluetooth TCC grant is tied to the code signature — ad-hoc rebuilds lose it, so sign with a stable identity.

## 2. Framing

Little-endian, MessagePack payload, no CRC, no transaction ID. [V]

```
TX  size | 0B 12 | id | ns                                (no payload, size = 4)
TX  size | 0B 92 | id | ns | len LE16 | msgpack           (size = len + 6)
RX  0C 12 | id | ns | err LE16                            reply
RX  0C 92 | id | ns | err LE16 | len LE16 | msgpack       reply with payload
RX  0D 12 | id | ns                                       event
RX  0D 92 | id | ns | len LE16 | msgpack                  event with payload
```

- Incoming frames have **no size byte**. On the wire the id precedes the namespace; this document writes the pair as `ns:id`.
- 1-byte size → max request 255 bytes, no fragmentation [I]. Meaning of `0x12` unknown.
- Replies are matched by `ns:id` only, and are **broadcast to every connected GATT client** — you also see the phone app's replies (it polls every ~30 s) [O].

**Exact frames** (HB `RPCCodecTests.swift`):

| Purpose | Bytes |
|---|---|
| ANC get | `04 0B 12 01 03` |
| ANC set 0 / 1 / 2 | `07 0B 92 02 03 01 00 00` / `…01` / `…02` |
| EQ set flat | `0C 0B 92 29 04 06 00 95 00 00 00 00 00` |
| Bass set −60 | `08 0B 92 17 04 02 00 D0 C4` |
| True Immersion on / preset 2 | `07 0B 92 2D 04 01 00 C3` / `07 0B 92 2F 04 01 00 02` |
| RX ANC reply = 1 | `0C 92 01 03 00 00 01 00 01` |
| RX ANC event = 2 | `0D 92 01 03 01 00 02` |
| RX error 8 (Px8, bass rejected) | `0C 12 17 04 08 00` |
| Battery get | `04 0B 12 0C 08` [O] |

**Error codes.** [V] 1 unsupported on this model · 3 busy (previous setter still applying) · 6 invalid value/state · 8 out of range. [O] 2 asleep · 5 unsupported · 13 invalid payload.

## 3. Commands (`ns:id`)

"S3" = exposed by HB after hardware validation on Px7 S3.

| Feature | GET | SET | Values | Models |
|---|---|---|---|---|
| Battery % | 08:0C | — | 0–100 | S3 [V] |
| Charging | 08:0B | — | bool | S3 [V] |
| Battery L / R / case | 08:17 | — | array, `0xFF` = unknown | Pi earbuds [O] |
| Noise control | 03:01 | 03:02 | **S3: 0 off · 1 ANC · 2 pass-through** | [V] |
| Pass-through level / enable | 03:03 / 03:05 | 03:04 / 03:06 | int / bool | Pi [O]; S3 unknown |
| 5-band EQ | 04:2A | 04:29 | array[5] of −60…60, probably 0.1 dB [O]; centre frequencies unknown | S3 [V] |
| EQ bypass ("True Sound") | 04:2C | 04:2B | bool. Px8 S2 rejects 04:29 (err 6) while bypass is on [O] | S3 |
| Bass / treble | 04:18 / 04:1A | 04:17 / 04:19 | −60…60 | Px8, Px7 S2 |
| EQ presets | — | — | none known on the wire; presets are client-side [I] | — |
| Wear sensor | 0A:01 | 0A:02 | bool | S3 |
| Wear sensitivity | 0A:03 | 0A:04 | 1–3 (direction unconfirmed) | S3 |
| Auto standby | 02:06 | 02:05 | minutes (HB offers 0 = never, 5, 10, 15, 30, 60, 120) | S3 |
| Voice prompts | 04:09 | 04:08 | bool | S3 |
| True Immersion | 04:2E | 04:2D | bool (Px8 → err 1) | S3 |
| True Immersion preset | 04:30 | 04:2F | 0 Focused · 1 Balanced · 2 Expanded | S3 |
| Quick-action button | 08:2B | 08:2A | 0 noise control · 1 voice assistant (OM: 2 = both) | S3 |
| Device name | 05:01 | 05:02 | string | S3 |
| Firmware | 02:01 | — | string | all |
| Serial / BT address | 08:04 / 08:02 | — | string / address (equals the classic address on Px8) | all |
| Codec | 05:06 | — | 1 SBC · 3 AAC · 5 aptX · 7 aptX HD · 8 aptX LL · 9 aptX Adaptive | S3 |
| Source / sample rate | 04:0C / 04:14 | — | 2 AUX · 5 USB · 6 A2DP1 · 7 A2DP2 / Hz | S3 |
| Paired list | 05:0B (count), 05:04 (index) | — | map {1: address, 2: name, 3: connected}; key type disputed (HB string, OM int) | read-only |
| Multipoint | 05:14 (primary) | 05:05 connect(slot), 05:10 disconnect(slot) | slot | Px7 S2 [O]; S3 unverified |

## 4. Events

| ns:id | Meaning |
|---|---|
| 03:01 | Noise-control mode changed on the device (verified on Px8; expected on S3) |
| 04:16 | Audio info `[source, codec, rate]` |
| 02:09 | Sleep |

No battery push is documented — HB polls every 5 min. Earshot reads battery only when the menu opens (decision Q11).

## 5. Model differences

| | Px7 S3 | Px8 (orig) | Px7 S2 / S2e | Px8 S2 |
|---|---|---|---|---|
| Advertised name | model name | `LE_BWHP`, rotating ID | `LE_BWHP` | intermittent [O] |
| ANC values | 0 / 1 / 2 [V] | 1 / 2 / 3, rejects 0 [V] | 1 / 2 / 3 [O] | 0 / 1 / 2 [O] |
| Tone | 5-band + bypass | bass / treble | bass / treble | 5-band, bypass must be off |
| True Immersion | yes | no | no [I] | unknown |

Older models (PX5, PX7 gen 1, PI4) use ANC 1–4 = off / low / high / auto [O]; whether they speak this RPC at all is unknown.

## 6. Safety

- **Never send** (firmware / factory reset / wipe pairings) [O]: `07:01`, `07:04`, `08:0E`, `02:17`, `02:1A`. Treat namespace `07` as firmware. Never write the DFU characteristics. Avoid `05:0D` (remove paired device).
- Earshot uses a **compile-time allowlist** plus this denylist and ships no raw-send API (decision Q10).
- Before any write, read `08:02` and compare it with the classic address of the connected headset, so a neighbour's pair is never written to [I].
- Writes fail while the device sleeps (err 2); reads still work [O].
- Setters apply late — re-read only after the setter's reply arrives [V].
- The phone app's traffic interleaves with yours, and control may be exclusive with it [O].

## Unknowns (resolved at M0)

EQ units and band frequencies · whether the S3 pushes noise-control / source changes · multipoint commands on the S3 · paired-list key type · advertised name of a renamed device · pass-through level on the S3 · the `0x12` byte.
