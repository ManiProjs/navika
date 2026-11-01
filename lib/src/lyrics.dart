part of '../main.dart';

const _lyricsCachePrefix = 'navika.lyrics.cache.v1.';

extension _LyricsMethods on _HomeScreenState {
  Future<void> _loadLyrics(MusicTrack track, {bool refresh = false}) async {
    if (!refresh &&
        _lyricsTrackId == track.id &&
        (_currentLyrics != null || _lyricsLoading)) {
      return;
    }
    final requestId = ++_lyricsRequestId;
    _updateState(() {
      _lyricsTrackId = track.id;
      _currentLyrics = null;
      _lyricsLoading = true;
      _lyricsError = '';
    });
    _lyricsRevision.value++;
    try {
      final preferences = await SharedPreferences.getInstance();
      final cacheKey =
          '$_lyricsCachePrefix${Uri.encodeComponent('${track.id}|${track.title}|${track.artist}|${track.duration}')}';
      TrackLyrics? lyrics;
      var validCache = false;
      final cached = refresh ? null : preferences.getString(cacheKey);
      if (cached != null) {
        try {
          final entry = Map<String, dynamic>.from(jsonDecode(cached) as Map);
          final savedAt = (entry['savedAt'] as num?)?.toInt() ?? 0;
          final age = DateTime.now().millisecondsSinceEpoch - savedAt;
          final cacheLifetime = entry['notFound'] == true
              ? const Duration(days: 1)
              : const Duration(days: 30);
          if (age >= 0 && age < cacheLifetime.inMilliseconds) {
            validCache = true;
            if (entry['notFound'] != true) {
              lyrics = TrackLyrics.fromJson(
                Map<String, dynamic>.from(entry['lyrics'] as Map),
              );
            }
          }
        } catch (_) {
          await preferences.remove(cacheKey);
        }
      }
      if (!validCache) lyrics = await lrclibClient.fetch(track);
      if (requestId != _lyricsRequestId || !mounted) return;
      if (lyrics != null || !validCache) {
        await preferences.setString(
          cacheKey,
          jsonEncode({
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'notFound': lyrics == null,
            if (lyrics != null) 'lyrics': lyrics.toJson(),
          }),
        );
      }
      _updateState(() {
        _currentLyrics = lyrics;
        _lyricsLoading = false;
        _lyricsError = '';
      });
      _lyricsRevision.value++;
    } catch (error) {
      if (requestId != _lyricsRequestId || !mounted) return;
      _updateState(() {
        _lyricsLoading = false;
        _lyricsError = 'Could not load lyrics: $error';
      });
      _lyricsRevision.value++;
    }
  }

  void _openLyrics(MusicTrack track) {
    _updateState(() {
      _showLyrics = true;
      _showUpNext = false;
    });
    unawaited(_loadLyrics(track));
  }

  Widget _lyricsPanelContent(MusicTrack track) => Expanded(
    child: ValueListenableBuilder<int>(
      valueListenable: _lyricsRevision,
      builder: (context, revision, child) {
        if (_lyricsLoading && _lyricsTrackId == track.id) {
          return const Center(child: CircularProgressIndicator());
        }
        final lyrics = _lyricsTrackId == track.id ? _currentLyrics : null;
        if (lyrics?.instrumental == true) {
          return Center(
            child: Text(
              'Instrumental',
              style: TextStyle(color: C.muted, fontSize: 18),
            ),
          );
        }
        if (lyrics != null && lyrics.lines.isNotEmpty) {
          return ValueListenableBuilder<Duration>(
            valueListenable: _position,
            builder: (context, position, child) => _SynchronizedLyricsList(
              lines: lyrics.lines,
              position: position,
            ),
          );
        }
        if (lyrics?.plainLyrics?.isNotEmpty == true) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 12, bottom: 30),
            child: SelectableText(
              lyrics!.plainLyrics!,
              style: TextStyle(color: C.text, fontSize: 18, height: 1.85),
            ),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lyrics_outlined, size: 34, color: C.muted),
                const SizedBox(height: 12),
                Text(
                  _lyricsError.isNotEmpty
                      ? _lyricsError
                      : 'No lyrics found for this track.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lyrics are provided by LRCLIB.',
                  style: TextStyle(color: C.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _SynchronizedLyricsList extends StatefulWidget {
  const _SynchronizedLyricsList({required this.lines, required this.position});

  final List<LyricLine> lines;
  final Duration position;

  @override
  State<_SynchronizedLyricsList> createState() =>
      _SynchronizedLyricsListState();
}

class _SynchronizedLyricsListState extends State<_SynchronizedLyricsList> {
  late List<GlobalKey> _lineKeys;
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant _SynchronizedLyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lines, widget.lines)) {
      _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
      _activeIndex = -1;
    }
  }

  int _indexAt(Duration position) {
    var low = 0;
    var high = widget.lines.length - 1;
    var result = -1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      if (widget.lines[middle].time <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final nextIndex = _indexAt(widget.position);
    if (nextIndex != _activeIndex) {
      _activeIndex = nextIndex;
      if (nextIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final lineContext = _lineKeys[nextIndex].currentContext;
          if (mounted && lineContext != null) {
            Scrollable.ensureVisible(
              lineContext,
              alignment: .48,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 28),
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final active = index == _activeIndex;
        return Padding(
          key: _lineKeys[index],
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: TextStyle(
              color: active ? C.text : C.muted.withValues(alpha: .68),
              fontFamily: active ? 'DMSansBold' : 'DMSans',
              fontSize: active ? 23 : 18,
              height: 1.35,
            ),
            child: Text(widget.lines[index].text),
          ),
        );
      },
    );
  }
}
