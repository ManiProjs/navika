part of '../main.dart';

extension _FlowLogicMethods on _HomeScreenState {
  List<MusicTrack> _recommended() {
    final cached = _cachedRecommendedTracks;
    if (cached != null) return cached;
    final ranked = recommendTracks(
      _modeTracks
          .where((track) => !_dismissedRecommendations.contains(track.id))
          .toList(),
      _history,
      currentId: _current?.id,
      favoriteIds: _favorites.toSet(),
      limit: _modeTracks.length,
    );
    // Keep a strong listening-history bias from turning the mix into one
    // artist's discography: no more than two of the last five picks per artist.
    final diversified = <MusicTrack>[];
    final remaining = List<MusicTrack>.of(ranked);
    while (remaining.isNotEmpty) {
      final nextIndex = remaining.indexWhere((candidate) {
        final recentArtists = diversified
            .skip(math.max(0, diversified.length - 4))
            .map((track) => track.artist.trim().toLowerCase());
        return recentArtists
                .where(
                  (artist) => artist == candidate.artist.trim().toLowerCase(),
                )
                .length <
            2;
      });
      diversified.add(remaining.removeAt(nextIndex < 0 ? 0 : nextIndex));
    }
    _cachedRecommendedTracks = diversified;
    return diversified;
  }

  List<MusicTrack> _buildFlowQueue() {
    if (!_flowQueueDirty && _cachedFlowQueue != null) return _cachedFlowQueue!;
    _cachedFlowQueue = _generateFlowBatch(
      excludedIds: _flowSessionPlayedIds,
      limit: 80,
    );
    _flowQueueDirty = false;
    return _cachedFlowQueue!;
  }

  List<MusicTrack> _generateFlowBatch({
    required Set<String> excludedIds,
    int limit = 20,
  }) => buildFlowQueue(
    tracks: _modeTracks,
    history: _history,
    favoriteIds: _favorites,
    artistFeedback: _tasteArtistFeedback,
    trackFeedback: _tasteTrackFeedback,
    excludedArtistKeys: _tasteArtistFeedback.entries
        .where((entry) => entry.value <= -2)
        .map((entry) => entry.key)
        .toSet(),
    excludedTrackIds: {..._flowExcludedTrackIds, ..._flowHiddenTrackIds},
    excludedIds: excludedIds,
    familiarity: _flowFamiliarity,
    variety: _flowVariety,
    limit: limit,
  );

  Future<void> _appendFlowBatch() async {
    if (!_flowActive || !mounted || _queue.length - _queueIndex - 1 > 5) return;
    var excluded = {
      ..._flowSessionPlayedIds,
      ..._queue.skip(_queueIndex).map((track) => track.id),
    };
    var batch = _generateFlowBatch(excludedIds: excluded, limit: 20);
    if (batch.isEmpty) {
      _flowSessionPlayedIds
        ..clear()
        ..addAll({_current?.id ?? ''}..remove(''));
      excluded = {
        ..._flowSessionPlayedIds,
        ..._queue.skip(_queueIndex).map((track) => track.id),
      };
      batch = _generateFlowBatch(excludedIds: excluded, limit: 20);
    }
    if (batch.isEmpty || !mounted) return;
    _updateState(() => _queue.addAll(batch));
    await _saveFlowQueueState();
  }

  void _refreshFlowQueue() {
    final current =
        _current ??
        _queue.where((track) => track.id == _flowResumeTrackId).firstOrNull;
    _flowQueueDirty = true;
    final protected = _queue
        .skip(_queueIndex + (current == null ? 0 : 1))
        .where((track) => _flowProtectedTrackIds.contains(track.id))
        .toList();
    final excluded = {
      ..._flowSessionPlayedIds,
      ...protected.map((track) => track.id),
    };
    var generated = _generateFlowBatch(excludedIds: excluded);
    if (generated.isEmpty) {
      _flowSessionPlayedIds
        ..clear()
        ..addAll({current?.id ?? _flowResumeTrackId ?? ''}..remove(''));
      generated = _generateFlowBatch(
        excludedIds: {
          ..._flowSessionPlayedIds,
          ...protected.map((track) => track.id),
        },
      );
    }
    final upcoming = [...protected, ...generated];
    if (!mounted) return;
    _updateState(() {
      _queue = [?current, ...upcoming];
      _queueIndex = 0;
      _queueIndexNotifier.value = 0;
      if (_current == null) _flowResumeTrackId = current?.id;
    });
    unawaited(_saveFlowQueueState());
  }

