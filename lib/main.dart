import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navidrome_client.dart';

Future<void> _audioServiceReady = Future<void>.value();
bool _audioServiceInitializationRequired = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    _audioServiceInitializationRequired = true;
    _audioServiceReady =
        JustAudioBackground.init(
          androidNotificationChannelId: 'app.navika.audio',
          androidNotificationChannelName: 'Navika playback',
          androidNotificationOngoing: true,
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint('Navika audio service initialization failed: $error');
        });
  }
  // Render Flutter's first frame immediately instead of keeping Android's
  // launch screen up while audio_service initializes.
  runApp(const NavikaApp());
}

enum NavikaTheme { dark, amoled, light }

const _themeKey = 'navika.theme';
final ValueNotifier<NavikaTheme> _themeMode = ValueNotifier(NavikaTheme.dark);

abstract final class C {
  static bool get light => _themeMode.value == NavikaTheme.light;
  static bool get amoled => _themeMode.value == NavikaTheme.amoled;
  static Color get bg => light
      ? Color(0xFFF6F6F3)
      : (amoled ? Color(0xFF000000) : Color(0xFF100F0D));
  static Color get surface => light
      ? Color(0xFFFFFFFF)
      : (amoled ? Color(0xFF090909) : Color(0xFF1B1916));
  static Color get surface2 => light
      ? Color(0xFFEBEBE6)
      : (amoled ? Color(0xFF141414) : Color(0xFF24211D));
  static Color get border => light
      ? Color(0xFFD8D8D0)
      : (amoled ? Color(0xFF242424) : Color(0xFF302D28));
  static Color get text => light ? Color(0xFF171713) : Color(0xFFF5F3EC);
  static Color get muted => light ? Color(0xFF68685F) : Color(0xFFA29D91);
  static Color get lime => light ? Color(0xFF426600) : Color(0xFFD6FF39);
  static Color get black => light ? const Color(0xFFFFFFFF) : bg;
  static Color get danger => light ? Color(0xFFB42318) : Color(0xFFFF8585);
}

const _credentialsKey = 'navika.navidrome.credentials';
const _historyKey = 'navika.listening.history';
const _favoritesKey = 'navika.favorites';
const _motionKey = 'navika.reduce-motion';
const _playlistsKey = 'navika.local.playlists';
const _autoAdvanceKey = 'navika.playback.auto-advance';
const _visualizerKey = 'navika.playback.visualizer';
const _shuffleKey = 'navika.playback.shuffle';
const _repeatAllKey = 'navika.playback.repeat-all';
const _repeatOneKey = 'navika.playback.repeat-one';
const _queueKey = 'navika.playback.queue';
const _recommendationFeedbackKey = 'navika.recommendations.dismissed';
const _tasteProfileKey = 'navika.taste-profile.v1';
const _flowHiddenTracksKey = 'navika.flow.hidden-tracks.v1';
const _librarySourceKey = 'navika.library-source.v1';
const _speedKey = 'navika.playback.speed';
const _localTracksKey = 'navika.local.tracks';
const _localFoldersKey = 'navika.local.folders';
const _androidLocalFolders = MethodChannel('app.navika/local_folders');
const _localFolderRescanInterval = Duration(minutes: 1);

Map<String, Object?> _readEmbeddedMetadata(String path) {
  final metadata = readMetadata(File(path), getImage: true);
  final frontCover = metadata.pictures.where(
    (picture) => picture.pictureType == PictureType.coverFront,
  );
  final picture = frontCover.isNotEmpty
      ? frontCover.first
      : (metadata.pictures.isEmpty ? null : metadata.pictures.first);
  return {
    'title': metadata.title,
    'artist': metadata.artist ?? metadata.albumArtist,
    'album': metadata.album,
    'duration': metadata.duration?.inSeconds,
    'artwork': picture?.bytes,
  };
}

enum AppTab { home, search, library, playlists, favorites, stats }

extension AppTabInfo on AppTab {
  String get label => switch (this) {
    AppTab.home => 'Home',
    AppTab.search => 'Search',
    AppTab.library => 'Library',
    AppTab.playlists => 'Playlists',
    AppTab.favorites => 'Favorites',
    AppTab.stats => 'Stats',
  };

  IconData get icon => switch (this) {
    AppTab.home => Icons.home_outlined,
    AppTab.search => Icons.search_rounded,
    AppTab.library => Icons.library_music_outlined,
    AppTab.playlists => Icons.queue_music_rounded,
    AppTab.favorites => Icons.favorite_border_rounded,
    AppTab.stats => Icons.bar_chart_rounded,
  };
}

