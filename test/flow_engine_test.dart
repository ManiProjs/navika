import 'package:flutter_test/flutter_test.dart';
import 'package:navika/navidrome_client.dart';

void main() {
  const tracks = [
    MusicTrack(id: 'one', title: 'One', artist: 'Artist A', album: 'Album A'),
    MusicTrack(id: 'two', title: 'Two', artist: 'Artist B', album: 'Album B'),
    MusicTrack(
      id: 'three',
      title: 'Three',
      artist: 'Artist C',
      album: 'Album C',
      genre: 'Ambient',
    ),
  ];

  test('Flow removes duplicate IDs and respects all permanent exclusions', () {
    final queue = buildFlowQueue(
      tracks: [...tracks, tracks.first],
      history: const [],
      excludedIds: {'two'},
      excludedArtistKeys: {'artist c'},
      excludedTrackIds: {'one'},
      seed: 7,
    );

    expect(queue, isEmpty);
  });

  test('Flow excludes tracks explicitly rated never-play', () {
    final queue = buildFlowQueue(
      tracks: tracks,
      history: const [],
      trackFeedback: {'one': -2},
      limit: 10,
      seed: 11,
    );

    expect(queue.map((track) => track.id), isNot(contains('one')));
    expect(queue.map((track) => track.id).toSet().length, queue.length);
  });

  test(
    'Flow can permanently exclude an artist without penalizing other artists',
    () {
      final queue = buildFlowQueue(
        tracks: tracks,
        history: const [],
        artistFeedback: {'artist a': -2},
        excludedArtistKeys: {'artist a'},
        seed: 13,
      );

      expect(queue.map((track) => track.artist), isNot(contains('Artist A')));
      expect(queue, hasLength(2));
    },
  );

  test(
    'separate Flow batches can exclude tracks already played this session',
    () {
      final first = buildFlowQueue(
        tracks: tracks,
        history: const [],
        limit: 1,
        seed: 19,
      ).single;
      final second = buildFlowQueue(
        tracks: tracks,
        history: const [],
        excludedIds: {first.id},
        limit: 1,
        seed: 19,
      ).single;

      expect(second.id, isNot(first.id));
    },
  );

  test('Flow queue is reproducible with the same seed', () {
    List<String> generate() => buildFlowQueue(
      tracks: tracks,
      history: const [],
      familiarity: .55,
      variety: .7,
      seed: 1234,
    ).map((track) => track.id).toList();

    expect(generate(), generate());
  });

  test('Navidrome ReplayGain metadata is parsed and persisted', () {
    final track = MusicTrack.fromJson({
      'id': 'gain-track',
      'title': 'Gain track',
      'replayGain': {
        'trackGain': '-5.25 dB',
        'albumGain': '-7.0 dB',
        'trackPeak': '0.91',
        'albumPeak': 0.88,
      },
    });

    expect(track.trackGainDb, -5.25);
    expect(track.albumGainDb, -7);
    expect(track.trackPeak, .91);
    expect(track.albumPeak, .88);
    final restored = MusicTrack.fromJson(track.toJson());
    expect(restored.trackGainDb, -5.25);
    expect(restored.albumGainDb, -7);
    expect(
      MusicTrack.fromJson({'id': 'legacy', 'title': 'Legacy'}).trackGainDb,
      isNull,
    );
  });

  test('ReplayGain volume supports album fallback and peak limiting', () {
    const track = MusicTrack(
      id: 'gain-track',
      title: 'Gain track',
      trackGainDb: -6,
      albumGainDb: -3,
      trackPeak: .5,
      albumPeak: .8,
    );

    expect(replayGainVolume(track), closeTo(.5012, .001));
    expect(replayGainVolume(track, useAlbumGain: true), closeTo(.7079, .001));
    expect(replayGainVolume(track, preampDb: 6), closeTo(1, .001));
    expect(
      replayGainVolume(const MusicTrack(id: 'no-gain', title: 'No tags')),
      1,
    );
  });

  test('track genre survives track and listening-event serialization', () {
    const track = MusicTrack(
      id: 'ambient-1',
      title: 'Ambient',
      artist: 'Artist',
      album: 'Album',
      genre: 'Ambient',
    );
    const event = ListeningEvent(
      id: 'ambient-1',
      artist: 'Artist',
      album: 'Album',
      playedAt: 100,
      genre: 'Ambient',
    );

    expect(MusicTrack.fromJson(track.toJson()).genre, 'Ambient');
    expect(
      MusicTrack.fromJson({'id': 'legacy', 'title': 'Legacy'}).genre,
      isEmpty,
    );
    expect(ListeningEvent.fromJson(event.toJson()).genre, 'Ambient');
    expect(
      ListeningEvent.fromJson({
        'id': 'old',
        'artist': 'Artist',
        'album': 'Album',
        'playedAt': 100,
      }).genre,
      isEmpty,
    );
  });
}
