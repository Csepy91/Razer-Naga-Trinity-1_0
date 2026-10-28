# Hardware verification log

Observed results on a real **Razer Naga Trinity** (VID `0x1532`, PID `0x0067`) with **this Swift stack**.
Only list what was actually tested here — do not mark features verified from unit tests alone.
Parity targets from the Rust sibling are noted; re-confirm after the first Swift hardware run.

| Feature | Status | Notes | Date |
|---|---|---|---|
| DPI stages / active DPI | **Working** | Confirmed on Swift/IOKit stack (apply from the app). | 2026-10-27 |
| Device scan (`info`) | Untested / unknown | | |
| RGB preview / static / effects | **Working (with caveats)** | Confirmed on Swift/IOKit stack; caveats observed (detail TBD). | 2026-10-28 |
| Polling rate | **Working** | Confirmed on Swift/IOKit stack (125 / 500 / 1000 Hz). | 2026-10-27 |
| Side-button bindings (EEPROM) | **Working (FPS + seven / MOBA + twelve / MMO)** | All three plates: FPS, MOBA (seven), MMO (twelve) bindings apply and fire after Send to mouse (Swift/IOKit). | 2026-10-28 |
| Wheel tilt Back/Forward | Untested / unknown | | |
| Full profile apply | **Working (core path)** | DPI, polling, side bindings (all plates), RGB confirmed; RGB caveats and lock/unlock restore still open. | 2026-10-28 |
| RGB off on lock / restore on unlock | Untested / unknown | | |
| Macros (F13–F20) | Untested / unknown | Side bindings work on all plates; dedicated macro re-check still pending. | |
| Tray / login item | Untested / unknown | | |

## How to update

When a feature is confirmed or ruled broken on hardware, edit this table and keep notes short (what you did, what you saw). Fix issues one by one; leave unverified rows as-is.
