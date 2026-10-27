part of '../main.dart';

extension _PlayerUiMethods on _HomeScreenState {
  Widget _playerOverlay() {
    final track = _current!;
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final duration =
        _player.duration?.inSeconds.toDouble() ?? track.duration.toDouble();
    final ambientColors = _playerAmbientColors();
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _reduceMotion ? Duration.zero : Duration(seconds: 3),
        builder: (context, phase, child) => RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + phase * 2, -1),
                end: Alignment(1 - phase * 2, 1),
                colors: [
                  ambientColors.first,
                  Color.lerp(ambientColors.last, C.bg, .22)!,
                  C.bg,
                ],
                stops: [0, .48, 1],
              ),
            ),
            child: child!,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 70,
                padding: EdgeInsets.fromLTRB(isMacOS ? 82 : 22, 0, 22, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _flowActive ? 'Back to Flow' : 'Back to library',
                      onPressed: () => _updateState(() {
                        _showPlayer = false;
                        _showUpNext = false;
                        if (_flowActive) _showFlow = true;
                      }),
                      icon: Icon(Icons.chevron_left_rounded, size: 30),
                    ),
                    Spacer(),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _flowActive ? 'NAVIKA FLOW' : 'NOW PLAYING',
                          style: TextStyle(
                            color: _artworkAccentColor ?? C.lime,
                            fontFamily: 'DMSansBold',
                            fontSize: 10,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _flowActive ? 'Your listening mix' : 'Your music',
                          style: TextStyle(
                            fontFamily: 'DMSansMedium',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    IconButton(
                      tooltip: _showVisualizer
                          ? 'Hide visualizer'
                          : 'Show visualizer',
                      onPressed: () => _updateState(
                        () => _showVisualizer = !_showVisualizer,
                      ),
                      icon: Icon(
                        Icons.graphic_eq_rounded,
                        color: _showVisualizer ? C.lime : C.muted,
                      ),
                    ),
                    IconButton(
                      tooltip: 'More player options',
                      onPressed: () => _showTrackMenu(track),
                      icon: Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: _reduceMotion
                      ? Duration.zero
                      : Duration(milliseconds: 150),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0.015, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: LayoutBuilder(
                    key: ValueKey(_showUpNext),
                    builder: (context, constraints) {
                      final artSize = (constraints.maxWidth * .72).clamp(
                        220.0,
                        390.0,
                      );

                      if (constraints.maxWidth > 680) {
                        // Keep enough room for the seek bar and controls in
                        // shorter windows to avoid a bottom RenderFlex overflow.
                        final desktopArtSize = (constraints.maxHeight * .58)
                            .clamp(220.0, 390.0);
                        if (_showUpNext) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(28, 12, 28, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NOW PLAYING',
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 10,
                                          letterSpacing: 1.3,
                                          fontFamily: 'DMSansBold',
                                        ),
                                      ),
                                      Spacer(),
                                      Center(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: _artwork(
                                            track.coverArt,
                                            localArtworkPath:
                                                track.localArtworkPath,
                                            size: desktopArtSize,
                                            seed: track.album,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              track.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'SyneBold',
                                                fontSize: 22,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip:
                                                _favorites.contains(track.id)
                                                ? 'Remove from favorites'
                                                : 'Add to favorites',
                                            onPressed: () =>
                                                _toggleFavorite(track),
                                            icon: Icon(
                                              _favorites.contains(track.id)
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                        .favorite_border_rounded,
                                              color: C.lime,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${track.artist} · ${track.album}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      _flowPlayerDetails(track),
                                      SizedBox(height: 8),
                                      _playbackProgress(duration),
                                      SizedBox(height: 0),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            tooltip: 'Shuffle',
                                            onPressed: _toggleShuffle,
                                            icon: Icon(
                                              Icons.shuffle_rounded,
                                              color: _shuffle
                                                  ? C.lime
                                                  : C.muted,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Previous track',
                                            onPressed: () => _skip(-1),
                                            icon: Icon(
                                              Icons.skip_previous_rounded,
                                              size: 27,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: _player.playing
                                                ? 'Pause'
                                                : 'Play',
                                            onPressed: _togglePlayback,
                                            icon: Icon(
                                              _player.playing
                                                  ? Icons
                                                        .pause_circle_filled_rounded
                                                  : Icons
                                                        .play_circle_fill_rounded,
                                              color: C.lime,
                                              size: 54,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Next track',
                                            onPressed: () => _skip(1),
                                            icon: Icon(
                                              Icons.skip_next_rounded,
                                              size: 27,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: _repeatOne
                                                ? 'Repeat one'
                                                : _repeatAll
                                                ? 'Repeat all'
                                                : 'Repeat off',
                                            onPressed: _cycleRepeatMode,
                                            icon: Icon(
                                              Icons.repeat_rounded,
                                              color: (_repeatAll || _repeatOne)
                                                  ? C.lime
                                                  : C.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 28),
                                Container(width: 1, color: C.border),
                                SizedBox(width: 24),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Up next',
                                              style: TextStyle(
                                                fontFamily: 'SyneBold',
                                                fontSize: 22,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Close Up Next',
                                            onPressed: () => _updateState(
                                              () => _showUpNext = false,
                                            ),
                                            icon: Icon(Icons.close_rounded),
                                          ),
                                          TextButton(
                                            onPressed: _clearUpcoming,
                                            child: Text('Clear'),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'NOW PLAYING',
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 10,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: C.surface,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              child: _artwork(
                                                track.coverArt,
                                                localArtworkPath:
                                                    track.localArtworkPath,
                                                size: 42,
                                                seed: track.album,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    track.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: 'DMSansBold',
                                                    ),
                                                  ),
                                                  Text(
                                                    track.artist,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: C.muted,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.graphic_eq_rounded,
                                              color: C.lime,
                                              size: 17,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 22),
                                      Text(
                                        'NEXT IN QUEUE',
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 10,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: math.min(
                                            30,
                                            math.max(
                                              0,
                                              _queue.length - _queueIndex - 1,
                                            ),
                                          ),
                                          itemBuilder: (context, index) =>
                                              _trackRow(
                                                _queue[_queueIndex + index + 1],
                                                _queueIndex + index + 1,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(28, 20, 28, 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 36,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _artwork(
                                    track.coverArt,
                                    localArtworkPath: track.localArtworkPath,
                                    size: desktopArtSize,
                                    seed: track.album,
                                  ),
                                ),
                                SizedBox(width: 30),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'SyneBold',
                                          fontSize: 27,
                                          letterSpacing: -.8,
                                        ),
                                      ),
                                      SizedBox(height: 7),
                                      InkWell(
                                        onTap: () => _openArtist(track),
                                        child: Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: C.muted,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _openAlbum(track),
                                        child: Text(
                                          track.album,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: C.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      _flowPlayerDetails(track),
                                      if (_showVisualizer) ...[
                                        SizedBox(height: 12),
                                        _visualizer(),
                                      ],
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: IconButton(
                                          tooltip: 'Toggle favorite',
                                          onPressed: () =>
                                              _toggleFavorite(track),
                                          icon: Icon(
                                            _favorites.contains(track.id)
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: _favorites.contains(track.id)
                                                ? C.lime
                                                : C.muted,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      _playbackProgress(duration),
                                      SizedBox(height: 8),
                                      SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            tooltip: 'Shuffle',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            onPressed: _toggleShuffle,
                                            icon: Icon(
                                              Icons.shuffle_rounded,
                                              color: _shuffle
                                                  ? C.lime
                                                  : C.muted,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Previous track',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            onPressed: () => _skip(-1),
                                            icon: Icon(
                                              Icons.skip_previous_rounded,
                                              size: 26,
                                            ),
                                          ),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              40,
                                            ),
                                            onTap: _togglePlayback,
                                            child: Semantics(
                                              button: true,
                                              label: _player.playing
                                                  ? 'Pause'
                                                  : 'Play',
                                              child: Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: C.lime,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _player.playing
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                            .play_arrow_rounded,
                                                  color: C.black,
                                                  size: 25,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Next track',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            onPressed: () => _skip(1),
                                            icon: Icon(
                                              Icons.skip_next_rounded,
                                              size: 26,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Repeat mode',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            onPressed: _cycleRepeatMode,
                                            icon: Icon(
                                              Icons.repeat_rounded,
                                              color: (_repeatAll || _repeatOne)
                                                  ? C.lime
                                                  : C.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _updateState(
                                            () => _showUpNext = true,
                                          ),
                                          icon: Icon(Icons.queue_music_rounded),
                                          label: Text(
                                            'Up Next · ${_queue.length - _queueIndex - 1}',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (_showUpNext) {
                        final firstIndex = _queueIndex + 1;
                        final upcomingCount = math.min(
                          100,
                          math.max(0, _queue.length - firstIndex),
                        );
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 12, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Up next',
                                      style: const TextStyle(
                                        fontFamily: 'SyneBold',
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Close Up Next',
                                    onPressed: () =>
                                        _updateState(() => _showUpNext = false),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'clear') _clearUpcoming();
                                      if (value == 'save') {
                                        _saveQueueAsPlaylist();
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'clear',
                                        child: Text('Clear upcoming tracks'),
                                      ),
                                      PopupMenuItem(
                                        value: 'save',
                                        child: Text('Save queue as playlist'),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_vert_rounded),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: upcomingCount,
                                itemExtent: 68,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                itemBuilder: (context, index) {
                                  final queueIndex = firstIndex + index;
                                  final queuedTrack = _queue[queueIndex];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: _artwork(
                                      queuedTrack.coverArt,
                                      localArtworkPath:
                                          queuedTrack.localArtworkPath,
                                      size: 42,
                                      seed: queuedTrack.album,
                                    ),
                                    title: Text(
                                      queuedTrack.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${queuedTrack.artist} · ${queuedTrack.album}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _play(queuedTrack),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Move up',
                                          onPressed:
                                              queueIndex > _queueIndex + 1
                                              ? () => _moveQueueItem(
                                                  queueIndex,
                                                  queueIndex - 1,
                                                )
                                              : null,
                                          icon: const Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 17,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Move down',
                                          onPressed:
                                              queueIndex < _queue.length - 1
                                              ? () => _moveQueueItem(
                                                  queueIndex,
                                                  queueIndex + 1,
                                                )
                                              : null,
                                          icon: const Icon(
                                            Icons.arrow_downward_rounded,
                                            size: 17,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove from queue',
                                          onPressed: () =>
                                              _removeFromQueue(queueIndex),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (upcomingCount == 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text("You're at the end of the queue."),
                              ),
                          ],
                        );
                      }

                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(22, 16, 22, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_showUpNext) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Up next',
                                      style: TextStyle(
                                        fontFamily: 'SyneBold',
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Close Up Next',
                                    onPressed: () =>
                                        _updateState(() => _showUpNext = false),
                                    icon: Icon(Icons.close_rounded),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'clear') _clearUpcoming();
                                      if (value == 'save') {
                                        _saveQueueAsPlaylist();
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'clear',
                                        child: Text('Clear upcoming tracks'),
                                      ),
                                      PopupMenuItem(
                                        value: 'save',
                                        child: Text('Save queue as playlist'),
                                      ),
                                    ],
                                    icon: Icon(Icons.more_vert_rounded),
                                  ),
                                ],
                              ),
                              ..._queue
                                  .asMap()
                                  .entries
                                  .where((entry) => entry.key > _queueIndex)
                                  .take(100)
                                  .map(
                                    (entry) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: _artwork(
                                        entry.value.coverArt,
                                        localArtworkPath:
                                            entry.value.localArtworkPath,
                                        size: 42,
                                        seed: entry.value.album,
                                      ),
                                      title: Text(
                                        entry.value.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${entry.value.artist} · ${entry.value.album}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _play(entry.value),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Move up',
                                            onPressed:
                                                entry.key > _queueIndex + 1
                                                ? () => _moveQueueItem(
                                                    entry.key,
                                                    entry.key - 1,
                                                  )
                                                : null,
                                            icon: Icon(
                                              Icons.arrow_upward_rounded,
                                              size: 17,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Move down',
                                            onPressed:
                                                entry.key < _queue.length - 1
                                                ? () => _moveQueueItem(
                                                    entry.key,
                                                    entry.key + 1,
                                                  )
                                                : null,
                                            icon: Icon(
                                              Icons.arrow_downward_rounded,
                                              size: 17,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Remove from queue',
                                            onPressed: () =>
                                                _removeFromQueue(entry.key),
                                            icon: Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              if (_queueIndex >= _queue.length - 1)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    "You're at the end of the queue.",
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ] else ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _artwork(
                                      track.coverArt,
                                      localArtworkPath: track.localArtworkPath,
                                      size: artSize,
                                      seed: track.album,
                                    ),
                                  ),
                                  SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          track.title,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'SyneBold',
                                            fontSize: 21,
                                            letterSpacing: -.7,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => _openArtist(track),
                                          child: Text(
                                            track.artist,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: C.muted,
                                              fontSize: 13,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: C.border,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _openAlbum(track),
                                          child: Text(
                                            track.album,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: C.muted,
                                              fontSize: 11,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: C.border,
                                            ),
                                          ),
                                        ),
                                        _flowPlayerDetails(track),
                                        if (_showVisualizer) ...[
                                          SizedBox(height: 8),
                                          _visualizer(),
                                        ],
                                        SizedBox(height: 10),
                                        IconButton(
                                          tooltip: _favorites.contains(track.id)
                                              ? 'Remove from favorites'
                                              : 'Add to favorites',
                                          alignment: Alignment.center,
                                          padding: EdgeInsets.zero,
                                          onPressed: () =>
                                              _toggleFavorite(track),
                                          icon: Icon(
                                            _favorites.contains(track.id)
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: _favorites.contains(track.id)
                                                ? C.lime
                                                : C.muted,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: 20),
                            _playbackProgress(duration),
                            SizedBox(height: 8),
                            SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: 'Shuffle',
                                  visualDensity: VisualDensity.compact,
                                  constraints: BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  onPressed: _toggleShuffle,
                                  icon: Icon(
                                    Icons.shuffle_rounded,
                                    color: _shuffle ? C.lime : C.muted,
                                    size: 21,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Previous track',
                                  visualDensity: VisualDensity.compact,
                                  constraints: BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  onPressed: () => _skip(-1),
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    size: 27,
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(40),
                                  onTap: _togglePlayback,
                                  child: Semantics(
                                    button: true,
                                    label: _player.playing ? 'Pause' : 'Play',
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: C.lime,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _player.playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: C.black,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Next track',
                                  visualDensity: VisualDensity.compact,
                                  constraints: BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  onPressed: () => _skip(1),
                                  icon: Icon(Icons.skip_next_rounded, size: 27),
                                ),
                                IconButton(
                                  tooltip: _repeatOne
                                      ? 'Repeat one'
                                      : _repeatAll
                                      ? 'Repeat all'
                                      : 'Repeat off',
                                  visualDensity: VisualDensity.compact,
                                  constraints: BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  onPressed: _cycleRepeatMode,
                                  icon: Icon(
                                    Icons.repeat_rounded,
                                    color: (_repeatAll || _repeatOne)
                                        ? C.lime
                                        : C.muted,
                                    size: 21,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _updateState(
                                  () => _showUpNext = !_showUpNext,
                                ),
                                icon: Icon(
                                  _showUpNext
                                      ? Icons.album_rounded
                                      : Icons.queue_music_rounded,
                                ),
                                label: Text(
                                  _showUpNext
                                      ? 'Back to artwork'
                                      : 'Up Next · ${_queue.length - _queueIndex - 1}',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
