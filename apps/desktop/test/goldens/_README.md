# Golden Tests

Golden tests capture pixel-perfect screenshots of screens for visual regression detection.

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
2. Add `@Tags(['golden'])` to the top of the file (above `library;`) so the test is gated behind the `golden` tag.
3. Import `package:golden_toolkit/golden_toolkit.dart`.
4. Use the **GetIt-mock pattern** (see below) for any screen that resolves repos via `GetIt.I<>()` inside `MultiBlocProvider.create`.
5. Wrap the test in `testGoldens(...)` and use `screenMatchesGolden(tester, 'my_test_name')` to capture.
6. Run `flutter test --tags=golden --update-goldens test/goldens/my_new_test.dart` once to generate the initial PNG baseline in `test/goldens/goldens/`.
7. Commit the generated PNG along with the test file.

## Windows / font-rendering note

Golden images are platform-sensitive. Baselines generated on Windows may differ from macOS/Linux due to font subpixel rendering differences. CI excludes golden tests via `flutter test --exclude-tags=golden`. The committed baselines reflect the maintainer's Windows machine; rebaseline on the same OS family if you regenerate.

If golden generation fails with `"Surface size too large"` or font-loading errors, try:

```dart
// At the top of the test file:
GoldenToolkit.runWithConfiguration(
  () async { ... },
  config: GoldenToolkitConfiguration(enableRealShadows: false),
);
```

## Current golden files

| File | Screen | Size | Notes |
|------|--------|------|-------|
| `m3_dashboard_golden_test.dart` | DashboardScreen | 1440×900 | Uses GetIt-mock recipe — see below |

## GetIt-mock recipe — for screens that resolve repos via `GetIt.I<>()`

Production screens like `DashboardScreen` create their cubits inside `MultiBlocProvider.create` using `GetIt.I<DashboardRepository>()` etc. A wrapping `MultiBlocProvider` in a test won't override those — the inner `create` block runs after the test's wrapping provider and asks the GetIt singleton directly.

The fix: register **mock repositories** in GetIt before pumping, and stub their methods to return deterministic data. The screen's `MultiBlocProvider.create` then constructs real cubits that talk to your mocks.

```dart
class _MockDashboardRepo extends Mock implements DashboardRepository {}
class _MockStorageRepo extends Mock implements StorageRepository {}
class _MockActivityRepo extends Mock implements RecentActivityRepository {}

void main() {
  final mockDashboardRepo = _MockDashboardRepo();
  final mockStorageRepo = _MockStorageRepo();
  final mockActivityRepo = _MockActivityRepo();

  setUp(() {
    GetIt.I.reset();
    GetIt.I.registerSingleton<DashboardRepository>(mockDashboardRepo);
    GetIt.I.registerSingleton<StorageRepository>(mockStorageRepo);
    GetIt.I.registerSingleton<RecentActivityRepository>(mockActivityRepo);

    when(() => mockDashboardRepo.getServerInfo()).thenAnswer((_) async => _serverInfo);
    when(() => mockDashboardRepo.getClients()).thenAnswer((_) async => _clients);
    when(() => mockDashboardRepo.getLibraryCount()).thenAnswer((_) async => 6);
    when(() => mockStorageRepo.fetch()).thenAnswer((_) async => _storage);
    when(() => mockActivityRepo.fetch(limit: any(named: 'limit')))
        .thenAnswer((_) async => _activities);
  });

  tearDown(() => GetIt.I.reset());

  testGoldens('DashboardScreen — m3 default state', (tester) async {
    await tester.pumpWidgetBuilder(
      // Wrap only cubits that aren't created by the screen itself.
      // SystemStatsCubit is provided by `flux_shell.dart` in prod.
      BlocProvider<SystemStatsCubit>.value(
        value: stubSystemStats,
        child: const DashboardScreen(),
      ),
      surfaceSize: const Size(1440, 900),
    );

    // Drain async repo loads.
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'm3_dashboard_default');
  });
}
```

### Why a stub `SystemStatsCubit` (not a mock repo)?

`SystemStatsCubit.start()` schedules a `Timer.periodic` poll. Under test that timer would fire mid-capture and produce a flaky snapshot. Subclassing the cubit and overriding `start()` to emit one deterministic state, then idling, is simpler than disabling the timer through mocks.

### Adapting for other screens

- If a screen creates its cubits via a parent `BlocProvider` (not `GetIt.I<>()`), stub the cubit directly with `BlocProvider<X>.value(...)` instead of registering repos.
- If a screen uses `BlocProvider.value` for an outer cubit and `MultiBlocProvider.create` + `GetIt` for inner ones, combine both patterns.
