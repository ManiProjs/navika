// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navika/main.dart';
import 'package:navika/navidrome_client.dart';

void main() {
  test('local track metadata survives persistence serialization', () {
    const track = MusicTrack(
      id: 'local:/music/track.flac',
      title: 'Track',
      artist: 'Embedded Artist',
      album: 'Embedded Album',
      localPath: '/music/track.flac',
      localArtworkPath: '/app/artwork/track.img',
      localMetadataRead: true,
    );

    final restored = MusicTrack.fromJson(track.toJson());

    expect(restored.isLocal, isTrue);
    expect(restored.localPath, '/music/track.flac');
    expect(restored.localArtworkPath, '/app/artwork/track.img');
    expect(restored.localMetadataRead, isTrue);
    expect(restored.title, 'Track');
    expect(restored.artist, 'Embedded Artist');
    expect(restored.album, 'Embedded Album');
  });

  testWidgets('Navika app starts and shows its main navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NavikaApp());
    await tester.pump();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
  });

  testWidgets('Search does not dump the entire library before a query', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NavikaApp());
    await tester.pump();

    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();

    expect(find.text('Find your music'), findsOneWidget);
    expect(find.text('Add music to search'), findsOneWidget);
  });
}
