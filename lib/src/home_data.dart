part of '../main.dart';

extension _HomeDataMethods on _HomeScreenState {
  String _describePlaybackError(Object error) {
    final details = error.toString();
    final normalized = details.toLowerCase();

    if (normalized.contains('cleartext') ||
        normalized.contains('clear text traffic')) {
      return 'Android blocked the HTTP audio stream. Rebuild and reinstall Navika with the latest version, then try again.';
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('network is unreachable')) {
      return 'Could not reach the music server. Check that your device is connected to the same network and the server is online.';
    }
    if (normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('unauthorized') ||
        normalized.contains('forbidden')) {
      return 'The server rejected the audio request. Check your Navidrome login and server permissions.';
    }
    if (normalized.contains('404') || normalized.contains('not found')) {
      return 'This track could not be found on the server. Refresh your library and try another track.';
    }
    if (normalized.contains('timeout') || normalized.contains('timed out')) {
      return 'The audio request timed out. Check your connection and try again.';
    }
    if (normalized.contains('format') ||
        normalized.contains('decoder') ||
        normalized.contains('unsupported')) {
      return 'Navika could not decode this audio format. Try another track or check the file on your server.';
    }

    return 'Playback failed: $details';
  }

  Future<void> _advanceAfterCompletion() async {
    if (_handlingCompletion ||
        _repeatOne ||
        _queue.isEmpty ||
        (!_autoAdvance && !_repeatAll)) {
      return;
    }
    _handlingCompletion = true;
    try {
      if (_shuffle && _queue.length > 1) {
        await _skip(1);
      } else if (_queueIndex < _queue.length - 1) {
        await _skip(1);
      } else if (_repeatAll) {
        await _play(_queue.first);
      }
    } finally {
      _handlingCompletion = false;
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning.';
    if (hour >= 12 && hour < 17) return 'Good afternoon.';
    if (hour >= 17 && hour < 21) return 'Good evening.';
    return 'Good night.';
  }

  Map<String, MusicTrack> get _tracksById {
    final tracks = _modeTracks;
    if (identical(_cachedTracksByIdSource, tracks) &&
        _cachedTracksById != null) {
      return _cachedTracksById!;
    }
    _cachedTracksByIdSource = tracks;
    _cachedTracksById = {for (final track in tracks) track.id: track};
    _cachedFavoriteTracks = null;
    return _cachedTracksById!;
  }

  List<MusicTrack> get _modeTracks {
    if (identical(_cachedModeSource, _tracks) &&
        identical(_cachedLocalSource, _localTracks) &&
        _cachedModeIsLocal == _showLocalLibrary &&
        _cachedModeTracks != null) {
      return _cachedModeTracks!;
    }
    _cachedModeSource = _tracks;
    _cachedLocalSource = _localTracks;
    _cachedModeIsLocal = _showLocalLibrary;
    _cachedModeTracks = _showLocalLibrary
        ? _mergeLibraryTracks(_localTracks)
        : _mergeLibraryTracks(_tracks.where((track) => !track.isLocal));
    _cachedTracksById = null;
    _cachedTracksByIdSource = null;
    _cachedFavoriteTracks = null;
    _invalidateRecommendationCaches();
    _flowQueueDirty = true;
    return _cachedModeTracks!;
  }

  List<MusicTrack> _mergeLibraryTracks(Iterable<MusicTrack> tracks) {
    final unique = <String, MusicTrack>{};
    for (final track in tracks) {
      if (track.id.isNotEmpty) unique[track.id] = track;
    }
    return unique.values.toList()..sort((a, b) {
      final artistOrder = a.artist.toLowerCase().compareTo(
        b.artist.toLowerCase(),
      );
      if (artistOrder != 0) return artistOrder;
      final albumOrder = a.album.toLowerCase().compareTo(b.album.toLowerCase());
      if (albumOrder != 0) return albumOrder;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  int get _albumCount => _modeTracks
      .map(
        (track) =>
            '${track.album.trim().toLowerCase()}::${track.artist.trim().toLowerCase()}',
      )
      .toSet()
      .length;

  List<MusicTrack> get _visibleLibraryTracks => _modeTracks;

  List<MusicTrack> get _favoriteTracks => _cachedFavoriteTracks ??= _favorites
      .map((id) => _tracksById[id])
      .whereType<MusicTrack>()
      .toList();

  void _selectTab(AppTab tab) {
    _updateState(() {
      _tab = tab;
      if (tab == AppTab.library && !_connected && _localTracks.isEmpty) {
        _showLogin = true;
      }
    });
    if (tab == AppTab.library && _connected && !_libraryLoaded) {
      unawaited(_loadLibrary());
    }
  }

  Future<void> _saveLibrarySourcePreference() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_librarySourceKey, _showLocalLibrary);
  }

  bool get _shouldHandleSystemBack =>
      _showFlow ||
      _showVisualizer ||
      _showUpNext ||
      _showPlayer ||
      _showSettings ||
      _showLogin ||
      _tab != AppTab.home;

  void _handleSystemBack() {
    if (_showFlow) {
      _updateState(() {
        if (_flowActive) {
          _showFlow = false;
        } else if (_flowPage > 0) {
          _flowPage = 0;
        } else {
          _showFlow = false;
        }
      });
    } else if (_showVisualizer) {
      _updateState(() => _showVisualizer = false);
    } else if (_showUpNext) {
      _updateState(() => _showUpNext = false);
    } else if (_showPlayer) {
      _updateState(() => _showPlayer = false);
    } else if (_showSettings) {
      _updateState(() => _showSettings = false);
    } else if (_showLogin) {
      _updateState(() => _showLogin = false);
    } else if (_tab != AppTab.home) {
      _selectTab(AppTab.home);
    }
  }

  void _runSearch(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    final requestId = ++_searchRequestId;
    if (query.isEmpty) {
      _updateState(() {
        _searchResults = [];
        _searching = false;
        _searchError = '';
      });
      return;
    }
    if (_showLocalLibrary || !_connected || _client == null) {
      final normalized = query.toLowerCase();
      _updateState(() {
        _searchResults =
            (_showLocalLibrary ? _localTracks : const <MusicTrack>[])
                .where(
                  (track) =>
                      track.title.toLowerCase().contains(normalized) ||
                      track.artist.toLowerCase().contains(normalized) ||
                      track.album.toLowerCase().contains(normalized),
                )
                .toList();
        _searching = false;
        _searchError = '';
      });
      return;
    }

    _updateState(() {
      _searching = true;
      _searchError = '';
    });
    _searchTimer = Timer(Duration(milliseconds: 300), () async {
      try {
        final results = await _client!.searchTracks(query);
        if (!mounted || requestId != _searchRequestId) return;
        _updateState(() {
          final normalized = query.toLowerCase();
          _searchResults = _showLocalLibrary
              ? _localTracks
                    .where(
                      (track) =>
                          track.title.toLowerCase().contains(normalized) ||
                          track.artist.toLowerCase().contains(normalized) ||
                          track.album.toLowerCase().contains(normalized),
                    )
                    .toList()
              : results.where((track) => !track.isLocal).toList();
          _searching = false;
        });
      } catch (error) {
        if (!mounted || requestId != _searchRequestId) return;
        _updateState(() {
          _searchResults = [];
          _searching = false;
          _searchError = 'Search failed: $error';
        });
      }
    });
  }

  List<({String album, String artist, int count, MusicTrack track})>
  get _mostPlayedAlbums {
    final result =
        <
          String,
          ({String album, String artist, int count, MusicTrack track})
        >{};

    for (final event in _history) {
      final track = _tracksById[event.id];
      if (track == null) continue;

      final key = '${event.album}::${event.artist}';
      final previous = result[key];

      result[key] = (
        album: event.album,
        artist: event.artist,
        count: (previous?.count ?? 0) + 1,
        track: track,
      );
    }

    final albums = result.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return albums.take(10).toList();
  }

  List<({String artist, int count, MusicTrack track})> get _mostPlayedArtists {
    final result = <String, ({String artist, int count, MusicTrack track})>{};
    for (final event in _history) {
      final track = _tracksById[event.id];
      if (track == null) continue;
      final key = event.artist.toLowerCase();
      final previous = result[key];
      result[key] = (
        artist: event.artist,
        count: (previous?.count ?? 0) + 1,
        track: previous?.track ?? track,
      );
    }
    final artists = result.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return artists.take(5).toList();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final restoreWarnings = <String>[];

    _reduceMotion = preferences.getBool(_motionKey) ?? false;
    final savedTheme = preferences.getString(_themeKey);
    _themeMode.value = NavikaTheme.values.firstWhere(
      (theme) => theme.name == savedTheme,
      orElse: () => NavikaTheme.dark,
    );
    _autoAdvance = preferences.getBool(_autoAdvanceKey) ?? true;
    _showLocalLibrary = preferences.getBool(_librarySourceKey) ?? false;
    _showVisualizer = preferences.getBool(_visualizerKey) ?? false;
    _shuffle = preferences.getBool(_shuffleKey) ?? false;
    _repeatAll = preferences.getBool(_repeatAllKey) ?? false;
    _repeatOne = preferences.getBool(_repeatOneKey) ?? false;
    _playbackSpeed = preferences.getDouble(_speedKey) ?? 1.0;
    final savedTaste = preferences.getString(_tasteProfileKey);
    if (savedTaste != null) {
      try {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(savedTaste) as Map,
        );
        // Older builds incorrectly turned song feedback into artist feedback.
        // Ignore that legacy map so disliking one song never penalizes its artist.
        _tasteArtistFeedback.clear();
        _tasteTrackFeedback
          ..clear()
          ..addAll(
            Map<String, dynamic>.from(decoded['tracks'] as Map? ?? {}).map(
              (key, value) =>
                  MapEntry(key, (value as num).toInt().clamp(-2, 2).toInt()),
            ),
          );
      } catch (_) {
        await preferences.remove(_tasteProfileKey);
      }
    }
    final savedFolders = preferences.getStringList(_localFoldersKey) ?? [];
    // Older Android builds stored filesystem paths, but scoped storage does
    // not grant access to those paths. Only SAF tree URIs are valid on Android.
    _localFolders = Platform.isAndroid
        ? savedFolders.where((folder) => folder.startsWith('saf:')).toList()
        : savedFolders;
    if (_localFolders.length != savedFolders.length) {
      await preferences.setStringList(_localFoldersKey, _localFolders);
    }
    final savedLocalTracks = preferences.getString(_localTracksKey);
    if (savedLocalTracks != null) {
      try {
        _localTracks = (jsonDecode(savedLocalTracks) as List)
            .map(
              (item) =>
                  MusicTrack.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .where((track) => track.isLocal)
            .toList();
        _tracks = List.of(_localTracks);
        // Local files can be browsed immediately, but do not mark the remote
        // library as loaded: saved Navidrome credentials still need a fetch.
        _libraryLoaded = false;
      } catch (_) {
        await preferences.remove(_localTracksKey);
      }
    }
    if (_localFolders.isNotEmpty) {
      // Refresh watched folders before showing the library. The picker grants
      // access to user-selected locations; if a location is no longer
      // accessible, the scan preserves its previously indexed tracks.
      // Do not compete with the first few frames for disk and SAF-provider I/O.
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        unawaited(_scanLocalFolders());
      });
    }
    _dismissedRecommendations.addAll(
      preferences.getStringList(_recommendationFeedbackKey) ?? const [],
    );
    _flowHiddenTrackIds.addAll(
      preferences.getStringList(_flowHiddenTracksKey) ?? const [],
    );
    final savedQueue = preferences.getString(_queueKey);
    if (savedQueue != null) {
      try {
        _queue = (jsonDecode(savedQueue) as List)
            .map(
              (item) =>
                  MusicTrack.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .where((track) => track.id.isNotEmpty)
            .toList();
      } catch (_) {
        await preferences.remove(_queueKey);
      }
    }

    final history = preferences.getString(_historyKey);
    if (history != null) {
      try {
        _history = (jsonDecode(history) as List)
            .map(
              (item) => ListeningEvent.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      } catch (_) {
        restoreWarnings.add(
          'Saved listening history was invalid and has been reset.',
        );
        await preferences.remove(_historyKey);
      }
    }

    _favorites = (preferences.getStringList(_favoritesKey) ?? []).toSet();
    _invalidateRecommendationCaches();
    _flowQueueDirty = true;

    final savedPlaylists = preferences.getString(_playlistsKey);
    if (savedPlaylists != null) {
      try {
        final decoded = jsonDecode(savedPlaylists) as Map<String, dynamic>;
        _playlists = decoded.map(
          (key, value) => MapEntry(key, List<String>.from(value as List)),
        );
      } catch (_) {
        restoreWarnings.add(
          'A saved playlist could not be read. Invalid playlist data was reset.',
        );
        await preferences.remove(_playlistsKey);
      }
    }

    // Credentials live in ordinary local preferences so desktop builds do not
    // require Keychain access or a paid Developer ID signing identity.
    final saved = preferences.getString(_credentialsKey);
    if (saved == null) {
      if (mounted) {
        _updateState(() {
          _showLogin = true;
          _error = restoreWarnings.join(' ');
        });
      }
      return;
    }

    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      final credentials = NavidromeCredentials.fromJson(json);
      _url.text = credentials.baseUrl;
      _username.text = credentials.username;

      final client = NavidromeClient(credentials);
      await client.connect();

      if (!mounted) return;

      _updateState(() {
        _credentials = credentials;
        _client = client;
        _connected = true;
        _error = restoreWarnings.join(' ');
      });

      // Home recommendations and library stats depend on the track list.
      // Load it during startup instead of waiting for the user to visit Library.
      unawaited(_loadLibrary());

      if (mounted && restoreWarnings.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(restoreWarnings.join(' '))));
      }
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
        _connected = false;
        _showLogin = true;
        _error = 'Reconnect to your Navidrome server to continue.';
      });
    }

    if (mounted) _updateState(() {});
  }

  Future<void> _connect() async {
    final url = _url.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final username = _username.text.trim();
    final password = _password.text;

    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      _updateState(
        () => _error =
            'Enter a complete server URL, including http:// or https://.',
      );
      return;
    }

    if (username.isEmpty || password.isEmpty) {
      _updateState(
        () => _error = 'Enter your Navidrome username and password.',
      );
      return;
    }

    _updateState(() {
      _busy = true;
      _error = '';
    });

    try {
      final credentials = NavidromeCredentials(
        baseUrl: url,
        username: username,
        password: password,
      );

      final client = NavidromeClient(credentials);
      await client.connect();

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _credentialsKey,
        jsonEncode(credentials.toJson()),
      );

      if (!mounted) return;

      _updateState(() {
        _credentials = credentials;
        _client = client;
        _tracks = List.of(_localTracks);
        _queue = [];
        _queueIndex = 0;
        _queueIndexNotifier.value = 0;
        _connected = true;
        _libraryLoaded = false;
        _libraryError = '';
        _showLogin = false;
        _busy = false;
        _password.clear();
      });
      // Home also depends on the library for its recommendations and stats.
      unawaited(_loadLibrary());
    } catch (error) {
      if (!mounted) return;
      _updateState(() {
        _busy = false;
        _connected = false;
        _error = 'Connection failed: $error';
      });
    }
  }

  Future<void> _loadLibrary({bool force = false}) async {
    final client = _client;
    if (client == null || (_libraryLoaded && !force) || _loading) return;

    _updateState(() {
      _loading = true;
      _libraryError = '';
    });

    try {
      final tracks = await client.getLibraryTracks();
      if (!mounted) return;

      _updateState(() {
        _tracks = _mergeLibraryTracks([...tracks, ..._localTracks]);
        if (_queue.isEmpty) _queue = tracks;
        _libraryLoaded = true;
        _loading = false;
        _connected = true;
      });
    } catch (error) {
      if (!mounted) return;
      _updateState(() {
        _loading = false;
        _libraryError = 'Could not load your music: $error';
      });
    }
  }

  Future<void> _importLocalMusic() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (files.isEmpty || !mounted) return;

      final imported = <MusicTrack>[];
      for (final file in files) {
        final path = file.path;
        if (path == null || path.isEmpty) continue;
        imported.add(await _localTrackFromPath(path));
      }
      if (!mounted) return;
      if (imported.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No readable audio files were selected.')),
        );
        return;
      }

      final merged = <String, MusicTrack>{
        for (final track in _localTracks) track.id: track,
        for (final track in imported) track.id: track,
      };
      final localTracks = merged.values.toList();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _localTracksKey,
        jsonEncode(localTracks.map((track) => track.toJson()).toList()),
      );
      if (!mounted) return;
      _updateState(() {
        _localTracks = localTracks;
        _tracks = _mergeLibraryTracks([
          ..._tracks.where((track) => !track.isLocal),
          ...localTracks,
        ]);
        _libraryLoaded = true;
        _showLogin = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${imported.length} local track(s).')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not import music: $error')));
    }
  }

  Future<void> _importLocalFolder() async {
    try {
      String? normalized;
      if (Platform.isAndroid) {
        final selected = await _androidLocalFolders
            .invokeMapMethod<String, dynamic>('pickFolder');
        final uri = selected?['uri'] as String?;
        if (uri == null || uri.isEmpty || !mounted) return;
        normalized = 'saf:$uri';
      } else {
        final folder = await FilePicker.getDirectoryPath(
          dialogTitle: 'Choose a folder containing music',
        );
        if (folder == null || folder.isEmpty || !mounted) return;
        normalized = folder.replaceFirst(RegExp(r'[/\\]+$'), '');
      }
      // Drop legacy Android filesystem paths when adding a SAF folder. Keeping
      // them causes Directory.list() to throw Permission denied on every scan.
      final existingFolders = Platform.isAndroid
          ? _localFolders.where((folder) => folder.startsWith('saf:'))
          : _localFolders;
      final folders = {...existingFolders, normalized}.toList();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_localFoldersKey, folders);
      if (!mounted) return;
      _updateState(() => _localFolders = folders);
      await _scanLocalFolders(showFeedback: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add music folder: $error')),
      );
    }
  }

  Future<void> _removeLocalFolder(String folder) async {
    final folders = _localFolders.where((item) => item != folder).toList();
    // SAF-copied tracks have cache paths rather than their original URI. Clear
    // their indexed entries, then repopulate from any remaining watched folders.
    final localTracks = _localTracks
        .where(
          (track) => !(track.localPath ?? '').contains('/navika_imported/'),
        )
        .toList();
    final merged = _mergeLibraryTracks([
      ..._tracks.where((track) => !track.isLocal),
      ...localTracks,
    ]);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_localFoldersKey, folders);
    await preferences.setString(
      _localTracksKey,
      jsonEncode(localTracks.map((track) => track.toJson()).toList()),
    );
    if (!mounted) return;
    _updateState(() {
      _localFolders = folders;
      _localTracks = localTracks;
      _tracks = merged;
    });
    unawaited(_scanLocalFolders());
  }

  String _folderDisplayName(String folder) {
    if (folder.startsWith('saf:')) {
      final uri = Uri.tryParse(folder.substring(4));
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
      return 'Android folder';
    }
    final parts = folder
        .split(RegExp(r'[/\\]'))
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? folder : parts.last;
  }

  bool _isAudioFile(String path) => RegExp(
    r'\.(mp3|m4a|m4b|m4p|aac|adts|wav|wave|bwf|flac|ogg|oga|opus|aiff|aif|alac|ape|wv|mp4|3gp|mka|webm|wma|mid|midi|caf|amr|ac3|dts|dsf|dff|mpc|tak|audio)$',
    caseSensitive: false,
  ).hasMatch(path);

  Future<MusicTrack> _localTrackFromPath(String path) async {
    final isContentUri = Platform.isAndroid && path.startsWith('content://');
    final fileName = isContentUri
        ? (Uri.tryParse(path)?.pathSegments.lastOrNull ?? 'Local audio')
        : path.split(RegExp(r'[/\\]')).last;
    final dot = fileName.lastIndexOf('.');
    final fallbackTitle = (dot > 0 ? fileName.substring(0, dot) : fileName)
        .replaceAll(RegExp(r'_+'), ' ')
        .trim();

    String? title;
    String? artist;
    String? album;
    int duration = 0;
    String? artworkPath;
    int? modifiedMillis;

    if (!isContentUri) {
      try {
        modifiedMillis = (await File(
          path,
        ).lastModified()).millisecondsSinceEpoch;
      } on FileSystemException {
        // Some virtual filesystems do not expose timestamps; metadata still works.
      }
    }

    try {
      final metadata = isContentUri
          ? await _androidLocalFolders.invokeMapMethod<String, dynamic>(
              'readMetadata',
              {'uri': path},
            )
          : await compute<String, Map<String, Object?>>(
              _readEmbeddedMetadata,
              path,
            );
      if (metadata == null) throw StateError('Could not read audio metadata');
      title = (metadata['title'] as String?)?.trim();
      if (title?.isNotEmpty != true && metadata['fileName'] is String) {
        final sourceName = (metadata['fileName'] as String).trim();
        final sourceDot = sourceName.lastIndexOf('.');
        title =
            (sourceDot > 0 ? sourceName.substring(0, sourceDot) : sourceName)
                .replaceAll(RegExp(r'_+'), ' ')
                .trim();
      }
      artist = (metadata['artist'] as String?)?.trim();
      album = (metadata['album'] as String?)?.trim();
      duration = (metadata['duration'] as int?) ?? 0;

      final artwork = metadata['artwork'];
      if (artwork is List<int> && artwork.isNotEmpty) {
        final supportDirectory = await getApplicationSupportDirectory();
        final artworkDirectory = Directory('${supportDirectory.path}/artwork');
        await artworkDirectory.create(recursive: true);
        final digest = md5
            .convert(utf8.encode('$path:$modifiedMillis'))
            .toString();
        final artworkFile = File('${artworkDirectory.path}/$digest.img');
        if (!await artworkFile.exists()) {
          await artworkFile.writeAsBytes(artwork, flush: true);
        }
        artworkPath = artworkFile.path;
      }
    } catch (_) {
      // Some formats have no supported tags. Keep the file importable and use
      // filename-based fallbacks rather than failing the entire import/scan.
    }

    return MusicTrack(
      id: 'local:$path',
      title: title?.isNotEmpty == true
          ? title!
          : (fallbackTitle.isEmpty ? fileName : fallbackTitle),
      artist: artist?.isNotEmpty == true ? artist! : 'Unknown artist',
      album: album?.isNotEmpty == true ? album! : 'Unknown album',
      duration: duration,
      localPath: path,
      localArtworkPath: artworkPath,
      localMetadataRead: true,
      localModifiedMillis: modifiedMillis,
    );
  }

  Future<void> _scanLocalFolders({bool showFeedback = false}) async {
    if (_localFolders.isEmpty) return;
    if (_scanningLocalFolders) {
      // A folder can be added while startup or a manual refresh is already
      // scanning. Never drop that request: run another pass with the latest
      // folder list as soon as the active scan finishes.
      _localFolderScanRequested = true;
      _pendingFolderScanFeedback = _pendingFolderScanFeedback || showFeedback;
      return;
    }
    _scanningLocalFolders = true;
    try {
      final discovered = <String, MusicTrack>{};
      final existingByPath = <String, MusicTrack>{
        for (final track in _localTracks)
          if (track.localPath != null) track.localPath!: track,
      };
      final inaccessibleFolders = <String>[];
      final folderErrors = <String, String>{};
      for (final folder in _localFolders) {
        try {
          late final Iterable<String> paths;
          if (Platform.isAndroid && folder.startsWith('saf:')) {
            final uri = folder.substring(4);
            final result = await _androidLocalFolders.invokeListMethod<String>(
              'scanFolder',
              {'uri': uri},
            );
            paths = result ?? const <String>[];
          } else {
            paths = await compute<String, List<String>>(
              _listAudioPathsInFolder,
              folder,
            );
          }
          for (final path in paths) {
            // Android's SAF scanner already filters by the document's real
            // display name and MIME type. A content:// URI is an opaque ID on
            // many providers (not a filename), so checking its suffix here
            // incorrectly discards valid MP3s and other audio files.
            if (!(Platform.isAndroid && folder.startsWith('saf:')) &&
                !_isAudioFile(path)) {
              continue;
            }
            final existing = existingByPath[path];
            if (existing != null && existing.localMetadataRead) {
              if (Platform.isAndroid && path.startsWith('content://')) {
                discovered['local:$path'] = existing;
                continue;
              }
              try {
                final modified = (await File(
                  path,
                ).lastModified()).millisecondsSinceEpoch;
                if (existing.localModifiedMillis == modified) {
                  discovered['local:$path'] = existing;
                  continue;
                }
              } on FileSystemException {
                if (existing.localModifiedMillis == null) {
                  discovered['local:$path'] = existing;
                  continue;
                }
              }
            }
            discovered['local:$path'] = await _localTrackFromPath(path);
          }
        } catch (error) {
          inaccessibleFolders.add(folder);
          folderErrors[folder] = error.toString();
        }
      }

      // Keep manually imported tracks and tracks in folders whose access was
      // temporarily denied; remove files that disappeared from readable folders.
      final retained = _localTracks.where((track) {
        final path = track.localPath;
        if (path == null) return false;
        // Old Android versions copied SAF audio into app-private storage.
        // Once a provider URI has been indexed, don't retain those duplicate
        // cached tracks alongside the original files.
        if (Platform.isAndroid &&
            inaccessibleFolders.isEmpty &&
            path.contains('/navika_imported/')) {
          return false;
        }
        final parentFolder = _localFolders.where(
          (folder) => path.startsWith('$folder/'),
        );
        if (parentFolder.isEmpty) return true;
        if (inaccessibleFolders.any((folder) => path.startsWith('$folder/'))) {
          return true;
        }
        return false;
      });
      final merged = <String, MusicTrack>{
        for (final track in retained) track.id: track,
        for (final track in discovered.values) track.id: track,
      };
      final updated = merged.values.toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      final changed =
          jsonEncode(updated.map((track) => track.toJson()).toList()) !=
          jsonEncode(_localTracks.map((track) => track.toJson()).toList());
      if (changed) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _localTracksKey,
          jsonEncode(updated.map((track) => track.toJson()).toList()),
        );
        if (mounted) {
          _updateState(() {
            _localTracks = updated;
            _tracks = _mergeLibraryTracks([
              ..._tracks.where((track) => !track.isLocal),
              ...updated,
            ]);
            _libraryLoaded = _connected ? _libraryLoaded : updated.isNotEmpty;
          });
        }
      }
      if (Platform.isAndroid &&
          discovered.keys.any((id) => id.startsWith('local:content://'))) {
        // Remove legacy copies after the library has been migrated to content
        // URIs. Keep the currently playing file until playback moves away.
        final legacyDirectory = Directory(
          '${(await getApplicationSupportDirectory()).path}/navika_imported',
        );
        if (await legacyDirectory.exists()) {
          final activePath = _current?.localPath;
          await for (final entity in legacyDirectory.list(followLinks: false)) {
            if (entity is File && entity.path != activePath) {
              try {
                await entity.delete();
              } catch (_) {
                // A legacy file may still be open by the audio player.
              }
            }
          }
        }
      }
      if (showFeedback && mounted) {
        final message = folderErrors.isNotEmpty
            ? 'Could not read ${folderErrors.length} folder(s): ${folderErrors.entries.map((entry) => '${entry.key}: ${entry.value}').join('; ')}'
            : discovered.isEmpty
            ? 'No supported audio files found. Navika checks MP3, M4A, AAC, WAV, FLAC, OGG, OPUS, AIFF, ALAC, WMA, MIDI and other common formats.'
            : 'Folder added. Found ${discovered.length} audio file(s); folders rescan when the app resumes or you tap refresh.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      _scanningLocalFolders = false;
      if (_localFolderScanRequested && mounted) {
        _localFolderScanRequested = false;
        final showPendingFeedback = _pendingFolderScanFeedback;
        _pendingFolderScanFeedback = false;
        unawaited(_scanLocalFolders(showFeedback: showPendingFeedback));
      } else if (_localFolders.isEmpty) {
        _localFolderScanRequested = false;
        _pendingFolderScanFeedback = false;
      }
    }
  }
}
