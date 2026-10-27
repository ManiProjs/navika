part of '../main.dart';

extension _SharedWidgetMethods on _HomeScreenState {
  Widget _credentialStorageWarning() {
    if (!Platform.isIOS && !Platform.isMacOS) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.danger.withValues(alpha: .08),
        border: Border.all(color: C.danger.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'WARNING: Your Navidrome credentials are stored in plain text because of.... well.... Apple!.',
        style: TextStyle(fontSize: 12, height: 1.5),
      ),
    );
  }

  List<Color> _playerAmbientColors() {
    // Sample the current cover for a restrained ambient tint. Missing or
    // unreadable artwork falls back to Navika's signature lime.
    final accent = _artworkAccentColor ?? C.lime;
    return [Color.lerp(accent, C.bg, C.light ? .78 : .82)!, C.bg];
  }

  Widget _trackRow(MusicTrack track, int index) {
    final active = _current?.id == track.id;

    return InkWell(
      onTap: () => _play(track),
      onLongPress: () => _showTrackMenu(track),
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
                  Row(
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: () => _openArtist(track),
                          child: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: C.muted, fontSize: 11),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          '·',
                          style: TextStyle(color: C.muted, fontSize: 11),
                        ),
                      ),
                      Flexible(
                        child: InkWell(
                          onTap: () => _openAlbum(track),
                          child: Text(
                            track.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: C.muted, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(
              _formatTime(track.duration.toDouble()),
              style: TextStyle(color: C.muted, fontSize: 10),
            ),
            IconButton(
              tooltip: 'More options',
              onPressed: () => _showTrackMenu(track),
              icon: Icon(Icons.more_horiz_rounded, color: C.muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artwork(
    String? coverArt, {
    String? localArtworkPath,
    required double size,
    required String seed,
  }) {
    final url = coverArt == null ? null : _client?.coverArtUrl(coverArt);
    final pixelSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 2048);

    final colors = [
      Color(0xFF3B4430),
      Color(0xFF35333E),
      Color(0xFF3D3329),
      Color(0xFF303C3A),
    ];

    final color = colors[seed.hashCode.abs() % colors.length];

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: localArtworkPath != null
            ? Image.file(
                File(localArtworkPath),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: pixelSize,
                cacheHeight: pixelSize,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return ColoredBox(
                    color: color,
                    child: Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: C.lime,
                        size: 30,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: color,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: C.lime,
                    size: 30,
                  ),
                ),
              )
            : url == null
            ? Container(
                color: color,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        size: size.isFinite ? size * .4 : 40,
                        color: C.lime,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: C.lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: pixelSize,
                cacheHeight: pixelSize,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return ColoredBox(
                    color: color,
                    child: Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: C.lime,
                        size: 30,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: color,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: C.lime,
                    size: 30,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontFamily: 'DMSansBold', fontSize: 19),
            ),
          ),
          if (action != null)
            Material(
              color: C.surface2,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(9),
                hoverColor: C.lime.withValues(alpha: .10),
                splashColor: C.lime.withValues(alpha: .18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: C.border),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      color: C.lime,
                      fontFamily: 'DMSansBold',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _homeStat(String value, String label) {
    return Container(
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontFamily: 'DMSansBold', fontSize: 21)),
          SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: C.muted,
              fontFamily: 'DMSansBold',
              fontSize: 10,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, {required double width}) {
    return SizedBox(width: width, child: _homeStat(value, label));
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: C.muted,
          fontFamily: 'DMSansBold',
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _actionButton(String label, {required VoidCallback onTap}) {
    return Material(
      color: C.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: C.lime.withValues(alpha: .10),
        splashColor: C.lime.withValues(alpha: .18),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: C.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: C.lime,
                  fontFamily: 'DMSansBold',
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: C.lime, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visualizer() {
    return _Visualizer(player: _player, position: _position);
  }

  Widget _playbackProgress(double duration) {
    return ValueListenableBuilder<Duration>(
      valueListenable: _position,
      builder: (context, position, _) {
        final seconds = position.inSeconds.toDouble();
        final progress = duration <= 0
            ? 0.0
            : (seconds / duration).clamp(0.0, 1.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seekBar(progress, duration),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(seconds),
                  style: TextStyle(color: C.muted, fontSize: 10),
                ),
                Text(
                  _formatTime(duration),
                  style: TextStyle(color: C.muted, fontSize: 10),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _seekBar(double progress, double duration) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _pendingSeekPosition = null;
        _updateState(() => _seeking = true);
      },
      onHorizontalDragUpdate: (details) =>
          _previewSeek(details.globalPosition, duration),
      onHorizontalDragEnd: (_) => _finishSeeking(duration),
      onHorizontalDragCancel: () => _finishSeeking(duration),
      onTapDown: (details) => _seekTo(details.globalPosition, duration),
      child: SizedBox(
        key: _progressBarKey,
        height: 16,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final thumbSize = _seeking ? 20.0 : 12.0;
            final thumbLeft = (width * progress - thumbSize / 2).clamp(
              0.0,
              (width - thumbSize).clamp(0.0, double.infinity),
            );
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 4,
                    width: width,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: C.border)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            // Position ticks arrive frequently. Keep the fill
                            // close to the playhead instead of making it chase
                            // an animation that is still in flight.
                            duration: _reduceMotion
                                ? Duration.zero
                                : Duration(milliseconds: _seeking ? 30 : 45),
                            curve: Curves.easeOutCubic,
                            widthFactor: progress,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ColoredBox(color: C.lime),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    width: 2,
                                    color: C.lime,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  left: thumbLeft,
                  duration: _reduceMotion
                      ? Duration.zero
                      : Duration(milliseconds: _seeking ? 30 : 45),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: C.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.text, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Color(0x55000000), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(
    String title,
    String subtitle, {
    String? action,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'DMSansBold', fontSize: 17),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: C.muted, fontSize: 12, height: 1.6),
          ),
          if (action != null && onTap != null) ...[
            SizedBox(height: 16),
            _actionButton(action, onTap: onTap),
          ],
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    if (!seconds.isFinite || seconds < 0) return '0:00';
    final minutes = seconds ~/ 60;
    final remaining = seconds.floor() % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }
}

class _Visualizer extends StatefulWidget {
  const _Visualizer({required this.player, required this.position});

  final AudioPlayer player;
  final ValueListenable<Duration> position;

  @override
  State<_Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<_Visualizer> {
  late bool _playing;
  StreamSubscription<PlayerState>? _subscription;

  @override
  void initState() {
    super.initState();
    _playing = widget.player.playing;
    widget.position.addListener(_onPosition);
    _subscription = widget.player.playerStateStream.listen((state) {
      if (!mounted || _playing == state.playing) return;
      setState(() => _playing = state.playing);
    });
  }

  void _onPosition() {
    if (_playing && mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.position.removeListener(_onPosition);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.position.value.inMilliseconds / 180;
    return RepaintBoundary(
      child: Container(
        height: 54,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: C.black.withValues(alpha: .35),
          border: Border.all(color: C.border.withValues(alpha: .7)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(24, (index) {
            final wave = (math.sin(phase + index * .68) + 1) / 2;
            final envelope = .25 + .75 * math.sin((index + 1) * math.pi / 25);
            final height = _playing
                ? 5 + wave * envelope * 32
                : 5 + envelope * 7;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 70),
                  height: height,
                  decoration: BoxDecoration(
                    color: _playing
                        ? C.lime.withValues(alpha: .55 + wave * .45)
                        : C.muted.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
