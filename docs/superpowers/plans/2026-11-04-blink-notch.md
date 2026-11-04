# Blink Notch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A menu-bar-only Mac app that, every 20 minutes by default, stretches the notch down into a fake "new mail" banner whose cartoon-eye avatar slams its eyelid a few times, as a funny blink reminder.

**Architecture:** All logic that can be pure (messages, settings, countdown state machine, display choice, pill geometry, the animation timeline as a function of time, the coordinator) lives in a testable library, `BlinkNotchCore`. A thin AppKit/SwiftUI executable, `BlinkNotch`, owns the click-through floating panel, the SwiftUI pill drawn from the timeline, the menu bar item, the system sleep/lock observers and launch-at-login.

**Tech Stack:** Swift 6.2 toolchain (language mode 5), SwiftUI, AppKit, ServiceManagement, Swift Testing. No third-party packages.

**Spec:** `docs/superpowers/specs/2026-11-04-blink-notch-design.md`. The chosen look is option 2 in `docs/superpowers/specs/assets/notch-mockups-round2.html`; open it in a browser to see the target animation.

## Global Constraints

- Only the Command Line Tools are installed: no Xcode.app, no `xcodebuild`. Build is a Swift Package plus `scripts/build-app.sh`, which assembles `build/Blink Notch.app` (Info.plist with `LSUIElement` true, then an ad-hoc `codesign --force --sign -`).
- XCTest is not available. Tests use Swift Testing, run through `scripts/test.sh` (Task 1), which passes the framework path flags. Always run tests through it, never bare `swift test`.
- Machine: macOS 26.5.2, Apple M3 Pro. Deployment target macOS 14 (my call). Real notch measured via `NSScreen`: 220 x 38 pt on a 2056 x 1329 pt screen. Read it from `NSScreen` at run time (`safeAreaInsets.top`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`); never hard-code it.
- Never steal keyboard focus; clicks pass through the pill; shown over full-screen apps and on every Space; silent; 60 fps; idle cost near zero (single-shot timer, no polling).
- Copy: kicker `MAIL · NOW`, headline `Blink, you goof.`, from-line `from: your eyeballs` (first message in the pool). The kicker renders in small grey caps, as in the mockup.
- Colours: eyelid `#ff5a5f` with `#b3262b` bottom rim, secondary text `#8e8e93`, pill black.
- Intervals 10 / 20 / 30 / 60 minutes, default 20, remembered. Menu items, in order: `Show one now`, `Pause` / `Resume`, `Every` (submenu), `Launch at login`, separator, `Quit`.
- Whole event is 6.0 s. Pill body about 270 x 70 pt (`notch width + 50`, minimum 260), whole shape about 108 pt tall on this notch. Keep a notch-width neck in the 38 pt menu-bar band; the body widens below it.
- No sleep or lock firing; on wake or unlock the countdown restarts from a full interval.
- Display is chosen fresh at each fire: the display holding the cursor. Notch display uses the notch animation; a display without a notch gets the same body dropping below its menu bar.

## Review Focus

Failure modes the spec implies but never states. Each has a test in the task named in brackets.

1. The Mac slept through a scheduled fire; the timer fires late on wake. It must not show immediately. [Task 4]
2. Screen locks, then sleeps, then the screen wakes while still locked. No reminder until unlock plus a full interval. [Task 4]
3. Timer fires or "Show one now" is clicked while a pill is already playing. Never stack two. [Task 7]
4. The cursor sits exactly on a screen's top edge (the normal place to be when reaching for the menu bar) or outside every display. A display must still be chosen. [Task 5]
5. A display is unplugged or rearranged while the pill is playing. Dismiss at once, never leave a stuck black shape. [Task 8]

---

### Task 1: Package, harness, build script, empty menu bar app

**Files:**
- Create: `Package.swift`, `.gitignore` (`.build/`, `build/`, `.superpowers/`), `scripts/test.sh`, `scripts/build-app.sh`, `Resources/Info.plist`
- Create: `Sources/BlinkNotchCore/AppInfo.swift`, `Tests/BlinkNotchCoreTests/AppInfoTests.swift`
- Create: `Sources/BlinkNotch/main.swift`, `Sources/BlinkNotch/AppDelegate.swift`

**Interfaces:**
- Produces: targets `BlinkNotchCore` (library), `BlinkNotch` (executable, depends on Core), `BlinkNotchCoreTests`; `AppInfo.name == "Blink Notch"`, `AppInfo.bundleID == "dev.kshitiz.blinknotch"`; `scripts/test.sh [swift test args]`; `scripts/build-app.sh` prints the `.app` path.

- [ ] **Step 1: Write the failing test** in `AppInfoTests.swift`: `@Test func nameAndBundleID() { #expect(AppInfo.name == "Blink Notch"); #expect(AppInfo.bundleID == "dev.kshitiz.blinknotch") }`
- [ ] **Step 2: Create `scripts/test.sh`** (executable) with exactly: `F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks; exec swift test -Xswiftc -F$F -Xlinker -F$F -Xlinker -rpath -Xlinker $F "$@"`. Create `Package.swift` (tools 6.0, `swiftLanguageModes: [.v5]`, `platforms: [.macOS(.v14)]`, the three targets) and a placeholder `Sources/BlinkNotch/main.swift` containing `import AppKit` so the manifest loads. Run `scripts/test.sh`; expected: fails to build, `AppInfo` not found.
- [ ] **Step 3: Implement `AppInfo`** in Core. Run `scripts/test.sh`; expected: 1 test passed.
- [ ] **Step 4: Minimal app.** `main.swift` creates `NSApplication.shared`, sets `.accessory` policy, installs `AppDelegate`, runs. `AppDelegate` is `@MainActor` and owns an `NSStatusItem` whose button shows the SF Symbol `eye` and whose menu has only `Quit`.
- [ ] **Step 5: `Resources/Info.plist`** with `CFBundleName` Blink Notch, `CFBundleIdentifier` from `AppInfo`, `CFBundleExecutable` BlinkNotch, `CFBundlePackageType` APPL, `CFBundleShortVersionString` 0.1.0, `LSMinimumSystemVersion` 14.0, `LSUIElement` true. `scripts/build-app.sh`: `swift build -c release --product BlinkNotch`, assemble `build/Blink Notch.app/Contents/{MacOS,Resources}`, copy binary and plist, ad-hoc codesign, print the path.
- [ ] **Step 6: Verify.** Run `scripts/build-app.sh`, then `plutil -extract LSUIElement raw "build/Blink Notch.app/Contents/Info.plist"` (expect `true`), `codesign --verify "build/Blink Notch.app"` (expect exit 0), `open "build/Blink Notch.app"`, `pgrep -x BlinkNotch` (expect a pid). Look at the top-right of the screen: an eye icon in the menu bar and no Dock icon. Choose Quit; `pgrep -x BlinkNotch` prints nothing.
- [ ] **Step 7: `git init`, commit** everything including `docs/`. Local only; nothing is pushed.

### Task 2: Message pool

**Files:**
- Create: `Sources/BlinkNotchCore/MessagePool.swift`, `Tests/BlinkNotchCoreTests/MessagePoolTests.swift`

**Interfaces:**
- Produces: `struct Message: Equatable, Sendable { let headline: String; let from: String }`; `struct MessagePool { static let kicker = "MAIL · NOW"; static let all: [Message]; init(messages: [Message] = MessagePool.all); mutating func next() -> Message; mutating func next<G: RandomNumberGenerator>(using: inout G) -> Message }`

- [ ] **Step 1: Write failing tests:** `allHasAtLeastTenDistinctMessages` (count >= 10, `Set(all.map(\.headline)).count == all.count`); `firstMessageIsTheMockupCopy` (`all[0] == Message(headline: "Blink, you goof.", from: "your eyeballs")`); `neverRepeatsConsecutively` (5,000 draws, no two adjacent equal); `singleMessagePoolDoesNotHang` (pool of one returns that message three times).
- [ ] **Step 2: Run** `scripts/test.sh --filter MessagePoolTests`; expected: FAIL, not defined.
- [ ] **Step 3: Implement.** Keep the last returned message and redraw from the others. Use the spec's starter lines plus at least five more of your own in the same voice; `all[0]` is fixed.
- [ ] **Step 4: Run again;** expected: PASS. **Step 5: Commit.**

### Task 3: Settings and intervals

**Files:**
- Create: `Sources/BlinkNotchCore/Settings.swift`, `Tests/BlinkNotchCoreTests/SettingsTests.swift`

**Interfaces:**
- Produces: `enum ReminderInterval: Int, CaseIterable, Sendable { case ten = 10, twenty = 20, thirty = 30, sixty = 60; static let defaultValue: ReminderInterval; var seconds: TimeInterval; var menuTitle: String }` (`"10 minutes"` … `"60 minutes"`); `final class Settings { init(defaults: UserDefaults = .standard); var interval: ReminderInterval { get set } }`, stored under key `reminderIntervalMinutes`.

- [ ] **Step 1: Write failing tests,** each using `UserDefaults(suiteName: UUID().uuidString)`: `defaultIsTwentyMinutes`; `setIntervalSurvivesNewInstance` (set `.thirty`, new `Settings` on the same suite reads `.thirty`); `unknownStoredValueFallsBackToDefault` (store `7`, expect `.twenty`); `secondsAndTitles` (`.sixty.seconds == 3600`, `.ten.menuTitle == "10 minutes"`).
- [ ] **Step 2:** `scripts/test.sh --filter SettingsTests`; expected FAIL. **Step 3: Implement.** **Step 4:** run; expected PASS. **Step 5: Commit.**

### Task 4: Reminder schedule state machine

**Files:**
- Create: `Sources/BlinkNotchCore/ReminderSchedule.swift`, `Tests/BlinkNotchCoreTests/ReminderScheduleTests.swift`

**Interfaces:**
- Produces: `struct SuspendReason: OptionSet, Sendable { static let screenAsleep, locked }`; `struct ReminderSchedule: Sendable { init(interval: TimeInterval, now: Date); private(set) var nextFire: Date?; private(set) var isPaused: Bool; var isSuspended: Bool { get }; mutating func pause(); mutating func resume(now: Date); mutating func setInterval(_: TimeInterval, now: Date); mutating func suspend(_: SuspendReason); mutating func unsuspend(_: SuspendReason, now: Date); mutating func timerDidFire(now: Date) -> Bool }`
- Rules: `nextFire` is nil while paused or suspended. Any change of interval, resume, or last-reason unsuspend restarts the countdown to `now + interval`. `timerDidFire` returns true only if running and `now >= nextFire - 1`; when due it advances `nextFire` to `now + interval`. If `now > nextFire + 60` the fire is stale: return false and reschedule to `now + interval`.

- [ ] **Step 1: Write failing tests,** with `t0 = Date(timeIntervalSince1970: 1_000)` and interval 1,200: `firesAtNextFireAndReschedules` (true at `t0+1200`, `nextFire == t0+2400`); `timerSlopWithinOneSecondStillFires` (true at `t0+1199.5`); `earlyFireIsIgnored` (false at `t0+1190`, `nextFire` unchanged); `pausedNeverFires` (`pause()`, `nextFire == nil`, false later); `resumeRestartsCountdown`; `setIntervalRestartsCountdown`; **Review Focus 1** `staleFireAfterSleepIsSkipped` (false at `t0+5000`, `nextFire == t0+5000+1200`); **Review Focus 2** `lockThenSleepThenWakeStillLockedStaysSilent` (suspend `.locked`, suspend `.screenAsleep`, `unsuspend(.screenAsleep)`: `isSuspended` still true, `nextFire == nil`; then `unsuspend(.locked, now: t1)`: `nextFire == t1+1200`); `unsuspendWhilePausedStaysPaused`.
- [ ] **Step 2:** `scripts/test.sh --filter ReminderScheduleTests`; expected FAIL. **Step 3: Implement. Step 4:** run; expected PASS. **Step 5: Commit.**

### Task 5: Display choice and pill geometry

**Files:**
- Create: `Sources/BlinkNotchCore/Display.swift`, `Sources/BlinkNotchCore/PillGeometry.swift`, `Tests/BlinkNotchCoreTests/DisplayTests.swift`, `Tests/BlinkNotchCoreTests/PillGeometryTests.swift`

**Interfaces:**
- Produces: `struct NotchSize: Equatable, Sendable { var width, height: CGFloat }`; `struct DisplayInfo: Equatable, Sendable { var id: UInt32; var frame: CGRect; var menuBarHeight: CGFloat; var notch: NotchSize? }` (frame in AppKit global coordinates, origin bottom-left); `func pickDisplay(cursor: CGPoint, from: [DisplayInfo]) -> DisplayInfo?`; `struct PillGeometry: Equatable, Sendable { enum Style { case notch, floating }; init(display: DisplayInfo); var style: Style; var neckSize: CGSize; var bodySize: CGSize; var topInset: CGFloat; var windowSize: CGSize; func windowFrame(on: DisplayInfo) -> CGRect }`
- Rules: `pickDisplay` uses inclusive edges (a point on `maxX` or `maxY` is inside); if no display contains the point, return the nearest by distance to its rect; empty list returns nil; the first match wins on a shared edge. Notch display: neck = notch size, body = `(max(260, notch.width + 50), 70)`, `topInset` 0. No notch: style `.floating`, neck `.zero`, body `(270, 70)`, `topInset` 8. `windowSize` must contain the shape at `PillAnimation.maxProgress` (1.12, defined in Task 6; use the literal 1.12 here and have Task 6 reference it). `windowFrame` is centred on `display.frame.midX`; its top is `frame.maxY` for a notch display and `frame.maxY - menuBarHeight` for floating.

- [ ] **Step 1: Write failing tests.** Display: `containsPicksThatDisplay`; **Review Focus 4** `cursorOnTopEdgePicksThatDisplay` (cursor `y == frame.maxY`); `cursorOutsideAllPicksNearest`; `emptyListIsNil`. Geometry: `notchDisplayMeasuresFromNotch` (220 x 38 notch gives neck 220x38, body 270x70, total height 108); `narrowNotchStillGetsMinimumBody` (notch 100 wide gives body width 260); `noNotchIsFloating` (neck `.zero`, body 270x70, `topInset == 8`); `windowFitsOvershoot` (width >= `1.12 * bodyWidth`, height >= `1.12 * (neck.height + body.height + topInset)`); `windowFrameIsCentredAndTopAligned` for both styles (notch: `maxY == frame.maxY`; floating with menuBarHeight 24: `maxY == frame.maxY - 24`; `midX == frame.midX`).
- [ ] **Step 2:** `scripts/test.sh --filter DisplayTests`, then `--filter PillGeometryTests`; expected FAIL. **Step 3: Implement. Step 4:** run both; expected PASS. **Step 5: Commit.**

### Task 6: Animation timeline

**Files:**
- Create: `Sources/BlinkNotchCore/PillAnimation.swift`, `Tests/BlinkNotchCoreTests/PillAnimationTests.swift`

**Interfaces:**
- Produces: `struct PillFrameState: Equatable, Sendable { var progress: Double; var contentOpacity: Double; var lidClosure: Double; var pupil: CGVector; var avatarScale: CGSize; var isFinished: Bool }`; `enum PillAnimation { static let duration: TimeInterval = 6.0; static let maxProgress = 1.12; static func state(at t: TimeInterval) -> PillFrameState }`. `progress` 0 = collapsed into the notch (or hidden above, for floating), 1 = settled. `lidClosure` 0 open, 1 shut. `pupil` components in -1...1. `avatarScale` is squash and stretch around (1, 1).
- Target timeline (seconds; derived from the mockup; tune by eye but keep the invariants below): `progress` 0 at 0.0, peaks 1.12 at 0.55, dips 0.96 at 0.80, 1.0 at 1.0, holds to 5.0, eases to 0 at 5.9. `contentOpacity` 0 until 0.6, 1 by 1.05, holds to 4.9, 0 by 5.25. Lid slams close over 0.08 s and hold, reopening: slam 1 closed 1.33 to 1.45, open by 1.60; slam 2 the same +1.0 s; slam 3 closed 3.33 to 3.85 (held), open by 4.05. `avatarScale` about (1.08, 0.88) at each close, about (0.97, 1.04) 0.12 s later, else (1, 1). `pupil` wanders: (0,0) at 0.9, (-1, 0.3) at 1.3, (1, -0.3) at 2.2, (-0.4, 0.8) at 3.0, (0,0) at 4.0.

- [ ] **Step 1: Write failing tests:** `startsCollapsedAndInvisible` (`state(at: 0)`: progress 0, contentOpacity 0, lidClosure 0, not finished); `overshootsThenSettles` (`state(at: 0.55).progress` in `(1.0, 1.12]`; `state(at: 1.0).progress` within 0.001 of 1); `lidShutAtEachSlam` (`lidClosure == 1` at 1.39, 2.39, 3.6; `== 0` at 1.0 and 2.9); `finishesAtDuration` (`state(at: 6.0)`: isFinished, progress 0, contentOpacity 0); `clampsOutOfRangeAndNaN` (`state(at: -3) == state(at: 0)`, `state(at: 600) == state(at: 6.0)`, `state(at: .nan) == state(at: 0)`); `neverExceedsMaxProgress` and `lidOnlyMovesWhileContentIsVisible` (sampling every 0.01 s: if `lidClosure > 0` then `contentOpacity > 0.9`); `noPopping` (adjacent 10 ms samples differ by less than 0.2 in progress, and less than 0.6 in lidClosure).
- [ ] **Step 2:** `scripts/test.sh --filter PillAnimationTests`; expected FAIL. **Step 3: Implement** with a small private keyframe track helper (time, value, easing between keys). The signature and tests fix everything else. **Step 4:** run; expected PASS. **Step 5: Commit.**

### Task 7: Reminder coordinator

**Files:**
- Create: `Sources/BlinkNotchCore/ReminderCoordinator.swift`, `Tests/BlinkNotchCoreTests/ReminderCoordinatorTests.swift`

**Interfaces:**
- Consumes: `Settings`, `ReminderSchedule`, `MessagePool`, `DisplayInfo`, `pickDisplay`.
- Produces: `protocol PillPresenting: AnyObject { var isPresenting: Bool { get }; func present(message: Message, on: DisplayInfo) }`; `protocol ScreenProviding { var displays: [DisplayInfo] { get }; var cursor: CGPoint { get } }`; `final class ReminderCoordinator { init(presenter: PillPresenting, screens: ScreenProviding, settings: Settings, pool: MessagePool = MessagePool(), intervalOverride: TimeInterval? = nil, now: @escaping () -> Date = Date.init); private(set) var schedule: ReminderSchedule; var isPaused: Bool { get }; var interval: ReminderInterval { get }; var onScheduleChange: (() -> Void)?; @discardableResult func showNow() -> Bool; func timerFired(); func setPaused(_: Bool); func setInterval(_: ReminderInterval); func suspend(_: SuspendReason); func unsuspend(_: SuspendReason) }`. Every method that changes the schedule calls `onScheduleChange`. `intervalOverride` (debug env var in Task 10) replaces the interval's seconds.

- [ ] **Step 1: Write failing tests** with a fake presenter and fake screens: `showNowPresentsOnCursorDisplay` (two displays, cursor on the second: `present` gets that display and a message from the pool); **Review Focus 3** `secondTriggerWhilePresentingIsIgnored` (fake `isPresenting` true after the first call: `showNow()` returns false, `present` called once; also `timerFired()` when due does not stack); `noDisplaysDoesNothing` (returns false, no crash); `timerFiredWhenPausedDoesNotPresent`; `timerFiredWhenDuePresentsAndRearms`; `setIntervalPersistsAndRestarts` (settings reads the new value, `onScheduleChange` called); `unsuspendRestartsCountdown`.
- [ ] **Step 2:** `scripts/test.sh --filter ReminderCoordinatorTests`; expected FAIL. **Step 3: Implement. Step 4:** run the whole suite with `scripts/test.sh`; expected all PASS. **Step 5: Commit.**

### Task 8: Click-through pill window on the right screen

**Files:**
- Create: `Sources/BlinkNotch/SystemScreens.swift`, `Sources/BlinkNotch/PillWindowController.swift`, `Sources/BlinkNotch/PillContent.swift` (placeholder: a black `PillShape`-sized rectangle sized from `PillAnimation.state`, replaced in Task 9)
- Modify: `Sources/BlinkNotch/AppDelegate.swift` (parse the `--preview` launch argument: show one pill on the cursor display about 1 s after launch)

**Interfaces:**
- Consumes: `ScreenProviding`, `PillPresenting`, `PillGeometry`, `PillAnimation`.
- Produces: `struct SystemScreens: ScreenProviding` (maps `NSScreen.screens` to `DisplayInfo`; `id` from `deviceDescription["NSScreenNumber"]`; `menuBarHeight = frame.maxY - visibleFrame.maxY`; notch width `frame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width` and height `safeAreaInsets.top` when `safeAreaInsets.top > 0`, else nil; `cursor` is `NSEvent.mouseLocation`); `@MainActor final class PillWindowController: PillPresenting` with `var debugFreezeAt: TimeInterval?` (used in Task 9).
- Panel rules: `NSPanel` subclass, borderless and `.nonactivatingPanel`, `canBecomeKey` and `canBecomeMain` false, `ignoresMouseEvents` true, transparent, no shadow, `level = .screenSaver`, collection behaviour `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `constrainFrameRect` overridden to return the frame unchanged (so it can sit over the menu bar), shown with `orderFrontRegardless()`. It dismisses itself when `PillAnimation.duration` has elapsed, and sets `isPresenting` true only between present and dismiss. **Review Focus 5:** observe `NSApplication.didChangeScreenParametersNotification` and dismiss immediately if a pill is up.

- [ ] **Step 1: Implement** the three files and the `--preview` flag.
- [ ] **Step 2: Build and run** `scripts/build-app.sh && "build/Blink Notch.app/Contents/MacOS/BlinkNotch" --preview`. Expected: about 1 s later a black shape grows out of the notch on the laptop screen (or drops below the menu bar on the external monitor) and is gone after about 6 s.
- [ ] **Step 3: Check focus.** With TextEdit frontmost, run `osascript -e 'tell application "System Events" to name of first process whose frontmost is true'` before and during the pill; both print `TextEdit`. Type into TextEdit while it plays; nothing is lost.
- [ ] **Step 4: Check click-through and placement.** Click something under the pill while it plays; the click lands on the thing underneath. Put the cursor on the external monitor and relaunch with `--preview`; the pill appears there, drops from below its menu bar. Do the same with the cursor at the very top of the laptop screen. Put a full-screen app (Safari) in front and relaunch; the pill still appears over it.
- [ ] **Step 5: Check display changes.** While a pill is playing, unplug or disable the external monitor or change Displays settings; the pill vanishes at once and the next `--preview` works. **Step 6: Commit.**

### Task 9: The real pill visuals

**Files:**
- Create: `Sources/BlinkNotch/PillShape.swift`, `Sources/BlinkNotch/EyeAvatarView.swift`, `Sources/BlinkNotch/PillView.swift`
- Modify: `Sources/BlinkNotch/PillWindowController.swift` (host `PillView`, honour `debugFreezeAt`), `Sources/BlinkNotch/AppDelegate.swift` (parse `--freeze-at <seconds>`; implies `--preview`). Delete `PillContent.swift`.

**Interfaces:**
- Consumes: `PillGeometry`, `PillFrameState`, `PillAnimation.state(at:)`, `Message`, `MessagePool.kicker`.
- Produces: `struct PillShape: Shape` (neck rectangle of the notch size flush with the window top, plus a body whose width is `lerp(neck.width, body.width, progress)` and height `body.height * progress`, bottom corner radius 26, drawn directly below the neck; for `.floating`, only the body, offset up by `(body.height + topInset) * (1 - progress)`, all corners rounded); `struct EyeAvatarView: View` (40 pt white circle, 16 pt black pupil offset by `pupil` within the circle, lid in `#ff5a5f` with a 3 pt `#b3262b` bottom rim covering `lidClosure` of the circle from the top, whole avatar scaled by `avatarScale` about its bottom); `struct PillView: View { init(geometry: PillGeometry, message: Message, startDate: Date, freezeAt: TimeInterval? = nil) }` driven by `TimelineView(.animation)`.
- Layout inside the body (below the neck): avatar 16 pt from the left, centred vertically; text block 70 pt from the left, left aligned, three lines: kicker 10 pt, tracked, `#8e8e93`; headline 15 pt bold white; `from: <from>` 11 pt `#8e8e93`. Everything in the content layer uses `contentOpacity`.

- [ ] **Step 1: Implement** the files and wiring.
- [ ] **Step 2: Verify key frames.** Build, then run `"build/Blink Notch.app/Contents/MacOS/BlinkNotch" --freeze-at 0.55` and capture the top-centre of the laptop screen: `screencapture -x -R 700,0,660,160 /tmp/blink-0.55.png` (adjust the region to the notch), then look at the image. Repeat for `1.39` and `3.0`. Expected: at 0.55 the body is slightly larger than at rest and the content is still faint; at 1.39 the eye is covered by the coral lid; at 3.0 the eye is open, the text reads `MAIL · NOW`, `Blink, you goof.`, `from: your eyeballs`, and the neck is exactly notch-width in the menu-bar band. Compare against the mockup in a browser; match feel, not pixels. If `screencapture` is refused for lack of permission, ask Kshitiz to look at the frozen frames.
- [ ] **Step 3: Verify motion.** Run `--preview` unfrozen on both the laptop screen and the external monitor and watch the whole 6 s once: smooth, squash and stretch on each slam, shape shrinks back to the notch with nothing left behind. **Step 4: Commit.**

### Task 10: Menu bar, timer, sleep and lock events

**Files:**
- Create: `Sources/BlinkNotch/ReminderTimer.swift`, `Sources/BlinkNotch/SystemEvents.swift`, `Sources/BlinkNotch/MenuBarController.swift`
- Modify: `Sources/BlinkNotch/AppDelegate.swift` (build `Settings`, `PillWindowController`, `ReminderCoordinator`, and the three new objects; read the env var `BLINKNOTCH_DEBUG_INTERVAL_SECONDS` into `intervalOverride`)

**Interfaces:**
- Consumes: `ReminderCoordinator` (all of it).
- Produces: `final class ReminderTimer { init(coordinator: ReminderCoordinator); func rearm() }` (a single-shot `Timer` set to `coordinator.schedule.nextFire`, tolerance 5 s, none when nil; its fire calls `coordinator.timerFired()`; hooked to `onScheduleChange`); `final class SystemEvents { init(coordinator: ReminderCoordinator) }` (`NSWorkspace` `screensDidSleep`/`willSleep` call `suspend(.screenAsleep)`, `screensDidWake`/`didWake` call `unsuspend(.screenAsleep)`; `DistributedNotificationCenter` `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` map to `.locked`); `final class MenuBarController` building the menu from the Global Constraints list (without `Launch at login` yet), with a check mark beside the current interval, and the pause item toggling its title between `Pause` and `Resume`.

- [ ] **Step 1: Implement** the three classes and wire them in `AppDelegate`.
- [ ] **Step 2: Verify menu.** Run the app from `build/`. `Show one now` plays the pill. `Pause` then wait: nothing fires, title now reads `Resume`. `Every` shows four intervals with 20 minutes ticked; choose 30, quit and relaunch: 30 is still ticked.
- [ ] **Step 3: Verify the timer fires on its own.** Launch with `BLINKNOTCH_DEBUG_INTERVAL_SECONDS=15`; a pill appears about 15 s after launch and again about 15 s after it ends. Pause stops it; Resume restarts the 15 s countdown.
- [ ] **Step 4: Verify lock and sleep.** With the 15 s override, lock the screen (Control-Command-Q) for 40 s: no pill while locked, and none for 15 s after unlock plus a moment. Put the display to sleep (`pmset displaysleepnow`) for 40 s: same. **Step 5: Commit.**

### Task 11: Launch at login and install

**Files:**
- Create: `Sources/BlinkNotch/LaunchAtLogin.swift`
- Modify: `Sources/BlinkNotch/MenuBarController.swift` (add the `Launch at login` item, checked when enabled), `scripts/build-app.sh` (add `--install`: quit a running `BlinkNotch`, copy the bundle to `~/Applications/Blink Notch.app`, replacing any previous copy)

**Interfaces:**
- Produces: `enum LaunchAtLogin { static var isEnabled: Bool { get }; static func setEnabled(_: Bool) throws }` using `SMAppService.mainApp`. If registration throws, leave the menu item unchecked and log the error with `NSLog`; do not crash or show a modal.

- [ ] **Step 1: Implement** and wire the menu item. **Step 2:** `scripts/build-app.sh --install`, open `~/Applications/Blink Notch.app`, tick `Launch at login`; System Settings, General, Login Items lists Blink Notch. Quit, relaunch, the item is still ticked. Untick it; the Login Items entry disappears. **Step 3: Commit.**

### Task 12: Acceptance pass and README

**Files:**
- Create: `README.md` (what it is, `scripts/test.sh`, `scripts/build-app.sh [--install]`, menu items, the `--preview`, `--freeze-at` and `BLINKNOTCH_DEBUG_INTERVAL_SECONDS` debug switches, known gaps)

- [ ] **Step 1: Run the full suite** with `scripts/test.sh`; expected all PASS.
- [ ] **Step 2: From a clean clone** (`git clone` the local repo into a scratch directory, run `scripts/build-app.sh`) the app builds with that one command (spec Done-when 1).
- [ ] **Step 3: Walk the spec's Done-when list** (menu bar icon and no Dock icon; Show one now plays and leaves nothing behind; typing and clicking unaffected; timer, pause and interval, login choice survive relaunch; looks right on the notch and on the external monitor, appearing on the cursor's screen) and also check idle cost: with the app running and no pill showing, `top -l 2 -pid $(pgrep -x BlinkNotch) | tail -1` reports about 0% CPU. Note any miss in the README under Known gaps.
- [ ] **Step 4: Install** with `scripts/build-app.sh --install` so the real thing is running, then commit.
