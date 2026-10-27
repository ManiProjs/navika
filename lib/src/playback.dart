part of '../main.dart';

extension _PlaybackMethods on _HomeScreenState {
  Future<void> _play(MusicTrack track, {List<MusicTrack>? playlist}) async {
    final client = _client;
    if (client == null && !track.isLocal) {
      _selectTab(AppTab.library);
      return;
    }

    final nextQueue = playlist ?? _queue;
    var index = nextQueue.indexWhere((item) => item.id == track.id);
    var finalQueue = nextQueue;

    if (index < 0) {
      finalQueue = [track, ..._queue];
      index = 0;
    }

    try {
      final mediaItem = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: Duration(seconds: track.duration),
        artUri: track.localArtworkPath != null
            ? Uri.file(track.localArtworkPath!)
            : (client?.coverArtUrl(track.coverArt) == null
                  ? null
                  : Uri.parse(client!.coverArtUrl(track.coverArt)!)),
      );
      final audioSource = track.isLocal
          ? (track.localPath!.startsWith('content://')
                ? AudioSource.uri(Uri.parse(track.localPath!), tag: mediaItem)
                : AudioSource.file(track.localPath!, tag: mediaItem))
          : AudioSource.uri(
              Uri.parse(client!.streamUrl(track.id)),
              tag: mediaItem,
            );
      await _player.setAudioSource(audioSource);
      await _player.setLoopMode(_repeatOne ? LoopMode.one : LoopMode.off);
      await _player.setSpeed(_playbackSpeed);
      final started = _player.playerStateStream
          .firstWhere((state) => state.playing)
          .timeout(Duration(seconds: 15));
      unawaited(
        _player.play().catchError((Object error) {
          if (mounted) {
            _updateState(() => _error = _describePlaybackError(error));
          }
        }),
      );
      await started;

      if (!mounted) return;
      _updateState(() {
        _queue = finalQueue;
        _queueIndex = index;
        _current = track;
        _invalidateRecommendationCaches();
        _currentTrackNotifier.value = track;
        _queueIndexNotifier.value = index;
        _artworkAccentColor = null;
        _showPlayer = !_showFlow;
        _showUpNext = false;
        _error = '';
      });
      unawaited(_updateArtworkAccentColor(track));

      unawaited(_saveQueue());
      final event = ListeningEvent(
        id: track.id,
        artist: track.artist,
        album: track.album,
        playedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _history = [..._history, event].takeLast(200).toList();
      _invalidateRecommendationCaches();
      _flowQueueDirty = true;
      _scheduleHistorySave();
      if (mounted && _flowActive) _refreshFlowQueue();
    } catch (error) {
      if (!mounted) return;
      _updateState(() => _error = _describePlaybackError(error));
    }
  }

  void _scheduleHistorySave() {
    _historySaveTimer?.cancel();
    _historySaveTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _historyKey,
          jsonEncode(_history.map((event) => event.toJson()).toList()),
        );
      } catch (error) {
        if (mounted) {
          _updateState(
            () => _error =
                'Playback started, but listening history could not be saved: $error',
          );
        }
      }
    });
  }

  Future<void> _saveQueue() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _queueKey,
        jsonEncode(_queue.map((track) => track.toJson()).toList()),
      );
    } catch (_) {
      // Queue persistence is best-effort; playback should never fail because of it.
    }
  }

  void _removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length || index == _queueIndex) return;
    _updateState(() {
      _queue.removeAt(index);
      if (index < _queueIndex) _queueIndex--;
      _queueIndexNotifier.value = _queueIndex;
    });
    unawaited(_saveQueue());
  }

  void _moveQueueItem(int from, int to) {
    if (from <= _queueIndex ||
        to <= _queueIndex ||
        from >= _queue.length ||
        to >= _queue.length) {
      return;
    }
    _updateState(() {
      final item = _queue.removeAt(from);
      _queue.insert(to, item);
    });
    unawaited(_saveQueue());
  }

  Future<void> _clearUpcoming() async {
    _updateState(() {
      if (_current != null) {
        _queue = [_current!];
        _queueIndex = 0;
      } else {
        _queue.clear();
        _queueIndex = 0;
      }
      _queueIndexNotifier.value = _queueIndex;
    });
    await _saveQueue();
  }

  Future<void> _saveQueueAsPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewPlaylistDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    final ids = _queue.map((track) => track.id).toSet().toList();
    _updateState(() => _playlists[name.trim()] = ids);
    await _savePlaylists();
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _updateState(() => _playbackSpeed = speed);
    await _player.setSpeed(speed);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_speedKey, speed);
  }

  void _startSleepTimer() {
    showModalBottomSheet<int>(
      context: context,
      backgroundColor: C.surface,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Sleep timer',
                style: TextStyle(fontFamily: 'SyneBold', fontSize: 20),
              ),
            ),
            for (final minutes in [15, 30, 45, 60, 90])
              ListTile(
                title: Text('$minutes minutes'),
                leading: Icon(Icons.bedtime_outlined),
                onTap: () => Navigator.pop(context, minutes),
              ),
            ListTile(
              title: Text('Cancel timer'),
              leading: Icon(Icons.timer_off_outlined),
              onTap: () => Navigator.pop(context, 0),
            ),
          ],
        ),
      ),
    ).then((minutes) {
      if (minutes == null) return;
      _sleepTimer?.cancel();
      if (minutes == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Sleep timer cancelled')));
        }
        return;
      }
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        unawaited(_player.pause());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback paused by sleep timer')),
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep timer set for $minutes minutes')),
        );
      }
    });
  }

  Future<void> _dismissRecommendation(MusicTrack track) async {
    _flowQueueDirty = true;
    _invalidateRecommendationCaches();
    _updateState(() => _dismissedRecommendations.add(track.id));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _recommendationFeedbackKey,
      _dismissedRecommendations.toList(),
    );
  }
}
