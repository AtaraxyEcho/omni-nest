import 'package:omninest/features/music/domain/music_models.dart';

/// 音乐内容来源平台。
enum MusicPlatform {
  local('local'),
  netease('netease'),
  qq('qq');

  const MusicPlatform(this.apiValue);

  final String apiValue;

  /// 将后端平台标识转换为类型安全枚举。
  static MusicPlatform fromApiValue(String value) {
    return MusicPlatform.values.firstWhere(
      (platform) => platform.apiValue == value.trim().toLowerCase(),
      orElse: () => throw FormatException('不支持的音乐平台: $value'),
    );
  }
}

/// 可播放音乐的来源引用。
sealed class MusicPlayableRef {
  const MusicPlayableRef();

  /// 用于缓存、队列和进度的稳定标识。
  String get playableKey;
}

/// 本地曲库引用。
final class LocalMusicRef extends MusicPlayableRef {
  const LocalMusicRef(this.trackId);

  final String trackId;

  @override
  String get playableKey => 'local:$trackId';
}

/// 外部平台曲目引用。
final class OnlineMusicRef extends MusicPlayableRef {
  const OnlineMusicRef({
    required this.platform,
    required this.songId,
    this.mediaMid,
  });

  final MusicPlatform platform;
  final String songId;
  final String? mediaMid;

  @override
  String get playableKey => 'online:${platform.apiValue}:$songId';
}

/// 统一可播放音乐对象。
class MusicPlayableItem {
  const MusicPlayableItem({required this.ref, required this.track});

  /// 从本地曲库曲目创建可播放对象。
  factory MusicPlayableItem.local(MusicTrack track) {
    return MusicPlayableItem(ref: LocalMusicRef(track.id), track: track);
  }

  /// 从外部平台搜索结果创建可播放对象。
  factory MusicPlayableItem.online(
    OnlineTrack onlineTrack, {
    String format = 'AUDIO',
  }) {
    final platform = MusicPlatform.fromApiValue(onlineTrack.platform);
    final ref = OnlineMusicRef(
      platform: platform,
      songId: onlineTrack.songId,
      mediaMid: onlineTrack.mediaMid,
    );
    return MusicPlayableItem(
      ref: ref,
      track: MusicTrack(
        id: ref.playableKey,
        fileNodeId: '',
        title: onlineTrack.title,
        artistName: onlineTrack.artistName,
        albumTitle: onlineTrack.albumTitle,
        format: format,
        favorite: false,
        durationSeconds: onlineTrack.durationSeconds,
        coverUrl: onlineTrack.coverUrl,
      ),
    );
  }

  /// 从播放队列缓存快照恢复类型化可播放对象。
  factory MusicPlayableItem.fromQueueJson(Map<String, dynamic> json) {
    final playableKey = json['playableKey']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    if (title.isEmpty) {
      throw const FormatException('播放队列曲目标题为空');
    }
    final track = MusicTrack(
      id: playableKey,
      fileNodeId: '',
      title: title,
      artistName: json['artistName']?.toString() ?? '',
      albumTitle: json['albumTitle']?.toString() ?? '',
      format: json['format']?.toString() ?? 'AUDIO',
      favorite: false,
      durationSeconds: _queueNullableInt(json['durationSeconds']),
      coverUrl: json['coverUrl']?.toString(),
    );
    if (playableKey.startsWith('local:')) {
      final trackId = playableKey.substring('local:'.length);
      if (trackId.isEmpty) {
        throw const FormatException('本地播放队列曲目标识为空');
      }
      return MusicPlayableItem(
        ref: LocalMusicRef(trackId),
        track: track.copyWithQueueIdentity(trackId),
      );
    }
    final parts = playableKey.split(':');
    if (parts.length != 3 || parts[0] != 'online' || parts[2].isEmpty) {
      throw FormatException('播放队列曲目标识格式不正确: $playableKey');
    }
    return MusicPlayableItem(
      ref: OnlineMusicRef(
        platform: MusicPlatform.fromApiValue(parts[1]),
        songId: parts[2],
        mediaMid: json['mediaMid']?.toString(),
      ),
      track: track,
    );
  }

  final MusicPlayableRef ref;

  /// 兼容现有展示组件的曲目信息投影。
  final MusicTrack track;

  String get playableKey => ref.playableKey;

  MusicPlayableItem copyWith({MusicTrack? track}) {
    return MusicPlayableItem(ref: ref, track: track ?? this.track);
  }

  /// 转换为不包含凭据和临时播放地址的队列快照。
  Map<String, dynamic> toQueueJson() {
    final mediaMid = switch (ref) {
      OnlineMusicRef(:final mediaMid) => mediaMid,
      LocalMusicRef() => null,
    };
    return <String, dynamic>{
      'playableKey': playableKey,
      'title': track.title,
      'artistName': track.artistName,
      'albumTitle': track.albumTitle,
      'coverUrl': track.coverUrl ?? '',
      'durationSeconds': track.durationSeconds,
      'format': track.format,
      if (mediaMid != null && mediaMid.isNotEmpty) 'mediaMid': mediaMid,
    };
  }
}

/// 可跨设备恢复的播放队列快照。
class MusicPlaybackQueueSnapshot {
  const MusicPlaybackQueueSnapshot({
    this.items = const <MusicPlayableItem>[],
    this.currentIndex = -1,
    this.repeatMode = 'off',
    this.shuffleEnabled = false,
    this.updatedAt,
  });

  factory MusicPlaybackQueueSnapshot.fromJson(Map<String, dynamic> json) {
    final items = <MusicPlayableItem>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          continue;
        }
        try {
          items.add(
            MusicPlayableItem.fromQueueJson(
              rawItem.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        } on FormatException {
          continue;
        }
      }
    }
    final rawIndex = _queueNullableInt(json['currentIndex']) ?? -1;
    final currentIndex =
        items.isEmpty ? -1 : rawIndex.clamp(0, items.length - 1).toInt();
    final repeatMode = switch (json['repeatMode']?.toString()) {
      'all' => 'all',
      'one' => 'one',
      _ => 'off',
    };
    return MusicPlaybackQueueSnapshot(
      items: List<MusicPlayableItem>.unmodifiable(items),
      currentIndex: currentIndex,
      repeatMode: repeatMode,
      shuffleEnabled: json['shuffleEnabled'] == true,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  final List<MusicPlayableItem> items;
  final int currentIndex;
  final String repeatMode;
  final bool shuffleEnabled;
  final DateTime? updatedAt;

  MusicPlayableItem? get currentItem =>
      currentIndex >= 0 && currentIndex < items.length
          ? items[currentIndex]
          : null;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((item) => item.toQueueJson()).toList(growable: false),
      'currentIndex': currentIndex,
      'repeatMode': repeatMode,
      'shuffleEnabled': shuffleEnabled,
    };
  }

  Map<String, dynamic> toCacheJson() {
    return <String, dynamic>{
      ...toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }
}

int? _queueNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

extension on MusicTrack {
  MusicTrack copyWithQueueIdentity(String id) {
    return MusicTrack(
      id: id,
      fileNodeId: fileNodeId,
      title: title,
      artistName: artistName,
      albumTitle: albumTitle,
      format: format,
      favorite: favorite,
      durationSeconds: durationSeconds,
      bitrate: bitrate,
      sampleRate: sampleRate,
      fileSize: fileSize,
      lyricsRaw: lyricsRaw,
      coverUrl: coverUrl,
      updatedAt: updatedAt,
    );
  }
}
