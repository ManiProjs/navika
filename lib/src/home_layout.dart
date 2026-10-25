part of '../main.dart';

extension _HomeLayoutMethods on _HomeScreenState {
  Widget _topBar({required bool isDesktop, required bool isMacOS}) {
    return Container(
      height: isDesktop ? 54 : 64,
      padding: EdgeInsets.fromLTRB(isMacOS ? 82 : 22, 0, 22, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: C.lime,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _brandLine(12),
                SizedBox(width: 2),
                _brandLine(15),
                SizedBox(width: 2),
                _brandLine(9),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            'navika',
            style: TextStyle(
              fontFamily: 'SyneBold',
              fontSize: 23,
              letterSpacing: -1,
            ),
          ),
          Spacer(),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              hoverColor: C.lime.withValues(alpha: .08),
              splashColor: C.lime.withValues(alpha: .18),
              onTap: () => _selectTab(AppTab.library),
              child: Ink(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: C.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _connected ? C.lime : C.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 7),
                    Text(
                      _connected ? 'NAVIDROME' : 'CONNECT',
                      style: TextStyle(
                        fontFamily: 'DMSansBold',
                        fontSize: 10,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          if (_current != null) ...[
            _iconButton(
              Icons.graphic_eq_rounded,
              tooltip: 'Open player',
              onTap: () => _updateState(() => _showPlayer = true),
            ),
            SizedBox(width: 10),
          ],
          _iconButton(
            Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => _updateState(() => _showSettings = true),
          ),
        ],
      ),
    );
  }

