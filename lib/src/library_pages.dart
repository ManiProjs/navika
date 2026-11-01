part of '../main.dart';

extension _LibraryPageMethods on _HomeScreenState {
  Widget _playlistsPage() {
    final allTracksById = _allTracksById;
    final smartPlaylists = _smartPlaylists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your playlists',
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 35,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Build collections for every mood, saved on this device.',
          style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
        ),
        SizedBox(height: 22),
        if (_modeTracks.isEmpty)
          _emptyState(
            'Add music to make playlists',
            'Import local audio files or a music folder, then create playlists from your collection.',
            action: 'Add music',
            onTap: _importLocalMusic,
          )
        else ...[
          if (smartPlaylists.isNotEmpty) ...[
            Text(
              'SMART PLAYLISTS',
              style: TextStyle(
                color: C.muted,
                fontFamily: 'DMSansBold',
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 10),
            ...smartPlaylists.map((playlist) {
              void play() =>
                  _play(playlist.tracks.first, playlist: playlist.tracks);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: play,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(playlist.icon, color: C.lime, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.title,
                                  style: TextStyle(
                                    fontFamily: 'DMSansBold',
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '${playlist.description} · ${playlist.tracks.length} tracks',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Play ${playlist.title}',
                            onPressed: play,
                            icon: Icon(Icons.play_arrow_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _createPlaylist,
              icon: Icon(Icons.add_rounded),
              label: Text('Create playlist'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.lime,
                side: BorderSide(color: C.border),
                padding: EdgeInsets.all(15),
              ),
            ),
          ),
          SizedBox(height: 18),
          if (_playlists.isEmpty)
            _emptyState(
              'Your playlists start here',
              'Create a playlist and add tracks from your library.',
            )
          else
            ..._playlists.entries.map((entry) {
              final tracks = entry.value
                  .map((id) => allTracksById[id])
                  .whereType<MusicTrack>()
                  .toList();
              final visibleTracks = _expandedPlaylists.contains(entry.key)
                  ? tracks
                  : tracks.take(20).toList();
              final totalSeconds = tracks.fold<int>(
                0,
                (total, track) => total + track.duration,
              );

              return Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            color: C.lime,
                            size: 26,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontFamily: 'DMSansBold',
                                fontSize: 15,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Rename playlist',
                            onPressed: () => _renamePlaylist(entry.key),
                            icon: Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Play playlist',
                            onPressed: tracks.isEmpty
                                ? null
                                : () => _play(tracks.first, playlist: tracks),
                            icon: Icon(Icons.play_arrow_rounded),
                          ),
                          IconButton(
                            tooltip: 'Shuffle playlist',
                            onPressed: tracks.length < 2
                                ? null
                                : () {
                                    final shuffled = tracks.toList()..shuffle();
                                    _play(shuffled.first, playlist: shuffled);
                                  },
                            icon: Icon(Icons.shuffle_rounded),
                          ),
                          IconButton(
                            tooltip: 'Duplicate playlist',
                            onPressed: () => _duplicatePlaylist(entry.key),
                            icon: Icon(Icons.copy_rounded),
                          ),
                          IconButton(
                            tooltip: 'Delete playlist',
                            onPressed: () => _deletePlaylist(entry.key),
                            icon: Icon(Icons.close_rounded, color: C.muted),
                          ),
                        ],
                      ),
                      Text(
                        '${tracks.length} tracks · ${_formatTime(totalSeconds.toDouble())}',
                        style: TextStyle(color: C.muted, fontSize: 11),
                      ),
                      if (tracks.isNotEmpty) ...[
                        SizedBox(height: 12),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: visibleTracks.length,
                          onReorderItem: (oldIndex, newIndex) =>
                              _reorderPlaylistTracks(
                                entry.key,
                                visibleTracks,
                                oldIndex,
                                newIndex,
                              ),
                          itemBuilder: (context, index) => KeyedSubtree(
                            key: ValueKey(visibleTracks[index].id),
                            child: _playlistTrackRow(
                              entry.key,
                              visibleTracks[index],
                              index,
                              reorderIndex: index,
                            ),
                          ),
                        ),
                        if (tracks.length > 20)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => _updateState(() {
                                if (!_expandedPlaylists.add(entry.key)) {
                                  _expandedPlaylists.remove(entry.key);
                                }
                              }),
                              child: Text(
                                _expandedPlaylists.contains(entry.key)
                                    ? 'Show fewer tracks'
                                    : 'Show all ${tracks.length} tracks',
                              ),
                            ),
                          ),
                      ],
                      SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _chooseTrackForPlaylist(entry.key),
                        icon: Icon(Icons.add_rounded, size: 18),
                        label: Text('Add tracks'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  Future<void> _duplicatePlaylist(String name) async {
    final source = _playlists[name];
    if (source == null) return;
    var copyName = '$name (copy)';
    var suffix = 2;
    while (_playlists.containsKey(copyName)) {
      copyName = '$name (copy $suffix)';
      suffix++;
    }
    _updateState(() => _playlists[copyName] = List<String>.of(source));
    await _savePlaylists();
  }

  Future<void> _deletePlaylist(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Delete playlist?'),
        content: Text(
          '“$name” will be removed. Your music files will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _updateState(() {
      _playlists.remove(name);
      _expandedPlaylists.remove(name);
    });
    await _savePlaylists();
  }

  Future<void> _reorderPlaylistTracks(
    String playlist,
    List<MusicTrack> visibleTracks,
    int oldIndex,
    int newIndex,
  ) async {
    final ids = _playlists[playlist];
    if (ids == null || oldIndex < 0 || oldIndex >= visibleTracks.length) {
      return;
    }
    final reorderedVisible = visibleTracks.map((track) => track.id).toList();
    final moved = reorderedVisible.removeAt(oldIndex);
    reorderedVisible.insert(
      newIndex.clamp(0, reorderedVisible.length).toInt(),
      moved,
    );
    var visibleIndex = 0;
    _updateState(() {
      for (var index = 0; index < ids.length; index++) {
        if (reorderedVisible.contains(ids[index]) &&
            visibleTracks.any((track) => track.id == ids[index])) {
          ids[index] = reorderedVisible[visibleIndex++];
        }
      }
    });
    await _savePlaylists();
  }

  Future<void> _renamePlaylist(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Rename playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName == oldName || !mounted) return;
    if (_playlists.containsKey(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A playlist with that name already exists.')),
      );
      return;
    }
    _updateState(() {
      final tracks = _playlists.remove(oldName);
      if (tracks != null) _playlists[newName] = tracks;
    });
    await _savePlaylists();
  }

  Future<void> _chooseTrackForPlaylist(String playlist) async {
    final tracks = await showModalBottomSheet<List<MusicTrack>>(
      context: context,
      backgroundColor: C.surface,
      isScrollControlled: true,
      builder: (_) => _PlaylistTrackPicker(
        tracks: _modeTracks,
        existingIds: _playlists[playlist]!.toSet(),
        artwork: (track) => _artwork(
          track.coverArt,
          localArtworkPath: track.localArtworkPath,
          size: 42,
          seed: track.album,
        ),
      ),
    );

    if (tracks == null || tracks.isEmpty || !mounted) return;

    _updateState(() {
      final ids = _playlists[playlist]!;
      for (final track in tracks) {
        if (!ids.contains(track.id)) ids.add(track.id);
      }
    });

    await _savePlaylists();
  }

  Widget _playlistTrackRow(
    String playlist,
    MusicTrack track,
    int index, {
    int? reorderIndex,
  }) {
    final active = _current?.id == track.id;
    return InkWell(
      onTap: () => _play(
        track,
        playlist: _playlists[playlist]!
            .map((id) => _allTracksById[id])
            .whereType<MusicTrack>()
            .toList(),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                active ? '♫' : '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? C.lime : C.muted,
                  fontFamily: 'DMSansMedium',
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(width: 10),
            _artwork(
              track.coverArt,
              localArtworkPath: track.localArtworkPath,
              size: 46,
              seed: track.album,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? C.lime : C.text,
                      fontFamily: 'DMSansMedium',
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${track.artist} · ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: C.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(
              _formatTime(track.duration.toDouble()),
              style: TextStyle(color: C.muted, fontSize: 10),
            ),
            if (reorderIndex != null)
              ReorderableDragStartListener(
                index: reorderIndex,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: C.muted,
                    size: 20,
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Remove from playlist',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                _updateState(() => _playlists[playlist]!.remove(track.id));
                await _savePlaylists();
              },
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                size: 20,
                color: C.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoritesPage() {
    final favorites = _favoriteTracks;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
      itemCount: favorites.isEmpty ? 4 : favorites.length + 3,
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return const Text(
              'Your favorites',
              style: TextStyle(
                fontFamily: 'SyneBold',
                fontSize: 35,
                letterSpacing: -1.5,
              ),
            );
          case 1:
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The tracks you saved with a heart.',
                style: TextStyle(color: C.muted, fontSize: 13),
              ),
            );
          case 2:
            return const SizedBox(height: 22);
          default:
            if (favorites.isEmpty) {
              return _emptyState(
                'No favorites yet',
                'Play a track and tap the heart in the full-screen player to save it here.',
              );
            }
            final trackIndex = index - 3;
            return _trackRow(favorites[trackIndex], trackIndex);
        }
      },
    );
  }

