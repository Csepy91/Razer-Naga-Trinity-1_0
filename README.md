# Naga Trinity Control (Swift)

Native **macOS** controller for the **Razer Naga Trinity** (VID `0x1532`, PID `0x0067`).

A **1:1 Swift + SwiftUI reimplementation** of the original Electron app — protocol bytes, `profiles.json` schema, UI strings, and verified hardware behavior preserved.

> **AI-developed / AI-ported.** This Swift port was developed and ported with substantial assistance from AI coding tools (Cursor / Composer), directed and reviewed by a human. It is not a hand-written line-by-line rewrite claimed as solely human-authored.

> **Unofficial.** Not affiliated with Razer Inc. Razer® and Naga® are trademarks of Razer Inc.

---

## Credits & attribution (required)

### Original project — please star & credit

This repository is a **native Swift port** of:

### **[cepheiden/Razer-Naga-Trinity-MACOS](https://github.com/cepheiden/Razer-Naga-Trinity-MACOS)**

Pinned upstream revision: [`28c00cf`](https://github.com/cepheiden/Razer-Naga-Trinity-MACOS/commit/28c00cf)

**All credit for the reverse-engineered Razer protocol, Electron driver (`nagaDriver.ts`), profile store design, macro model, tray/daemon behavior, bilingual UI copy, and the original macOS control experience goes to [cepheiden](https://github.com/cepheiden).** The original Electron app is human-authored upstream work; this repo is an AI-assisted native reimplementation of that design.

This Swift tree does **not** replace that work — it reimplements it for a native AppKit/SwiftUI binary (no Electron, no Node, no Rust). If you use, fork, or build on this project, **mention and link the original Electron repository** as the source of the protocol and product design.

| Upstream (source of truth) | This repo (Swift port) |
|---|---|
| [cepheiden/Razer-Naga-Trinity-MACOS](https://github.com/cepheiden/Razer-Naga-Trinity-MACOS) | Native SwiftPM app |
| Electron + TypeScript driver | `NagaCore` + thin `NagaUSB` (C/IOKit) |
| React UI | SwiftUI + AppKit |
| Commit `28c00cf` | Behavior / bytes / JSON / i18n parity target |

Upstream is MIT-licensed (Copyright © 2026 cepheiden). This port retains that license and attribution.

---

## Features

- **RGB** (scroll + logo): static, breathing, spectrum, wave, reactive, off  
- **DPI** stages (1–5) and **polling rate** (125 / 500 / 1000 Hz)  
- **Side-button remapping** written to device EEPROM (macro / key → F13–F24 path on Trinity)  
- **Multi-step macros** via `CGEvent` injection  
- **RGB off** on lock / sleep; restore on unlock / wake  
- **Menu-bar tray** daemon + launch-at-login  
- **Bilingual UI** (German / English), strings aligned with upstream  

## Requirements

- macOS 13+  
- Swift 5.9+ from **Command Line Tools** (`swift build` — no Xcode project required)  
- A wired **Razer Naga Trinity**  

## Build

```bash
# 1. Quick UI iteration (no full TCC / login-item path)
cd app && swift build && swift run

# 2. Bundled .app (needed for Accessibility, Input Monitoring, tray, login item)
./scripts/bundle-app.sh
open "build/Naga Trinity Control.app"
```

### Hardware smoke test

```bash
cd app
swift run naga-cli info
swift run naga-cli rgb static '#ff0000'
swift run naga-cli apply
```

### Tests

```bash
./scripts/test-core.sh
# golden protocol bytes + profiles migration + apply settle
# (no XCTest — Command Line Tools only)
```

## Layout

| Path | Role |
|---|---|
| `app/Sources/NagaCore` | Protocol encoders, USB transport, profile store, driver API |
| `app/Sources/NagaUSB` | Thin C bridge for IOKit USB control transfers |
| `app/Sources/NagaCLI` | Hardware smoke-test CLI |
| `app/Sources/NagaTrinityControl` | SwiftUI + AppKit app (tray, macros, i18n) |
| `scripts/` | `bundle-app.sh`, `test-core.sh` |
| `docs/` | Hardware verification notes |
| `.upstream/` | Optional local clone of the Electron repo (gitignored) |

Profiles: `~/Library/Application Support/NagaTrinityControl/profiles.json`  
(schema matches upstream so existing Electron profiles can load).

## Hardware status

Live mouse results are tracked in [`docs/hardware-verification.md`](docs/hardware-verification.md).

## Development notes

- Protocol and defaults track upstream `electron/nagaDriver.ts` / store — **do not invent bytes** without a hardware test.  
- To compare against upstream locally:

  ```bash
  git clone https://github.com/cepheiden/Razer-Naga-Trinity-MACOS.git .upstream
  git -C .upstream checkout 28c00cf
  ```

## License

[MIT](LICENSE) — same terms as the original Electron project.

- Upstream copyright: © 2026 [cepheiden](https://github.com/cepheiden)  
- Port / Swift implementation: © 2026 [Csepy91](https://github.com/Csepy91)  

**Please keep the upstream attribution visible** in forks, distributions, and derivative works.

## Trademark

Razer® and Naga® are trademarks of Razer Inc. This project is unofficial and not affiliated with Razer.
