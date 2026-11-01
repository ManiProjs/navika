// lib/navidrome_client.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class NavidromeCredentials {
  const NavidromeCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'password': password,
  };

  factory NavidromeCredentials.fromJson(Map<String, dynamic> json) =>
      NavidromeCredentials(
        baseUrl: json['baseUrl'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
      );
}

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    this.artist = 'Unknown artist',
    this.album = 'Unknown album',
    this.genre = '',
    this.duration = 0,
    this.coverArt,
    this.coverUrl,
    this.localPath,
    this.localArtworkPath,
    this.localMetadataRead = false,
    this.localModifiedMillis,
    this.trackGainDb,
    this.albumGainDb,
    this.trackPeak,
    this.albumPeak,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int duration;
  final String? coverArt;
  final String? coverUrl;
  final String? localPath;
  final String? localArtworkPath;
  final bool localMetadataRead;
  final int? localModifiedMillis;
  final double? trackGainDb;
  final double? albumGainDb;
  final double? trackPeak;
  final double? albumPeak;

  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    final replayGain = parseReplayGain(json['replayGain']);
    return MusicTrack(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Untitled'}',
      artist: (json['artist'] as String?)?.trim().isNotEmpty == true
          ? json['artist'] as String
          : 'Unknown artist',
      album: (json['album'] as String?)?.trim().isNotEmpty == true
          ? json['album'] as String
          : 'Unknown album',
      genre: (json['genre'] as String?)?.trim() ?? '',
      duration: (json['duration'] as num?)?.round() ?? 0,
      coverArt: json['coverArt'] as String?,
      coverUrl: json['coverUrl'] as String?,
      localPath: json['localPath'] as String?,
      localArtworkPath: json['localArtworkPath'] as String?,
      localMetadataRead: json['localMetadataRead'] as bool? ?? false,
      localModifiedMillis: (json['localModifiedMillis'] as num?)?.toInt(),
      trackGainDb:
          replayGain['trackGainDb'] ?? _replayGainNumber(json['trackGainDb']),
      albumGainDb:
          replayGain['albumGainDb'] ?? _replayGainNumber(json['albumGainDb']),
      trackPeak:
          replayGain['trackPeak'] ?? _replayGainNumber(json['trackPeak']),
      albumPeak:
          replayGain['albumPeak'] ?? _replayGainNumber(json['albumPeak']),
    );
  }

  MusicTrack withCover(String? url) => MusicTrack(
    id: id,
    title: title,
    artist: artist,
    album: album,
    genre: genre,
    duration: duration,
    coverArt: coverArt,
    coverUrl: url,
    localPath: localPath,
    localArtworkPath: localArtworkPath,
    localMetadataRead: localMetadataRead,
    localModifiedMillis: localModifiedMillis,
    trackGainDb: trackGainDb,
    albumGainDb: albumGainDb,
    trackPeak: trackPeak,
    albumPeak: albumPeak,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'genre': genre,
    'duration': duration,
    'coverArt': coverArt,
    'coverUrl': coverUrl,
    'localPath': localPath,
    'localArtworkPath': localArtworkPath,
    'localMetadataRead': localMetadataRead,
    'localModifiedMillis': localModifiedMillis,
    'trackGainDb': trackGainDb,
    'albumGainDb': albumGainDb,
    'trackPeak': trackPeak,
    'albumPeak': albumPeak,
  };
}

double? _replayGainNumber(dynamic value) {
  if (value is num) return value.isFinite ? value.toDouble() : null;
  if (value is! String) return null;
  final match = RegExp(r'^\s*([+-]?(?:\d+\.?\d*|\.\d+))').firstMatch(value);
  final parsed = match == null ? null : double.tryParse(match.group(1)!);
  return parsed != null && parsed.isFinite ? parsed : null;
}

double? parseReplayGainDb(String? value) => _replayGainNumber(value);

/// Parses the Subsonic/Navidrome ReplayGain object without requiring it.
Map<String, double?> parseReplayGain(dynamic value) {
  if (value is! Map) return const {};
  final gain = Map<String, dynamic>.from(value);
  return {
    'trackGainDb': _replayGainNumber(gain['trackGain']),
    'albumGainDb': _replayGainNumber(gain['albumGain']),
    'trackPeak': _replayGainNumber(gain['trackPeak']),
    'albumPeak': _replayGainNumber(gain['albumPeak']),
  };
}

