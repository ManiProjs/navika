import 'dart:convert';

import 'package:http/http.dart' as http;

import 'navidrome_client.dart';

final LrclibClient lrclibClient = LrclibClient();

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;

  Map<String, Object> toJson() => {'time': time.inMilliseconds, 'text': text};

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    time: Duration(milliseconds: (json['time'] as num).toInt()),
    text: json['text'] as String,
  );
}

class TrackLyrics {
  TrackLyrics({this.plainLyrics, this.syncedLyrics, this.instrumental = false});

  final String? plainLyrics;
  final String? syncedLyrics;
  final bool instrumental;

  late final List<LyricLine> lines = parseLrc(syncedLyrics ?? '');

  Map<String, Object?> toJson() => {
    'plainLyrics': plainLyrics,
    'syncedLyrics': syncedLyrics,
    'instrumental': instrumental,
  };

  factory TrackLyrics.fromJson(Map<String, dynamic> json) => TrackLyrics(
    plainLyrics: json['plainLyrics'] as String?,
    syncedLyrics: json['syncedLyrics'] as String?,
    instrumental: json['instrumental'] as bool? ?? false,
  );
}

/// Parses line-timed LRC, including multiple timestamps and global offsets.
List<LyricLine> parseLrc(String source) {
  final timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final offsetPattern = RegExp(
    r'^\[offset:([+-]?\d+)\]$',
    caseSensitive: false,
  );
  var offsetMillis = 0;
  final lines = <LyricLine>[];

  for (final rawLine in const LineSplitter().convert(source)) {
    final offsetMatch = offsetPattern.firstMatch(rawLine.trim());
    if (offsetMatch != null) {
      offsetMillis = int.tryParse(offsetMatch.group(1)!) ?? 0;
      continue;
    }
    final matches = timestampPattern.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;
    final text = rawLine.replaceAll(timestampPattern, '').trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3) ?? '0';
      final millis = switch (fraction.length) {
        1 => int.parse(fraction) * 100,
        2 => int.parse(fraction) * 10,
        _ => int.parse(fraction.padRight(3, '0').substring(0, 3)),
      };
      final total = (minutes * 60 + seconds) * 1000 + millis + offsetMillis;
      lines.add(
        LyricLine(
          time: Duration(milliseconds: total.clamp(0, 1 << 31)),
          text: text,
        ),
      );
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

class LrclibClient {
  LrclibClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _userAgent =
      'Navika/0.1.2 (https://github.com/ManiProjs/navika)';

  Future<TrackLyrics?> fetch(MusicTrack track) async {
    if (track.title.trim().isEmpty || track.artist.trim().isEmpty) return null;
    final parameters = <String, String>{
      'track_name': track.title,
      'artist_name': track.artist,
      if (track.album.trim().isNotEmpty && track.album != 'Unknown album')
        'album_name': track.album,
      if (track.duration > 0 && track.duration <= 3600)
        'duration': '${track.duration}',
    };
    final exactUri = Uri.https('lrclib.net', '/api/get', parameters);
    final exact = await _request(exactUri);
    if (exact != null) return exact;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final searchUri = Uri.https('lrclib.net', '/api/search', {
      'track_name': track.title,
      'artist_name': track.artist,
      if (track.album.trim().isNotEmpty && track.album != 'Unknown album')
        'album_name': track.album,
    });
    final response = await _client
        .get(
          searchUri,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return null;
    if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw Exception(
        'LRCLIB rate limit reached${retryAfter == null ? '' : '. Retry after $retryAfter seconds'}.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('LRCLIB returned HTTP ${response.statusCode}.');
    }
    final results = jsonDecode(response.body) as List<dynamic>;
    if (results.isEmpty) return null;
    final records = results.whereType<Map<String, dynamic>>().toList();
    if (records.isEmpty) return null;
    records.sort(
      (a, b) => _matchScore(track, b).compareTo(_matchScore(track, a)),
    );
    return _lyricsFromRecord(records.first);
  }

  Future<TrackLyrics?> _request(Uri uri) async {
    final response = await _client
        .get(
          uri,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return null;
    if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw Exception(
        'LRCLIB rate limit reached${retryAfter == null ? '' : '. Retry after $retryAfter seconds'}.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('LRCLIB returned HTTP ${response.statusCode}.');
    }
    return _lyricsFromRecord(jsonDecode(response.body) as Map<String, dynamic>);
  }

  int _matchScore(MusicTrack track, Map<String, dynamic> record) {
    final title = (record['trackName'] ?? record['name'] ?? '').toString();
    final artist = (record['artistName'] ?? '').toString();
    final album = (record['albumName'] ?? '').toString();
    var score = 0;
    if (_normalize(title) == _normalize(track.title)) score += 8;
    if (_normalize(artist) == _normalize(track.artist)) score += 6;
    if (track.album.isNotEmpty &&
        _normalize(album) == _normalize(track.album)) {
      score += 2;
    }
    final duration = (record['duration'] as num?)?.round() ?? 0;
    if (track.duration > 0 && duration > 0) {
      score += (5 - (duration - track.duration).abs()).clamp(-5, 5).toInt();
    }
    return score;
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  TrackLyrics _lyricsFromRecord(Map<String, dynamic> record) => TrackLyrics(
    plainLyrics: record['plainLyrics'] as String?,
    syncedLyrics: record['syncedLyrics'] as String?,
    instrumental: record['instrumental'] as bool? ?? false,
  );

  void close() => _client.close();
}