  Widget _brandLine(double height) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: C.black,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _desktopSidebar() {
    return Container(
      width: 252,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: C.border)),
      ),
      padding: EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: C.muted,
                fontFamily: 'DMSansBold',
                fontSize: 10,
                letterSpacing: 1.3,
              ),
            ),
          ),
          for (final tab in AppTab.values)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Material(
                color: _tab == tab ? C.surface2 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectTab(tab),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 22,
                          color: _tab == tab ? C.lime : C.muted,
                        ),
                        SizedBox(width: 14),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontFamily: 'DMSansMedium',
                            fontSize: 14,
                            color: _tab == tab ? C.text : C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Spacer(),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.surface,
              border: Border.all(color: C.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _connected ? C.lime : C.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connected ? 'Server connected' : 'Not connected',
                    style: TextStyle(color: C.muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(
    IconData icon, {
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: C.lime.withValues(alpha: .10),
          splashColor: C.lime.withValues(alpha: .20),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.surface,
              border: Border.all(color: C.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: C.text),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading && !_connected) {
      return Center(child: CircularProgressIndicator(color: C.lime));
    }

    return AnimatedSwitcher(
      duration: _reduceMotion ? Duration.zero : Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(begin: Offset(0, 0.012), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_tab),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 28, 22, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1280),
              child: switch (_tab) {
                AppTab.home => _homePage(),
                AppTab.search => _searchPage(),
                AppTab.library => _libraryPage(),
                AppTab.playlists => _playlistsPage(),
                AppTab.favorites => _favoritesPage(),
                AppTab.stats => _statsPage(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _flowLaunchCard() {
    final available = _modeTracks.isNotEmpty;
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _updateState(() {
          _flowPage = _flowActive ? 1 : 0;
          _showFlow = true;
        }),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: C.lime.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.graphic_eq_rounded, color: C.lime, size: 25),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navika Flow',
                      style: TextStyle(fontFamily: 'DMSansBold', fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      available
                          ? 'A personal listening session that adapts to you.'
                          : 'Load your library to start a personal listening session.',
                      style: TextStyle(
                        color: C.muted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: C.lime, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homePage() {
    if ((_showLocalLibrary && _localTracks.isEmpty) ||
        (!_showLocalLibrary && !_connected && _modeTracks.isEmpty)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your soundtrack\nstarts here.',
            style: TextStyle(
              fontFamily: 'SyneBold',
              fontSize: 42,
              height: 1.12,
              letterSpacing: -2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Import music from your device, or connect a Navidrome server if you use one.',
            style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 26),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _artwork(null, size: 90, seed: 'Navika'),
                SizedBox(height: 18),
                Text(
                  'Your music lives here.',
                  style: TextStyle(fontFamily: 'SyneBold', fontSize: 21),
                ),
                SizedBox(height: 8),
                Text(
                  'Add music files or folders from your device. You can also connect Navidrome if you have a server.',
                  style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
                ),
                SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _actionButton('Add your music', onTap: _importLocalMusic),
                    _actionButton(
                      'Connect to Navidrome',
                      onTap: () => _updateState(() => _showLogin = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_libraryError.isNotEmpty) {
      return _emptyState(
        'Could not load your library',
        _libraryError,
        action: 'Retry',
        onTap: () => _loadLibrary(force: true),
      );
    }

    if (!_libraryLoaded && _loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: C.lime),
              SizedBox(height: 14),
              Text('Loading your music…', style: TextStyle(color: C.muted)),
            ],
          ),
        ),
      );
    }

    if (_libraryLoaded && _modeTracks.isEmpty && !_showLocalLibrary) {
      return _emptyState(
        'No tracks found',
        'Your server connected, but no tracks were returned.',
        action: 'Try again',
        onTap: () => _loadLibrary(force: true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting,
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 42,
            height: 1.12,
            letterSpacing: -2,
          ),
        ),
        SizedBox(height: 18),
        _flowLaunchCard(),
        SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Listen now',
                style: TextStyle(
                  fontFamily: 'SyneBold',
                  fontSize: 25,
                  letterSpacing: -.7,
                ),
              ),
            ),
            _iconButton(
              Icons.tune_rounded,
              tooltip: 'Settings',
              onTap: () => _updateState(() => _showSettings = true),
            ),
          ],
        ),
        SizedBox(height: 14),
        _sectionTitle(
          'Most played albums',
          action: 'See all',
          onAction: () => _selectTab(AppTab.library),
        ),
        if (_libraryLoaded && _mostPlayedAlbums.isNotEmpty)
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(8, _mostPlayedAlbums.length),
              separatorBuilder: (_, _) => SizedBox(width: 14),
              itemBuilder: (context, index) {
                final album = _mostPlayedAlbums[index];
                return SizedBox(
                  width: 148,
                  child: InkWell(
                    onTap: () => _play(album.track),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _artwork(
                          album.track.coverArt,
                          localArtworkPath: album.track.localArtworkPath,
                          size: 148,
                          seed: album.album,
                        ),
                        SizedBox(height: 9),
                        Text(
                          album.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'DMSansBold',
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          album.artist,
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
          )
        else if (!_libraryLoaded)
          _card(
            child: Row(
              children: [
                Icon(Icons.library_music_outlined, color: C.lime, size: 25),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Open Library to load your collection and personalize these sections.',
                    style: TextStyle(color: C.muted, fontSize: 12, height: 1.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Open Library',
                  onPressed: () => _selectTab(AppTab.library),
                  icon: Icon(Icons.arrow_forward_rounded, color: C.lime),
                ),
              ],
            ),
          ),
        _recentlyPlayedShelf(),
        _sectionTitle(
          'Your library at a glance',
          action: 'Browse',
          onAction: () => _selectTab(AppTab.library),
        ),
        Row(
          children: [
            Expanded(
              child: _homeStat(
                _libraryLoaded || _showLocalLibrary
                    ? '${_modeTracks.length}'
                    : '—',
                'TRACKS',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _homeStat(_libraryLoaded ? '$_albumCount' : '—', 'ALBUMS'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _homeStat(
                _libraryLoaded
                    ? '${_modeTracks.map((t) => t.artist).toSet().length}'
                    : '—',
                'ARTISTS',
              ),
            ),
          ],
        ),
        SizedBox(height: 28),
        _sectionTitle('Your artist rotation'),
        if (_mostPlayedArtists.isEmpty)
          Text(
            'Your regular artists will appear after you listen for a while.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mostPlayedArtists.map((artist) {
              final artistTracks = _modeTracks
                  .where(
                    (track) =>
                        track.artist.toLowerCase() ==
                        artist.artist.toLowerCase(),
                  )
                  .toList();
              return ActionChip(
                avatar: Icon(Icons.graphic_eq_rounded, size: 16),
                label: Text('${artist.artist} · ${artist.count} plays'),
                onPressed: artistTracks.isEmpty
                    ? null
                    : () => _play(artist.track, playlist: artistTracks),
                backgroundColor: C.surface,
                side: BorderSide(color: C.border),
                labelStyle: TextStyle(color: C.text, fontSize: 11),
              );
            }).toList(),
          ),
        SizedBox(height: 20),
        _recommendationShelf(
          'Picked for you',
          _recommended(),
          subtitle: _history.isEmpty
              ? 'A discovery mix from your library. It gets smarter as you listen.'
              : 'Ranked from your listening patterns and favorites.',
        ),
        _recommendationShelf(
          'A little different',
          _discoveryTracks(),
          subtitle:
              'Less-recently played tracks from artists you already enjoy.',
        ),
        _recommendationShelf(
          'More from your favorite artists',
          _tracksFromFavoriteArtists(),
        ),
        SizedBox(height: 20),
        _sectionTitle('Your favorites'),
        if (_favoriteTracks.isEmpty)
          Text(
            'Save tracks with the heart in the player to keep them here.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          ..._favoriteTracks
              .take(5)
              .toList()
              .asMap()
              .entries
              .map((entry) => _trackRow(entry.value, entry.key)),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _recentlyPlayedShelf() {
    final seen = <String>{};
    final tracks = _history.reversed
        .map((event) => _tracksById[event.id])
        .whereType<MusicTrack>()
        .where((track) => seen.add(track.id))
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recently played'),
        if (tracks.isEmpty)
          Text(
            'Your recent listens will appear here.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, _) => SizedBox(width: 14),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return SizedBox(
                  width: 126,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _play(track),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _artwork(
                          track.coverArt,
                          localArtworkPath: track.localArtworkPath,
                          size: 126,
                          seed: track.album,
                        ),
                        SizedBox(height: 9),
                        Text(
                          track.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'DMSansMedium',
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
        SizedBox(height: 26),
      ],
    );
  }
}
