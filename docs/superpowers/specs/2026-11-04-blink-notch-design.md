# Blink Notch: design

## Intent

Kshitiz stares at a screen all day and forgets to blink. He wants a Mac app that
reminds him, and the reminder itself should be funny enough that he's glad to
see it instead of annoyed. The joke is the delivery: the MacBook notch stretches
down into a fake "new mail" notification, a cartoon eye is the sender's avatar,
and the eye's eyelid slams shut a few times ("blink, you goof"). The email is
fake. There's no real mail integration anywhere.

The first idea was an envelope character that blinks. Kshitiz liked the big
slamming-eye idea but disliked the envelope itself, so the envelope is out.

## What he decided

- **Look:** the "notch grows into a notification" mockup, option 2 of round 2.
  Source: `assets/notch-mockups-round2.html` (open it in a browser; the animation
  loops). Round 1 (`assets/notch-mockups-round1-envelopes.html`) is kept only as
  history. Do not build anything from it.
- **Sequence (revised 2026-11-04 at his request):** the first version stretched the
  notch itself into the pill and shrank it back through an ugly pointed-rectangle
  shape that vanished abruptly. Replaced by one rounded shape that never touches
  the notch (about 6.6 s in total; timings are targets, tune by eye):
  1. A 44 pt black circle drops out from behind the notch to a resting spot with a
     gap (10 pt) below the notch, with a small overshoot-and-settle.
  2. It then grows into a 270 x 70 pt pill (a capsule), with a small overshoot.
  3. Content fades in. Left: a ~40 pt round white eyeball with a black pupil that
     looks around. Right, three text lines: small grey caps `MAIL · NOW`, bold white
     headline (default `Blink, you goof.`), small grey `from: your eyeballs`.
  4. The eyelid is a coral-red (#ff5a5f, darker rim #b3262b) slab that slams down
     over the eye and pops back up, three times; the third is held shut a beat
     longer. The avatar squashes and stretches on every slam.
  5. Content fades out, the pill shrinks back into a circle, and the circle is held
     in view for about 0.3 s before it rises back behind the notch.
  The shape never moves and changes size at the same time.
- The whole event is non-interactive (clicks pass through it).

### Geometry on the real notch (measured on this Mac; my call)

The real notch, read from `NSScreen`, is **220 pt wide and 38 pt tall** (screen
2056 x 1329 pt). The shape never overlaps the menu-bar band beside the notch:
it rests below the notch, with a 10 pt gap, and the circle is hidden behind the
notch until it drops out. On a screen without a notch the same sequence runs
from just below the menu bar, with an 8 pt gap. Read the notch size from
`NSScreen` at run time; don't hard-code 220 x 38.

### Animation styles (added 2026-11-04 at his request)

After the first design he asked for ten more blink mockups and then for all of them
to be added, so each reminder shows a different animation. There are 11 styles in
total (the original plus the ten), never the same style twice in a row. Mockups:
`assets/notch-mockups-round3-blink-ideas.html`. Styles 2 to 9 reuse the circle-then-pill
motion with a different avatar or trick; style 1 is a white pill with a giant iris;
style 10 has no pill (a bouncing eyeball with a caption under it). Some styles
carry their own fixed text (cat, countdown, wiper, shutter, sleepy, buffering);
the others use the random message pool. A separate water reminder was discussed
but is not part of this.

## What he agreed to (stated as guesses, he said "cool")

- Native Mac app, lives in the menu bar (small icon), no Dock icon.
- Fires every 20 minutes.
- On screen about 6 seconds.
- Never steals keyboard focus and can't be clicked: it must not interrupt typing.
- The text varies between a handful of goofy lines and senders so it stays funny.
- Screens without a notch (his external monitor): the pill drops from
  top-centre of the screen instead. He said he uses both the laptop and an
  external monitor.

## Goals

- It's fun to watch. The animation is smooth (60 fps) and feels hand-made, with
  squash, stretch and overshoot, not a linear fade.
- It really works as a reminder: you notice it without having to stop what you're
  doing.
- Zero friction: start it once, forget it. Idle cost is effectively nothing.

## Non-goals

- Real email, Mail.app, or any network access.
- Tracking blinks with the camera, or any health claims.
- A settings window. Menu bar items are the whole UI.
- App Store distribution, notarization, or sharing with other people. It's a
  personal app for one Mac.
- Sound. (My call: silent. Easy to add later.)

## Anti-goals (failure even if it technically works)

- It steals focus, eats keystrokes, or blocks a click on whatever is under it.
- It becomes annoying: too frequent, too long, or the same joke every time.
- It misbehaves visually: wrong place on the screen, flicker, covers the menu bar
  items on the sides of the notch, ends up stuck on screen.
- Idle CPU or battery use that's noticeable.

## Menu bar (my call; he only asked for pause and quit)

- Status item with a small eye or blink glyph.
- **Show one now** (so he can preview it and so it can be tested).
- **Pause / Resume.**
- **Every:** 10 / 20 / 30 / 60 minutes (default 20), remembered between launches.
- **Launch at login** toggle.
- **Quit.**

## Behaviour details (my calls)

- Display choice: show it on the display the user is looking at, taken as the
  display that holds the mouse cursor. On the built-in display (the one with the
  notch) use the notch animation. On any display without a notch, the same pill
  drops from top-centre of that display with a plain rounded top edge.
  He uses the laptop and an external monitor, so the no-notch drop-down is an
  everyday path, not a fallback. Build and test both equally. The display is
  chosen fresh each time the reminder fires, since he moves between the two.
- Appears above other windows including full-screen apps and on every Space, so
  it still reaches him while he's watching a video or coding full-screen.
- Doesn't fire while the display is asleep or the screen is locked. When the Mac
  wakes, restart the countdown instead of firing immediately.
- Message pool: at least ten goofy variants. Keep the `MAIL · now` frame; vary
  the headline and the `from:` line. Don't repeat the same one twice in a row.
  Starter ideas: "Blink, you goof." / from your eyeballs; "Your cornea is
  filing a complaint." / from Dry Eye Dept.; "Re: Re: Re: BLINK." / from your
  optic nerve; "URGENT: eyelids available." / from Management; "You have 1 unread
  blink." / from your face.

## How it gets made (my calls, he handed this to me)

- Swift 6.2 and SwiftUI for the pill's content and animation, AppKit for the
  borderless floating window and the menu bar item. No third-party dependencies.
- This Mac has the Command Line Tools only: no Xcode.app and no `xcodebuild`.
  So the project is a Swift Package plus a small script that assembles the
  `.app` bundle (Info.plist with `LSUIElement` set so there's no Dock icon,
  then an ad-hoc code signature). The goal is a single command that builds and
  produces `Blink Notch.app`.
- Machine: macOS 26.5.2, Apple M3 Pro, MacBook with a notch.
- Notch size and position come from `NSScreen` (safe area insets and the
  auxiliary top areas); don't hard-code pixel sizes for the notch.

## Left to the builder

- Exact timings, easing and sizes. Match the mockup in feel; tune by eye.
- Code structure, naming, how the window is layered and ordered.
- Menu bar glyph design and the app's icon.
- The final wording of the message pool.
- How to test the animation (e.g. a way to preview with "Show one now").

## Done when

1. One command builds `Blink Notch.app` from a clean checkout.
2. Launching it shows a menu bar icon and no Dock icon.
3. "Show one now" plays the full sequence and ends back at the notch with
   nothing left on screen.
4. While it plays, typing into another app is not interrupted and a click on
   the thing under the pill still works.
5. The timer fires on its own at the chosen interval, pause stops it, and the
   interval and login choices survive a relaunch.
6. It looks right on this MacBook's notch and also on a screen without a notch
   (his external monitor), and it appears on the screen the cursor is on.
