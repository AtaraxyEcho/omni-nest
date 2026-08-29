import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('封面点阵渲染管线已移除并保留原封面底板', () {
    final oldPipeline = File(
      'lib/features/music/presentation/player/music_immersive_cover_field.dart',
    );
    final stageSource =
        File(
          'lib/features/music/presentation/player/music_immersive_player_stage.dart',
        ).readAsStringSync();
    final planeSource =
        File(
          'lib/features/music/presentation/player/music_immersive_cover_plane.dart',
        ).readAsStringSync();
    final performancePipeline = File(
      'lib/features/music/presentation/player/music_immersive_performance_budget.dart',
    );
    final editorSource =
        File(
          'lib/features/music/presentation/player/music_immersive_preset_editor.dart',
        ).readAsStringSync();

    expect(oldPipeline.existsSync(), isFalse);
    expect(stageSource, contains('_DigitalImmersiveCoverPlane'));
    expect(stageSource, isNot(contains('_DigitalImmersiveCoverParticleField')));
    expect(planeSource, contains('_MusicImmersiveArtwork'));
    expect(planeSource, isNot(contains('drawRawAtlas')));
    expect(planeSource, isNot(contains('_DigitalCoverParticle')));
    expect(performancePipeline.existsSync(), isFalse);
    expect(editorSource, isNot(contains('_draft.coverParticles')));
  });

  test('沉浸背景不再绘制全屏节拍闪光和低频光圈', () {
    final backgroundPipeline = File(
      'lib/features/music/presentation/player/music_immersive_particles.dart',
    );
    final presetSource =
        File(
          'lib/features/music/domain/music_visualizer_preset.dart',
        ).readAsStringSync();
    final editorSource =
        File(
          'lib/features/music/presentation/player/music_immersive_preset_editor.dart',
        ).readAsStringSync();

    expect(backgroundPipeline.existsSync(), isFalse);
    expect(presetSource, isNot(contains('beatFlashEnabled')));
    expect(presetSource, isNot(contains('lowPulseEnabled')));
    expect(editorSource, isNot(contains('portalMusicVisualizerBeatFlash')));
    expect(editorSource, isNot(contains('portalMusicVisualizerLowPulse')));
  });

  test('视觉编辑器不再包含预设、舞台和平台档位', () {
    final modelSource =
        File(
          'lib/features/music/domain/music_visualizer_preset.dart',
        ).readAsStringSync();
    final editorSource =
        File(
          'lib/features/music/presentation/player/music_immersive_preset_editor.dart',
        ).readAsStringSync();
    final stageSource =
        File(
          'lib/features/music/presentation/player/music_immersive_player_stage.dart',
        ).readAsStringSync();

    expect(modelSource, isNot(contains('PortalStageVisualSettings')));
    expect(modelSource, isNot(contains('PortalPlatformVisualProfile')));
    expect(modelSource, isNot(contains('builtIns')));
    expect(editorSource, isNot(contains('VisualizerPreset')));
    expect(editorSource, isNot(contains('portalMusicVisualizerStage')));
    expect(editorSource, isNot(contains('portalMusicVisualizerPlatform')));
    expect(stageSource, contains('_MusicImmersiveAudioBar'));
    expect(stageSource, contains('visual.player.enabled'));
    expect(stageSource, contains('visual.player.audioBarEnabled'));
  });

  test('频谱绘制不再触发封面和音频条组件逐帧重建', () {
    final playerSource =
        File(
          'lib/features/music/application/music_audio_playback.dart',
        ).readAsStringSync();
    final stageSource =
        File(
          'lib/features/music/presentation/player/music_immersive_player_stage.dart',
        ).readAsStringSync();
    final audioBarSource =
        File(
          'lib/features/music/presentation/player/music_immersive_audio_bar.dart',
        ).readAsStringSync();
    final coverSource =
        File(
          'lib/features/music/presentation/player/music_immersive_cover_plane.dart',
        ).readAsStringSync();

    expect(playerSource, contains('setFftSmoothing(0)'));
    expect(audioBarSource, contains('super(repaint: spectrum)'));
    expect(audioBarSource, isNot(contains('ValueListenableBuilder')));
    expect(audioBarSource, contains('final active = frame.active'));
    expect(audioBarSource, isNot(contains('required this.isPlaying')));
    expect(coverSource, contains('super(repaint: spectrum)'));
    expect(stageSource, isNot(contains('animation: spectrumFeed')));
  });

  test('主封面默认正放并支持统一调整封面和边框倾斜角度', () {
    final modelSource =
        File(
          'lib/features/music/domain/music_visualizer_preset.dart',
        ).readAsStringSync();
    final coverSource =
        File(
          'lib/features/music/presentation/player/music_immersive_cover_plane.dart',
        ).readAsStringSync();

    expect(modelSource, contains('tiltDegrees: 0'));
    expect(coverSource, contains('visual.coverElements.tiltDegrees'));
    expect(coverSource, contains('canvas.rotate(tiltRadians)'));
    expect(coverSource, isNot(contains('rotateX(')));
    expect(coverSource, isNot(contains('rotateY(')));
  });

  test('Portal 沉浸模式为顶部栏预留视觉编辑空间', () {
    final portalSource =
        File(
          'lib/features/portal/presentation/widgets/portal_desktop_visual_shells.dart',
        ).readAsStringSync();
    final stageSource =
        File(
          'lib/features/music/presentation/player/music_immersive_player_stage.dart',
        ).readAsStringSync();

    expect(portalSource, contains('reservedTopInset:'));
    expect(portalSource, contains('MediaQuery.paddingOf(context).top + 58'));
    expect(stageSource, contains('widget.reservedTopInset + 12 * scale'));
  });

  test('视觉编辑器切换选项时保留滚动位置', () {
    final editorSource =
        File(
          'lib/features/music/presentation/player/music_immersive_preset_editor.dart',
        ).readAsStringSync();
    final stageSource =
        File(
          'lib/features/music/presentation/player/music_immersive_player_stage.dart',
        ).readAsStringSync();

    expect(
      editorSource,
      contains('late final ScrollController _scrollController'),
    );
    expect(editorSource, contains('controller: _scrollController'));
    expect(editorSource, contains('_scrollController.dispose()'));
    expect(stageSource, contains("ValueKey('music-visual-editor-positioned')"));
    expect(stageSource, contains("ValueKey('music-visual-editor')"));
  });
}