class NavikaApp extends StatelessWidget {
  const NavikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NavikaTheme>(
      valueListenable: _themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Navika',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: mode == NavikaTheme.light
              ? Brightness.light
              : Brightness.dark,
          scaffoldBackgroundColor: C.bg,
          canvasColor: C.bg,
          fontFamily: 'DMSans',
          colorScheme: ColorScheme(
            brightness: mode == NavikaTheme.light
                ? Brightness.light
                : Brightness.dark,
            primary: C.lime,
            onPrimary: C.black,
            surface: C.surface,
            onSurface: C.text,
            outline: C.border,
            error: C.danger,
            onError: Colors.white,
            primaryContainer: C.surface2,
            onPrimaryContainer: C.text,
            secondary: C.lime,
            onSecondary: C.black,
            secondaryContainer: C.surface2,
            onSecondaryContainer: C.text,
            tertiary: C.lime,
            onTertiary: C.black,
            tertiaryContainer: C.surface2,
            onTertiaryContainer: C.text,
            errorContainer: C.danger,
            onErrorContainer: Colors.white,
            surfaceContainerHighest: C.surface2,
            onSurfaceVariant: C.muted,
            inverseSurface: C.text,
            onInverseSurface: C.bg,
            inversePrimary: C.lime,
            shadow: Colors.black,
            scrim: Colors.black,
            surfaceTint: C.lime,
          ),
          textTheme: TextTheme(
            bodyLarge: TextStyle(fontFamily: 'DMSans', color: C.text),
            bodyMedium: TextStyle(fontFamily: 'DMSans', color: C.text),
            bodySmall: TextStyle(fontFamily: 'DMSans', color: C.text),
            titleLarge: TextStyle(fontFamily: 'SyneBold', color: C.text),
            headlineMedium: TextStyle(fontFamily: 'SyneBold', color: C.text),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: C.bg,
            hintStyle: TextStyle(
              color: C.muted,
              fontFamily: 'DMSans',
              fontSize: 13,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.lime),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: C.lime,
              foregroundColor: C.black,
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: const TextStyle(
                fontFamily: 'DMSansBold',
                fontSize: 12,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: C.text,
              side: BorderSide(color: C.border),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: const TextStyle(
                fontFamily: 'DMSansBold',
                fontSize: 12,
              ),
            ),
          ),
          dividerColor: C.border,
          useMaterial3: true,
        ),
        home: const _StartupGate(),
      ),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    if (!_audioServiceInitializationRequired) return const HomeScreen();
    return FutureBuilder<void>(
      future: _audioServiceReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const HomeScreen();
        }
        return Scaffold(
          backgroundColor: C.bg,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'navika',
                  style: TextStyle(
                    fontFamily: 'SyneBold',
                    fontSize: 38,
                    color: C.text,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: C.lime,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NewPlaylistDialog extends StatefulWidget {
  const _NewPlaylistDialog();

  @override
  State<_NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _FlowSlider extends StatefulWidget {
  const _FlowSlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  State<_FlowSlider> createState() => _FlowSliderState();
}

class _FlowSliderState extends State<_FlowSlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _FlowSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  void _update(double dx, double width) {
    if (width <= 0) return;
    setState(() => _value = (dx / width).clamp(0.0, 1.0));
  }

  void _finish() {
    widget.onChanged(_value);
    widget.onChangeEnd();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _update(details.localPosition.dx, width),
            onTapUp: (_) => _finish(),
            onHorizontalDragUpdate: (details) =>
                _update(details.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _finish(),
            child: Center(
              child: SizedBox(
                height: 4,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: C.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: Duration(milliseconds: 90),
                      curve: Curves.easeOutCubic,
                      widthFactor: _value,
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: C.lime,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: C.lime,
                                boxShadow: [
                                  BoxShadow(
                                    color: C.lime.withValues(alpha: .6),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedPositioned(
                      left: (width * _value - 7).clamp(-1.0, width - 13),
                      top: -5,
                      duration: Duration(milliseconds: 90),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: C.lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.bg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewPlaylistDialogState extends State<_NewPlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: C.surface,
      title: Text('New playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (value) {
          final name = value.trim();
          if (name.isNotEmpty) Navigator.pop(context, name);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
          child: Text('Create'),
        ),
      ],
    );
  }
}

class _PlaylistTrackPicker extends StatefulWidget {
  const _PlaylistTrackPicker({
    required this.tracks,
    required this.existingIds,
    required this.artwork,
  });

  final List<MusicTrack> tracks;
  final Set<String> existingIds;
  final Widget Function(MusicTrack track) artwork;

  @override
  State<_PlaylistTrackPicker> createState() => _PlaylistTrackPickerState();
}

class _PlaylistTrackPickerState extends State<_PlaylistTrackPicker> {
  final _search = TextEditingController();
  final Set<String> _selected = {};

  List<MusicTrack> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.tracks;
    return widget.tracks
        .where(
          (track) => '${track.title} ${track.artist} ${track.album}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _filtered;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose tracks',
                      style: TextStyle(fontFamily: 'SyneBold', fontSize: 22),
                    ),
                  ),
                  Text(
                    '${_selected.length} selected',
                    style: TextStyle(color: C.lime, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search title, artist, or album',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    '${tracks.length} tracks',
                    style: TextStyle(color: C.muted, fontSize: 11),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed:
                        tracks
                            .where((t) => !widget.existingIds.contains(t.id))
                            .isEmpty
                        ? null
                        : () {
                            setState(() {
                              final available = tracks
                                  .where(
                                    (t) => !widget.existingIds.contains(t.id),
                                  )
                                  .map((t) => t.id);
                              if (available.every(_selected.contains)) {
                                _selected.removeAll(available);
                              } else {
                                _selected.addAll(available);
                              }
                            });
                          },
                    child: Text('Select all results'),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Text(
                        'No matching tracks',
                        style: TextStyle(color: C.muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final alreadyAdded = widget.existingIds.contains(
                          track.id,
                        );
                        final selected = _selected.contains(track.id);
                        return ListTile(
                          enabled: !alreadyAdded,
                          leading: widget.artwork(track),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            alreadyAdded
                                ? '${track.artist} · Already in playlist'
                                : '${track.artist} · ${track.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: alreadyAdded
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: C.muted,
                                  size: 20,
                                )
                              : Checkbox(
                                  value: selected,
                                  onChanged: (_) => setState(() {
                                    if (selected) {
                                      _selected.remove(track.id);
                                    } else {
                                      _selected.add(track.id);
                                    }
                                  }),
                                ),
                          onTap: alreadyAdded
                              ? null
                              : () => setState(() {
                                  if (selected) {
                                    _selected.remove(track.id);
                                  } else {
                                    _selected.add(track.id);
                                  }
                                }),
                        );
                      },
                    ),
            ),
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              widget.tracks
                                  .where(
                                    (track) => _selected.contains(track.id),
                                  )
                                  .toList(),
                            ),
                      icon: Icon(Icons.playlist_add_rounded),
                      label: Text('Add ${_selected.length} tracks'),
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
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  final GlobalKey _progressBarKey = GlobalKey();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  Timer? _searchTimer;
  Timer? _sleepTimer;
  Timer? _folderScanTimer;
  int _searchRequestId = 0;
  final Set<String> _dismissedRecommendations = {};
  final Map<String, int> _tasteArtistFeedback = {};
  final Map<String, int> _tasteTrackFeedback = {};
  final Set<String> _flowHiddenTrackIds = {};
  double _playbackSpeed = 1.0;
  double _flowFamiliarity = .62;
  double _flowVariety = .68;
  Color? _artworkAccentColor;
  int _artworkColorRequest = 0;

  AppTab _tab = AppTab.home;
  bool _showLocalLibrary = false;
  NavidromeClient? _client;
  NavidromeCredentials? _credentials;

  List<MusicTrack> _tracks = [];
  List<MusicTrack> _localTracks = [];
  List<String> _localFolders = [];
  List<MusicTrack> _searchResults = [];
  List<MusicTrack> _queue = [];
  List<ListeningEvent> _history = [];
  List<String> _favorites = [];
  Map<String, List<String>> _playlists = {};

  MusicTrack? _current;
  int _queueIndex = 0;

  bool _connected = false;
  bool _libraryLoaded = false;
  bool _loading = false;
  bool _searching = false;
  bool _busy = false;
  bool _showLogin = false;
  bool _showSettings = false;
  bool _showPlayer = false;
  bool _showFlow = false;
  int _flowPage = 0;
  bool _flowActive = false;
  bool _showUpNext = false;
  bool _showVisualizer = false;
  bool _reduceMotion = false;
  bool _autoAdvance = true;
  bool _shuffle = false;
  bool _repeatAll = false;
  bool _repeatOne = false;
  bool _handlingCompletion = false;
  bool _seeking = false;
  Offset? _pendingSeekPosition;
  bool _scanningLocalFolders = false;
  bool _localFolderScanRequested = false;
  bool _pendingFolderScanFeedback = false;

  String _error = '';
  String _libraryError = '';
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    _restore();

    _playerSubscriptions.add(
      _player.playerStateStream.listen((_) {
        if (mounted) setState(() {});
      }),
    );

    _playerSubscriptions.add(
      _player.currentIndexStream.listen((_) {
        if (mounted) setState(() {});
      }),
    );

    _playerSubscriptions.add(
      _player.positionStream.listen((position) {
        // Position ticks arrive several times per second. Keep them out of the
        // page-level setState so a progress update doesn't rebuild the entire
        // library, settings, artwork shelves, and navigation on older phones.
        if (!_seeking) _position.value = position;
      }),
    );
    _playerSubscriptions.add(
      _player.durationStream.listen((_) {
        if (mounted) setState(() {});
      }),
    );
    _playerSubscriptions.add(
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed && mounted) {
          unawaited(_advanceAfterCompletion());
        }
      }),
    );

    _playerSubscriptions.add(
      _player.errorStream.listen((error) {
        if (!mounted) return;
        setState(() => _error = _describePlaybackError(error));
      }),
    );
  }

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

  Map<String, MusicTrack> get _tracksById => {
    for (final track in _modeTracks) track.id: track,
  };

  List<MusicTrack> get _modeTracks => _showLocalLibrary
      ? _mergeLibraryTracks(_localTracks)
      : _mergeLibraryTracks(_tracks.where((track) => !track.isLocal));

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

  List<MusicTrack> get _favoriteTracks =>
      _favorites.map((id) => _tracksById[id]).whereType<MusicTrack>().toList();

  void _selectTab(AppTab tab) {
    setState(() {
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
      setState(() {
        if (_flowActive) {
          _showFlow = false;
        } else if (_flowPage > 0) {
          _flowPage = 0;
        } else {
          _showFlow = false;
        }
      });
    } else if (_showVisualizer) {
      setState(() => _showVisualizer = false);
    } else if (_showUpNext) {
      setState(() => _showUpNext = false);
    } else if (_showPlayer) {
      setState(() => _showPlayer = false);
    } else if (_showSettings) {
      setState(() => _showSettings = false);
    } else if (_showLogin) {
      setState(() => _showLogin = false);
    } else if (_tab != AppTab.home) {
      _selectTab(AppTab.home);
    }
  }

  void _runSearch(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    final requestId = ++_searchRequestId;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
        _searchError = '';
      });
      return;
    }
    if (_showLocalLibrary || !_connected || _client == null) {
      final normalized = query.toLowerCase();
      setState(() {
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

    setState(() {
      _searching = true;
      _searchError = '';
    });
    _searchTimer = Timer(Duration(milliseconds: 300), () async {
      try {
        final results = await _client!.searchTracks(query);
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
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
        setState(() {
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
        _folderScanTimer ??= Timer.periodic(
          _localFolderRescanInterval,
          (_) => unawaited(_scanLocalFolders()),
        );
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

    _favorites = preferences.getStringList(_favoritesKey) ?? [];

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
        setState(() {
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

      setState(() {
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
      setState(() {
        _connected = false;
        _showLogin = true;
        _error = 'Reconnect to your Navidrome server to continue.';
      });
    }

    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    final url = _url.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final username = _username.text.trim();
    final password = _password.text;

    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      setState(
        () => _error =
            'Enter a complete server URL, including http:// or https://.',
      );
      return;
    }

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your Navidrome username and password.');
      return;
    }

    setState(() {
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

      setState(() {
        _credentials = credentials;
        _client = client;
        _tracks = List.of(_localTracks);
        _queue = [];
        _queueIndex = 0;
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
      setState(() {
        _busy = false;
        _connected = false;
        _error = 'Connection failed: $error';
      });
    }
  }

  Future<void> _loadLibrary({bool force = false}) async {
    final client = _client;
    if (client == null || (_libraryLoaded && !force) || _loading) return;

    setState(() {
      _loading = true;
      _libraryError = '';
    });

    try {
      final tracks = await client.getLibraryTracks();
      if (!mounted) return;

      setState(() {
        _tracks = _mergeLibraryTracks([...tracks, ..._localTracks]);
        if (_queue.isEmpty) _queue = tracks;
        _libraryLoaded = true;
        _loading = false;
        _connected = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
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
      setState(() {
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
      setState(() => _localFolders = folders);
      _folderScanTimer ??= Timer.periodic(
        _localFolderRescanInterval,
        (_) => unawaited(_scanLocalFolders()),
      );
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
    setState(() {
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
        final digest = md5.convert(utf8.encode(path)).toString();
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
    );
  }

  Future<void> _scanLocalFolders({bool showFeedback = false}) async {
    if (_localFolders.isEmpty) return;
    if (_scanningLocalFolders) {
      // A folder can be added while startup or the periodic refresh is already
      // scanning. Never drop that request: run another pass with the latest
      // folder list as soon as the active scan finishes.
      _localFolderScanRequested = true;
      _pendingFolderScanFeedback = _pendingFolderScanFeedback || showFeedback;
      return;
    }
    _scanningLocalFolders = true;
    try {
      final discovered = <String, MusicTrack>{};
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
            final directory = Directory(folder);
            if (!await directory.exists()) {
              inaccessibleFolders.add(folder);
              folderErrors[folder] = 'Folder no longer exists';
              continue;
            }
            final found = <String>[];
            await for (final entity in directory.list(
              recursive: true,
              followLinks: false,
            )) {
              if (entity is File && _isAudioFile(entity.path)) {
                found.add(entity.path);
              }
            }
            paths = found;
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
            final existing = _localTracks.where(
              (track) => track.localPath == path,
            );
            discovered['local:$path'] =
                existing.isNotEmpty && existing.first.localMetadataRead
                ? existing.first
                : await _localTrackFromPath(path);
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
          setState(() {
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
            : 'Folder added. Found ${discovered.length} audio file(s); checking for changes every minute.';
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
            setState(() => _error = _describePlaybackError(error));
          }
        }),
      );
      await started;

      if (!mounted) return;
      setState(() {
        _queue = finalQueue;
        _queueIndex = index;
        _current = track;
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
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _historyKey,
          jsonEncode(_history.map((event) => event.toJson()).toList()),
        );
      } catch (error) {
        if (mounted) {
          setState(
            () => _error =
                'Playback started, but listening history could not be saved: $error',
          );
        }
      }
      if (mounted && _flowActive) _refreshFlowQueue();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _describePlaybackError(error));
    }
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
    setState(() {
      _queue.removeAt(index);
      if (index < _queueIndex) _queueIndex--;
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
    setState(() {
      final item = _queue.removeAt(from);
      _queue.insert(to, item);
    });
    unawaited(_saveQueue());
  }

  Future<void> _clearUpcoming() async {
    setState(() {
      if (_current != null) {
        _queue = [_current!];
        _queueIndex = 0;
      } else {
        _queue.clear();
        _queueIndex = 0;
      }
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
    setState(() => _playlists[name.trim()] = ids);
    await _savePlaylists();
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
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
    setState(() => _dismissedRecommendations.add(track.id));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _recommendationFeedbackKey,
      _dismissedRecommendations.toList(),
    );
  }

  Future<void> _showCollectionDetails({
    required String title,
    required String subtitle,
    required List<MusicTrack> tracks,
    required bool isArtist,
    required MusicTrack artworkTrack,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          backgroundColor: C.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 6, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(pageContext),
                        icon: Icon(Icons.arrow_back_rounded),
                      ),
                      SizedBox(width: 8),
                      Text(
                        isArtist ? 'ARTIST' : 'ALBUM',
                        style: TextStyle(
                          color: C.muted,
                          fontFamily: 'DMSansBold',
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(22, 12, 22, 32),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _artwork(
                              artworkTrack.coverArt,
                              localArtworkPath: artworkTrack.localArtworkPath,
                              size: 148,
                              seed: isArtist ? title : artworkTrack.album,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'SyneBold',
                                    fontSize: 30,
                                    height: 1.05,
                                    letterSpacing: -1,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () => _play(tracks.first, playlist: tracks),
                          icon: Icon(Icons.play_arrow_rounded),
                          label: Text('Play all'),
                        ),
                      ),
                      SizedBox(height: 18),
                      if (isArtist) ...[
                        Text(
                          'DISCOGRAPHY',
                          style: TextStyle(
                            color: C.muted,
                            fontFamily: 'DMSansBold',
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 10),
                      ],
                      for (var index = 0; index < tracks.length; index++) ...[
                        if (isArtist &&
                            (index == 0 ||
                                tracks[index].album.toLowerCase() !=
                                    tracks[index - 1].album.toLowerCase()))
                          Padding(
                            padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
                            child: InkWell(
                              onTap: () => _openAlbum(tracks[index]),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  tracks[index].album,
                                  style: TextStyle(
                                    fontFamily: 'DMSansBold',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _trackRow(tracks[index], index),
                      ],
                      if (tracks.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Text(
                            'No tracks found in this collection.',
                            style: TextStyle(color: C.muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAlbum(MusicTrack track) {
    final matches =
        _tracks
            .where(
              (item) =>
                  item.album.toLowerCase() == track.album.toLowerCase() &&
                  item.artist.toLowerCase() == track.artist.toLowerCase(),
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    unawaited(
      _showCollectionDetails(
        title: track.album,
        subtitle: track.artist,
        tracks: matches,
        isArtist: false,
        artworkTrack: track,
      ),
    );
  }

  void _openArtist(MusicTrack track) {
    final matches =
        _tracks
            .where(
              (item) => item.artist.toLowerCase() == track.artist.toLowerCase(),
            )
            .toList()
          ..sort((a, b) {
            final albumOrder = a.album.toLowerCase().compareTo(
              b.album.toLowerCase(),
            );
            return albumOrder != 0
                ? albumOrder
                : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
    unawaited(
      _showCollectionDetails(
        title: track.artist,
        subtitle:
            'Artist · ${matches.map((item) => item.album).toSet().length} albums',
        tracks: matches,
        isArtist: true,
        artworkTrack: track,
      ),
    );
  }

  void _seekTo(Offset globalPosition, double durationSeconds) {
    if (durationSeconds <= 0) return;
    final box = _progressBarKey.currentContext?.findRenderObject();
    if (box is! RenderBox || box.size.width <= 0) return;

    final local = box.globalToLocal(globalPosition);
    final fraction = (local.dx / box.size.width).clamp(0.0, 1.0);
    unawaited(
      _player.seek(
        Duration(milliseconds: (durationSeconds * 1000 * fraction).round()),
      ),
    );
  }

  void _previewSeek(Offset globalPosition, double durationSeconds) {
    _pendingSeekPosition = globalPosition;
    final box = _progressBarKey.currentContext?.findRenderObject();
    if (box is! RenderBox || box.size.width <= 0 || durationSeconds <= 0) {
      return;
    }
    final local = box.globalToLocal(globalPosition);
    final fraction = (local.dx / box.size.width).clamp(0.0, 1.0);
    _position.value = Duration(
      milliseconds: (durationSeconds * 1000 * fraction).round(),
    );
  }

  void _finishSeeking(double durationSeconds) {
    final position = _pendingSeekPosition;
    _pendingSeekPosition = null;
    setState(() => _seeking = false);
    if (position != null) _seekTo(position, durationSeconds);
  }

  Future<void> _togglePlayback() async {
    if (_current == null) return;

    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle) {
        await _play(_current!);
      } else {
        unawaited(
          _player.play().catchError((Object error) {
            if (mounted) {
              setState(() => _error = _describePlaybackError(error));
            }
          }),
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _skip(int direction) async {
    if (_queue.isEmpty) return;

    var next = _queueIndex + direction;

    if (_shuffle && direction == 1 && _queue.length > 1) {
      final candidates = List<int>.generate(
        _queue.length,
        (i) => i,
      ).where((i) => i != _queueIndex).toList();
      candidates.shuffle();
      next = candidates.first;
    } else if (_repeatAll && next >= _queue.length) {
      next = 0;
    } else if (_repeatAll && next < 0) {
      next = _queue.length - 1;
    } else if (direction > 0 && next >= _queue.length) {
      return;
    } else {
      next = next.clamp(0, _queue.length - 1);
    }

    await _play(_queue[next]);
  }

  Future<void> _toggleShuffle() async {
    setState(() => _shuffle = !_shuffle);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_shuffleKey, _shuffle);
  }

  Future<void> _cycleRepeatMode() async {
    setState(() {
      if (!_repeatAll && !_repeatOne) {
        _repeatAll = true;
      } else if (_repeatAll) {
        _repeatAll = false;
        _repeatOne = true;
      } else {
        _repeatOne = false;
      }
    });
    await _player.setLoopMode(_repeatOne ? LoopMode.one : LoopMode.off);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_repeatAllKey, _repeatAll);
    await preferences.setBool(_repeatOneKey, _repeatOne);
  }

  Future<void> _toggleFavorite(MusicTrack track) async {
    setState(() {
      if (_favorites.contains(track.id)) {
        _favorites.remove(track.id);
      } else {
        _favorites.add(track.id);
      }
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_favoritesKey, _favorites);
  }

  Future<void> _logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_credentialsKey);
    await _player.stop();

    if (!mounted) return;

    setState(() {
      _credentials = null;
      _client = null;
      _tracks = List.of(_localTracks);
      _searchResults = [];
      _searchTimer?.cancel();
      _search.clear();
      _queue = [];
      _current = null;
      _queueIndex = 0;
      _connected = false;
      _libraryLoaded = false;
      _libraryError = '';
      _searching = false;
      _searchError = '';
      _showPlayer = false;
      _showLogin = true;
      _password.clear();
      _error = '';
      _tab = AppTab.library;
    });
  }

  Future<void> _savePlaylists() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_playlistsKey, jsonEncode(_playlists));
  }

  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewPlaylistDialog(),
    );

    if (name == null || name.trim().isEmpty) return;

    setState(() => _playlists.putIfAbsent(name.trim(), () => []));
    await _savePlaylists();
  }

  Future<void> _addToPlaylist(MusicTrack track) async {
    if (_playlists.isEmpty) {
      await _createPlaylist();
    }

    if (!mounted || _playlists.isEmpty) return;

    final playlists = _playlists.keys.toList(growable: false);
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.surface,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length + 1,
          itemBuilder: (context, index) => index == 0
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Add to playlist',
                    style: TextStyle(fontFamily: 'SyneBold', fontSize: 20),
                  ),
                )
              : ListTile(
                  title: Text(playlists[index - 1]),
                  leading: const Icon(Icons.queue_music_rounded),
                  onTap: () => Navigator.pop(context, playlists[index - 1]),
                ),
        ),
      ),
    );

    if (name == null) return;

    setState(() {
      final ids = _playlists[name]!;
      if (!ids.contains(track.id)) ids.add(track.id);
    });

    await _savePlaylists();
  }

  void _showTrackMenu(MusicTrack track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.favorite_border_rounded),
              title: Text('Toggle favorite'),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add_rounded),
              title: Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                _addToPlaylist(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline_rounded),
              title: Text('Open artist'),
              onTap: () {
                Navigator.pop(context);
                _openArtist(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.album_outlined),
              title: Text('Open album'),
              onTap: () {
                Navigator.pop(context);
                _openAlbum(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.thumb_down_outlined),
              title: Text('Show me less like this'),
              onTap: () {
                Navigator.pop(context);
                _dismissRecommendation(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.play_arrow_rounded),
              title: Text('Play now'),
              onTap: () {
                Navigator.pop(context);
                _play(track);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _sleepTimer?.cancel();
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _player.dispose();
    _position.dispose();
    _search.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final isMacOS = platform == TargetPlatform.macOS;

    return PopScope(
      canPop: !_shouldHandleSystemBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: C.bg,
          statusBarIconBrightness: C.light ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: C.bg,
          systemNavigationBarIconBrightness: C.light
              ? Brightness.dark
              : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: C.bg,
          body: SafeArea(
            top: !isMacOS && (isDesktop || !_showPlayer),
            bottom: isDesktop || !_showPlayer,
            child: Stack(
              children: [
                Column(
                  children: [
                    if (isDesktop) SizedBox(height: 54),
                    Expanded(
                      child: Row(
                        children: [
                          if (isDesktop) _desktopSidebar(),
                          Expanded(child: _content()),
                        ],
                      ),
                    ),
                    // Playback is independent of the active library mode and
                    // server connection. Local tracks must keep the mini player
                    // visible too.
                    if (_current != null) RepaintBoundary(child: _miniPlayer()),
                    if (!isDesktop) _tabBar(),
                  ],
                ),
                // Keep settings mounted while closed so its slide transition
                // can animate both when opening and when dismissing.
                _settingsOverlay(isMobile: !isDesktop),
                // Keep the player mounted so its open/close transition can run,
                // but make the hidden layer transparent to taps.
                if (_current != null)
                  Positioned(
                    top: _showPlayer ? 0 : (isDesktop ? 54 : 0),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: !_showPlayer,
                      child: AnimatedSlide(
                        offset: _showPlayer ? Offset.zero : Offset(0, 1),
                        duration: _reduceMotion
                            ? Duration.zero
                            : Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _showPlayer ? 1 : 0,
                          duration: _reduceMotion
                              ? Duration.zero
                              : Duration(milliseconds: 220),
                          child: _playerOverlay(),
                        ),
                      ),
                    ),
                  ),
                if (_showFlow) Positioned.fill(child: _flowOverlay()),
                // Keep the custom app titlebar above the player overlay so it
                // remains visible and interactive while the player is open.
                if (isDesktop && !_showPlayer && !_showFlow)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _topBar(isDesktop: isDesktop, isMacOS: isMacOS),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar({required bool isDesktop, required bool isMacOS}) {
    return Container(
      height: isDesktop ? 54 : 64,
      padding: EdgeInsets.fromLTRB(isMacOS ? 82 : 22, 0, 22, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [
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
          Text(
            'navika',
            style: TextStyle(
              fontFamily: 'SyneBold',
              fontSize: 23,
              letterSpacing: -1,
            ),
          ),
          Spacer(),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              hoverColor: C.lime.withValues(alpha: .08),
              splashColor: C.lime.withValues(alpha: .18),
              onTap: () => _selectTab(AppTab.library),
              child: Ink(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: C.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _connected ? C.lime : C.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 7),
                    Text(
                      _connected ? 'NAVIDROME' : 'CONNECT',
                      style: TextStyle(
                        fontFamily: 'DMSansBold',
                        fontSize: 10,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          if (_current != null) ...[
            _iconButton(
              Icons.graphic_eq_rounded,
              tooltip: 'Open player',
              onTap: () => setState(() => _showPlayer = true),
            ),
            SizedBox(width: 10),
          ],
          _iconButton(
            Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => setState(() => _showSettings = true),
          ),
        ],
      ),
    );
  }

  Widget _brandLine(double height) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: C.black,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _desktopSidebar() {
    return Container(
      width: 252,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: C.border)),
      ),
      padding: EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: C.muted,
                fontFamily: 'DMSansBold',
                fontSize: 10,
                letterSpacing: 1.3,
              ),
            ),
          ),
          for (final tab in AppTab.values)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Material(
                color: _tab == tab ? C.surface2 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectTab(tab),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 22,
                          color: _tab == tab ? C.lime : C.muted,
                        ),
                        SizedBox(width: 14),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontFamily: 'DMSansMedium',
                            fontSize: 14,
                            color: _tab == tab ? C.text : C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Spacer(),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.surface,
              border: Border.all(color: C.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _connected ? C.lime : C.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connected ? 'Server connected' : 'Not connected',
                    style: TextStyle(color: C.muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(
    IconData icon, {
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: C.lime.withValues(alpha: .10),
          splashColor: C.lime.withValues(alpha: .20),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.surface,
              border: Border.all(color: C.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: C.text),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading && !_connected) {
      return Center(child: CircularProgressIndicator(color: C.lime));
    }

    return AnimatedSwitcher(
      duration: _reduceMotion ? Duration.zero : Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(begin: Offset(0, 0.012), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_tab),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 28, 22, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1280),
              child: switch (_tab) {
                AppTab.home => _homePage(),
                AppTab.search => _searchPage(),
                AppTab.library => _libraryPage(),
                AppTab.playlists => _playlistsPage(),
                AppTab.favorites => _favoritesPage(),
                AppTab.stats => _statsPage(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _flowLaunchCard() {
    final available = _modeTracks.isNotEmpty;
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => setState(() {
          _flowPage = _flowActive ? 1 : 0;
          _showFlow = true;
        }),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: C.lime.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.graphic_eq_rounded, color: C.lime, size: 25),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navika Flow',
                      style: TextStyle(fontFamily: 'DMSansBold', fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      available
                          ? 'A personal listening session that adapts to you.'
                          : 'Load your library to start a personal listening session.',
                      style: TextStyle(
                        color: C.muted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: C.lime, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homePage() {
    if ((_showLocalLibrary && _localTracks.isEmpty) ||
        (!_showLocalLibrary && !_connected && _modeTracks.isEmpty)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your soundtrack\nstarts here.',
            style: TextStyle(
              fontFamily: 'SyneBold',
              fontSize: 42,
              height: 1.12,
              letterSpacing: -2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Import music from your device, or connect a Navidrome server if you use one.',
            style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
          ),
          SizedBox(height: 26),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _artwork(null, size: 90, seed: 'Navika'),
                SizedBox(height: 18),
                Text(
                  'Your music lives here.',
                  style: TextStyle(fontFamily: 'SyneBold', fontSize: 21),
                ),
                SizedBox(height: 8),
                Text(
                  'Add music files or folders from your device. You can also connect Navidrome if you have a server.',
                  style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
                ),
                SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _actionButton('Add your music', onTap: _importLocalMusic),
                    _actionButton(
                      'Connect to Navidrome',
                      onTap: () => setState(() => _showLogin = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_libraryError.isNotEmpty) {
      return _emptyState(
        'Could not load your library',
        _libraryError,
        action: 'Retry',
        onTap: () => _loadLibrary(force: true),
      );
    }

    if (!_libraryLoaded && _loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: C.lime),
              SizedBox(height: 14),
              Text('Loading your music…', style: TextStyle(color: C.muted)),
            ],
          ),
        ),
      );
    }

    if (_libraryLoaded && _modeTracks.isEmpty && !_showLocalLibrary) {
      return _emptyState(
        'No tracks found',
        'Your server connected, but no tracks were returned.',
        action: 'Try again',
        onTap: () => _loadLibrary(force: true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting,
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 42,
            height: 1.12,
            letterSpacing: -2,
          ),
        ),
        SizedBox(height: 18),
        _flowLaunchCard(),
        SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Listen now',
                style: TextStyle(
                  fontFamily: 'SyneBold',
                  fontSize: 25,
                  letterSpacing: -.7,
                ),
              ),
            ),
            _iconButton(
              Icons.tune_rounded,
              tooltip: 'Settings',
              onTap: () => setState(() => _showSettings = true),
            ),
          ],
        ),
        SizedBox(height: 14),
        _sectionTitle(
          'Most played albums',
          action: 'See all',
          onAction: () => _selectTab(AppTab.library),
        ),
        if (_libraryLoaded && _mostPlayedAlbums.isNotEmpty)
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(8, _mostPlayedAlbums.length),
              separatorBuilder: (_, _) => SizedBox(width: 14),
              itemBuilder: (context, index) {
                final album = _mostPlayedAlbums[index];
                return SizedBox(
                  width: 148,
                  child: InkWell(
                    onTap: () => _play(album.track),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _artwork(
                          album.track.coverArt,
                          localArtworkPath: album.track.localArtworkPath,
                          size: 148,
                          seed: album.album,
                        ),
                        SizedBox(height: 9),
                        Text(
                          album.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'DMSansBold',
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: C.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else if (!_libraryLoaded)
          _card(
            child: Row(
              children: [
                Icon(Icons.library_music_outlined, color: C.lime, size: 25),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Open Library to load your collection and personalize these sections.',
                    style: TextStyle(color: C.muted, fontSize: 12, height: 1.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Open Library',
                  onPressed: () => _selectTab(AppTab.library),
                  icon: Icon(Icons.arrow_forward_rounded, color: C.lime),
                ),
              ],
            ),
          ),
        _recentlyPlayedShelf(),
        _sectionTitle(
          'Your library at a glance',
          action: 'Browse',
          onAction: () => _selectTab(AppTab.library),
        ),
        Row(
          children: [
            Expanded(
              child: _homeStat(
                _libraryLoaded || _showLocalLibrary
                    ? '${_modeTracks.length}'
                    : '—',
                'TRACKS',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _homeStat(_libraryLoaded ? '$_albumCount' : '—', 'ALBUMS'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _homeStat(
                _libraryLoaded
                    ? '${_modeTracks.map((t) => t.artist).toSet().length}'
                    : '—',
                'ARTISTS',
              ),
            ),
          ],
        ),
        SizedBox(height: 28),
        _sectionTitle('Your artist rotation'),
        if (_mostPlayedArtists.isEmpty)
          Text(
            'Your regular artists will appear after you listen for a while.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mostPlayedArtists.map((artist) {
              final artistTracks = _modeTracks
                  .where(
                    (track) =>
                        track.artist.toLowerCase() ==
                        artist.artist.toLowerCase(),
                  )
                  .toList();
              return ActionChip(
                avatar: Icon(Icons.graphic_eq_rounded, size: 16),
                label: Text('${artist.artist} · ${artist.count} plays'),
                onPressed: artistTracks.isEmpty
                    ? null
                    : () => _play(artist.track, playlist: artistTracks),
                backgroundColor: C.surface,
                side: BorderSide(color: C.border),
                labelStyle: TextStyle(color: C.text, fontSize: 11),
              );
            }).toList(),
          ),
        SizedBox(height: 20),
        _recommendationShelf(
          'Picked for you',
          _recommended(),
          subtitle: _history.isEmpty
              ? 'A discovery mix from your library. It gets smarter as you listen.'
              : 'Ranked from your listening patterns and favorites.',
        ),
        _recommendationShelf(
          'A little different',
          _discoveryTracks(),
          subtitle:
              'Less-recently played tracks from artists you already enjoy.',
        ),
        _recommendationShelf(
          'More from your favorite artists',
          _tracksFromFavoriteArtists(),
        ),
        SizedBox(height: 20),
        _sectionTitle('Your favorites'),
        if (_favoriteTracks.isEmpty)
          Text(
            'Save tracks with the heart in the player to keep them here.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          ..._favoriteTracks
              .take(5)
              .toList()
              .asMap()
              .entries
              .map((entry) => _trackRow(entry.value, entry.key)),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _recentlyPlayedShelf() {
    final seen = <String>{};
    final tracks = _history.reversed
        .map((event) => _tracksById[event.id])
        .whereType<MusicTrack>()
        .where((track) => seen.add(track.id))
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recently played'),
        if (tracks.isEmpty)
          Text(
            'Your recent listens will appear here.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, _) => SizedBox(width: 14),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return SizedBox(
                  width: 126,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _play(track),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _artwork(
                          track.coverArt,
                          localArtworkPath: track.localArtworkPath,
                          size: 126,
                          seed: track.album,
                        ),
                        SizedBox(height: 9),
                        Text(
                          track.album,
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
                          style: TextStyle(color: C.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        SizedBox(height: 26),
      ],
    );
  }

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
    setState(() {
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
    setState(() {
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
    setState(() {
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
    setState(() => _flowHiddenTrackIds.add(track.id));
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
    setState(() => _flowHiddenTrackIds.clear());
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
    setState(() {
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
          setState(() => _artworkAccentColor = null);
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
            setState(() => _artworkAccentColor = accent);
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
        setState(() => _artworkAccentColor = null);
      }
    }
  }

  List<MusicTrack> _discoveryTracks() {
    final playedRecently = _history
        .skip(math.max(0, _history.length - 12))
        .map((event) => event.id)
        .toSet();
    final picks = _recommended()
        .where(
          (track) =>
              !playedRecently.contains(track.id) &&
              !_favorites.contains(track.id),
        )
        .toList();
    if (picks.isNotEmpty) return picks;
    return _modeTracks
        .where(
          (track) =>
              track.id != _current?.id &&
              !_dismissedRecommendations.contains(track.id),
        )
        .toList();
  }

  List<MusicTrack> _tracksFromFavoriteArtists() {
    final artists = <String, int>{};
    for (final event in _history) {
      artists.update(
        event.artist.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    for (final track in _favoriteTracks) {
      artists.update(
        track.artist.toLowerCase(),
        (count) => count + 3,
        ifAbsent: () => 3,
      );
    }
    final topArtists = artists.keys.toList()
      ..sort((a, b) => artists[b]!.compareTo(artists[a]!));
    final playedRecently = _history
        .skip(math.max(0, _history.length - 8))
        .map((event) => event.id)
        .toSet();
    final picks = _modeTracks
        .where(
          (track) =>
              topArtists.take(5).contains(track.artist.toLowerCase()) &&
              !playedRecently.contains(track.id),
        )
        .toList();
    return picks.isNotEmpty ? picks : _recommended();
  }

  List<MusicTrack> _recentlyPlayedTracks() {
    final seen = <String>{};
    return _history.reversed
        .map((event) => _tracksById[event.id])
        .whereType<MusicTrack>()
        .where((track) => seen.add(track.id))
        .toList();
  }

  Widget _recommendationShelf(
    String title,
    List<MusicTrack> tracks, {
    String? subtitle,
  }) {
    final picks = tracks
        .where((track) => !_dismissedRecommendations.contains(track.id))
        .take(8)
        .toList();
    if (picks.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title,
          action: 'Play mix',
          onAction: () => _play(picks.first, playlist: picks),
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: C.muted, fontSize: 11)),
        ],
        SizedBox(height: 13),
        SizedBox(
          height: 194,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: picks.length,
            separatorBuilder: (_, _) => SizedBox(width: 14),
            itemBuilder: (context, index) {
              final track = picks[index];
              return SizedBox(
                width: 136,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _play(track, playlist: picks),
                  onLongPress: () => _showTrackMenu(track),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _artwork(
                        track.coverArt,
                        localArtworkPath: track.localArtworkPath,
                        size: 136,
                        seed: track.album,
                      ),
                      SizedBox(height: 8),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'DMSansBold',
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: C.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _searchPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find your music',
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 35,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Search your tracks, artists, and albums.',
          style: TextStyle(color: C.muted, fontSize: 13),
        ),
        SizedBox(height: 22),
        TextField(
          controller: _search,
          onChanged: _runSearch,
          decoration: InputDecoration(
            hintText: 'Search your library',
            prefixIcon: Icon(Icons.search_rounded, color: C.muted),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      _runSearch('');
                    },
                    icon: Icon(Icons.close_rounded, color: C.muted),
                  ),
          ),
        ),
        SizedBox(height: 20),
        if (!_connected && _localTracks.isEmpty && _searchResults.isEmpty)
          _emptyState(
            'Add music to search',
            'Import audio files or a music folder to search your local library.',
            action: 'Add music',
            onTap: _importLocalMusic,
          )
        else if (_searchError.isNotEmpty)
          _emptyState(
            'Search unavailable',
            _searchError,
            action: 'Retry search',
            onTap: () => _runSearch(_search.text),
          )
        else if (_searching)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: C.lime),
            ),
          )
        else if (_search.text.trim().isEmpty)
          _emptyState(
            'Start typing to search',
            _connected
                ? 'Search your Navidrome library.'
                : 'Search your imported local music.',
          )
        else if (_searchResults.isEmpty)
          _emptyState('No results found', 'Try a different search.')
        else
          ..._searchResults
              .take(30)
              .toList()
              .asMap()
              .entries
              .map((entry) => _trackRow(entry.value, entry.key)),
      ],
    );
  }

  Widget _libraryPage() {
    final libraryTracks = _visibleLibraryTracks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your library',
                    style: TextStyle(
                      fontFamily: 'SyneBold',
                      fontSize: 35,
                      letterSpacing: -1.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _showLocalLibrary
                        ? 'Music files imported from this device.'
                        : 'Music streamed from your Navidrome server.',
                    style: TextStyle(color: C.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Add local music',
              onPressed: _importLocalMusic,
              icon: Icon(Icons.library_add_rounded, color: C.lime),
            ),
            IconButton(
              tooltip: 'Add a music folder',
              onPressed: _importLocalFolder,
              icon: Icon(Icons.create_new_folder_outlined, color: C.lime),
            ),
            if (!_connected && _localTracks.isNotEmpty)
              IconButton(
                tooltip: 'Connect Navidrome',
                onPressed: () => setState(() => _showLogin = !_showLogin),
                icon: Icon(Icons.dns_outlined, color: C.lime),
              ),
            if (_connected)
              IconButton(
                onPressed: _logout,
                icon: Icon(Icons.logout_rounded, color: C.muted),
              ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _showLocalLibrary = !_showLocalLibrary;
                _showLogin = false;
                _searchResults = [];
                _searching = false;
                _searchError = '';
              });
              unawaited(_saveLibrarySourcePreference());
              if (!_showLocalLibrary && _connected && !_libraryLoaded) {
                unawaited(_loadLibrary());
              }
              if (_tab == AppTab.search && _search.text.trim().isNotEmpty) {
                _runSearch(_search.text);
              }
            },
            icon: Icon(
              _showLocalLibrary ? Icons.dns_outlined : Icons.folder_outlined,
              size: 18,
            ),
            label: Text(
              'Switch to ${_showLocalLibrary ? 'Navidrome' : 'local music'}',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.lime,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _selectTab(AppTab.favorites),
              icon: Icon(Icons.favorite_rounded, size: 17),
              label: Text('Liked songs'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.lime,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _selectTab(AppTab.stats),
              icon: Icon(Icons.bar_chart_rounded, size: 17),
              label: Text('Listening stats'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.text,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        SizedBox(height: 18),
        if (_showLocalLibrary && libraryTracks.isEmpty)
          _emptyState(
            'No local music yet',
            'Import audio files or choose a folder. Your Navidrome library stays separate.',
            action: 'Add music',
            onTap: _importLocalMusic,
          )
        else if (!_showLocalLibrary && !_connected)
          _loginCard()
        else if (_loading && !_showLocalLibrary)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: C.lime),
            ),
          )
        else if (libraryTracks.isEmpty)
          _emptyState(
            _showLocalLibrary ? 'No local music yet' : 'No Navidrome tracks',
            _showLocalLibrary
                ? 'Import audio files or choose a folder.'
                : 'Refresh your server library or switch to local music.',
            action: _showLocalLibrary ? 'Add music' : 'Refresh library',
            onTap: _showLocalLibrary
                ? _importLocalMusic
                : () => _loadLibrary(force: true),
          )
        else ...[
          _recommendationShelf('Recently played', _recentlyPlayedTracks()),
          _recommendationShelf(
            'Picked for you',
            _recommended(),
            subtitle: 'A mix shaped by your listening and favorites.',
          ),
          _recommendationShelf('A little different', _discoveryTracks()),
          _recommendationShelf(
            'More from your favorite artists',
            _tracksFromFavoriteArtists(),
          ),
          if (!_showLocalLibrary && _connected) ...[
            SizedBox(height: 8),
            _actionButton('Refresh library', onTap: _loadLibrary),
          ],
        ],
      ],
    );
  }

  Widget _loginCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _artwork(null, size: 48, seed: 'Navidrome'),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navidrome',
                      style: TextStyle(fontFamily: 'DMSansBold', fontSize: 20),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Connect to your music server',
                      style: TextStyle(color: C.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _fieldLabel('SERVER URL'),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(hintText: 'https://music.example.com'),
          ),
          SizedBox(height: 14),
          _fieldLabel('USERNAME'),
          TextField(
            controller: _username,
            autocorrect: false,
            decoration: InputDecoration(hintText: 'Your Navidrome username'),
          ),
          SizedBox(height: 14),
          _fieldLabel('PASSWORD'),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Your password'),
            onSubmitted: (_) => _connect(),
          ),
          if (_error.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(_error, style: TextStyle(color: C.danger, fontSize: 12)),
          ],
          SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _busy ? null : _connect,
              style: FilledButton.styleFrom(
                backgroundColor: C.lime,
                foregroundColor: C.black,
                disabledBackgroundColor: C.lime.withValues(alpha: .65),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.black,
                      ),
                    )
                  : Text(
                      'Connect to Navidrome ↗',
                      style: TextStyle(fontFamily: 'DMSansBold', fontSize: 13),
                    ),
            ),
          ),
          SizedBox(height: 13),
          Text(
            'Use the same URL you use to open Navidrome in your browser.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _playlistsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your playlists',
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 35,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Build collections for every mood, saved on this device.',
          style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
        ),
        SizedBox(height: 22),
        if (_modeTracks.isEmpty)
          _emptyState(
            'Add music to make playlists',
            'Import local audio files or a music folder, then create playlists from your collection.',
            action: 'Add music',
            onTap: _importLocalMusic,
          )
        else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _createPlaylist,
              icon: Icon(Icons.add_rounded),
              label: Text('Create playlist'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.lime,
                side: BorderSide(color: C.border),
                padding: EdgeInsets.all(15),
              ),
            ),
          ),
          SizedBox(height: 18),
          if (_playlists.isEmpty)
            _emptyState(
              'Your playlists start here',
              'Create a playlist and add tracks from your library.',
            )
          else
            ..._playlists.entries.map((entry) {
              final tracks = entry.value
                  .map((id) => _tracksById[id])
                  .whereType<MusicTrack>()
                  .toList();

              return Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            color: C.lime,
                            size: 26,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontFamily: 'DMSansBold',
                                fontSize: 15,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Rename playlist',
                            onPressed: () => _renamePlaylist(entry.key),
                            icon: Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Play playlist',
                            onPressed: tracks.isEmpty
                                ? null
                                : () => _play(tracks.first, playlist: tracks),
                            icon: Icon(Icons.play_arrow_rounded),
                          ),
                          IconButton(
                            tooltip: 'Delete playlist',
                            onPressed: () async {
                              setState(() => _playlists.remove(entry.key));
                              await _savePlaylists();
                            },
                            icon: Icon(Icons.close_rounded, color: C.muted),
                          ),
                        ],
                      ),
                      Text(
                        '${tracks.length} tracks',
                        style: TextStyle(color: C.muted, fontSize: 11),
                      ),
                      if (tracks.isNotEmpty) ...[
                        SizedBox(height: 12),
                        ...tracks.asMap().entries.map(
                          (item) => _playlistTrackRow(
                            entry.key,
                            item.value,
                            item.key,
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _chooseTrackForPlaylist(entry.key),
                        icon: Icon(Icons.add_rounded, size: 18),
                        label: Text('Add tracks'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  Future<void> _renamePlaylist(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Rename playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName == oldName || !mounted) return;
    if (_playlists.containsKey(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A playlist with that name already exists.')),
      );
      return;
    }
    setState(() {
      final tracks = _playlists.remove(oldName);
      if (tracks != null) _playlists[newName] = tracks;
    });
    await _savePlaylists();
  }

  Future<void> _chooseTrackForPlaylist(String playlist) async {
    final tracks = await showModalBottomSheet<List<MusicTrack>>(
      context: context,
      backgroundColor: C.surface,
      isScrollControlled: true,
      builder: (_) => _PlaylistTrackPicker(
        tracks: _modeTracks,
        existingIds: _playlists[playlist]!.toSet(),
        artwork: (track) => _artwork(
          track.coverArt,
          localArtworkPath: track.localArtworkPath,
          size: 42,
          seed: track.album,
        ),
      ),
    );

    if (tracks == null || tracks.isEmpty || !mounted) return;

    setState(() {
      final ids = _playlists[playlist]!;
      for (final track in tracks) {
        if (!ids.contains(track.id)) ids.add(track.id);
      }
    });

    await _savePlaylists();
  }

  Widget _playlistTrackRow(String playlist, MusicTrack track, int index) {
    final active = _current?.id == track.id;
    return InkWell(
      onTap: () => _play(
        track,
        playlist: _playlists[playlist]!
            .map((id) => _tracksById[id])
            .whereType<MusicTrack>()
            .toList(),
      ),
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
                  Text(
                    '${track.artist} · ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: C.muted, fontSize: 11),
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
              tooltip: 'Remove from playlist',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                setState(() => _playlists[playlist]!.remove(track.id));
                await _savePlaylists();
              },
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                size: 20,
                color: C.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoritesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your favorites',
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 35,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'The tracks you saved with a heart.',
          style: TextStyle(color: C.muted, fontSize: 13),
        ),
        SizedBox(height: 22),
        if (_favoriteTracks.isEmpty)
          _emptyState(
            'No favorites yet',
            'Play a track and tap the heart in the full-screen player to save it here.',
          )
        else
          ..._favoriteTracks.asMap().entries.map(
            (entry) => _trackRow(entry.value, entry.key),
          ),
      ],
    );
  }

  Widget _statsPage() {
    final albums = _albumCount;
    final artists = _modeTracks.map((track) => track.artist).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your listening',
          style: TextStyle(
            fontFamily: 'SyneBold',
            fontSize: 35,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'A little snapshot of your music world, stored locally.',
          style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
        ),
        SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 900 ? 3 : 2;
            final cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _statCard(
                  '${_modeTracks.length}',
                  'TRACKS IN LIBRARY',
                  width: cardWidth,
                ),
                _statCard('$albums', 'ALBUMS', width: cardWidth),
                _statCard('$artists', 'ARTISTS', width: cardWidth),
                _statCard(
                  '${_history.length}',
                  'RECORDED PLAYS',
                  width: cardWidth,
                ),
                _statCard(
                  '${_favorites.length}',
                  'FAVORITES',
                  width: cardWidth,
                ),
              ],
            );
          },
        ),
        SizedBox(height: 28),
        _sectionTitle('Most played albums'),
        if (_mostPlayedAlbums.isEmpty)
          Text(
            'Your most-played albums will appear after you start listening.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          ..._mostPlayedAlbums
              .take(5)
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _artwork(
                    item.track.coverArt,
                    localArtworkPath: item.track.localArtworkPath,
                    size: 44,
                    seed: item.album,
                  ),
                  title: Text(
                    item.album,
                    style: TextStyle(fontFamily: 'DMSansMedium'),
                  ),
                  subtitle: Text(
                    item.artist,
                    style: TextStyle(color: C.muted, fontSize: 11),
                  ),
                  trailing: Text(
                    '${item.count} plays',
                    style: TextStyle(color: C.lime, fontSize: 10),
                  ),
                  onTap: () => _play(item.track),
                ),
              ),
      ],
    );
  }

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
                      icon: Icon(
                        _player.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: C.lime,
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
    setState(() {
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
                                  : Duration(milliseconds: 160),
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
                                : Duration(milliseconds: 180),
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

  Widget _settingsOverlay({required bool isMobile}) {
    final duration = _reduceMotion
        ? Duration.zero
        : Duration(milliseconds: 280);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showSettings,
        child: AnimatedSlide(
          offset: _showSettings
              ? Offset.zero
              : (isMobile ? Offset(1, 0) : Offset(0.08, -0.02)),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showSettings ? 1 : 0,
            duration: duration,
            child: Material(
              color: isMobile ? C.bg : Color(0x99000000),
              child: Stack(
                children: [
                  if (!isMobile)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _showSettings = false),
                        child: SizedBox.expand(),
                      ),
                    ),
                  Align(
                    alignment: isMobile ? Alignment.center : Alignment.topRight,
                    child: Container(
                      width: isMobile ? double.infinity : 390,
                      height: isMobile ? double.infinity : null,
                      constraints: isMobile
                          ? BoxConstraints.expand()
                          : BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 28,
                              maxHeight:
                                  MediaQuery.sizeOf(context).height - 100,
                            ),
                      margin: isMobile
                          ? EdgeInsets.zero
                          : EdgeInsets.only(top: 68, right: 14, left: 14),
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isMobile ? null : C.surface,
                        border: isMobile ? null : Border.all(color: C.border),
                        borderRadius: isMobile
                            ? BorderRadius.zero
                            : BorderRadius.circular(18),
                        boxShadow: isMobile
                            ? null
                            : [
                                BoxShadow(
                                  color: Color(0x4D000000),
                                  blurRadius: 24,
                                ),
                              ],
                      ),
                      child: Material(
                        color: isMobile ? C.bg : C.surface,
                        borderRadius: isMobile
                            ? BorderRadius.zero
                            : BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Settings',
                                          style: TextStyle(
                                            fontFamily: 'SyneBold',
                                            fontSize: 22,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Make Navika feel right.',
                                          style: TextStyle(
                                            color: C.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        setState(() => _showSettings = false),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: C.muted,
                                    ),
                                  ),
                                ],
                              ),
                              _settingsSection('APPEARANCE'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Theme',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  switch (_themeMode.value) {
                                    NavikaTheme.dark => 'Dark',
                                    NavikaTheme.amoled => 'AMOLED black',
                                    NavikaTheme.light => 'Light',
                                  },
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: DropdownButton<NavikaTheme>(
                                  value: _themeMode.value,
                                  underline: SizedBox.shrink(),
                                  borderRadius: BorderRadius.circular(12),
                                  items: [
                                    DropdownMenuItem(
                                      value: NavikaTheme.dark,
                                      child: Text('Dark'),
                                    ),
                                    DropdownMenuItem(
                                      value: NavikaTheme.amoled,
                                      child: Text('AMOLED'),
                                    ),
                                    DropdownMenuItem(
                                      value: NavikaTheme.light,
                                      child: Text('Light'),
                                    ),
                                  ],
                                  onChanged: (theme) async {
                                    if (theme == null) return;
                                    _themeMode.value = theme;
                                    final preferences =
                                        await SharedPreferences.getInstance();
                                    await preferences.setString(
                                      _themeKey,
                                      theme.name,
                                    );
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                              _settingsSection('PERFORMANCE'),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _reduceMotion,
                                activeThumbColor: C.black,
                                activeTrackColor: C.lime,
                                inactiveThumbColor: C.muted,
                                inactiveTrackColor: C.surface2,
                                title: Text(
                                  'Reduce animations',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  'Use fewer entrance animations for a snappier feel.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                onChanged: (value) async {
                                  setState(() => _reduceMotion = value);
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.setBool(_motionKey, value);
                                },
                              ),
                              _settingsSection('PLAYBACK'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Playback speed',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Currently ${_playbackSpeed.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}×',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: DropdownButton<double>(
                                  value: _playbackSpeed,
                                  items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                                      .map(
                                        (speed) => DropdownMenuItem(
                                          value: speed,
                                          child: Text('$speed×'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (speed) {
                                    if (speed != null) {
                                      unawaited(_setPlaybackSpeed(speed));
                                    }
                                  },
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Sleep timer',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Pause playback after a set time.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.bedtime_outlined,
                                  color: C.muted,
                                ),
                                onTap: _startSleepTimer,
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _autoAdvance,
                                activeThumbColor: C.black,
                                activeTrackColor: C.lime,
                                inactiveThumbColor: C.muted,
                                inactiveTrackColor: C.surface2,
                                title: Text(
                                  'Play next track automatically',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  'Continue through the queue when a track ends.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                onChanged: (value) async {
                                  setState(() => _autoAdvance = value);
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.setBool(
                                    _autoAdvanceKey,
                                    value,
                                  );
                                },
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _showVisualizer,
                                activeThumbColor: C.black,
                                activeTrackColor: C.lime,
                                inactiveThumbColor: C.muted,
                                inactiveTrackColor: C.surface2,
                                title: Text(
                                  'Show player visualizer',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  'Show animated bars beside the current track.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                onChanged: (value) async {
                                  setState(() => _showVisualizer = value);
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.setBool(
                                    _visualizerKey,
                                    value,
                                  );
                                },
                              ),
                              _settingsSection('LIBRARY'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Refresh library',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Fetch the latest tracks from Navidrome.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: C.muted,
                                ),
                                onTap: () {
                                  setState(() => _showSettings = false);
                                  _loadLibrary(force: true);
                                },
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Music folders',
                                        style: TextStyle(
                                          fontFamily: 'DMSansMedium',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _importLocalFolder,
                                      icon: Icon(
                                        Icons.create_new_folder_outlined,
                                        size: 16,
                                      ),
                                      label: Text('Add folder'),
                                    ),
                                  ],
                                ),
                              ),
                              if (_localFolders.isEmpty)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'No watched folders. Add one to keep local music updated automatically.',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 10,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                              else
                                ..._localFolders.map(
                                  (folder) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.folder_outlined,
                                      color: C.muted,
                                      size: 19,
                                    ),
                                    title: Text(
                                      _folderDisplayName(folder),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    subtitle: Text(
                                      folder.startsWith('saf:')
                                          ? 'Android · scans nested folders'
                                          : folder,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 9,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Remove folder',
                                      onPressed: () =>
                                          _removeLocalFolder(folder),
                                      icon: Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: C.danger,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Server connection',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  _connected
                                      ? (_credentials?.baseUrl ?? '')
                                      : 'Connect to a Navidrome server',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: C.muted,
                                ),
                                onTap: () {
                                  setState(() => _showSettings = false);
                                  _selectTab(AppTab.library);
                                },
                              ),
                              _settingsSection('PERSONAL TASTE'),
                              Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Navika learns from your listening history, favorites, and feedback. Explicit feedback is saved only on this device and influences Flow.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                              ..._tasteTopArtists().map(
                                (artist) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    artist.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  subtitle: Text(
                                    '${artist.plays} plays${artist.feedback == 0
                                        ? ''
                                        : artist.feedback > 0
                                        ? ' · you like this artist'
                                        : ' · lower priority'}',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  trailing: artist.feedback == 0
                                      ? Icon(
                                          Icons.graphic_eq_rounded,
                                          color: C.muted,
                                          size: 17,
                                        )
                                      : Icon(
                                          artist.feedback > 0
                                              ? Icons.thumb_up_alt_rounded
                                              : Icons.thumb_down_alt_rounded,
                                          color: artist.feedback > 0
                                              ? C.lime
                                              : C.danger,
                                          size: 17,
                                        ),
                                ),
                              ),
                              if (_tasteTopArtists().isEmpty)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'Your profile will take shape as you listen and give feedback.',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Reset personal taste profile',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Clear your More/Less like this feedback. Listening history and favorites stay intact.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.restart_alt_rounded,
                                  color: C.danger,
                                  size: 19,
                                ),
                                onTap: () async {
                                  await _resetTasteProfile();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Personal taste feedback reset.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              _settingsSection('YOUR DATA'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Clear listening history',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Remove locally stored listening history and stats.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.close_rounded,
                                  color: C.danger,
                                  size: 18,
                                ),
                                onTap: () async {
                                  setState(() {
                                    _history.clear();
                                    _showSettings = false;
                                  });
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.remove(_historyKey);
                                },
                              ),
                              if (_connected)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.logout_rounded,
                                    color: C.danger,
                                    size: 18,
                                  ),
                                  title: Text(
                                    'Disconnect server',
                                    style: TextStyle(
                                      color: C.danger,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() => _showSettings = false);
                                    _logout();
                                  },
                                ),
                              SizedBox(height: 12),
                              Text(
                                'Navika · Your listening history stays on this device.',
                                style: TextStyle(
                                  color: C.muted,
                                  fontSize: 9,
                                  height: 1.6,
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _settingsSection(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 17, bottom: 5),
      child: Text(
        title,
        style: TextStyle(
          color: C.lime,
          fontFamily: 'DMSansBold',
          fontSize: 9,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

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
                      onPressed: () => setState(() {
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
                                  onChanged: (value) =>
                                      setState(() => _flowFamiliarity = value),
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
                                      setState(() => _flowVariety = value),
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
                              onTap: () => setState(() {
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
                                        onPressed: () => setState(() {
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
                                onPressed: () => setState(() {
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
                      onPressed: () => setState(() => _showFlow = false),
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
                              onPressed: () => setState(() => _flowPage = 1),
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
        duration: _reduceMotion ? Duration.zero : Duration(seconds: 8),
        builder: (context, phase, child) => AnimatedContainer(
          duration: _reduceMotion ? Duration.zero : Duration(milliseconds: 900),
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
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 70,
                  padding: EdgeInsets.fromLTRB(isMacOS ? 82 : 22, 0, 22, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: _flowActive
                            ? 'Back to Flow'
                            : 'Back to library',
                        onPressed: () => setState(() {
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
                              fontSize: 9,
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
                        onPressed: () =>
                            setState(() => _showVisualizer = !_showVisualizer),
                        icon: Icon(
                          Icons.graphic_eq_rounded,
                          color: _showVisualizer ? C.lime : C.muted,
                        ),
                      ),
                      IconButton(
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
                        : Duration(milliseconds: 220),
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
                                            fontSize: 9,
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
                                              onPressed: _toggleShuffle,
                                              icon: Icon(
                                                Icons.shuffle_rounded,
                                                color: _shuffle
                                                    ? C.lime
                                                    : C.muted,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => _skip(-1),
                                              icon: Icon(
                                                Icons.skip_previous_rounded,
                                                size: 27,
                                              ),
                                            ),
                                            IconButton(
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
                                              onPressed: () => _skip(1),
                                              icon: Icon(
                                                Icons.skip_next_rounded,
                                                size: 27,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: _cycleRepeatMode,
                                              icon: Icon(
                                                Icons.repeat_rounded,
                                                color: _repeatAll
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
                                              onPressed: () => setState(
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
                                            fontSize: 9,
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
                                                        fontFamily:
                                                            'DMSansBold',
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
                                            fontSize: 9,
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
                                                  _queue[_queueIndex +
                                                      index +
                                                      1],
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                  : Icons
                                                        .favorite_border_rounded,
                                              color:
                                                  _favorites.contains(track.id)
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
                                              borderRadius:
                                                  BorderRadius.circular(40),
                                              onTap: _togglePlayback,
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
                                                color:
                                                    (_repeatAll || _repeatOne)
                                                    ? C.lime
                                                    : C.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: OutlinedButton.icon(
                                            onPressed: () => setState(
                                              () => _showUpNext = true,
                                            ),
                                            icon: Icon(
                                              Icons.queue_music_rounded,
                                            ),
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
                                          setState(() => _showUpNext = false),
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
                                        localArtworkPath:
                                            track.localArtworkPath,
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
                                            alignment: Alignment.center,
                                            padding: EdgeInsets.zero,
                                            onPressed: () =>
                                                _toggleFavorite(track),
                                            icon: Icon(
                                              _favorites.contains(track.id)
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                        .favorite_border_rounded,
                                              color:
                                                  _favorites.contains(track.id)
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
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
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    onPressed: () => _skip(1),
                                    icon: Icon(
                                      Icons.skip_next_rounded,
                                      size: 27,
                                    ),
                                  ),
                                  IconButton(
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
                                  onPressed: () => setState(
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
                cacheWidth: pixelSize,
                cacheHeight: pixelSize,
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
                cacheWidth: pixelSize,
                cacheHeight: pixelSize,
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
              fontSize: 9,
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
    return ValueListenableBuilder<Duration>(
      valueListenable: _position,
      builder: (context, _, _) => RepaintBoundary(child: _visualizerBody()),
    );
  }

  Widget _visualizerBody() {
    final phase = _position.value.inMilliseconds / 180;
    return Container(
      height: 54,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
          final height = _player.playing
              ? 5 + wave * envelope * 32
              : 5 + envelope * 7;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 1.2),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 130),
                height: height,
                decoration: BoxDecoration(
                  color: _player.playing
                      ? C.lime.withValues(alpha: .55 + wave * .45)
                      : C.muted.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ),
    );
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
        setState(() => _seeking = true);
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
                                : Duration(milliseconds: _seeking ? 45 : 70),
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
                      : Duration(milliseconds: _seeking ? 45 : 70),
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

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final list = toList();
    return list.skip(list.length > count ? list.length - count : 0);
  }
}
