# Navika v0.2.0

This release brings Navika to the car, adds synchronized lyrics and smart playlists, and improves playback personalization and loudness handling.

## What's new

- **Android Auto** — browse your music library, favorites, recent tracks and playlists from a compatible car display, with playback controls and metadata.
- **Synchronized lyrics** — fetch timed lyrics from LRCLIB and follow along with the currently playing track. Plain-text lyrics are supported when timed lyrics are unavailable.
- **Smart playlists** — automatically generated collections for Recently played, Most played, Never played, Forgotten favorites and Short & sweet.
- **ReplayGain normalization** — use track or album gain metadata from Navidrome and supported local audio tags. Choose a preamp level, and use peak metadata to help avoid clipping. Tracks without ReplayGain tags play normally.

## Improvements

- **Flow** — more consistent artist variety, session-aware queue generation, track exclusions and the ability to resume a Flow session.
- **Player experience** — clearer tactile playback controls, plus lyrics and Up Next panels that switch in the same player area.
- **App identity** — platform application identifiers now use `com.maniarasteh.navika`.
- **Playback integration** — more complete media metadata and controls for Android's media experience.

## Upgrade notes

- Android treats the new application ID as a different app from earlier builds using `com.example.navika`. The previous installation may remain separately installed; transfer or back up any local-only data before removing it.
- ReplayGain only changes tracks that include usable gain metadata. It does not analyze audio or create ReplayGain tags.

---
