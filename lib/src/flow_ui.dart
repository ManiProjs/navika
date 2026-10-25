part of '../main.dart';

extension _FlowUiMethods on _HomeScreenState {
  Widget _flowOverlay() {
    final accent = C.lime;
    final preview = _flowActive
        ? _queue.skip(_queueIndex + 1).take(5).toList()
        : _buildFlowQueue().take(5).toList();
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    if (_flowPage == 0) {
      return _flowWelcome(isMacOS: isMacOS, accent: accent);
    }
    return _flowPageEntrance(
      page: 1,
      child: Material(
        color: C.bg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(isMacOS ? 82 : 14, 4, 18, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _flowActive ? 'Close Flow' : 'Back to welcome',
                      onPressed: () => _updateState(() {
                        if (_flowActive) {
                          _showFlow = false;
                        } else {
                          _flowPage = 0;
                        }
                      }),
                      icon: Icon(
                        _flowActive
                            ? Icons.close_rounded
                            : Icons.arrow_back_rounded,
                      ),
                    ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'navika flow',
                            style: TextStyle(
                              fontFamily: 'SyneBold',
                              fontSize: 23,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_flowActive)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'LIVE',
                          style: TextStyle(
                            color: accent,
                            fontFamily: 'DMSansBold',
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _flowStepProgress(activeStep: 1),
                          SizedBox(height: 24),
                          Text(
                            'Choose your taste',
                            style: TextStyle(
                              fontFamily: 'SyneBold',
                              fontSize: 30,
                              letterSpacing: -1.1,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Tune the mix, then preview your first picks below.',
                            style: TextStyle(
                              color: C.muted,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 20),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Familiarity',
                                        style: TextStyle(
                                          fontFamily: 'DMSansBold',
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _flowFamiliarity > .68
                                          ? 'Comfort zone'
                                          : (_flowFamiliarity < .32
                                                ? 'Discover'
                                                : 'A bit of both'),
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Lean into artists you know, or explore less-played music.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                _flowSlider(
                                  value: _flowFamiliarity,
                                  onChanged: (value) => _updateState(
                                    () => _flowFamiliarity = value,
                                  ),
                                  onChangeEnd: () {
                                    if (_flowActive) _refreshFlowQueue();
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'DISCOVER',
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 9,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      'FAMILIAR',
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 9,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Artist variety',
                                        style: TextStyle(
                                          fontFamily: 'DMSansBold',
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _flowVariety > .68
                                          ? 'Eclectic'
                                          : (_flowVariety < .32
                                                ? 'Longer runs'
                                                : 'Balanced'),
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Choose how often Flow switches to a different artist.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                _flowSlider(
                                  value: _flowVariety,
                                  onChanged: (value) =>
                                      _updateState(() => _flowVariety = value),
                                  onChangeEnd: () {
                                    if (_flowActive) _refreshFlowQueue();
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (_flowActive && _current != null) ...[
                            SizedBox(height: 20),
                            Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                color: accent,
                                fontFamily: 'DMSansBold',
                                fontSize: 9,
                                letterSpacing: 1.3,
                              ),
                            ),
                            SizedBox(height: 10),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _updateState(() {
                                _showFlow = false;
                                _showPlayer = true;
                                _showUpNext = false;
                              }),
                              child: Row(
                                children: [
                                  _artwork(
                                    _current!.coverArt,
                                    localArtworkPath:
                                        _current!.localArtworkPath,
                                    size: 66,
                                    seed: _current!.album,
                                  ),
                                  SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _current!.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'DMSansBold',
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _current!.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: C.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          _flowReason(_current!),
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _player.playing ? 'Pause' : 'Play',
                                    onPressed: _togglePlayback,
                                    icon: Icon(
                                      _player.playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: accent,
                                      size: 29,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Next track',
                                    onPressed: () => _skip(1),
                                    icon: Icon(
                                      Icons.skip_next_rounded,
                                      color: accent,
                                      size: 27,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _rateCurrentTrack(like: true),
                                    icon: Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 16,
                                    ),
                                    label: Text('More like this'),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _rateCurrentTrack(like: false),
                                    icon: Icon(
                                      Icons.thumb_down_alt_outlined,
                                      size: 16,
                                    ),
                                    label: Text('Less like this'),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14),
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Flow controls',
                                          style: TextStyle(
                                            fontFamily: 'DMSansBold',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${math.max(0, _queue.length - _queueIndex - 1)} upcoming',
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Shape the session without changing what you think of the artist.',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 10,
                                      height: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _togglePlayback,
                                        icon: Icon(
                                          _player.playing
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          _player.playing
                                              ? 'Pause Flow'
                                              : 'Resume Flow',
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _skip(1),
                                        icon: Icon(
                                          Icons.skip_next_rounded,
                                          size: 16,
                                        ),
                                        label: Text('Skip track'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _clearFlowHiddenTracks,
                                        icon: Icon(
                                          Icons.restart_alt_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Restore hidden (${_flowHiddenTrackIds.length})',
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _updateState(() {
                                          _flowActive = false;
                                          _showFlow = false;
                                          _showPlayer = false;
                                        }),
                                        icon: Icon(
                                          Icons.stop_circle_outlined,
                                          size: 16,
                                        ),
                                        label: Text('End Flow'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _flowActive
                                      ? 'Coming up'
                                      : 'Your first picks',
                                  style: TextStyle(
                                    fontFamily: 'SyneBold',
                                    fontSize: 20,
                                    letterSpacing: -.4,
                                  ),
                                ),
                              ),
                              Text(
                                '${preview.length} tracks',
                                style: TextStyle(color: C.muted, fontSize: 10),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          if (preview.isEmpty)
                            _card(
                              child: Text(
                                'Open Library and load your music to give Flow something to work with.',
                                style: TextStyle(
                                  color: C.muted,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            )
                          else
                            ...preview.asMap().entries.map((entry) {
                              final track = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: TextStyle(
                                          color: C.muted,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    _artwork(
                                      track.coverArt,
                                      localArtworkPath: track.localArtworkPath,
                                      size: 42,
                                      seed: track.album,
                                    ),
                                    SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'DMSansMedium',
                                              fontSize: 12,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            '${track.artist} · ${_flowReason(track)}',
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
                                  ],
                                ),
                              );
                            }),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _modeTracks.isEmpty
                                  ? null
                                  : (_flowActive
                                        ? _refreshFlowQueue
                                        : _startFlow),
                              icon: Icon(
                                _flowActive
                                    ? Icons.refresh_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                _flowActive
                                    ? 'Refresh upcoming tracks'
                                    : 'Start Navika Flow',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: C.bg,
                              ),
                            ),
                          ),
                          if (_flowActive) ...[
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => _updateState(() {
                                  _flowActive = false;
                                  _showFlow = false;
                                }),
                                child: Text(
                                  'End Flow session',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flowPageEntrance({required int page, required Widget child}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('flow-page-$page'),
      tween: Tween(begin: 0, end: 1),
      duration: _reduceMotion ? Duration.zero : Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 8),
          child: child,
        ),
      ),
    );
  }

  Widget _flowStepProgress({required int activeStep}) {
    return Row(
      children: List.generate(
        2,
        (index) => Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index == 0 ? 7 : 0),
            decoration: BoxDecoration(
              color: index <= activeStep ? C.lime : C.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _flowSlider({
    required double value,
    required ValueChanged<double> onChanged,
    required VoidCallback onChangeEnd,
  }) {
    return _FlowSlider(
      value: value,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }

  Widget _flowWelcome({required bool isMacOS, required Color accent}) {
    return _flowPageEntrance(
      page: 0,
      child: Material(
        color: C.bg,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(isMacOS ? 82 : 14, 4, 18, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close Navika Flow',
                      onPressed: () => _updateState(() => _showFlow = false),
                      icon: Icon(Icons.close_rounded),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: C.lime,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                      'navika flow',
                      style: TextStyle(
                        fontFamily: 'SyneBold',
                        fontSize: 23,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _flowStepProgress(activeStep: 0),
                          SizedBox(height: 34),
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: C.lime,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _brandLine(22),
                                SizedBox(width: 4),
                                _brandLine(31),
                                SizedBox(width: 4),
                                _brandLine(16),
                              ],
                            ),
                          ),
                          SizedBox(height: 28),
                          Text(
                            'Your music,\nyour momentum.',
                            style: TextStyle(
                              fontFamily: 'SyneBold',
                              fontSize: 42,
                              height: 1.05,
                              letterSpacing: -1.8,
                            ),
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Navika Flow builds a listening queue from your library, history, and favorites. Shape the balance between familiar tracks and new discoveries, then let the music run.',
                            style: TextStyle(
                              color: C.muted,
                              fontSize: 13,
                              height: 1.75,
                            ),
                          ),
                          SizedBox(height: 18),
                          Row(
                            children: [
                              Icon(
                                Icons.devices_rounded,
                                color: accent,
                                size: 17,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your listening data stays on this device.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _updateState(() => _flowPage = 1),
                              icon: Icon(Icons.arrow_forward_rounded),
                              label: Text('Choose your taste'),
                              style: FilledButton.styleFrom(
                                backgroundColor: C.lime,
                                foregroundColor: C.bg,
                              ),
                            ),
                          ),
                          if (_modeTracks.isEmpty) ...[
                            SizedBox(height: 12),
                            Text(
                              'Load music in your Library to get your first picks.',
                              style: TextStyle(color: C.muted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
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
