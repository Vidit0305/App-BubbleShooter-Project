# Changelog

## Unreleased

### Added
- A How to play screen, opened from the home screen.
- The NEW ROW counter pulses on the last shot before a new row.
- A CI check for code formatting (`dart format`, 100-column lines).

## 1.1.0

### Changed
- Reorganized the code:
  - The app widget moved to `app.dart`.
  - Widgets are grouped into `common/`, `hud/` and `overlays/`.
  - The playfield is now its own `GameBoard` widget.
  - Sound and haptic mapping moved to the new `GameFeedback` service.
  - Gameplay tuning values are in `GameConfig`.
- Stricter static analysis rules.
- Line endings are normalized and byte-order marks removed.

### Added
- Unit tests for settings, storage, sound feedback and board layout (105 tests in total).
- A GitHub Actions workflow that runs `flutter analyze` and `flutter test`.
- `docs/ARCHITECTURE.md` and this changelog.

## 1.0.0

First release:
- **Gameplay:** honeycomb bubble grid, drag to aim and tap to fire, wall bounces, matching and floating-bubble drops, a new row after 5 misses, game over at the danger line, and endless levels.
- **Engagement:** combo multiplier, rainbow wildcard bubble, praise banners, confetti, shockwaves and haptics.
- **Presentation:** premium animated home screen, new app icon, relaxing music loop and synthesized sound effects.
- **Persistence:** pause, settings, and best score saved on the device.