/// Converts ReplayGain dB metadata to a safe linear player volume.
double replayGainVolume(
  MusicTrack track, {
  bool useAlbumGain = false,
  double preampDb = 0,
}) {
  final gain = useAlbumGain
      ? (track.albumGainDb ?? track.trackGainDb)
      : track.trackGainDb;
  if (gain == null || !gain.isFinite) return 1;
  final peak = useAlbumGain
      ? (track.albumPeak ?? track.trackPeak)
      : track.trackPeak;
  var adjustedGain = gain + preampDb;
  if (peak != null && peak > 0 && peak.isFinite) {
    adjustedGain = math.min(adjustedGain, -20 * math.log(peak) / math.ln10);
  }
  return math.pow(10, adjustedGain / 20).clamp(0.0, 1.0).toDouble();
}

class ListeningEvent {
  const ListeningEvent({
    required this.id,
    required this.artist,
    required this.album,
    required this.playedAt,
    this.genre = '',
  });

  final String id;
  final String artist;
  final String album;
  final int playedAt;
  final String genre;

  Map<String, dynamic> toJson() => {
    'id': id,
    'artist': artist,
    'album': album,
    'playedAt': playedAt,
    'genre': genre,
  };

  factory ListeningEvent.fromJson(Map<String, dynamic> json) => ListeningEvent(
    id: '${json['id']}',
    artist: '${json['artist'] ?? 'Unknown artist'}',
    album: '${json['album'] ?? 'Unknown album'}',
    playedAt: (json['playedAt'] as num?)?.toInt() ?? 0,
    genre: (json['genre'] as String?)?.trim() ?? '',
  );
}

