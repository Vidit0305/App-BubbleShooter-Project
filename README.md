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

There are 105 tests, and GitHub Actions runs them, along with the analyzer, on every push and pull request.

- **Game logic unit tests** (`test/game/`) cover:
  - The hex grid, BFS matching (3, 4+ and diagonal) and floating-bubble detection.
  - Collision without tunneling, wall bounces, snapping and trajectory prediction.
  - Board layout, shooter aim limits and scoring.
  - Engine rules: new row after 5 misses, game over, pause, restart, level clear and frame-rate independence.
  - Combo multiplier, rainbow award and wildcard matching, praise tiers and sound events.
- **Service unit tests** (`test/services/`) cover settings, storage, and the mapping from game events to sounds and haptics.
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
  main.dart, app.dart   Bootstrap and root widget
  game/                 Pure game logic and tuning (GameConfig), no widgets
  painters/             Bubble, brand and board painters
  screens/              Home, game and settings screens
  services/             Storage, settings, audio, game feedback
  theme/                Palette, text styles, glass panel
  widgets/              GameBoard, plus common/, hud/ and overlays/
assets/sounds/          Generated sound effects and music
branding/               Icon masters
docs/                   Architecture notes
tool/                   Sound and icon generators
test/                   game/, services/ and widget/ tests
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the parts fit together and for the main design decisions, and [CHANGELOG.md](CHANGELOG.md) for release notes.
