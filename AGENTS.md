# AGENTS.md — Navika

Navika is a Flutter music player. It streams from a Navidrome server and plays local files, built on `just_audio` and `just_audio_background`. Targets: Android, iOS, macOS, Windows, Linux. It includes a "Flow" feature that builds a listening queue from history, favorites, and taste feedback.

Primary goal right now: **performance** on low-end Android phones and 8 GB Macs. Behavior and visual design must not change unless a task says so.

## Project layout

- `lib/main.dart` — app entry, theme (`C` color class), constants/keys, `HomeScreen` and `_HomeScreenState`.
- `lib/navidrome_client.dart` — Navidrome API client and models (`MusicTrack`, `NavidromeCredentials`, `ListeningEvent`).
- `lib/src/*.dart` — `part of '../main.dart'` files. Each is an `extension _XMethods on _HomeScreenState`:
  `app_widgets`, `home_data`, `playback`, `collections`, `home_layout`, `flow_logic`, `discovery`, `library_pages`, `mini_player`, `settings`, `flow_ui`, `player_ui`, `shared_widgets`.
- All of these share one `State` object. Any field on `_HomeScreenState` is visible everywhere, and any `setState` rebuilds the whole home screen.

## Commands

```bash
flutter pub get
flutter analyze            # must pass with no new warnings
dart format lib            # format before finishing
flutter test               # if tests exist
flutter run --profile -d <device>   # for ANY performance check; never judge speed in debug mode
```

Never claim a performance improvement without profile-mode evidence (see "Performance work").

## Hard rules

1. **Scope.** Change only what the task asks. No drive-by refactors, renames, reformatting of untouched code, or dependency changes unless asked.
2. **Don't change behavior or UI.** Same layout, fonts, colors, animations, and user-visible strings unless the task explicitly says otherwise.
3. **Keep the `part` / `extension` structure** unless the task is specifically to refactor it. Don't convert parts to libraries or move methods between files on your own.
4. **No new packages** without asking first. Explain why and what it costs in app size.
5. **Don't touch persistence formats.** SharedPreferences keys (`navika.*`) and their JSON shapes must stay backward compatible. If a format must change, write a migration and say so.
6. **Platform code.** Don't edit `android/`, `ios/`, `macos/`, `windows/`, `linux/` or the `app.navika/local_folders` method channel unless the task requires it.
7. **Small steps.** One task at a time. After each change, run `flutter analyze` and report the result. Show a summary of the diff and the files changed.
8. **If you are unsure or need a file you can't see, say which one.** Don't invent APIs, methods, or file contents.
9. **Never leave `...`, `TODO`, or placeholder code** in the changes you deliver.

## Performance work

Known problem areas (verify before fixing; don't assume):

- Playback streams (`playerStateStream`, `currentIndexStream`, `durationStream`) call a bare `setState`, rebuilding the whole screen. Position already uses a `ValueNotifier`; prefer the same approach for other playback state.
- Overlays (`_playerOverlay`, `_flowOverlay`, settings) stay mounted while closed and rebuild on every `setState`.
- `_playerOverlay` uses a `TweenAnimationBuilder` whose `child` parameter is unused, so the whole player UI rebuilds each animation frame.
- Some lists (e.g. the mobile Up Next view) build all items in a `Column` instead of lazily. Use `ListView.builder` / slivers.
- `_buildFlowQueue()` may run inside `build()`. Cache it; recompute only when its inputs change.
- `_favorites` is a `List<String>`. Per-row `.contains` is O(n); use a `Set<String>` for lookups.
- Artwork may be decoded at full resolution. Use `cacheWidth` / `cacheHeight` and thumbnails.
- Local-folder scanning and `readMetadata(..., getImage: true)` may run on the main isolate, and the folder rescan interval is 1 minute.
- Large JSON in SharedPreferences (history, local tracks, queue, taste profile) is expensive to read and write.

Process for any performance task:

1. State the suspected cause and the file/lines.
2. Make the minimal fix.
3. Explain how to verify it: profile mode, DevTools "Track widget rebuilds", CPU profiler, Memory tab.
4. Report what you measured, or say plainly that you could not measure.

Do not add `const` everywhere as a "fix". It's fine where it's trivially correct, but it is not a substitute for finding the real hotspot.

## Flutter conventions

- Never call `setState` for high-frequency data (position ticks, animation values). Use `ValueNotifier` / `ValueListenableBuilder` or `AnimatedBuilder` scoped to the smallest subtree.
- Pass static subtrees through the `child` parameter of `AnimatedBuilder`, `TweenAnimationBuilder`, and `ValueListenableBuilder`.
- Wrap independently animating or frequently repainting areas (visualizer, animated gradients, progress bars) in `RepaintBoundary`.
- Dispose every controller, timer, notifier, and stream subscription. Check `mounted` before `setState` after any `await`.
- Heavy work (metadata parsing, JSON decoding of large data, image analysis) goes off the main isolate with `Isolate.run` or `compute`.
- Respect `_reduceMotion`: animations must use `Duration.zero` when it's on.
- Use `C.*` for colors, since they depend on the active theme. Don't hard-code colors.
- Prefer `withValues(alpha: ...)` over the deprecated `withOpacity`.
- Keep platform branching consistent with the existing pattern (`Theme.of(context).platform`, `defaultTargetPlatform`).

## Definition of done

- `flutter analyze` is clean, and `dart format` has been run on touched files.
- The app still builds for the platform you touched, if you can build it.
- Playback, queue, Flow, favorites, and playlists still work, and you listed what you checked manually.
- The summary lists files changed, what changed and why, and anything you could not verify.
