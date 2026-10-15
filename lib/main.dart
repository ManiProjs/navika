import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navidrome_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'app.navika.audio',
      androidNotificationChannelName: 'Navika playback',
      androidNotificationOngoing: true,
    );
  }
  runApp(NavikaApp());
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
const _speedKey = 'navika.playback.speed';
const _localTracksKey = 'navika.local.tracks';

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
        home: HomeScreen(),
      ),
    );
  }
}

class _NewPlaylistDialog extends StatefulWidget {
  const _NewPlaylistDialog();

  @override
  State<_NewPlaylistDialog> createState() => _NewPlaylistDialogState();
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
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  final GlobalKey _progressBarKey = GlobalKey();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  Timer? _searchTimer;
  Timer? _sleepTimer;
  int _searchRequestId = 0;
  final Set<String> _dismissedRecommendations = {};
  double _playbackSpeed = 1.0;

  AppTab _tab = AppTab.home;
  NavidromeClient? _client;
  NavidromeCredentials? _credentials;

  List<MusicTrack> _tracks = [];
  List<MusicTrack> _localTracks = [];
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
  bool _showUpNext = false;
  bool _showVisualizer = false;
  bool _reduceMotion = false;
  bool _autoAdvance = true;
  bool _shuffle = false;
  bool _repeatAll = false;
  bool _repeatOne = false;
  bool _handlingCompletion = false;
  bool _seeking = false;

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
      _player.positionStream.listen((_) {
        if (mounted) setState(() {});
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
    for (final track in _tracks) track.id: track,
  };

  int get _albumCount => _tracks
      .map(
        (track) =>
            '${track.album.trim().toLowerCase()}::${track.artist.trim().toLowerCase()}',
      )
      .toSet()
      .length;

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
    if (!_connected || _client == null) {
      final normalized = query.toLowerCase();
      setState(() {
        _searchResults = _localTracks
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
          _searchResults = [
            ...results,
            ..._localTracks.where(
              (track) =>
                  track.title.toLowerCase().contains(normalized) ||
                  track.artist.toLowerCase().contains(normalized) ||
                  track.album.toLowerCase().contains(normalized),
            ),
          ];
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
    _showVisualizer = preferences.getBool(_visualizerKey) ?? false;
    _shuffle = preferences.getBool(_shuffleKey) ?? false;
    _repeatAll = preferences.getBool(_repeatAllKey) ?? false;
    _repeatOne = preferences.getBool(_repeatOneKey) ?? false;
    _playbackSpeed = preferences.getDouble(_speedKey) ?? 1.0;
    final savedLocalTracks = preferences.getString(_localTracksKey);
    if (savedLocalTracks != null) {
      try {
        _localTracks = (jsonDecode(savedLocalTracks) as List)
            .map(
              (item) => MusicTrack.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
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
    _dismissedRecommendations.addAll(
      preferences.getStringList(_recommendationFeedbackKey) ?? const [],
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
        _tracks = [...tracks, ..._localTracks];
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
        final fileName = path.split(RegExp(r'[/\\]')).last;
        final dot = fileName.lastIndexOf('.');
        final title = (dot > 0 ? fileName.substring(0, dot) : fileName)
            .replaceAll(RegExp(r'_+'), ' ')
            .trim();
        imported.add(
          MusicTrack(
            id: 'local:$path',
            title: title.isEmpty ? fileName : title,
            artist: 'Local file',
            album: 'On this device',
            localPath: path,
          ),
        );
      }
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
        _tracks = [..._tracks.where((track) => !track.isLocal), ...localTracks];
        _libraryLoaded = true;
        _showLogin = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${imported.length} local track(s).')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import music: $error')),
      );
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
        artUri: client?.coverArtUrl(track.coverArt) == null
            ? null
            : Uri.parse(client!.coverArtUrl(track.coverArt)!),
      );
      final audioSource = track.isLocal
          ? AudioSource.file(track.localPath!, tag: mediaItem)
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
        _showPlayer = true;
        _showUpNext = false;
        _error = '';
      });

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
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .88,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(fontFamily: 'SyneBold', fontSize: 25),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(subtitle, style: TextStyle(color: C.muted, fontSize: 12)),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tracks.length} tracks',
                        style: TextStyle(color: C.muted, fontSize: 12),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: tracks.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _play(tracks.first, playlist: tracks);
                            },
                      icon: Icon(Icons.play_arrow_rounded),
                      label: Text('Play all'),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: tracks
                        .asMap()
                        .entries
                        .map((entry) => _trackRow(entry.value, entry.key))
                        .toList(),
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

    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.surface,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Add to playlist',
                style: TextStyle(fontFamily: 'SyneBold', fontSize: 20),
              ),
            ),
            for (final playlist in _playlists.keys)
              ListTile(
                title: Text(playlist),
                leading: Icon(Icons.queue_music_rounded),
                onTap: () => Navigator.pop(context, playlist),
              ),
          ],
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: C.bg,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: C.bg,
        systemNavigationBarIconBrightness: Brightness.light,
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
                  SizedBox(height: isDesktop ? 54 : 64),
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop) _desktopSidebar(),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _content()),
                              if (_connected && _current != null) _miniPlayer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  top: _showPlayer ? 0 : (isDesktop ? 54 : 64),
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
              // Keep the custom app titlebar above the player overlay so it
              // remains visible and interactive while the player is open.
              if (!_showPlayer && (isDesktop || !_showSettings))
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
      child: KeyedSubtree(
        key: ValueKey(_tab),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 28, 22, 30),
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
    );
  }

  Widget _homePage() {
    if (!_connected) {
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
            'Connect your Navidrome server to get started.',
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
                  'Connect Navidrome to explore your library.',
                  style: TextStyle(color: C.muted, fontSize: 13, height: 1.6),
                ),
                SizedBox(height: 18),
                _actionButton(
                  'Connect server ↗',
                  onTap: () => _selectTab(AppTab.library),
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

    if (_libraryLoaded && _tracks.isEmpty) {
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
        _sectionTitle('Recently played'),
        if (_history.isEmpty)
          Text(
            'Your recently played music will appear here.',
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
          )
        else
          ..._history.reversed.take(5).map((event) {
            final track = _tracksById[event.id];
            if (track == null) return SizedBox.shrink();
            return _trackRow(track, _history.indexOf(event));
          }),
        _sectionTitle(
          'Your library at a glance',
          action: 'Browse',
          onAction: () => _selectTab(AppTab.library),
        ),
        Row(
          children: [
            Expanded(
              child: _homeStat(
                _libraryLoaded ? '${_tracks.length}' : '—',
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
                    ? '${_tracks.map((t) => t.artist).toSet().length}'
                    : '—',
                'ARTISTS',
              ),
            ),
          ],
        ),
        SizedBox(height: 28),
        SizedBox(height: 12),
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
              final artistTracks = _tracks
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
        _sectionTitle(
          'Picked for you',
          action: 'Play mix',
          onAction: () {
            final picks = _recommended();
            if (picks.isNotEmpty) _play(picks.first, playlist: picks);
          },
        ),
        Text(
          _history.isEmpty
              ? 'A discovery mix from your library. It gets smarter as you listen.'
              : 'Ranked from your listening patterns and favorites. Your history stays on this device.',
          style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
        ),
        SizedBox(height: 12),
        ..._recommended()
            .take(4)
            .toList()
            .asMap()
            .entries
            .map((entry) => _trackRow(entry.value, entry.key)),
        SizedBox(height: 20),
        _sectionTitle(
          'A little different',
          action: 'Surprise me',
          onAction: () {
            final picks = _discoveryTracks();
            if (picks.isNotEmpty) _play(picks.first, playlist: picks);
          },
        ),
        Text(
          'Less-recently played tracks from artists you already enjoy.',
          style: TextStyle(color: C.muted, fontSize: 11, height: 1.6),
        ),
        SizedBox(height: 10),
        ..._discoveryTracks()
            .take(3)
            .toList()
            .asMap()
            .entries
            .map((entry) => _trackRow(entry.value, entry.key)),
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
        _sectionTitle(
          'Recently played',
          action: 'Your library',
          onAction: () => _selectTab(AppTab.library),
        ),
        SizedBox(
          height: 174,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _history.reversed.take(8).map((event) {
              final track = _tracksById[event.id];
              if (track == null) return SizedBox.shrink();

              return SizedBox(
                width: 126,
                child: Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: InkWell(
                    onTap: () => _play(track),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _artwork(track.coverArt, size: 126, seed: track.album),
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
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<MusicTrack> _recommended() {
    final ranked = recommendTracks(
      _tracks
          .where((track) => !_dismissedRecommendations.contains(track.id))
          .toList(),
      _history,
      currentId: _current?.id,
      favoriteIds: _favorites.toSet(),
      limit: _tracks.length,
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
    return _tracks
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
    final picks = _tracks
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
        .take(24)
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
                      _artwork(track.coverArt, size: 136, seed: track.album),
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
          'Find your music.',
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
        if (!_connected && _searchResults.isEmpty)
          _emptyState(
            'Connect your music library',
            'Connect to Navidrome to search your music.',
            action: 'Connect server',
            onTap: () => _selectTab(AppTab.library),
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
            'Results come directly from your Navidrome server.',
          )
        else if (_searchResults.isEmpty)
          _emptyState('No results found', 'Try a different search.')
        else
          ..._searchResults
              .take(100)
              .toList()
              .asMap()
              .entries
              .map((entry) => _trackRow(entry.value, entry.key)),
      ],
    );
  }

  Widget _libraryPage() {
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
                    'Your library.',
                    style: TextStyle(
                      fontFamily: 'SyneBold',
                      fontSize: 35,
                      letterSpacing: -1.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Music from Navidrome and files on this device.',
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
            if (_connected)
              IconButton(
                onPressed: _logout,
                icon: Icon(Icons.logout_rounded, color: C.muted),
              ),
          ],
        ),
        SizedBox(height: 24),
        if (_showLogin || !_connected)
          _loginCard()
        else ...[
          _card(
            child: Row(
              children: [
                Icon(Icons.dns_outlined, color: C.lime, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navidrome',
                        style: TextStyle(fontFamily: 'DMSansBold'),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _credentials?.baseUrl ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: C.muted, fontSize: 11),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Connected as ${_credentials?.username ?? ''}',
                        style: TextStyle(color: C.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: _logout, child: Text('Log out')),
              ],
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _homeStat('${_tracks.length}', 'LOADED TRACKS')),
              SizedBox(width: 10),
              Expanded(
                child: _homeStat(
                  '${_tracks.map((t) => t.artist).toSet().length}',
                  'ARTISTS',
                ),
              ),
              SizedBox(width: 10),
              Expanded(child: _homeStat('$_albumCount', 'ALBUMS')),
            ],
          ),
          SizedBox(height: 26),
          if (_loading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: C.lime),
              ),
            )
          else if (_libraryError.isNotEmpty)
            _emptyState(
              'Library unavailable',
              _libraryError,
              action: 'Retry',
              onTap: () => _loadLibrary(force: true),
            )
          else if (_tracks.isEmpty)
            _emptyState(
              'Your library is empty',
              'Try refreshing the connection.',
              action: 'Refresh',
              onTap: () => _loadLibrary(force: true),
            )
          else ...[
            _recommendationShelf('Made for you', _recommended()),
            SizedBox(height: 26),
            _recommendationShelf(
              'More from your favorite artists',
              _tracksFromFavoriteArtists(),
              subtitle: 'Artists you keep coming back to',
            ),
            SizedBox(height: 26),
            _recommendationShelf(
              'Rediscover your rotation',
              _recentlyPlayedTracks(),
              subtitle: 'Tracks you have listened to before',
            ),
            SizedBox(height: 26),
            _recommendationShelf(
              'Something new for you',
              _discoveryTracks(),
              subtitle: 'Familiar sounds, with a little variety',
            ),
            if (_favoriteTracks.isNotEmpty) ...[
              SizedBox(height: 26),
              _recommendationShelf(
                'Your favorites',
                _favoriteTracks,
                subtitle: 'The tracks you saved',
              ),
            ],
          ],
          SizedBox(height: 18),
          _actionButton('Refresh library', onTap: _loadLibrary),
        ],
        if (_localTracks.isNotEmpty) ...[
          SizedBox(height: 26),
          _sectionTitle(
            'On this device',
            action: 'Add music',
            onAction: _importLocalMusic,
          ),
          SizedBox(height: 8),
          ..._localTracks.asMap().entries.map(
            (entry) => _trackRow(entry.value, entry.key),
          ),
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
          'Your playlists.',
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
        if (!_connected)
          _emptyState(
            'Connect your music library',
            'Your playlists need tracks from your Navidrome server.',
            action: 'Connect server',
            onTap: () => _selectTab(AppTab.library),
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
        tracks: _tracks,
        existingIds: _playlists[playlist]!.toSet(),
        artwork: (track) =>
            _artwork(track.coverArt, size: 42, seed: track.album),
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
            _artwork(track.coverArt, size: 46, seed: track.album),
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
          'Your favorites.',
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
    final artists = _tracks.map((track) => track.artist).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your listening.',
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
                  '${_tracks.length}',
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
    final duration = _player.duration?.inMilliseconds ?? 0;
    final position = _player.position.inMilliseconds;
    final progress = duration == 0
        ? 0.0
        : (position / duration).clamp(0.0, 1.0);

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
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(C.lime),
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
        children: AppTab.values.map((tab) {
          final active = _tab == tab;

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
                        Icon(
                          tab.icon,
                          size: 22,
                          color: active ? C.lime : C.muted,
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
                    if (active)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 2,
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
        }).toList(),
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

  Widget _playerOverlay() {
    final track = _current!;
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final duration =
        _player.duration?.inSeconds.toDouble() ?? track.duration.toDouble();
    final position = _player.position.inSeconds.toDouble();
    final progress = duration <= 0
        ? 0.0
        : (position / duration).clamp(0.0, 1.0);

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
                        tooltip: 'Back to library',
                        onPressed: () => setState(() {
                          _showPlayer = false;
                          _showUpNext = false;
                        }),
                        icon: Icon(Icons.chevron_left_rounded, size: 30),
                      ),
                      Spacer(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              color: C.lime,
                              fontFamily: 'DMSansBold',
                              fontSize: 9,
                              letterSpacing: 1.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your music',
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
                                      SizedBox(height: 8),
                                      _seekBar(progress, duration),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTime(position),
                                            style: TextStyle(
                                              color: C.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(duration),
                                            style: TextStyle(
                                              color: C.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
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
                                          fontSize: 9,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Expanded(
                                        child: ListView(
                                          children: _queue
                                              .skip(_queueIndex + 1)
                                              .take(30)
                                              .toList()
                                              .asMap()
                                              .entries
                                              .map(
                                                (entry) => _trackRow(
                                                  entry.value,
                                                  _queueIndex + entry.key + 1,
                                                ),
                                              )
                                              .toList(),
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
                                      _seekBar(progress, duration),
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTime(position),
                                            style: TextStyle(
                                              color: C.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(duration),
                                            style: TextStyle(
                                              color: C.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
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
                                                    : Icons.play_arrow_rounded,
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
                                          onPressed: () => setState(
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
                            _seekBar(progress, duration),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatTime(position),
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  _formatTime(duration),
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  icon: Icon(Icons.skip_next_rounded, size: 27),
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
                                onPressed: () =>
                                    setState(() => _showUpNext = !_showUpNext),
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
    // Match the background glow to Navika's actual lime accent, rather than
    // choosing an unrelated pseudo-random palette from the album name.
    return [Color.lerp(C.lime, C.bg, C.light ? .82 : .88)!, C.bg];
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
            _artwork(track.coverArt, size: 46, seed: track.album),
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
                  Wrap(
                    spacing: 5,
                    children: [
                      InkWell(
                        onTap: () => _openArtist(track),
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: C.muted,
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                            decorationColor: C.border,
                          ),
                        ),
                      ),
                      Text('·', style: TextStyle(color: C.muted, fontSize: 11)),
                      InkWell(
                        onTap: () => _openAlbum(track),
                        child: Text(
                          track.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: C.muted,
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                            decorationColor: C.border,
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
    required double size,
    required String seed,
  }) {
    final url = coverArt == null ? null : _client?.coverArtUrl(coverArt);

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
        child: url == null
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
    final phase = _player.position.inMilliseconds / 180;
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

  Widget _seekBar(double progress, double duration) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => setState(() => _seeking = true),
      onHorizontalDragUpdate: (details) =>
          _seekTo(details.globalPosition, duration),
      onHorizontalDragEnd: (_) => setState(() => _seeking = false),
      onHorizontalDragCancel: () => setState(() => _seeking = false),
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
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: C.border,
                    valueColor: AlwaysStoppedAnimation(C.lime),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
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
