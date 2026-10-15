// lib/navidrome_client.dart
import 'dart:convert';
import 'dart:math';

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
    this.duration = 0,
    this.coverArt,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String? coverArt;
  final String? coverUrl;

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? 'Untitled'}',
    artist: (json['artist'] as String?)?.trim().isNotEmpty == true
        ? json['artist'] as String
        : 'Unknown artist',
    album: (json['album'] as String?)?.trim().isNotEmpty == true
        ? json['album'] as String
        : 'Unknown album',
    duration: (json['duration'] as num?)?.round() ?? 0,
    coverArt: json['coverArt'] as String?,
  );

  MusicTrack withCover(String? url) => MusicTrack(
    id: id,
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    coverArt: coverArt,
    coverUrl: url,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'duration': duration,
    'coverArt': coverArt,
    'coverUrl': coverUrl,
  };
}

class ListeningEvent {
  const ListeningEvent({
    required this.id,
    required this.artist,
    required this.album,
    required this.playedAt,
  });

  final String id;
  final String artist;
  final String album;
  final int playedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'artist': artist,
    'album': album,
    'playedAt': playedAt,
  };

  factory ListeningEvent.fromJson(Map<String, dynamic> json) => ListeningEvent(
    id: '${json['id']}',
    artist: '${json['artist'] ?? 'Unknown artist'}',
    album: '${json['album'] ?? 'Unknown album'}',
    playedAt: (json['playedAt'] as num?)?.toInt() ?? 0,
  );
}

class NavidromeClient {
  NavidromeClient(this.credentials)
    : baseUrl = credentials.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  final NavidromeCredentials credentials;
  final String baseUrl;
  final Random _random = Random.secure();
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
  final favoriteArtists = <String, int>{};
  final favoriteAlbums = <String, int>{};

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
    final weight = max(.25, 1 - age / max(recent.length, 1));

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

    // Lightweight on-device personalization: favor familiar artists/albums,
    // give favorites a boost, and avoid repeating the same tracks too often.
    // This is intentionally explainable and needs no cloud AI service or key.
    final score =
        (artistCounts[artist] ?? 0) * 1.8 +
        (albumCounts[album] ?? 0) * 1.15 +
        (favoriteArtists[artist] ?? 0) * 2.4 +
        (favoriteAlbums[album] ?? 0) * 1.4 -
        (trackCounts[track.id] ?? 0) * 1.25 +
        (favoriteIds.contains(track.id) ? 1.8 : 0) +
        // Small stable tie-breaker so equal scores do not jump around.
        (track.id.isEmpty
                ? 0
                : track.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
                      23) /
            100;

    return (track: track, score: score, wasPlayed: played.contains(track.id));
  }).toList()..sort((a, b) => b.score.compareTo(a.score));

  final unplayed = ranked.where((item) => !item.wasPlayed).toList();

  final candidates = unplayed.length >= min(limit, tracks.length)
      ? unplayed
      : ranked;

  return candidates.take(limit).map((item) => item.track).toList();
}
