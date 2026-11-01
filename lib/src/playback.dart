part of '../main.dart';

extension _PlaybackMethods on _HomeScreenState {
  Future<void> _play(MusicTrack track, {List<MusicTrack>? playlist}) {
    final requestId = ++_playRequestId;
    final operation = _playbackOperation.then(
      (_) => _playInternal(track, playlist: playlist, requestId: requestId),
    );
    // A failed playback attempt must not poison the serialization chain.
    _playbackOperation = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _playInternal(
    MusicTrack track, {
    List<MusicTrack>? playlist,
    required int requestId,
  }) async {
    if (requestId != _playRequestId) return;
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
      final mediaItem = _mediaItemForTrack(track, client);
      final audioSource = track.isLocal
          ? (track.localPath!.startsWith('content://')
                ? AudioSource.uri(Uri.parse(track.localPath!), tag: mediaItem)
                : AudioSource.file(track.localPath!, tag: mediaItem))
          : AudioSource.uri(
              Uri.parse(client!.streamUrl(track.id)),
              tag: mediaItem,
            );
      await _player.setAudioSource(audioSource);
      if (requestId != _playRequestId) return;
      await _player.setLoopMode(_repeatOne ? LoopMode.one : LoopMode.off);
      await _player.setSpeed(_playbackSpeed);
      await _applyReplayGain(track);
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

      if (!mounted || requestId != _playRequestId) return;
      _updateState(() {
        _queue = finalQueue;
        _queueIndex = index;
        if (_flowActive && _queueIndex > 40) {
          final discardCount = _queueIndex - 20;
          _queue.removeRange(0, discardCount);
          _queueIndex -= discardCount;
        }
        _current = track;
        _invalidateRecommendationCaches();
        _currentTrackNotifier.value = track;
        _queueIndexNotifier.value = _queueIndex;
        _artworkAccentColor = null;
        _showPlayer = !_showFlow;
        _showUpNext = false;
        _showLyrics = false;
        _error = '';
      });
      unawaited(_updateArtworkAccentColor(track));

      final event = ListeningEvent(
        id: track.id,
        artist: track.artist,
        album: track.album,
        playedAt: DateTime.now().millisecondsSinceEpoch,
        genre: track.genre,
      );
      _history = [..._history, event].takeLast(200).toList();
      _syncAudioService();
      if (_flowActive) _flowSessionPlayedIds.add(track.id);
      _invalidateRecommendationCaches();
      // History influences the next Flow session, but never reshuffle the
      // active Flow queue just because the current song changed.
      _flowQueueDirty = true;
      _scheduleHistorySave();
      if (_flowActive) {
        await _saveFlowQueueState();
        if (_queue.length - _queueIndex - 1 <= 5) {
          await _appendFlowBatch();
        }
      } else {
        unawaited(_saveQueue());
      }
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
    final removed = _queue[index];
    _updateState(() {
      _queue.removeAt(index);
      if (_flowActive) {
        _flowSessionPlayedIds.add(removed.id);
        _flowProtectedTrackIds.remove(removed.id);
        _flowQueueDirty = true;
      }
      if (index < _queueIndex) _queueIndex--;
      _queueIndexNotifier.value = _queueIndex;
    });
    if (_flowActive) {
      unawaited(_saveFlowQueueState());
      unawaited(_saveFlowProtectedTracks());
    } else {
      unawaited(_saveQueue());
    }
  }

  void _moveQueueItem(int from, int to) {
    if (from <= _queueIndex ||
        to <= _queueIndex ||
        from >= _queue.length ||
        to >= _queue.length) {
      return;
    }
    final moved = _queue[from];
    _updateState(() {
      final item = _queue.removeAt(from);
      _queue.insert(to, item);
      if (_flowActive) _flowProtectedTrackIds.add(moved.id);
    });
    if (_flowActive) {
      unawaited(_saveFlowQueueState());
      unawaited(_saveFlowProtectedTracks());
    } else {
      unawaited(_saveQueue());
    }
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

  Future<void> _applyReplayGain(MusicTrack track) => _player.setVolume(
    _replayGainEnabled
        ? replayGainVolume(
            track,
            useAlbumGain: _replayGainAlbumMode,
            preampDb: _replayGainPreampDb,
          )
        : 1,
  );

  Future<void> _setReplayGainEnabled(bool enabled) async {
    _updateState(() => _replayGainEnabled = enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_replayGainEnabledKey, enabled);
    final track = _current;
    if (track != null) await _applyReplayGain(track);
  }

  Future<void> _setReplayGainAlbumMode(bool albumMode) async {
    _updateState(() => _replayGainAlbumMode = albumMode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_replayGainAlbumKey, albumMode);
    final track = _current;
    if (track != null) await _applyReplayGain(track);
  }

  Future<void> _setReplayGainPreamp(double preampDb) async {
    final value = preampDb.clamp(-6.0, 6.0).toDouble();
    _updateState(() => _replayGainPreampDb = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_replayGainPreampKey, value);
    final track = _current;
    if (track != null) await _applyReplayGain(track);
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