/// Builds a personalized Flow batch using only metadata and listening signals
/// Navika actually has. A seed can be supplied by tests for reproducibility.
List<MusicTrack> buildFlowQueue({
  required List<MusicTrack> tracks,
  required List<ListeningEvent> history,
  Set<String> favoriteIds = const {},
  Map<String, int> artistFeedback = const {},
  Map<String, int> trackFeedback = const {},
  Set<String> excludedArtistKeys = const {},
  Set<String> excludedTrackIds = const {},
  Set<String> excludedIds = const {},
  double familiarity = .62,
  double variety = .68,
  int limit = 80,
  int? seed,
  int? nowMillis,
}) {
  if (tracks.isEmpty || limit <= 0) return [];
  final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
  final artistAffinity = <String, double>{};
  final albumAffinity = <String, double>{};
  final genreAffinity = <String, double>{};
  final favoriteArtistAffinity = <String, int>{};
  final favoriteAlbumAffinity = <String, int>{};
  final favoriteGenreAffinity = <String, int>{};
  final trackRecency = <String, double>{};
  final artistRecency = <String, double>{};
  final albumRecency = <String, double>{};

  for (var index = 0; index < history.length; index++) {
    final event = history[index];
    final ageDays = event.playedAt <= 0
        ? (history.length - index).toDouble()
        : math.max(0, now - event.playedAt) / Duration.millisecondsPerDay;
    final weight = math.exp(-ageDays / 45).clamp(.04, 1.0).toDouble();
    final artist = event.artist.trim().toLowerCase();
    final album = '${event.album.trim().toLowerCase()}::$artist';
    final genre = event.genre.trim().toLowerCase();
    artistAffinity.update(
      artist,
      (value) => value + weight,
      ifAbsent: () => weight,
    );
    albumAffinity.update(
      album,
      (value) => value + weight,
      ifAbsent: () => weight,
    );
    trackRecency.update(
      event.id,
      (value) => math.max(value, weight).toDouble(),
      ifAbsent: () => weight,
    );
    artistRecency.update(
      artist,
      (value) => math.max(value, weight).toDouble(),
      ifAbsent: () => weight,
    );
    albumRecency.update(
      album,
      (value) => math.max(value, weight).toDouble(),
      ifAbsent: () => weight,
    );
    if (genre.isNotEmpty) {
      genreAffinity.update(
        genre,
        (value) => value + weight,
        ifAbsent: () => weight,
      );
    }
  }

  for (final track in tracks.where((item) => favoriteIds.contains(item.id))) {
    final artist = track.artist.trim().toLowerCase();
    final album = '${track.album.trim().toLowerCase()}::$artist';
    final genre = track.genre.trim().toLowerCase();
    favoriteArtistAffinity.update(
      artist,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    favoriteAlbumAffinity.update(
      album,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    if (genre.isNotEmpty) {
      favoriteGenreAffinity.update(
        genre,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }

  final unique = <String, MusicTrack>{};
  for (final track in tracks) {
    final artist = track.artist.trim().toLowerCase();
    if (track.id.isEmpty ||
        excludedIds.contains(track.id) ||
        excludedTrackIds.contains(track.id) ||
        excludedArtistKeys.contains(artist) ||
        (trackFeedback[track.id] ?? 0) <= -2) {
      continue;
    }
    unique.putIfAbsent(track.id, () => track);
  }

  final candidates = unique.values.map((track) {
    final artist = track.artist.trim().toLowerCase();
    final album = '${track.album.trim().toLowerCase()}::$artist';
    final genre = track.genre.trim().toLowerCase();
    final artistFamiliarity =
        (artistAffinity[artist] ?? 0) / 5 +
        (favoriteArtistAffinity[artist] ?? 0) * .16;
    final albumFamiliarity =
        (albumAffinity[album] ?? 0) / 4 +
        (favoriteAlbumAffinity[album] ?? 0) * .18;
    final familiarityScore =
        (artistFamiliarity * .68 +
                albumFamiliarity * .22 +
                (favoriteIds.contains(track.id) ? .3 : 0))
            .clamp(0.0, 1.0)
            .toDouble();
    final discoveryScore =
        (1 - familiarityScore) * .78 +
        (trackRecency.containsKey(track.id)
            ? -.42 * trackRecency[track.id]!
            : .18);
    final genreScore = genre.isEmpty
        ? 0.0
        : (((genreAffinity[genre] ?? 0) / 5) +
                      (favoriteGenreAffinity[genre] ?? 0) * .12)
                  .clamp(0.0, 1.0) *
              .22;
    final artistScore = ((artistFeedback[artist] ?? 0).clamp(-2, 2) * .24)
        .toDouble();
    final trackScore = ((trackFeedback[track.id] ?? 0).clamp(-2, 2) * .34)
        .toDouble();
    final recencyPenalty =
        (artistRecency[artist] ?? 0) * .12 + (albumRecency[album] ?? 0) * .08;
    final familiarityValue = familiarity.clamp(0.0, 1.0).toDouble();
    final score =
        familiarityValue * familiarityScore +
        (1 - familiarityValue) * discoveryScore +
        genreScore +
        artistScore +
        trackScore -
        recencyPenalty;
    return (track: track, artist: artist, album: album, score: score);
  }).toList();

  final remaining = List.of(candidates);
  final result = <MusicTrack>[];
  final recentArtists = <String, int>{};
  final recentAlbums = <String, int>{};
  final random = math.Random(seed);
  while (remaining.isNotEmpty && result.length < limit) {
    final scores = remaining
        .map(
          (candidate) =>
              candidate.score -
              (recentArtists[candidate.artist] ?? 0) *
                  variety.clamp(0.0, 1.0) *
                  .48 -
              (recentAlbums[candidate.album] ?? 0) *
                  variety.clamp(0.0, 1.0) *
                  .22,
        )
        .toList();
    final maximum = scores.reduce((a, b) => math.max(a, b).toDouble());
    final temperature = .22 + variety.clamp(0.0, 1.0) * .22;
    final weights = scores
        .map((score) => math.exp((score - maximum) / temperature))
        .toList();
    final total = weights.fold<double>(0, (sum, weight) => sum + weight);
    var draw = random.nextDouble() * total;
    var selected = weights.length - 1;
    for (var index = 0; index < weights.length; index++) {
      draw -= weights[index];
      if (draw <= 0) {
        selected = index;
        break;
      }
    }
    final pick = remaining.removeAt(selected);
    result.add(pick.track);
    recentArtists.update(pick.artist, (count) => count + 1, ifAbsent: () => 1);
    recentAlbums.update(pick.album, (count) => count + 1, ifAbsent: () => 1);
    if (result.length > 4) {
      final expiredTrack = result[result.length - 5];
      final expiredArtist = expiredTrack.artist.trim().toLowerCase();
      final expiredAlbum =
          '${expiredTrack.album.trim().toLowerCase()}::$expiredArtist';
      final artistCount = recentArtists[expiredArtist] ?? 0;
      final albumCount = recentAlbums[expiredAlbum] ?? 0;
      if (artistCount <= 1) {
        recentArtists.remove(expiredArtist);
      } else {
        recentArtists[expiredArtist] = artistCount - 1;
      }
      if (albumCount <= 1) {
        recentAlbums.remove(expiredAlbum);
      } else {
        recentAlbums[expiredAlbum] = albumCount - 1;
      }
    }
  }
  return result;
}

class NavidromeClient {
  NavidromeClient(this.credentials)
    : baseUrl = credentials.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  final NavidromeCredentials credentials;
  final String baseUrl;
  final math.Random _random = math.Random.secure();
  final Map<String, String> _coverArtUrls = {};

  Map<String, String> _authParams() {
    final salt = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final token = md5
        .convert(utf8.encode('${credentials.password}$salt'))
        .toString();

    return {
      'u': credentials.username,
      't': token,
      's': salt,
      'v': '1.16.1',
      'c': 'Navika',
      'f': 'json',
    };
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, [
    Map<String, String> params = const {},
  ]) async {
    final uri = Uri.parse('$baseUrl/rest/$endpoint.view')
        .replace(queryParameters: {..._authParams(), ...params});

    final response = await http.get(uri).timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    final result = decoded['subsonic-response'] as Map<String, dynamic>?;

    if (result == null || result['status'] != 'ok') {
      final error = result?['error'] as Map<String, dynamic>?;
      throw Exception(error?['message'] ?? 'Navidrome request failed');
    }

    return result;
  }

  Future<void> connect() async {
    await _request('ping');
  }

  Future<List<MusicTrack>> searchTracks(String query, {int limit = 100}) async {
    final normalized = query.trim();
    if (normalized.isEmpty || limit <= 0) return [];

    final result = await _request('search3', {
      'query': normalized,
      'songCount': '${limit.clamp(1, 500)}',
      'songOffset': '0',
      'albumCount': '0',
      'artistCount': '0',
    });
    final searchResult = result['searchResult3'] as Map<String, dynamic>?;
    return (searchResult?['song'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MusicTrack.fromJson)
        .where((track) => track.id.isNotEmpty)
        .toList();
  }

  Future<List<MusicTrack>> getLibraryTracks() async {
    const pageSize = 500;
    final albums = <Map<String, dynamic>>[];
    final seenAlbumIds = <String>{};

    for (var offset = 0; ; offset += pageSize) {
      final result = await _request('getAlbumList2', {
        'type': 'alphabeticalByName',
        'size': '$pageSize',
        'offset': '$offset',
      });
      final list = result['albumList2'] as Map<String, dynamic>?;
      final page = (list?['album'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final newAlbums = page.where((album) {
        final id = '${album['id'] ?? ''}';
        return id.isNotEmpty && seenAlbumIds.add(id);
      }).toList();
      albums.addAll(newAlbums);
      if (page.length < pageSize || newAlbums.isEmpty) break;
    }

    final collected = <MusicTrack>[];

    // Limit concurrency to keep large libraries responsive.
    for (var start = 0; start < albums.length; start += 8) {
      final batch = albums.skip(start).take(8).toList();

      final results = await Future.wait(
        batch.map((album) async {
          final albumResult = await _request('getAlbum', {
            'id': '${album['id']}',
          });

          final body = albumResult['album'] as Map<String, dynamic>?;

          return (body?['song'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(MusicTrack.fromJson)
              .toList();
        }),
      );

      collected.addAll(results.expand((items) => items));
    }

    final unique = <String, MusicTrack>{};

    for (final track in collected) {
      if (track.id.isNotEmpty) {
        unique[track.id] = track;
      }
    }

    return unique.values.toList();
  }

  String? coverArtUrl(String? id, {int size = 512}) {
    if (id == null || id.isEmpty) return null;

    return _coverArtUrls.putIfAbsent('$id:$size', () {
      return Uri.parse('$baseUrl/rest/getCoverArt.view')
          .replace(
            queryParameters: {..._authParams(), 'id': id, 'size': '$size'},
          )
          .toString();
    });
  }

  String streamUrl(String id) {
    return Uri.parse('$baseUrl/rest/stream.view')
        .replace(queryParameters: {..._authParams(), 'id': id})
        .toString();
  }
}

List<MusicTrack> recommendTracks(
  List<MusicTrack> tracks,
  List<ListeningEvent> history, {
  String? currentId,
  Set<String> favoriteIds = const {},
  int limit = 10,
}) {
  if (tracks.isEmpty || limit <= 0) return [];

  final recent = history.length > 120
      ? history.sublist(history.length - 120)
      : history;

  final artistCounts = <String, double>{};
  final albumCounts = <String, double>{};
  final trackCounts = <String, double>{};
  final libraryArtistCounts = <String, int>{};
  final libraryAlbumCounts = <String, int>{};
  final favoriteArtists = <String, int>{};
  final favoriteAlbums = <String, int>{};

  // Treat the actual library as the recommendation universe and learn its
  // artist/album shape before applying listening-history personalization.
  for (final track in tracks) {
    libraryArtistCounts.update(
      track.artist.toLowerCase(),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    libraryAlbumCounts.update(
      '${track.album.toLowerCase()}::${track.artist.toLowerCase()}',
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  for (final track in tracks.where((track) => favoriteIds.contains(track.id))) {
    favoriteArtists.update(
      track.artist.toLowerCase(),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    favoriteAlbums.update(
      track.album.toLowerCase(),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  for (var i = 0; i < recent.length; i++) {
    final event = recent[i];
    final age = recent.length - i;
    final weight = math.max(.25, 1 - age / math.max(recent.length, 1));

    artistCounts.update(
      event.artist.toLowerCase(),
      (value) => value + weight,
      ifAbsent: () => weight,
    );

    albumCounts.update(
      event.album.toLowerCase(),
      (value) => value + weight * .65,
      ifAbsent: () => weight * .65,
    );

    trackCounts.update(
      event.id,
      (value) => value + weight,
      ifAbsent: () => weight,
    );
  }

  final played = recent.map((event) => event.id).toSet();

  final ranked = tracks.where((track) => track.id != currentId).map((track) {
    final artist = track.artist.toLowerCase();
    final album = track.album.toLowerCase();
    final albumKey = '$album::$artist';

    // Lightweight on-device personalization: favor familiar artists/albums,
    // give favorites a boost, and avoid repeating the same tracks too often.
    // This is intentionally explainable and needs no cloud AI service or key.
    final score =
        (artistCounts[artist] ?? 0) * 2.0 +
        (albumCounts[album] ?? 0) * 1.5 +
        (favoriteArtists[artist] ?? 0) * 2.8 +
        (favoriteAlbums[album] ?? 0) * 1.8 -
        (trackCounts[track.id] ?? 0) * 1.5 +
        (favoriteIds.contains(track.id) ? 2.0 : 0) +
        // Favor complete album journeys and artists already represented in
        // the user's collection, without letting large catalogs dominate.
        math.min((libraryAlbumCounts[albumKey] ?? 1) - 1, 6) * .12 +
        ((libraryArtistCounts[artist] ?? 1) > 1 ? .15 : 0) +
        // Small stable tie-breaker so equal scores do not jump around.
        (track.id.isEmpty
                ? 0
                : track.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
                      23) /
            100;

    return (track: track, score: score, wasPlayed: played.contains(track.id));
  }).toList()..sort((a, b) => b.score.compareTo(a.score));

  final unplayed = ranked.where((item) => !item.wasPlayed).toList();

  final candidates = unplayed.length >= math.min(limit, tracks.length)
      ? unplayed
      : ranked;

  return candidates.take(limit).map((item) => item.track).toList();
}