  Widget _statsPage() {
    final albums = _albumCount;
    final artists = _modeTracks.map((track) => track.artist).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your listening',
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 35,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'A little snapshot of your music world, stored locally.',
          style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
        ),
        SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 900 ? 3 : 2;
            final cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _statCard(
                  '${_modeTracks.length}',
                  'TRACKS IN LIBRARY',
                  width: cardWidth,
                ),
                _statCard('$albums', 'ALBUMS', width: cardWidth),
                _statCard('$artists', 'ARTISTS', width: cardWidth),
                _statCard(
                  '${_history.length}',
                  'RECORDED PLAYS',
                  width: cardWidth,
                ),
                _statCard(
                  '${_favorites.length}',
                  'FAVORITES',
                  width: cardWidth,
                ),
              ],
            );
          },
        ),
        SizedBox(height: 28),
        _sectionTitle('Most played albums'),
        if (_mostPlayedAlbums.isEmpty)
          Text(
            'Your most-played albums will appear after you start listening.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          ..._mostPlayedAlbums
              .take(5)
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _artwork(
                    item.track.coverArt,
                    localArtworkPath: item.track.localArtworkPath,
                    size: 44,
                    seed: item.album,
                  ),
                  title: Text(
                    item.album,
                    style: TextStyle(fontFamily: 'DMSansMedium'),
                  ),
                  subtitle: Text(
                    item.artist,
                    style: TextStyle(color: C.muted, fontSize: 11),
                  ),
                  trailing: Text(
                    '${item.count} plays',
                    style: TextStyle(color: C.lime, fontSize: 10),
                  ),
                  onTap: () => _play(item.track),
                ),
              ),
      ],
    );
  }
}