  Future<void> _startFlow() async {
    _flowSessionPlayedIds.clear();
    _flowResumeTrackId = null;
    _flowQueueDirty = true;
    final picks = _buildFlowQueue();
    if (picks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add more available songs to start Navika Flow.'),
        ),
      );
      return;
    }
    _updateState(() {
      _showFlow = true;
      _flowActive = true;
      _showPlayer = false;
    });
    await _play(picks.first, playlist: picks);
  }

  Future<void> _resumeFlowSession() async {
    final id = _flowResumeTrackId;
    final track =
        _queue.where((item) => item.id == id).firstOrNull ??
        _modeTracks.where((item) => item.id == id).firstOrNull;
    if (track == null) {
      _flowSessionPlayedIds.clear();
      _flowQueueDirty = true;
      final picks = _buildFlowQueue();
      if (picks.isEmpty) return;
      _updateState(() => _flowActive = true);
      await _play(picks.first, playlist: picks);
      return;
    }
    _updateState(() {
      _flowActive = true;
      _showFlow = true;
      _flowPage = 1;
    });
    await _play(track, playlist: _queue.isEmpty ? [track] : _queue);
    if (_flowResumePositionMillis > 0 && mounted && _current?.id == track.id) {
      final maximumPosition = track.duration > 0
          ? track.duration * 1000
          : _flowResumePositionMillis;
      final resumePosition = _flowResumePositionMillis
          .clamp(0, maximumPosition)
          .toInt();
      await _player.seek(Duration(milliseconds: resumePosition));
      _position.value = Duration(milliseconds: resumePosition);
      _flowResumePositionMillis = 0;
      await _saveFlowSession();
    }
  }

  Future<void> _saveFlowPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _flowPreferencesKey,
      jsonEncode({'familiarity': _flowFamiliarity, 'variety': _flowVariety}),
    );
  }

  Future<void> _saveFlowSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _flowSessionKey,
        jsonEncode({
          'active': _flowActive,
          'currentId': _current?.id ?? _flowResumeTrackId,
          'queueIndex': _queueIndex,
          'playedIds': _flowSessionPlayedIds.toList().takeLast(2000).toList(),
          'positionMs': _current == null
              ? _flowResumePositionMillis
              : _position.value.inMilliseconds,
        }),
      );
    } catch (_) {
      // Session recovery is best-effort and must never interrupt playback.
    }
  }

  Future<void> _saveFlowQueueState() async {
    await _saveQueue();
    await _saveFlowSession();
  }

  Future<void> _setArtistFeedback(String artist, int value) async {
    final key = artist.trim().toLowerCase();
    if (key.isEmpty) return;
    _updateState(() {
      if (value == 0) {
        _tasteArtistFeedback.remove(key);
      } else {
        _tasteArtistFeedback[key] = value.clamp(-2, 2).toInt();
      }
      _flowQueueDirty = true;
      _invalidateRecommendationCaches();
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _flowArtistFeedbackKey,
      jsonEncode(_tasteArtistFeedback),
    );
    if (_flowActive) _refreshFlowQueue();
  }

  Future<void> _excludeCurrentTrack() async {
    final track = _current;
    if (track == null || !_flowActive) return;
    _updateState(() {
      _flowExcludedTrackIds.add(track.id);
      _flowSessionPlayedIds.add(track.id);
      _flowQueueDirty = true;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _flowExcludedTracksKey,
      _flowExcludedTrackIds.toList(),
    );
    await _saveFlowSession();
    if (_queueIndex + 1 >= _queue.length) await _appendFlowBatch();
    await _skip(1);
  }

  Future<void> _toggleFlowProtected(MusicTrack track) async {
    _updateState(() {
      if (_flowProtectedTrackIds.contains(track.id)) {
        _flowProtectedTrackIds.remove(track.id);
      } else {
        _flowProtectedTrackIds.add(track.id);
      }
    });
    await _saveFlowProtectedTracks();
  }

  Future<void> _saveFlowProtectedTracks() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _flowProtectedTracksKey,
      _flowProtectedTrackIds.toList(),
    );
  }

  Future<void> _endFlow() async {
    _updateState(() {
      _flowActive = false;
      _showFlow = false;
      _showPlayer = false;
      _flowResumeTrackId = null;
      _flowSessionPlayedIds.clear();
    });
    await _saveFlowSession();
  }

  String _flowReason(MusicTrack track) {
    if ((_tasteTrackFeedback[track.id] ?? 0) > 0) {
      return 'You asked for more like this';
    }
    if ((_tasteTrackFeedback[track.id] ?? 0) < 0) {
      return 'You asked for less of this song';
    }
    final artistFeedback =
        _tasteArtistFeedback[track.artist.trim().toLowerCase()] ?? 0;
    if (artistFeedback >= 2) return 'You asked for more from this artist';
    if (artistFeedback == 1) return 'An artist you enjoy';
    if (track.genre.trim().isNotEmpty &&
        _history.any(
          (event) => event.genre.toLowerCase() == track.genre.toLowerCase(),
        )) {
      return 'Matches a genre you listen to';
    }
    if (_favorites.contains(track.id)) return 'One of your favorites';
    final artistPlays = _history
        .where(
          (event) =>
              event.artist.trim().toLowerCase() ==
              track.artist.trim().toLowerCase(),
        )
        .length;
    final albumPlays = _history
        .where(
          (event) =>
              event.artist.trim().toLowerCase() ==
                  track.artist.trim().toLowerCase() &&
              event.album.toLowerCase() == track.album.toLowerCase(),
        )
        .length;
    final trackWasRecent = _history
        .skip(math.max(0, _history.length - 18))
        .any((event) => event.id == track.id);
    if (trackWasRecent) return 'A familiar track in your rotation';
    if (albumPlays >= 2) return 'A return to an album you enjoy';
    if (artistPlays >= 3) return 'More from an artist you return to';
    if (artistPlays == 0) return 'A fresh artist from your library';
    return 'A less-played track to broaden the mix';
  }

  Widget _flowPlayerDetails(MusicTrack track) {
    if (!_flowActive) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: C.lime, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _flowReason(track),
                  style: TextStyle(color: C.lime, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _rateCurrentTrack(like: true),
                icon: const Icon(Icons.thumb_up_alt_outlined, size: 14),
                label: const Text('More like this'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _rateCurrentTrack(like: false),
                icon: const Icon(Icons.thumb_down_alt_outlined, size: 14),
                label: const Text('Less like this'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _hideCurrentFromFlow,
                icon: const Icon(Icons.block_rounded, size: 14),
                label: const Text('Skip for this session'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _refreshFlowQueue,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Refresh mix'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveTasteProfile() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _tasteProfileKey,
      jsonEncode({'tracks': _tasteTrackFeedback}),
    );
  }

  Future<void> _rateCurrentTrack({required bool like}) async {
    await _setCurrentTrackFeedback(like ? 1 : -1);
  }

  Future<void> _setCurrentTrackFeedback(int value) async {
    final track = _current;
    if (track == null) return;
    _flowQueueDirty = true;
    _invalidateRecommendationCaches();
    _updateState(() {
      _tasteTrackFeedback[track.id] = value;
    });
    await _saveTasteProfile();
    if (_flowActive) _refreshFlowQueue();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value >= 2
              ? 'Saved — Flow will strongly favor this track.'
              : value > 0
              ? 'Got it — Navika will look for more like this.'
              : 'Got it — Navika will recommend less like this.',
        ),
      ),
    );
  }

  Future<void> _regenerateFlowQueueItem(int index) async {
    if (!_flowActive || index <= _queueIndex || index >= _queue.length) return;
    final oldTrack = _queue[index];
    final excluded = {
      ..._flowSessionPlayedIds,
      ..._queue
          .where((track) => track.id != oldTrack.id)
          .map((track) => track.id),
    };
    final replacement = _generateFlowBatch(excludedIds: excluded, limit: 1);
    if (replacement.isEmpty) return;
    _updateState(() {
      _queue[index] = replacement.first;
      _flowSessionPlayedIds.add(oldTrack.id);
      _flowProtectedTrackIds.remove(oldTrack.id);
      _flowQueueDirty = true;
    });
    await _saveQueue();
    await _saveFlowProtectedTracks();
    await _saveFlowSession();
  }

  Future<void> _hideCurrentFromFlow() async {
    final track = _current;
    if (track == null || !_flowActive) return;
    _updateState(() {
      _flowSessionPlayedIds.add(track.id);
      _flowQueueDirty = true;
    });
    await _saveFlowSession();
    if (!mounted) return;
    final nextIndex = _queueIndex + 1;
    if (nextIndex < _queue.length) {
      await _skip(1);
    } else {
      await _appendFlowBatch();
      if (_queue.length > _queueIndex + 1) {
        await _skip(1);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skipped for this Flow session.')),
      );
    }
  }

  Future<void> _clearFlowHiddenTracks() async {
    _flowQueueDirty = true;
    _updateState(() {
      _flowHiddenTrackIds.clear();
      _flowExcludedTrackIds.clear();
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_flowHiddenTracksKey);
    await preferences.remove(_flowExcludedTracksKey);
    if (_flowActive) _refreshFlowQueue();
  }

  List<({String artist, int plays, int feedback})> _tasteTopArtists() {
    final names = <String, String>{};
    final plays = <String, int>{};
    for (final track in _modeTracks) {
      names.putIfAbsent(track.artist.trim().toLowerCase(), () => track.artist);
    }
    for (final event in _history) {
      final key = event.artist.trim().toLowerCase();
      names.putIfAbsent(key, () => event.artist);
      plays.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final key in _tasteArtistFeedback.keys) {
      names.putIfAbsent(
        key,
        () =>
            _modeTracks
                .where((track) => track.artist.trim().toLowerCase() == key)
                .map((track) => track.artist)
                .firstOrNull ??
            key,
      );
    }
    final artists = names.entries
        .map(
          (entry) => (
            artist: entry.value,
            plays: plays[entry.key] ?? 0,
            feedback: _tasteArtistFeedback[entry.key] ?? 0,
          ),
        )
        .toList();
    artists.sort((a, b) {
      final aScore = a.feedback * 4 + a.plays;
      final bScore = b.feedback * 4 + b.plays;
      return bScore.compareTo(aScore);
    });
    final rated = artists.where((artist) => artist.feedback != 0).toList();
    final unrated = artists.where((artist) => artist.feedback == 0).take(12);
    return [...rated, ...unrated];
  }

  Future<void> _resetTasteProfile() async {
    _flowQueueDirty = true;
    _invalidateRecommendationCaches();
    _updateState(() {
      _tasteArtistFeedback.clear();
      _tasteTrackFeedback.clear();
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tasteProfileKey);
    await preferences.remove(_flowArtistFeedbackKey);
    if (_flowActive) _refreshFlowQueue();
  }

  Future<void> _updateArtworkAccentColor(MusicTrack track) async {
    final request = ++_artworkColorRequest;
    try {
      List<int>? bytes;
      final localArtworkPath = track.localArtworkPath;
      if (localArtworkPath != null && localArtworkPath.isNotEmpty) {
        bytes = await File(localArtworkPath).readAsBytes();
      } else {
        final url = (track.coverUrl?.trim().isNotEmpty ?? false)
            ? track.coverUrl
            : _client?.coverArtUrl(track.coverArt);
        if (url != null && url.isNotEmpty) {
          final client = HttpClient();
          try {
            final response = await (await client.getUrl(Uri.parse(url)))
                .close()
                .timeout(const Duration(seconds: 8));
            if (response.statusCode >= 200 && response.statusCode < 300) {
              bytes = await response
                  .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
                  .timeout(const Duration(seconds: 8));
            }
          } finally {
            client.close(force: true);
          }
        }
      }
      if (bytes == null || bytes.isEmpty) {
        if (mounted && request == _artworkColorRequest) {
          _updateState(() => _artworkAccentColor = null);
        }
        return;
      }

      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(bytes),
        targetWidth: 32,
        targetHeight: 32,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) return;
          final pixels = data.buffer.asUint8List();
          final hueWeights = List<double>.filled(12, 0);
          final hueRed = List<int>.filled(12, 0);
          final hueGreen = List<int>.filled(12, 0);
          final hueBlue = List<int>.filled(12, 0);
          final hueCounts = List<int>.filled(12, 0);
          var redTotal = 0;
          var greenTotal = 0;
          var blueTotal = 0;
          var count = 0;
          for (var i = 0; i + 3 < pixels.length; i += 4) {
            final alpha = pixels[i + 3];
            if (alpha < 96) continue;
            final red = pixels[i];
            final green = pixels[i + 1];
            final blue = pixels[i + 2];
            final color = Color.fromARGB(255, red, green, blue);
            final hsl = HSLColor.fromColor(color);
            redTotal += red;
            greenTotal += green;
            blueTotal += blue;
            count++;
            if (hsl.saturation < .22 ||
                hsl.lightness < .12 ||
                hsl.lightness > .88) {
              continue;
            }
            final bucket = (hsl.hue / 30).floor().clamp(0, 11);
            hueWeights[bucket] +=
                hsl.saturation * (1 - (hsl.lightness - .5).abs());
            hueRed[bucket] += red;
            hueGreen[bucket] += green;
            hueBlue[bucket] += blue;
            hueCounts[bucket]++;
          }
          if (count == 0) return;
          final strongest = hueWeights.indexOf(hueWeights.reduce(math.max));
          final accent = hueCounts[strongest] == 0
              ? Color.fromARGB(
                  255,
                  redTotal ~/ count,
                  greenTotal ~/ count,
                  blueTotal ~/ count,
                )
              : Color.fromARGB(
                  255,
                  hueRed[strongest] ~/ hueCounts[strongest],
                  hueGreen[strongest] ~/ hueCounts[strongest],
                  hueBlue[strongest] ~/ hueCounts[strongest],
                );
          if (mounted &&
              request == _artworkColorRequest &&
              _current?.id == track.id) {
            _updateState(() => _artworkAccentColor = accent);
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted &&
          request == _artworkColorRequest &&
          _current?.id == track.id) {
        _updateState(() => _artworkAccentColor = null);
      }
    }
  }
}
