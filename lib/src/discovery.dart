part of '../main.dart';

extension _DiscoveryMethods on _HomeScreenState {
  void _invalidateRecommendationCaches() {
    _cachedRecommendedTracks = null;
    _cachedDiscoveryTracks = null;
    _cachedFavoriteArtistTracks = null;
    _cachedRecentlyPlayedTracks = null;
  }

  List<MusicTrack> _discoveryTracks() {
    final cached = _cachedDiscoveryTracks;
    if (cached != null) return cached;
    final playedRecently = _history
        .skip(math.max(0, _history.length - 12))
        .map((event) => event.id)
        .toSet();
    final picks = _recommended()
        .where(
          (track) =>
              !playedRecently.contains(track.id) &&
              !_favorites.contains(track.id),
        )
        .toList();
    if (picks.isNotEmpty) {
      _cachedDiscoveryTracks = picks;
      return picks;
    }
    final fallback = _modeTracks
        .where(
          (track) =>
              track.id != _current?.id &&
              !_dismissedRecommendations.contains(track.id),
        )
        .toList();
    _cachedDiscoveryTracks = fallback;
    return fallback;
  }

  List<MusicTrack> _tracksFromFavoriteArtists() {
    final cached = _cachedFavoriteArtistTracks;
    if (cached != null) return cached;
    final artists = <String, int>{};
    for (final event in _history) {
      artists.update(
        event.artist.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    for (final track in _favoriteTracks) {
      artists.update(
        track.artist.toLowerCase(),
        (count) => count + 3,
        ifAbsent: () => 3,
      );
    }
    final topArtists = artists.keys.toList()
      ..sort((a, b) => artists[b]!.compareTo(artists[a]!));
    final playedRecently = _history
        .skip(math.max(0, _history.length - 8))
        .map((event) => event.id)
        .toSet();
    final picks = _modeTracks
        .where(
          (track) =>
              topArtists.take(5).contains(track.artist.toLowerCase()) &&
              !playedRecently.contains(track.id),
        )
        .toList();
    final result = picks.isNotEmpty ? picks : _recommended();
    _cachedFavoriteArtistTracks = result;
    return result;
  }

  List<MusicTrack> _recentlyPlayedTracks() {
    final cached = _cachedRecentlyPlayedTracks;
    if (cached != null) return cached;
    final seen = <String>{};
    final tracks = _history.reversed
        .map((event) => _tracksById[event.id])
        .whereType<MusicTrack>()
        .where((track) => seen.add(track.id))
        .toList();
    _cachedRecentlyPlayedTracks = tracks;
    return tracks;
  }

  Widget _recommendationShelf(
    String title,
    List<MusicTrack> tracks, {
    String? subtitle,
  }) {
    final picks = tracks
        .where((track) => !_dismissedRecommendations.contains(track.id))
        .take(8)
        .toList();
    if (picks.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title,
          action: 'Play mix',
          onAction: () => _play(picks.first, playlist: picks),
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: C.muted, fontSize: 11)),
        ],
        SizedBox(height: 13),
        SizedBox(
          height: 194,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: picks.length,
            separatorBuilder: (_, _) => SizedBox(width: 14),
            itemBuilder: (context, index) {
              final track = picks[index];
              return SizedBox(
                width: 136,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _play(track, playlist: picks),
                  onLongPress: () => _showTrackMenu(track),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _artwork(
                        track.coverArt,
                        localArtworkPath: track.localArtworkPath,
                        size: 136,
                        seed: track.album,
                      ),
                      SizedBox(height: 8),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'DMSansBold',
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: C.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _searchPage() {
    final results = _searchResults.take(30).toList(growable: false);
    final hasResults =
        !_searching &&
        _searchError.isEmpty &&
        _search.text.trim().isNotEmpty &&
        results.isNotEmpty;
    final Widget status;
    if (!_connected && _localTracks.isEmpty && _searchResults.isEmpty) {
      status = _emptyState(
        'Add music to search',
        'Import audio files or a music folder to search your local library.',
        action: 'Add music',
        onTap: _importLocalMusic,
      );
    } else if (_searchError.isNotEmpty) {
      status = _emptyState(
        'Search unavailable',
        _searchError,
        action: 'Retry search',
        onTap: () => _runSearch(_search.text),
      );
    } else if (_searching) {
      status = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: C.lime),
        ),
      );
    } else if (_search.text.trim().isEmpty) {
      status = _emptyState(
        'Start typing to search',
        _connected
            ? 'Search your Navidrome library.'
            : 'Search your imported local music.',
      );
    } else {
      status = _emptyState('No results found', 'Try a different search.');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
      itemCount: 5 + (hasResults ? results.length : 1),
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return const Text(
              'Find your music',
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
                'Search your tracks, artists, and albums.',
                style: TextStyle(color: C.muted, fontSize: 13),
              ),
            );
          case 2:
            return const SizedBox(height: 22);
          case 3:
            return TextField(
              controller: _search,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search your library',
                prefixIcon: Icon(Icons.search_rounded, color: C.muted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          _runSearch('');
                        },
                        icon: Icon(Icons.close_rounded, color: C.muted),
                      ),
              ),
            );
          case 4:
            return const SizedBox(height: 20);
          default:
            if (!hasResults) return status;
            final resultIndex = index - 5;
            return _trackRow(results[resultIndex], resultIndex);
        }
      },
    );
  }

  Widget _libraryPage() {
    final libraryTracks = _visibleLibraryTracks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your library',
                    style: TextStyle(
                      fontFamily: 'SyneBold',
                      fontSize: 35,
                      letterSpacing: -1.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _showLocalLibrary
                        ? 'Music files imported from this device.'
                        : 'Music streamed from your Navidrome server.',
                    style: TextStyle(color: C.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Add local music',
              onPressed: _importLocalMusic,
              icon: Icon(Icons.library_add_rounded, color: C.lime),
            ),
            IconButton(
              tooltip: 'Add a music folder',
              onPressed: _importLocalFolder,
              icon: Icon(Icons.create_new_folder_outlined, color: C.lime),
            ),
            if (!_connected && _localTracks.isNotEmpty)
              IconButton(
                tooltip: 'Connect Navidrome',
                onPressed: () => _updateState(() => _showLogin = !_showLogin),
                icon: Icon(Icons.dns_outlined, color: C.lime),
              ),
            if (_connected)
              IconButton(
                tooltip: 'Disconnect server',
                onPressed: _logout,
                icon: Icon(Icons.logout_rounded, color: C.muted),
              ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _updateState(() {
                _showLocalLibrary = !_showLocalLibrary;
                _showLogin = false;
                _searchResults = [];
                _searching = false;
                _searchError = '';
              });
              unawaited(_saveLibrarySourcePreference());
              if (!_showLocalLibrary && _connected && !_libraryLoaded) {
                unawaited(_loadLibrary());
              }
              if (_tab == AppTab.search && _search.text.trim().isNotEmpty) {
                _runSearch(_search.text);
              }
            },
            icon: Icon(
              _showLocalLibrary ? Icons.dns_outlined : Icons.folder_outlined,
              size: 18,
            ),
            label: Text(
              'Switch to ${_showLocalLibrary ? 'Navidrome' : 'local music'}',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.lime,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _selectTab(AppTab.favorites),
              icon: Icon(Icons.favorite_rounded, size: 17),
              label: Text('Liked songs'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.lime,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _selectTab(AppTab.stats),
              icon: Icon(Icons.bar_chart_rounded, size: 17),
              label: Text('Listening stats'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.text,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        SizedBox(height: 18),
        if (_showLocalLibrary && libraryTracks.isEmpty)
          _emptyState(
            'No local music yet',
            'Import audio files or choose a folder. Your Navidrome library stays separate.',
            action: 'Add music',
            onTap: _importLocalMusic,
          )
        else if (!_showLocalLibrary && !_connected)
          _loginCard()
        else if (_loading && !_showLocalLibrary)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: C.lime),
            ),
          )
        else if (libraryTracks.isEmpty)
          _emptyState(
            _showLocalLibrary ? 'No local music yet' : 'No Navidrome tracks',
            _showLocalLibrary
                ? 'Import audio files or choose a folder.'
                : 'Refresh your server library or switch to local music.',
            action: _showLocalLibrary ? 'Add music' : 'Refresh library',
            onTap: _showLocalLibrary
                ? _importLocalMusic
                : () => _loadLibrary(force: true),
          )
        else ...[
          _recommendationShelf('Recently played', _recentlyPlayedTracks()),
          _recommendationShelf(
            'Picked for you',
            _recommended(),
            subtitle: 'A mix shaped by your listening and favorites.',
          ),
          _recommendationShelf('A little different', _discoveryTracks()),
          _recommendationShelf(
            'More from your favorite artists',
            _tracksFromFavoriteArtists(),
          ),
          if (!_showLocalLibrary && _connected) ...[
            SizedBox(height: 8),
            _actionButton('Refresh library', onTap: _loadLibrary),
          ],
        ],
      ],
    );
  }

  Widget _loginCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _artwork(null, size: 48, seed: 'Navidrome'),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navidrome',
                      style: TextStyle(fontFamily: 'DMSansBold', fontSize: 20),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Connect to your music server',
                      style: TextStyle(color: C.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _fieldLabel('SERVER URL'),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            autofillHints: const [AutofillHints.url],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://music.example.com',
            ),
          ),
          SizedBox(height: 14),
          _fieldLabel('USERNAME'),
          TextField(
            controller: _username,
            keyboardType: TextInputType.text,
            autocorrect: false,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'Your Navidrome username',
            ),
          ),
          SizedBox(height: 14),
          _fieldLabel('PASSWORD'),
          TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Your password',
            ),
            onSubmitted: (_) => _connect(),
          ),
          _credentialStorageWarning(),
          if (Platform.isIOS || Platform.isMacOS) SizedBox(height: 12),
          if (_error.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(_error, style: TextStyle(color: C.danger, fontSize: 12)),
          ],
          SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _busy ? null : _connect,
              style: FilledButton.styleFrom(
                backgroundColor: C.lime,
                foregroundColor: C.black,
                disabledBackgroundColor: C.lime.withValues(alpha: .65),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.black,
                      ),
                    )
                  : Text(
                      'Connect to Navidrome ↗',
                      style: TextStyle(fontFamily: 'DMSansBold', fontSize: 13),
                    ),
            ),
          ),
          SizedBox(height: 13),
        ],
      ),
    );
  }
}
