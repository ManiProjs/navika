import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:navika/navidrome_client.dart';
import 'package:navika/navika_audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android Auto browse tree exposes library, favorites, recent and playlists',
    () async {
      final player = AudioPlayer();
      final selectedTracks = <String>[];
      final handler = NavikaAudioHandler(player, (id) async {
        selectedTracks.add(id);
      }, (_) async {});
      final browseUpdates = <Map<String, dynamic>>[];
      final browseSubscription = handler
          .subscribeToChildren('navika:favorites')
          .listen(browseUpdates.add);
      const track = MusicTrack(
        id: 'track-1',
        title: 'Track One',
        artist: 'Artist',
        album: 'Album',
      );
      final mediaItem = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
      );
      handler.updateLibrary(
        tracks: [track],
        favorites: [track.id],
        history: [
          ListeningEvent(
            id: track.id,
            artist: track.artist,
            album: track.album,
            playedAt: 100,
          ),
        ],
        playlists: const {
          'Road mix': ['track-1'],
        },
        smartPlaylists: const {
          'Recently played': ['track-1'],
        },
        mediaItems: [mediaItem],
      );

      try {
        await Future<void>.delayed(Duration.zero);
        expect(browseUpdates.length, greaterThan(1));
        final root = await handler.getChildren(AudioService.browsableRootId);
        expect(root.map((item) => item.title), [
          'All music',
          'Favorites',
          'Recently played',
          'Playlists',
        ]);

        final favorites = await handler.getChildren('navika:favorites');
        expect(favorites.single.id, track.id);

        final playlistFolders = await handler.getChildren('navika:playlists');
        expect(playlistFolders.map((item) => item.title), [
          'Smart playlists',
          'Road mix',
        ]);

        final smartFolders = await handler.getChildren(
          'navika:smart-playlists',
        );
        final smartTracks = await handler.getChildren(smartFolders.single.id);
        expect(smartTracks.single.id, track.id);

        await handler.playFromMediaId(track.id);
        expect(selectedTracks, [track.id]);
      } finally {
        await browseSubscription.cancel();
        await handler.dispose();
        await player.dispose();
      }
    },
  );
}
