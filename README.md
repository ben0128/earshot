# Earshot

Lightweight native macOS menu bar app (+ CLI) for Bowers & Wilkins headphones.
No official B&W app exists for macOS; Earshot fills that gap with zero dependencies.

| | |
|---|---|
| Status | Planning — no code, no release yet. Next: M0 hardware spike |
| Protocol | B&W RPC over BLE GATT ([cheat sheet](docs/protocol-bw-rpc.md)) |
| Platform | macOS 14+, Swift + AppKit, zero third-party dependencies |
| Footprint goal | < 1 MB binary, < 15 MB resident |
| License | MIT |

## Compatibility

Any headset exposing the B&W RPC characteristic is picked up automatically; nothing below is verified by Earshot yet.

| Model | Status |
|---|---|
| Px7 S3 | Target — maintainer's device, verified at M0 |
| Px8 S2, Px8, Px7 S2, Px7 S2e, Pi8, Pi6, Pi7 S2, Pi5 S2 | Untested — same protocol family per other projects |
| PX, PX5, PX7 (gen 1), PI3, PI4 | Unknown protocol |

## Docs

| File | Contents |
|---|---|
| [docs/decisions.md](docs/decisions.md) | Decision log, architecture, scope, milestones, M0 checklist |
| [docs/protocol-bw-rpc.md](docs/protocol-bw-rpc.md) | Transport, framing, command table, safety rules |
| [docs/competitive-analysis.md](docs/competitive-analysis.md) | Official app, HeadBridge, others, gap |

A throwaway UI prototype lives on branch `prototype/menu` (`./prototype/menu/run.sh`).

Not affiliated with or endorsed by Bowers & Wilkins.
