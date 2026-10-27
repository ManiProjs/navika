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

part 'src/app_widgets.dart';
part 'src/home_data.dart';
part 'src/playback.dart';
part 'src/collections.dart';
part 'src/home_layout.dart';
part 'src/flow_logic.dart';
part 'src/discovery.dart';
part 'src/library_pages.dart';
part 'src/mini_player.dart';
part 'src/settings.dart';
part 'src/flow_ui.dart';
part 'src/player_ui.dart';
part 'src/shared_widgets.dart';

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
      ? const Color(0xFFF6F6F3)
      : (amoled ? const Color(0xFF000000) : const Color(0xFF100F0D));
  static Color get surface => light
      ? const Color(0xFFFFFFFF)
      : (amoled ? const Color(0xFF090909) : const Color(0xFF1B1916));
  static Color get surface2 => light
      ? const Color(0xFFEBEBE6)
      : (amoled ? const Color(0xFF141414) : const Color(0xFF24211D));
  static Color get border => light
      ? const Color(0xFFD8D8D0)
      : (amoled ? const Color(0xFF242424) : const Color(0xFF302D28));
  static Color get text =>
      light ? const Color(0xFF171713) : const Color(0xFFF5F3EC);
  static Color get muted =>
      light ? const Color(0xFF68685F) : const Color(0xFFA29D91);
  static Color get lime =>
      light ? const Color(0xFF426600) : const Color(0xFFD6FF39);
  static Color get black => light ? const Color(0xFFFFFFFF) : bg;
  static Color get danger =>
      light ? const Color(0xFFB42318) : const Color(0xFFFF8585);
}

const _credentialsKey = 'navika.navidrome.credentials';
typedef CredentialReaderOverride = Future<String?> Function(
  SharedPreferences preferences,
);
const _secureCredentialsChannel = MethodChannel(
  'app.navika/secure_credentials',
);
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

