import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omninest/features/music/application/music_audio_playback.dart';
import 'package:omninest/features/music/application/music_playback_session.dart';

class _MockMusicAudioPlayer extends Mock implements MusicAudioPlayback {}

void main() {
  test('MusicPlaybackSession copyWith can update and clear lastError', () {
    final player = _MockMusicAudioPlayer();
    final session = MusicPlaybackSession(player: player, lastError: null);
    final failed = session.copyWith(lastError: 'failed');
    expect(failed.player, same(player));
    expect(failed.lastError, 'failed');
    final cleared = failed.copyWith(lastError: null);
    expect(cleared.lastError, isNull);
  });

  test('isIgnorableMusicPlayerLog ignores known native fallback logs', () {
    expect(
      isIgnorableMusicPlayerLog(
        'error: property not found _setProperty(osc, 1)',
      ),
      isTrue,
    );
    expect(isIgnorableMusicPlayerLog('Failed to create file cache.'), isTrue);
    expect(isIgnorableMusicPlayerLog('Failed to open audio stream.'), isFalse);
  });

  test('only typed playback failures are promoted to user-visible errors', () {
    expect(
      isMusicPlaybackFailureLog(
        const MusicAudioLog('SoLoud 频谱读取失败: visualization unavailable'),
      ),
      isFalse,
    );
    expect(
      isMusicPlaybackFailureLog(
        const MusicAudioLog(
          'SoLoud 音乐打开失败: unsupported codec',
          playbackFailure: true,
        ),
      ),
      isTrue,
    );
  });
}
