part of '../main.dart';

extension _MiniPlayerMethods on _HomeScreenState {
  Widget _miniPlayer() {
    final track = _current!;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: C.surface,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: C.border)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _openFullPlayer,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            _artwork(
                              track.coverArt,
                              localArtworkPath: track.localArtworkPath,
                              size: 42,
                              seed: track.album,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    track.artist,
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
                      ),
                    ),
                    IconButton(
                      onPressed: _togglePlayback,
                      icon: ValueListenableBuilder<bool>(
                        valueListenable: _isPlaying,
                        builder: (context, playing, _) => Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: C.lime,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _skip(1),
                      icon: Icon(Icons.skip_next_rounded),
                    ),
                    IconButton(
                      tooltip: 'Open player',
                      onPressed: _openFullPlayer,
                      icon: Icon(Icons.open_in_full_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 2,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: _position,
                    builder: (context, position, _) {
                      final duration = _player.duration?.inMilliseconds ?? 0;
                      final progress = duration <= 0
                          ? 0.0
                          : (position.inMilliseconds / duration).clamp(
                              0.0,
                              1.0,
                            );
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: ColoredBox(color: C.lime),
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

  void _openFullPlayer() {
    if (_current == null || _showPlayer) return;
    _updateState(() {
      _showUpNext = false;
      _showPlayer = true;
    });
  }

  Widget _tabBar() {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [AppTab.home, AppTab.search, AppTab.library, AppTab.playlists]
            .map((tab) {
              final active =
                  _tab == tab ||
                  (tab == AppTab.library &&
                      (_tab == AppTab.favorites || _tab == AppTab.stats));

              return Expanded(
                child: InkWell(
                  onTap: () => _selectTab(tab),
                  child: SizedBox(
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: active ? 1 : 0.96,
                              duration: _reduceMotion
                                  ? Duration.zero
                                  : Duration(milliseconds: 110),
                              curve: Curves.easeOut,
                              child: Icon(
                                tab.icon,
                                size: 22,
                                color: active ? C.lime : C.muted,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontFamily: 'DMSansMedium',
                                fontSize: 9,
                                color: active ? C.lime : C.muted,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 0,
                          child: AnimatedContainer(
                            width: active ? 18 : 0,
                            height: 2,
                            duration: _reduceMotion
                                ? Duration.zero
                                : Duration(milliseconds: 120),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: C.lime,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(),
      ),
    );
  }
}