Future<List<String>> _listAudioPathsInFolder(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    throw FileSystemException('Folder no longer exists', path);
  }
  final found = <String>[];
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File &&
        RegExp(
          r'\.(mp3|m4a|m4b|m4p|aac|adts|wav|wave|bwf|flac|ogg|oga|opus|aiff|aif|alac|ape|wv|mp4|3gp|mka|webm|wma|mid|midi|caf|amr|ac3|dts|dsf|dff|mpc|tak|audio)$',
          caseSensitive: false,
        ).hasMatch(entity.path)) {
      found.add(entity.path);
    }
  }
  return found;
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.credentialReaderOverride});

  final CredentialReaderOverride? credentialReaderOverride;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  final ValueNotifier<MusicTrack?> _currentTrackNotifier = ValueNotifier(null);
  final ValueNotifier<Duration?> _durationNotifier = ValueNotifier(null);
  final ValueNotifier<int> _queueIndexNotifier = ValueNotifier(0);
  late final Listenable _playbackListenable = Listenable.merge([
    _isPlaying,
    _currentTrackNotifier,
    _durationNotifier,
    _queueIndexNotifier,
  ]);
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  Future<void> _playbackOperation = Future<void>.value();
  int _playRequestId = 0;
  final GlobalKey _progressBarKey = GlobalKey();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  Timer? _searchTimer;
  Timer? _sleepTimer;
  Timer? _historySaveTimer;
  Timer? _settingsUnmountTimer;
  Timer? _playerUnmountTimer;
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
  Set<String> _favorites = <String>{};
  Map<String, List<String>> _playlists = {};
  final Set<String> _expandedPlaylists = {};

  MusicTrack? _current;
  int _queueIndex = 0;
  List<MusicTrack>? _cachedModeTracks;
  List<MusicTrack>? _cachedModeSource;
  List<MusicTrack>? _cachedLocalSource;
  bool? _cachedModeIsLocal;
  Map<String, MusicTrack>? _cachedTracksById;
  List<MusicTrack>? _cachedTracksByIdSource;
  List<MusicTrack>? _cachedFavoriteTracks;
  List<MusicTrack>? _cachedFlowQueue;
  List<MusicTrack>? _cachedRecommendedTracks;
  List<MusicTrack>? _cachedDiscoveryTracks;
  List<MusicTrack>? _cachedFavoriteArtistTracks;
  List<MusicTrack>? _cachedRecentlyPlayedTracks;
  bool _flowQueueDirty = true;

  bool _connected = false;
  bool _libraryLoaded = false;
  bool _loading = false;
  bool _searching = false;
  bool _busy = false;
  bool _showLogin = false;
  bool _showSettings = false;
  bool _settingsOverlayMounted = false;
  bool _showPlayer = false;
  bool _playerOverlayMounted = false;
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

  void _updateState(VoidCallback update) {
    final wasSettingsOpen = _showSettings;
    final wasPlayerOpen = _showPlayer;
    setState(() {
      update();
      if (_showSettings) {
        _settingsUnmountTimer?.cancel();
        _settingsOverlayMounted = true;
      } else if (wasSettingsOpen && _settingsOverlayMounted) {
        _settingsUnmountTimer?.cancel();
        _settingsUnmountTimer = Timer(
          _reduceMotion ? Duration.zero : const Duration(milliseconds: 170),
          () {
            if (!mounted || _showSettings) return;
            setState(() => _settingsOverlayMounted = false);
          },
        );
      }
      if (_showPlayer) {
        _playerUnmountTimer?.cancel();
        _playerOverlayMounted = true;
      } else if (wasPlayerOpen && _playerOverlayMounted) {
        _playerUnmountTimer?.cancel();
        _playerUnmountTimer = Timer(
          _reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          () {
            if (!mounted || _showPlayer) return;
            setState(() => _playerOverlayMounted = false);
          },
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep artwork decoding bounded on memory-constrained phones and laptops.
    PaintingBinding.instance.imageCache
      ..maximumSize = 300
      ..maximumSizeBytes = 64 << 20;
    _restore();

    _isPlaying.value = _player.playing;
    _durationNotifier.value = _player.duration;
    _playerSubscriptions.add(
      _player.playerStateStream.listen((state) {
        _isPlaying.value = state.playing;
      }),
    );

    _playerSubscriptions.add(
      _player.currentIndexStream.listen((index) {
        if (index != null && index >= 0 && index < _queue.length) {
          _queueIndexNotifier.value = index;
        }
      }),
    );

    _playerSubscriptions.add(
      _player
          .createPositionStream(
            minPeriod: const Duration(milliseconds: 250),
            maxPeriod: const Duration(milliseconds: 500),
          )
          .listen((position) {
            // Position ticks arrive several times per second. Keep them out of the
            // page-level setState so a progress update doesn't rebuild the entire
            // library, settings, artwork shelves, and navigation on older phones.
            if (!_seeking) _position.value = position;
          }),
    );
    _playerSubscriptions.add(
      _player.durationStream.listen((duration) {
        _durationNotifier.value = duration;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchTimer?.cancel();
    _sleepTimer?.cancel();
    _historySaveTimer?.cancel();
    _settingsUnmountTimer?.cancel();
    _playerUnmountTimer?.cancel();
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _player.dispose();
    _position.dispose();
    _isPlaying.dispose();
    _currentTrackNotifier.dispose();
    _durationNotifier.dispose();
    _queueIndexNotifier.dispose();
    _search.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _localFolders.isNotEmpty) {
      unawaited(_scanLocalFolders());
    }
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
                if (_settingsOverlayMounted)
                  _settingsOverlay(isMobile: !isDesktop),
                // Keep the player mounted so its open/close transition can run,
                // but make the hidden layer transparent to taps.
                if (_current != null && _playerOverlayMounted)
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
                            : Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _showPlayer ? 1 : 0,
                          duration: _reduceMotion
                              ? Duration.zero
                              : Duration(milliseconds: 140),
                          child: ListenableBuilder(
                            listenable: _playbackListenable,
                            builder: (context, child) => _playerOverlay(),
                          ),
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
}

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final list = toList();
    return list.skip(list.length > count ? list.length - count : 0);
  }
}
