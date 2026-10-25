part of '../main.dart';

extension _FlowLogicMethods on _HomeScreenState {
  List<MusicTrack> _recommended() {
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
            .map((track) => track.artist.toLowerCase());
        return recentArtists
                .where((artist) => artist == candidate.artist.toLowerCase())
                .length <
            2;
      });
      diversified.add(remaining.removeAt(nextIndex < 0 ? 0 : nextIndex));
    }
    return diversified;
  }

  List<MusicTrack> _buildFlowQueue() {
    final tracks = _modeTracks
        .where(
          (track) =>
              !_dismissedRecommendations.contains(track.id) &&
              !_flowHiddenTrackIds.contains(track.id),
        )
        .toList();
    if (tracks.isEmpty) return [];

    final artistPlays = <String, int>{};
    final albumPlays = <String, int>{};
    final trackPlays = <String, int>{};
    for (final event in _history) {
      artistPlays.update(
        event.artist.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      albumPlays.update(
        event.album.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      trackPlays.update(event.id, (count) => count + 1, ifAbsent: () => 1);
    }

    final recentIds = _history
        .skip(math.max(0, _history.length - 18))
        .map((event) => event.id)
        .toSet();
    final candidates = tracks.where((track) => track.id != _current?.id).map((
      track,
    ) {
      final artist = track.artist.toLowerCase();
      final album = track.album.toLowerCase();
      final artistFamiliarity =
          (math.min(artistPlays[artist] ?? 0, 8) / 8) * .62;
      final albumFamiliarity = (math.min(albumPlays[album] ?? 0, 5) / 5) * .18;
      final favoriteBoost = _favorites.contains(track.id) ? .28 : 0.0;
      final trackFeedback = (_tasteTrackFeedback[track.id] ?? 0) * .5;
      final familiarity = (artistFamiliarity + albumFamiliarity + favoriteBoost)
          .clamp(0.0, 1.0);
      final discovery =
          (1 - familiarity) * .78 +
          ((trackPlays[track.id] ?? 0) == 0 ? .2 : 0.0) -
          (recentIds.contains(track.id) ? .38 : 0.0);
      final score =
          _flowFamiliarity * familiarity +
          (1 - _flowFamiliarity) * discovery +
          trackFeedback;
      return (track: track, score: score);
    }).toList();

    final queue = <MusicTrack>[];
    final remaining = List.of(candidates);
    while (remaining.isNotEmpty && queue.length < 80) {
      var bestIndex = 0;
      var bestScore = double.negativeInfinity;
      for (var i = 0; i < remaining.length; i++) {
        final candidate = remaining[i];
        final recentArtistCount = queue
            .skip(math.max(0, queue.length - 4))
            .where(
              (track) =>
                  track.artist.toLowerCase() ==
                  candidate.track.artist.toLowerCase(),
            )
            .length;
        final score = candidate.score - recentArtistCount * _flowVariety * .42;
        if (score > bestScore) {
          bestScore = score;
          bestIndex = i;
        }
      }
      queue.add(remaining.removeAt(bestIndex).track);
    }

    // Keep the session useful even when the current song is the only library
    // item, rather than returning a queue that can never advance.
    return queue.isEmpty ? [tracks.first] : queue;
  }

  void _refreshFlowQueue() {
    final current = _current;
    final upcoming = _buildFlowQueue()
        .where((track) => track.id != current?.id)
        .toList();
    if (!mounted) return;
    _updateState(() {
      _queue = [?current, ...upcoming];
      _queueIndex = 0;
    });
    unawaited(_saveQueue());
  }

  Future<void> _startFlow() async {
    final picks = _buildFlowQueue();
    if (picks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load a music library to start Navika Flow.')),
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

  String _flowReason(MusicTrack track) {
    if ((_tasteTrackFeedback[track.id] ?? 0) > 0) {
      return 'You asked for more like this';
    }
    if ((_tasteTrackFeedback[track.id] ?? 0) < 0) {
      return 'You asked for less of this song';
    }
    if ((_tasteTrackFeedback[track.id] ?? 0) > 0) {
      return 'You asked for more like this song';
    }
    if (_favorites.contains(track.id)) return 'One of your favorites';
    final artistPlays = _history
        .where(
          (event) => event.artist.toLowerCase() == track.artist.toLowerCase(),
        )
        .length;
    final trackWasRecent = _history
        .skip(math.max(0, _history.length - 18))
        .any((event) => event.id == track.id);
    if (trackWasRecent) return 'A familiar track in your rotation';
    if (artistPlays >= 3) return 'More from an artist you return to';
    if (artistPlays == 0) return 'A fresh artist from your library';
    return 'Keeps your listening varied';
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
                label: const Text('Don’t play this song'),
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
      jsonEncode({
        'artists': _tasteArtistFeedback,
        'tracks': _tasteTrackFeedback,
      }),
    );
  }

  Future<void> _rateCurrentTrack({required bool like}) async {
    final track = _current;
    if (track == null) return;
    _updateState(() {
      final value = like ? 1 : -1;
      _tasteTrackFeedback[track.id] = value;
    });
    await _saveTasteProfile();
    if (_flowActive) _refreshFlowQueue();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          like
              ? 'Got it — Navika will look for more like this.'
              : 'Got it — Navika will recommend less like this.',
        ),
      ),
    );
  }

  Future<void> _hideCurrentFromFlow() async {
    final track = _current;
    if (track == null || !_flowActive) return;
    _updateState(() => _flowHiddenTrackIds.add(track.id));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _flowHiddenTracksKey,
      _flowHiddenTrackIds.toList(),
    );
    if (!mounted) return;
    final nextIndex = _queueIndex + 1;
    if (nextIndex < _queue.length) {
      await _skip(1);
    } else {
      _refreshFlowQueue();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This song won’t be played in Flow again.'),
        ),
      );
    }
  }

  Future<void> _clearFlowHiddenTracks() async {
    _updateState(() => _flowHiddenTrackIds.clear());
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_flowHiddenTracksKey);
    if (_flowActive) _refreshFlowQueue();
  }

  List<({String artist, int plays, int feedback})> _tasteTopArtists() {
    final names = <String, String>{};
    final plays = <String, int>{};
    for (final track in _modeTracks) {
      names.putIfAbsent(track.artist.toLowerCase(), () => track.artist);
    }
    for (final event in _history) {
      final key = event.artist.toLowerCase();
      names.putIfAbsent(key, () => event.artist);
      plays.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final key in _tasteArtistFeedback.keys) {
      names.putIfAbsent(
        key,
        () =>
            _modeTracks
                .where((track) => track.artist.toLowerCase() == key)
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
    return artists.take(5).toList();
  }

  Future<void> _resetTasteProfile() async {
    _updateState(() {
      _tasteArtistFeedback.clear();
      _tasteTrackFeedback.clear();
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tasteProfileKey);
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
