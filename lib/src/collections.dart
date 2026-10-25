part of '../main.dart';

extension _CollectionMethods on _HomeScreenState {
  Future<void> _showCollectionDetails({
    required String title,
    required String subtitle,
    required List<MusicTrack> tracks,
    required bool isArtist,
    required MusicTrack artworkTrack,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          backgroundColor: C.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 6, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(pageContext),
                        icon: Icon(Icons.arrow_back_rounded),
                      ),
                      SizedBox(width: 8),
                      Text(
                        isArtist ? 'ARTIST' : 'ALBUM',
                        style: TextStyle(
                          color: C.muted,
                          fontFamily: 'DMSansBold',
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(22, 12, 22, 32),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _artwork(
                              artworkTrack.coverArt,
                              localArtworkPath: artworkTrack.localArtworkPath,
                              size: 148,
                              seed: isArtist ? title : artworkTrack.album,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'SyneBold',
                                    fontSize: 30,
                                    height: 1.05,
                                    letterSpacing: -1,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () => _play(tracks.first, playlist: tracks),
                          icon: Icon(Icons.play_arrow_rounded),
                          label: Text('Play all'),
                        ),
                      ),
                      SizedBox(height: 18),
                      if (isArtist) ...[
                        Text(
                          'DISCOGRAPHY',
                          style: TextStyle(
                            color: C.muted,
                            fontFamily: 'DMSansBold',
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 10),
                      ],
                      for (var index = 0; index < tracks.length; index++) ...[
                        if (isArtist &&
                            (index == 0 ||
                                tracks[index].album.toLowerCase() !=
                                    tracks[index - 1].album.toLowerCase()))
                          Padding(
                            padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
                            child: InkWell(
                              onTap: () => _openAlbum(tracks[index]),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  tracks[index].album,
                                  style: TextStyle(
                                    fontFamily: 'DMSansBold',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _trackRow(tracks[index], index),
                      ],
                      if (tracks.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Text(
                            'No tracks found in this collection.',
                            style: TextStyle(color: C.muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAlbum(MusicTrack track) {
    final matches =
        _tracks
            .where(
              (item) =>
                  item.album.toLowerCase() == track.album.toLowerCase() &&
                  item.artist.toLowerCase() == track.artist.toLowerCase(),
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    unawaited(
      _showCollectionDetails(
        title: track.album,
        subtitle: track.artist,
        tracks: matches,
        isArtist: false,
        artworkTrack: track,
      ),
    );
  }

  void _openArtist(MusicTrack track) {
    final matches =
        _tracks
            .where(
              (item) => item.artist.toLowerCase() == track.artist.toLowerCase(),
            )
            .toList()
          ..sort((a, b) {
            final albumOrder = a.album.toLowerCase().compareTo(
              b.album.toLowerCase(),
            );
            return albumOrder != 0
                ? albumOrder
                : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
    unawaited(
      _showCollectionDetails(
        title: track.artist,
        subtitle:
            'Artist · ${matches.map((item) => item.album).toSet().length} albums',
        tracks: matches,
        isArtist: true,
        artworkTrack: track,
      ),
    );
  }

  void _seekTo(Offset globalPosition, double durationSeconds) {
    if (durationSeconds <= 0) return;
    final box = _progressBarKey.currentContext?.findRenderObject();
    if (box is! RenderBox || box.size.width <= 0) return;

    final local = box.globalToLocal(globalPosition);
    final fraction = (local.dx / box.size.width).clamp(0.0, 1.0);
    unawaited(
      _player.seek(
        Duration(milliseconds: (durationSeconds * 1000 * fraction).round()),
      ),
    );
  }

  void _previewSeek(Offset globalPosition, double durationSeconds) {
    _pendingSeekPosition = globalPosition;
    final box = _progressBarKey.currentContext?.findRenderObject();
    if (box is! RenderBox || box.size.width <= 0 || durationSeconds <= 0) {
      return;
    }
    final local = box.globalToLocal(globalPosition);
    final fraction = (local.dx / box.size.width).clamp(0.0, 1.0);
    _position.value = Duration(
      milliseconds: (durationSeconds * 1000 * fraction).round(),
    );
  }

  void _finishSeeking(double durationSeconds) {
    final position = _pendingSeekPosition;
    _pendingSeekPosition = null;
    _updateState(() => _seeking = false);
    if (position != null) _seekTo(position, durationSeconds);
  }

  Future<void> _togglePlayback() async {
    if (_current == null) return;

    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle) {
        await _play(_current!);
      } else {
        unawaited(
          _player.play().catchError((Object error) {
            if (mounted) {
              _updateState(() => _error = _describePlaybackError(error));
            }
          }),
        );
      }
    }

    if (mounted) _updateState(() {});
  }

  Future<void> _skip(int direction) async {
    if (_queue.isEmpty) return;

    var next = _queueIndex + direction;

    if (_shuffle && direction == 1 && _queue.length > 1) {
      final candidates = List<int>.generate(
        _queue.length,
        (i) => i,
      ).where((i) => i != _queueIndex).toList();
      candidates.shuffle();
      next = candidates.first;
    } else if (_repeatAll && next >= _queue.length) {
      next = 0;
    } else if (_repeatAll && next < 0) {
      next = _queue.length - 1;
    } else if (direction > 0 && next >= _queue.length) {
      return;
    } else {
      next = next.clamp(0, _queue.length - 1);
    }

    await _play(_queue[next]);
  }

  Future<void> _toggleShuffle() async {
    _updateState(() => _shuffle = !_shuffle);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_shuffleKey, _shuffle);
  }

  Future<void> _cycleRepeatMode() async {
    _updateState(() {
      if (!_repeatAll && !_repeatOne) {
        _repeatAll = true;
      } else if (_repeatAll) {
        _repeatAll = false;
        _repeatOne = true;
      } else {
        _repeatOne = false;
      }
    });
    await _player.setLoopMode(_repeatOne ? LoopMode.one : LoopMode.off);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_repeatAllKey, _repeatAll);
    await preferences.setBool(_repeatOneKey, _repeatOne);
  }

  Future<void> _toggleFavorite(MusicTrack track) async {
    _updateState(() {
      if (_favorites.contains(track.id)) {
        _favorites.remove(track.id);
      } else {
        _favorites.add(track.id);
      }
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_favoritesKey, _favorites);
  }

  Future<void> _logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_credentialsKey);
    await _player.stop();

    if (!mounted) return;

    _updateState(() {
      _credentials = null;
      _client = null;
      _tracks = List.of(_localTracks);
      _searchResults = [];
      _searchTimer?.cancel();
      _search.clear();
      _queue = [];
      _current = null;
      _queueIndex = 0;
      _connected = false;
      _libraryLoaded = false;
      _libraryError = '';
      _searching = false;
      _searchError = '';
      _showPlayer = false;
      _showLogin = true;
      _password.clear();
      _error = '';
      _tab = AppTab.library;
    });
  }

  Future<void> _savePlaylists() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_playlistsKey, jsonEncode(_playlists));
  }

  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewPlaylistDialog(),
    );

    if (name == null || name.trim().isEmpty) return;

    _updateState(() => _playlists.putIfAbsent(name.trim(), () => []));
    await _savePlaylists();
  }

  Future<void> _addToPlaylist(MusicTrack track) async {
    if (_playlists.isEmpty) {
      await _createPlaylist();
    }

    if (!mounted || _playlists.isEmpty) return;

    final playlists = _playlists.keys.toList(growable: false);
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.surface,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length + 1,
          itemBuilder: (context, index) => index == 0
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Add to playlist',
                    style: TextStyle(fontFamily: 'SyneBold', fontSize: 20),
                  ),
                )
              : ListTile(
                  title: Text(playlists[index - 1]),
                  leading: const Icon(Icons.queue_music_rounded),
                  onTap: () => Navigator.pop(context, playlists[index - 1]),
                ),
        ),
      ),
    );

    if (name == null) return;

    _updateState(() {
      final ids = _playlists[name]!;
      if (!ids.contains(track.id)) ids.add(track.id);
    });

    await _savePlaylists();
  }

  void _showTrackMenu(MusicTrack track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.favorite_border_rounded),
              title: Text('Toggle favorite'),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add_rounded),
              title: Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                _addToPlaylist(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline_rounded),
              title: Text('Open artist'),
              onTap: () {
                Navigator.pop(context);
                _openArtist(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.album_outlined),
              title: Text('Open album'),
              onTap: () {
                Navigator.pop(context);
                _openAlbum(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.thumb_down_outlined),
              title: Text('Show me less like this'),
              onTap: () {
                Navigator.pop(context);
                _dismissRecommendation(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.play_arrow_rounded),
              title: Text('Play now'),
              onTap: () {
                Navigator.pop(context);
                _play(track);
              },
            ),
          ],
        ),
      ),
    );
  }
}
