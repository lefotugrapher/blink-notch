# Blink Notch

A menu-bar-only Mac app that reminds you to blink. Every so often a circle drops out from behind the notch and grows into a fake
"new mail" banner. A cartoon eye is the sender's avatar and its eyelid slams shut a few times:
**MAIL · NOW / Blink, you goof. / from: your eyeballs**. The email is fake; there is no mail access and no network.

Design: `docs/superpowers/specs/2026-11-04-blink-notch-design.md` (mockups next to it). Plan: `docs/superpowers/plans/`.

## Build, test, install

Only the Xcode Command Line Tools are needed (no Xcode.app).

```bash
scripts/test.sh                  # runs the Swift Testing suite
scripts/build-app.sh             # builds build/Blink Notch.app (ad-hoc signed)
scripts/build-app.sh --install   # also copies it to ~/Applications
```

`scripts/test.sh` exists because XCTest is not available with only the Command Line Tools; it points the
toolchain at the Swift Testing framework shipped inside them. Test files cannot `import Foundation` for the
same reason (see `Tests/BlinkNotchCoreTests/FoundationSupport.swift`).

## Using it

Menu bar eye icon: **Show one now**, **Pause / Resume**, **Every** (10 / 20 / 30 / 60 minutes, default 20),
**Launch at login**, **Quit**. The reminder appears on the screen your cursor is on: a circle dropping out of the notch on the
MacBook screen, the same thing from just below the menu bar on a screen without a notch. It never takes keyboard
focus, clicks pass through it, and nothing fires while the screen is asleep or locked (the countdown restarts
from a full interval when you wake or unlock).

## Debug switches

Launch `build/Blink Notch.app/Contents/MacOS/BlinkNotch` with:

- `--preview`: show one pill about a second after launch
- `--freeze-at <seconds>`: show one pill held at that moment of the 6.6 s animation (for screenshots)
- `--message <index>`: use only that message from the pool
- `--dump-menu`: print the menu and exit
- `--login-item-selftest`: register and unregister the login item once, printing the status
- env `BLINKNOTCH_DEBUG_INTERVAL_SECONDS=15`: replace the interval (menu choices keep working but use this value)
- env `BLINKNOTCH_DEBUG_NO_NOTCH=1`: pretend there is no notch, to see the floating style on the laptop screen

## Known gaps

Not exercised on real hardware during the build (only the built-in display was connected):

- the external-monitor path (the floating style was checked on the laptop screen with `BLINKNOTCH_DEBUG_NO_NOTCH=1`)
- overlay above a full-screen app, and actually clicking through the pill
- dismissal when a display is unplugged mid-animation
- live screen sleep and lock (the schedule logic for these is unit-tested)
- clicking the menu items (the menu structure is checked with `--dump-menu`; the logic behind them is unit-tested)
