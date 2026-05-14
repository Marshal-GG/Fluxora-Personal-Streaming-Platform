# Mobile Golden Tests

Golden tests capture pixel-perfect screenshots of the 10 redesigned
mobile components (M14 Definition of Done in
`docs/11_design/mobile_redesign_plan.md` §13) for visual regression
detection.

## Running golden tests

```bash
# Run golden tests only
flutter test --tags=golden test/goldens/

# Update golden baselines after intentional visual changes
flutter test --tags=golden --update-goldens test/goldens/

# Default test run + CI: skip goldens (platform subpixel rendering differs)
flutter test --exclude-tags=golden
```

## Adding a new golden test

1. Create a test file in `test/goldens/`.
2. Add `@Tags(['golden'])` to the top of the file (above `library;`) so
   the test is gated behind the `golden` tag.
3. Import `package:golden_toolkit/golden_toolkit.dart`.
4. For widgets that take a `Player`, use `buildFakePlayer(...)` from
   `_player_mocks.dart` instead of constructing a real `media_kit`
   player — the native libmpv bindings are not available headlessly.
5. Wrap the test in `testGoldens(...)` and use
   `screenMatchesGolden(tester, 'my_test_name')` to capture.
6. Run `flutter test --tags=golden --update-goldens test/goldens/my_new_test.dart`
   once to generate the initial PNG baseline in `test/goldens/goldens/`.
7. Commit the generated PNG along with the test file.

## Windows / font-rendering note

Golden images are platform-sensitive. Baselines generated on Windows
may differ from macOS / Linux due to font subpixel rendering. CI
excludes golden tests via `flutter test --exclude-tags=golden`. The
committed baselines reflect the maintainer's Windows machine; rebaseline
on the same OS family if you regenerate.

If golden generation fails with `"Surface size too large"` or font
loading errors, try:

```dart
// At the top of the test file:
GoldenToolkit.runWithConfiguration(
  () async { ... },
  config: GoldenToolkitConfiguration(enableRealShadows: false),
);
```

## Current golden files

| File | Widget | Surface | Notes |
|------|--------|---------|-------|
| `top_bar_golden_test.dart` | `PlayerTopBar` (flux_player_controls.dart) | 412×88 | HDR chip + back + PIP + X-Ray + overflow |
| `center_transport_golden_test.dart` | `PlayerCenterTransport` (flux_player_controls.dart) | 412×140 | Paused state; gradient play button autofocused |
| `progress_bar_golden_test.dart` | `PlayerProgressBar` (flux_player_controls.dart) | 412×60 | 30 % playhead through 1 h 30 m; mocked `Player` |
| `side_rail_left_golden_test.dart` | `PlayerSideRail` left brightness rail | 80×540 | Passive indicator (no value text) |
| `side_rail_right_golden_test.dart` | `PlayerSideRail` right volume rail | 80×540 | Passive indicator (no value text) |
| `lock_overlay_golden_test.dart` | `FluxPlayerControls` with `controller.lock()` | 412×892 | Full chrome captured in lock mode — hold-to-unlock pill + caption |
| `mini_player_golden_test.dart` | `FluxMiniPlayer` (`shared/widgets/flux_mini_player.dart`) | 412×80 | Stub `PlayerCubit` + `GoRouter` + mocked `Player` |
| `bottom_sheet_golden_test.dart` | `PlayerQuickActions` 4x2 grid | 412×80 | Captures the player-chrome quick-action row that launches every modal sheet |
| `app_bar_golden_test.dart` | `FluxAppBar` (fluxora_core) | 412×80 | Title + back chevron + trailing icon |
| `poster_golden_test.dart` | `FluxPoster` hero (fluxora_core) | 180×250 | Gradient fallback + 4K badge + 30 % progress |

## Private-widget exposure pattern

The five player-chrome components (`_TopBar`, `_CenterTransport`,
`_ProgressBar`, `_SideRail`, `_QuickActions`) were private widgets in
`flux_player_controls.dart`. Rather than reach into them via a `part of`
shim, we renamed each to a public class (`PlayerTopBar`,
`PlayerCenterTransport`, `PlayerProgressBar`, `PlayerSideRail`,
`PlayerQuickActions`) and annotated the constructor with
`@visibleForTesting`. The analyzer enforces that production code
outside the defining library can't call those constructors, so the
public API surface stays minimal even though the symbol names are
exposed for the goldens.

The lock affordance is not a separate widget — it is inline within
`FluxPlayerControls.build` when `controller.lockMode == true`. The
`lock_overlay_golden_test.dart` captures the entire chrome with a
locked controller; there is nothing smaller to extract.

## `Player` mock recipe — for widgets that take a `media_kit` Player

`media_kit`'s `Player()` constructor reaches into native libmpv on
first use, which is not available in a headless test harness. We mock
it with mocktail; see `_player_mocks.dart`:

```dart
final player = buildFakePlayer(
  position: const Duration(minutes: 27),
  duration: const Duration(hours: 1, minutes: 30),
  playing: true,
);
```

`buildFakePlayer` stubs both the synchronous `player.state` getter and
the per-channel streams (`player.stream.position`, `.duration`,
`.playing`) so a `StreamBuilder` resolves on the first pump. Other
fields fall back to `PlayerState`'s const defaults — fine for
chrome-only captures.

## `PlayerCubit` + GetIt recipe — for `FluxMiniPlayer`

`FluxMiniPlayer.build` reads `GetIt.I<PlayerCubit>()` directly, so
the test pattern is:

1. Register a stub `PlayerCubit` subclass before pumping (`GetIt.I.reset()`
   then `registerSingleton<PlayerCubit>(stub)`).
2. The stub subclasses `PlayerCubit` and exposes a `seed()` method that
   emits a deterministic `PlayerReady` state with a mocked `Player`
   and a mocked `VideoController` (only the constructor needs the
   reference; no methods are called).
3. Pump a `MaterialApp.router` with a one-route `GoRouter` so the
   `context.push(Routes.playerResume)` lookup in the mini-player's tap
   handler doesn't throw — the route doesn't have to be reached.
4. Call `seed()` after pump, then
   `await tester.pumpAndSettle(const Duration(milliseconds: 400))` to
   drain the bar's 200 ms `AnimatedSize` mount + the
   `StreamBuilder` initial-data settle before capturing.

## Sharp edges encountered during baseline generation

* `_CircleButton` has a 50 ms press-scale animation and the play /
  pause button is `autofocus: true` — capture at rest by simply
  pumping past 300 ms; the focus ring is part of the baseline.
* `_SeekRipple` is now time-driven (400 ms `AnimationController`) but
  it is only mounted while `_ripplePos != null`. None of the goldens
  trigger a double-tap, so the ripple is absent from every baseline.
* `_DragHud` is permanently in the tree behind an `AnimatedOpacity` +
  `IgnorePointer`. With `controller.dragHudVisible == false` the
  opacity is 0 and the layer is hit-test-disabled, so it doesn't
  contribute pixels.
* The 600 ms HUD clear delay (`_onVerticalDragEnd`) is a real-time
  `Future.delayed`. None of the goldens exercise drag flows, so this
  is not a problem here.
* `MaterialApp.shortcuts` is left at default. The play / pause
  autofocus paints a focus ring; we accept that ring as part of the
  baseline rather than scrubbing it out.
