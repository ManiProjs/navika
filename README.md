# Navika

Navika is a cross-platform music player for [Navidrome](https://www.navidrome.org/) servers, built with Flutter. It brings your streamed music library, playback queue, favorites, playlists, and listening insights into a focused desktop-and-mobile app.

## Features

- **Navidrome connection** — connect to your own server with its URL and account credentials.
- **Music library** — browse your collection and search for tracks without dumping the entire library into search results.
- **Playback controls** — play, pause, skip, seek through tracks, shuffle, repeat, and manage the Up Next queue.
- **Mini-player and full player** — keep playback controls close, or open the animated full-screen player with artwork and optional visualizer.
- **Personalized Home** — Quick start, listening-based picks, discovery suggestions, and your most-played artists.
- **Favorites and playlists** — save favorites and create local playlists.
- **Listening stats** — review listening activity and the history stored on your device.
- **Local recommendations** — a lightweight ranking algorithm uses listening recency, familiar artists and albums, and favorites to suggest tracks. It runs locally and does not require an AI API key.
- **Preferences** — adjust reduced motion, automatic track advancement, and the player visualizer.
- **Cross-platform Flutter app** — platform folders are included for Android, iOS, Linux, macOS, Windows, and web.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) with a Dart SDK compatible with the version in `pubspec.yaml`.
- Access to a running Navidrome server and a user account on that server.
- Network access from the device running Navika to the server URL.

## Getting started

Clone or download this repository, then run these commands from the project directory:

```sh
flutter pub get
flutter run
```

When Navika opens, use the connection flow to enter your Navidrome server URL, username, and password. Use the server's reachable address for your device—for example, a local network address when running Navika on the same network.

## Build

Choose the target platform and run its Flutter build command:

```sh
# macOS
flutter build macos

# Linux
flutter build linux

# Windows
flutter build windows

# Android APK
flutter build apk

# iOS (requires macOS and Xcode)
flutter build ios

# Web
flutter build web
```

Platform-specific prerequisites still apply. For example, iOS builds require Xcode, and Android release builds may need signing configuration.

## Development checks

Run the formatter, static analyzer, and tests before submitting changes:

```sh
dart format lib test
flutter analyze
flutter test
```

## Data and privacy

Navika stores app preferences, favorites, local playlists, connection details, and listening history using local app preferences. Listening history is used by the on-device recommendation algorithm and stats views. Keep your device account protected, and only connect to servers you trust. Use HTTPS when connecting over an untrusted network if your Navidrome setup supports it.

Recommendations are algorithmic and local; the current project does not require a cloud AI provider. Music files and streaming are served by your Navidrome server.

## Tech stack

- [Flutter](https://flutter.dev/) and Dart
- [Navidrome](https://www.navidrome.org/) with its Subsonic-compatible API
- [`just_audio`](https://pub.dev/packages/just_audio) for audio playback
- [`http`](https://pub.dev/packages/http) for API requests
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) for local app settings and data
- [`crypto`](https://pub.dev/packages/crypto) for request authentication

## License

See [`LICENSE`](LICENSE) for the project's license.
