# Bubble Shooter

A classic arcade bubble shooter for Android and iOS, built with Flutter and Dart. Everything is drawn with `CustomPainter`; there is no WebView and no game engine dependency. All sound effects and the music are synthesized by a script in this repo.

## How to play

- **Drag** anywhere on the board to aim. A dotted line shows the path, including wall bounces and a ghost of where the bubble will land.
- **Lift your finger.** This only stops aiming; it does not shoot.
- **Tap** to fire in the selected direction. Taps are ignored while a bubble is moving.
- **Tap the NEXT bubble** to swap it with the loaded one.
- Connect **3 or more** bubbles of the same color to pop them. Bubbles that are no longer attached to the ceiling fall.
- After **5 shots without a match**, a new row is pushed in from the top. The NEW ROW counter shows how many shots remain.
- The game ends when a bubble crosses the red dashed **danger line**. When bubbles get close, a warning sounds and the bottom of the board pulses red.
- Clearing the board shows **LEVEL CLEARED** with confetti, awards a bonus and starts a new board with more rows (endless mode).

### Combos, rainbow bubbles and celebrations

- **Combo streak:** each consecutive matching shot raises the multiplier (x2, x3 … up to x5). A COMBO badge appears under the score and the chime rises in pitch. A miss resets the streak.
- **Rainbow bubble:** every 3rd match in a row awards a rainbow bubble as your next shot. It's a wildcard that takes the neighboring color that makes the biggest group.
- **Praise:** big shots trigger GREAT!, AWESOME!, AMAZING!, INCREDIBLE! or AVALANCHE! with confetti, a screen flash and a shake.
- **NEW BEST!:** beating your best score mid-game sets off a confetti shower and a fanfare. A new high score at game over shows confetti on the result card.
- **Effects:** shockwave rings on every pop, a glowing trail behind the shot, pop sounds that climb in pitch during a cascade, and haptic feedback (can be turned off in Settings).

### Scoring

| Event | Points |
|---|---|
| Popped bubble | 10 each |
| Combo bonus | +10 for each popped bubble beyond 3 |
| Dropped (floating) bubble | 20 each (doubled when 5 or more drop at once) |
| Streak multiplier | Shot total × 1 to 5 for consecutive matching shots |
| Level cleared | 500, plus 250 for each level after the first |

The best score, sound effects, music and vibration settings are saved with SharedPreferences.

## Requirements

- Flutter 3.47 or newer (Dart 3.13 or newer). Developed with Flutter 3.47.2.
- Android: Android SDK.
- iOS: macOS with Xcode and CocoaPods.

## Run

```bash
flutter pub get
flutter run            # on a connected device or emulator
```

The app is locked to portrait orientation.

## Test

```bash
flutter analyze
flutter test
```

There are 87 tests:

- **Unit tests** (`test/game/`) cover:
  - The hex grid, BFS matching (3, 4+ and diagonal) and floating-bubble detection.
  - Collision without tunneling, wall bounces, snapping and trajectory prediction.
  - Shooter aim limits and scoring.
  - Engine rules: new row after 5 misses, game over, pause, restart, level clear and frame-rate independence.
  - Combo multiplier, rainbow award and wildcard matching, praise tiers and sound events.
- **Widget tests** (`test/widget/`) cover:
  - Home screen and PLAY.
  - Drag-to-aim without firing, and tap-to-fire with only one bubble in flight.
  - Pause/resume, restart, and the game-over overlay with NEW HIGH SCORE.
  - Persistence of settings, vibration and best score, and bubble swapping.
  - Layout on five screen sizes.

## Build an Android APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk

# smaller, per-architecture APKs:
flutter build apk --release --split-per-abi
```

Install it on a device with `adb install build/app/outputs/flutter-apk/app-release.apk`.

> **Signing:** the release build is signed with the **debug key**. That is fine for sideloading and testing, but Google Play needs your own upload key. See https://docs.flutter.dev/deployment/android#sign-the-app. For the Play Store, build an app bundle with `flutter build appbundle`.

> **Windows note:** `android/gradle.properties` sets `kotlin.incremental=false`. Without it, Kotlin's incremental cache fails when the project and the pub cache are on different drives.

## Build for iOS

On macOS:

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode to set your signing team and archive.

## Regenerating assets

- **Sounds and music:** `dart run tool/generate_sounds.dart` writes `assets/sounds/*.wav`.

  The music is a calm 16-bar loop at 70 BPM: Cmaj7 – Am7 – Dm7 – G, then Fmaj7 – Em7 – Dm7 – G. It layers a chorused pad, a soft bass, a kalimba-like arpeggio with echo and a flute-like melody. The reverb is applied circularly, so the loop has no seam.
- **App icon:** `flutter test tool/generate_app_icon_test.dart` renders the brand art in `lib/painters/brand_painter.dart` to:
  - every Android density: legacy icon plus adaptive foreground, background and monochrome layers;
  - every iOS icon size, as opaque RGB PNGs;
  - `branding/`, including the 512 px Play Store icon.

## Project structure

```
lib/
  main.dart                     App entry: services, portrait lock, app lifecycle (music)
  game/                         Pure game logic (no widgets)
    bubble_color.dart           The six colors and their shades
    bubble.dart                 GridCell, FlyingBubble (with trail, rainbow flag)
    bubble_grid.dart            Honeycomb grid: rows/cols, neighbors, row insertion
    board_layout.dart           Screen <-> world mapping, column count, danger line
    bubble_shooter.dart         Aim (clamped above horizontal), current/next bubbles
    collision_detector.dart     Sub-stepped movement, wall bounce, hits, snap cell
    trajectory_calculator.dart  Aim preview using the same physics as real shots
    match_finder.dart           BFS same-color groups and floating bubbles
    scoring.dart                Points, streak multiplier, praise tiers
    game_effects.dart           Pops, falls, particles, shockwaves, confetti, banners
    game_engine.dart            Rules, phases, streaks, rainbow, new rows, levels
  painters/
    bubble_painter.dart         Glossy bubble, rainbow bubble (cached shaders)
    brand_painter.dart          Glass bubbles + emblem shared by the icon and home logo
    game_painter.dart           Board, trajectory, launcher, trail, effects, banners
  screens/                      home_screen, game_screen, settings_screen
  widgets/                      Premium background, PLAY button, HUD, overlays, confetti
  services/
    storage_service.dart        SharedPreferences wrapper
    audio_service.dart          audioplayers (low-latency SFX); missing assets skipped
    settings_controller.dart    Settings, best score, haptics (ChangeNotifier)
  theme/app_theme.dart          Indigo palette, text styles, glass panel
assets/sounds/                  Generated WAV effects and music loop
branding/                       Icon masters (1024, Play Store 512, adaptive foreground)
tool/                           Sound and icon generators
test/                           Unit and widget tests
```

### Design notes

- **World units.** The game logic uses world units where the bubble radius is 1. `BoardLayout` picks the column count from the screen width and scales the board to fit, so bubble size, the shooter and the danger line all adapt to the screen.
- **Physics and prediction.** Bubbles move in fixed 0.25-unit sub-steps, so they cannot tunnel through other bubbles and movement does not depend on frame rate. The trajectory preview uses the same stepping, so the predicted landing cell matches the real one. A test checks this.
- **Rendering.** The board repaints through a `Listenable` tied to the engine, so the game loop never rebuilds widgets. Effects are drawn by the same painter. The gameplay background is a static frame; the menus use the animated one.
- **Pause and lifecycle.** Pausing stops the ticker, so nothing advances. The game pauses automatically when the app goes inactive or into the background, and music stops while the app is hidden.
