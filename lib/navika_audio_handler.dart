import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'navidrome_client.dart';

typedef AudioTrackSelector = Future<void> Function(String trackId);
typedef AudioTrackSkipper = Future<void> Function(int direction);

/// Bridges Navika's existing player and library to Android Auto and system
/// media controls. The Flutter UI remains the owner of queue policy.
class NavikaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  NavikaAudioHandler(this._player, this._onSelectTrack, this._onSkip) {
    _subscriptions.add(
      _player.playbackEventStream.listen((_) => _broadcastState()),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((_) => _broadcastState()),
    );
  }

  static const _allMusicId = 'navika:all-music';
  static const _favoritesId = 'navika:favorites';
  static const _recentId = 'navika:recently-played';
  static const _smartPlaylistsId = 'navika:smart-playlists';
  static const _playlistsId = 'navika:playlists';

  final AudioPlayer _player;
  final AudioTrackSelector _onSelectTrack;
  final AudioTrackSkipper _onSkip;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, BehaviorSubject<Map<String, dynamic>>> _childrenSubjects =
      {};
  final Map<String, MusicTrack> _tracksById = {};
  final Map<String, MediaItem> _itemsById = {};
  final Map<String, List<String>> _playlists = {};
  final Map<String, List<String>> _smartPlaylists = {};
  Set<String> _favorites = {};
  List<String> _recentIds = [];

  void updateLibrary({
    required Iterable<MusicTrack> tracks,
    required Iterable<String> favorites,
    required Iterable<ListeningEvent> history,
    required Map<String, List<String>> playlists,
    required Map<String, List<String>> smartPlaylists,
    required Iterable<MediaItem> mediaItems,
  }) {
    _tracksById
      ..clear()
      ..addEntries(tracks.map((track) => MapEntry(track.id, track)));
    _itemsById
      ..clear()
      ..addEntries(mediaItems.map((item) => MapEntry(item.id, item)));
    _favorites = favorites.toSet();
    _playlists
      ..clear()
      ..addEntries(
        playlists.entries.map(
          (entry) => MapEntry(entry.key, List<String>.of(entry.value)),
        ),
      );
    _smartPlaylists
      ..clear()
      ..addEntries(
        smartPlaylists.entries.map(
          (entry) => MapEntry(entry.key, List<String>.of(entry.value)),
        ),
      );
    final seen = <String>{};
    _recentIds = history
        .toList()
        .reversed
        .map((event) => event.id)
        .where((id) => _tracksById.containsKey(id) && seen.add(id))
        .take(100)
        .toList();
    _notifyChildrenChanged();
  }

  void updatePlaybackQueue(List<MediaItem> items, int currentIndex) {
    queue.add(List<MediaItem>.unmodifiable(items));
    if (items.isNotEmpty && currentIndex >= 0 && currentIndex < items.length) {
      mediaItem.add(items[currentIndex]);
    }
    _broadcastState(queueIndex: currentIndex);
  }

  MusicTrack? trackForId(String id) => _tracksById[id];

  Future<void> dispose() async {
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await Future.wait(
      _childrenSubjects.values.map((subject) => subject.close()),
    );
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) =>
      _childrenSubjects.putIfAbsent(
        parentMediaId,
        () => BehaviorSubject<Map<String, dynamic>>.seeded(const {}),
      );

  void _notifyChildrenChanged() {
    for (final subject in _childrenSubjects.values) {
      subject.add(const {});
    }
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return const [
        MediaItem(id: _allMusicId, title: 'All music', playable: false),
        MediaItem(id: _favoritesId, title: 'Favorites', playable: false),
        MediaItem(id: _recentId, title: 'Recently played', playable: false),
        MediaItem(id: _playlistsId, title: 'Playlists', playable: false),
      ];
    }
    if (parentMediaId == _allMusicId) {
      return _tracksById.keys
          .take(100)
          .map((id) => _itemsById[id])
          .whereType<MediaItem>()
          .toList();
    }
    if (parentMediaId == _favoritesId) {
      return _tracksById.keys
          .where(_favorites.contains)
          .take(100)
          .map((id) => _itemsById[id])
          .whereType<MediaItem>()
          .toList();
    }
    if (parentMediaId == _smartPlaylistsId) {
      return _smartPlaylists.keys
          .map(
            (name) => MediaItem(
              id: _smartPlaylistId(name),
              title: name,
              playable: false,
            ),
          )
          .toList();
    }
    if (parentMediaId == _recentId) {
      return _recentIds
          .map((id) => _itemsById[id])
          .whereType<MediaItem>()
          .toList();
    }
    if (parentMediaId == _playlistsId) {
      return [
        const MediaItem(
          id: _smartPlaylistsId,
          title: 'Smart playlists',
          playable: false,
        ),
        ..._playlists.keys.map(
          (name) =>
              MediaItem(id: _playlistId(name), title: name, playable: false),
        ),
      ];
    }
    if (parentMediaId.startsWith('navika:playlist:')) {
      final encoded = parentMediaId.substring('navika:playlist:'.length);
      final name = utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
      return (_playlists[name] ?? const <String>[])
          .map((id) => _itemsById[id])
          .whereType<MediaItem>()
          .take(100)
          .toList();
    }
    if (parentMediaId.startsWith('navika:smart-playlist:')) {
      final encoded = parentMediaId.substring('navika:smart-playlist:'.length);
      final name = utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
      return (_smartPlaylists[name] ?? const <String>[])
          .map((id) => _itemsById[id])
          .whereType<MediaItem>()
          .take(100)
          .toList();
    }
    return const [];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async => _itemsById[mediaId];

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    if (_tracksById.containsKey(mediaId)) await _onSelectTrack(mediaId);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    await playFromMediaId(mediaItem.id);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _onSkip(1);

  @override
  Future<void> skipToPrevious() => _onSkip(-1);

  @override
  Future<void> skipToQueueItem(int index) async {
    final items = queue.value;
    if (index >= 0 && index < items.length) {
      await playFromMediaId(items[index].id);
    }
  }

  String _playlistId(String name) =>
      'navika:playlist:${base64Url.encode(utf8.encode(name)).replaceAll('=', '')}';

  String _smartPlaylistId(String name) =>
      'navika:smart-playlist:${base64Url.encode(utf8.encode(name)).replaceAll('=', '')}';

  void _broadcastState({int? queueIndex}) {
    final state = _player.playerState;
    final processingState = switch (state.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          state.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: state.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex ?? playbackState.value.queueIndex,
      ),
    );
  }
}
