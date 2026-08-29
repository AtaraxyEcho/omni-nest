part of 'music_controller.dart';

extension _MusicCenterMapping on MusicCenterController {
  List<MusicPlayableItem> _toRecentItems(List<MusicRecentEntry> entries) {
    final items = <MusicPlayableItem>[];
    for (final entry in entries) {
      final localTrack = entry.localTrack;
      final onlineTrack = entry.onlineTrack;
      if (localTrack != null) {
        items.add(MusicPlayableItem.local(localTrack));
      } else if (onlineTrack != null) {
        items.add(MusicPlayableItem.online(onlineTrack));
      }
    }
    return List<MusicPlayableItem>.unmodifiable(items);
  }

  MusicRepeatMode _repeatModeFromValue(String value) {
    return switch (value) {
      'all' => MusicRepeatMode.all,
      'one' => MusicRepeatMode.one,
      _ => MusicRepeatMode.off,
    };
  }
}
