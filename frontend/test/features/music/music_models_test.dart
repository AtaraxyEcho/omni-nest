import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/music/domain/music_models.dart';

void main() {
  test('parses lrc lyrics and keeps timestamps ordered', () {
    final lines = parseMusicLyrics('''
[00:10.00]First line
[00:05.50]Intro
[ar:Unknown Artist]
[00:10.00][00:20.00]Hook
''');

    expect(lines, hasLength(4));
    expect(lines[0].position, const Duration(seconds: 5, milliseconds: 500));
    expect(lines[0].text, 'Intro');
    expect(lines[1].position, const Duration(seconds: 10));
    expect(lines[1].text, 'First line');
    expect(lines[2].position, const Duration(seconds: 10));
    expect(lines[2].text, 'Hook');
    expect(lines[3].position, const Duration(seconds: 20));
    expect(lines[3].text, 'Hook');
  });

  test('music track exposes parsed lyric lines', () {
    const track = MusicTrack(
      id: 'track-1',
      fileNodeId: 'file-1',
      title: 'Night Drive',
      artistName: 'Omni Band',
      albumTitle: 'Unknown Album',
      format: 'flac',
      favorite: false,
      lyricsRaw: '[00:01.00]Hello',
    );

    expect(track.lyricLines, hasLength(1));
    expect(track.lyricLines.single.position, const Duration(seconds: 1));
    expect(track.lyricLines.single.text, 'Hello');
  });
}
