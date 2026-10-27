# Navika v0.1.0

Navika's first public release: a focused, cross-platform music player for your Navidrome library and local music files.

## Highlights

- **Navidrome streaming:** connect to your own server and browse your music library.
- **Local music playback:** import local tracks and scan watched folders on demand.
- **Playback controls:** queue management, seek, shuffle, repeat, and a compact mini-player alongside the full player.
- **Flow recommendations:** a locally generated listening queue informed by listening history, favorites, and taste feedback.
- **Library and discovery:** search tracks, browse recommendations, manage favorites and local playlists, and review listening statistics.
- **Personalized player:** artwork, accent colors, animated background, and an optional visualizer.
- **Desktop and mobile:** release builds for Windows, macOS, Linux, and Android.

## Performance and reliability

- Reduced unnecessary screen rebuilds from playback updates.
- Made the mobile Up Next, search, and favorites lists lazy-built.
- Reduced artwork decoding and image-cache memory use.
- Cached library lookups and recommendation results to avoid repeating expensive work during unrelated rebuilds.
- Moved supported local-file scanning and metadata work off the UI isolate, skipped unchanged files, and replaced the periodic folder scan with app-resume and manual refresh.
- Debounced listening-history persistence and capped the retained history.
- Kept player transitions and visualizer animations while reducing unnecessary work around them.

## Downloads

- **Windows:** `Navika-0.1.0-windows-x64.zip` — extract and launch `navika.exe`.
- **macOS:** `Navika-0.1.0-macos-arm64.zip` — extract and open `navika.app`.
- **Linux:** `Navika-0.1.0-linux-x64.tar.gz` — extract the archive and launch `bundle/navika`.
- **Android:** `Navika-0.1.0-android.apk` — install the APK on a compatible Android device.

Desktop archives contain the application bundle and its runtime files. macOS builds are not notarized, so macOS may require you to approve opening the downloaded app.

## Getting started

1. Download the build for your platform from the Assets section of this release.
2. Launch Navika.
3. Connect to a reachable Navidrome server, or add local music.

Navika does not require a cloud AI service for its local recommendations. You need access to your own Navidrome server to stream server-hosted music.

## Known limitations

- This is the first public release; expect rough edges and report reproducible issues with your platform and steps to reproduce.
- Windows and Linux downloads are x64 builds. The macOS archive is an Apple Silicon arm64 build.
- The macOS app is not signed and notarized for distribution.
