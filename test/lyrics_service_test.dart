import 'package:flutter_test/flutter_test.dart';
import 'package:navika/lyrics_service.dart';

void main() {
  group('parseLrc', () {
    test('parses centisecond timestamps and sorts lines', () {
      final lines = parseLrc('''
[00:12.34]Second line
[00:02.05]First line
[ar:Artist]
''');

      expect(lines, hasLength(2));
      expect(lines[0].text, 'First line');
      expect(lines[0].time, const Duration(milliseconds: 2050));
      expect(lines[1].text, 'Second line');
      expect(lines[1].time, const Duration(milliseconds: 12340));
    });

    test('supports multiple timestamps and millisecond precision', () {
      final lines = parseLrc('[00:01.250][00:03.500]Repeated line');

      expect(lines, hasLength(2));
      expect(lines.map((line) => line.time.inMilliseconds), [1250, 3500]);
      expect(lines.map((line) => line.text), [
        'Repeated line',
        'Repeated line',
      ]);
    });

    test('applies positive and negative global offsets', () {
      final positive = parseLrc('[offset:+500]\n[00:01.00]Line');
      final negative = parseLrc('[offset:-500]\n[00:01.00]Line');

      expect(positive.single.time, const Duration(milliseconds: 1500));
      expect(negative.single.time, const Duration(milliseconds: 500));
    });

    test('ignores metadata and empty timestamp lines', () {
      expect(parseLrc('[ti:Title]\n[00:01.00]\nPlain text'), isEmpty);
    });
  });

  test('TrackLyrics survives cache serialization', () {
    final lyrics = TrackLyrics(
      plainLyrics: 'A line',
      syncedLyrics: '[00:01.00]A line',
    );

    final restored = TrackLyrics.fromJson(lyrics.toJson());
    expect(restored.plainLyrics, 'A line');
    expect(restored.lines.single.text, 'A line');
    expect(restored.instrumental, isFalse);
  });
}
