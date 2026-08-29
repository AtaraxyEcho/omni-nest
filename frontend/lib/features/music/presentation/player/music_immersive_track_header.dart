part of 'music_immersive_player.dart';

class _DigitalImmersiveTrackHeader extends StatelessWidget {
  const _DigitalImmersiveTrackHeader({
    required this.palette,
    required this.track,
    required this.scale,
  });

  final MusicImmersivePalette palette;
  final MusicTrack? track;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = track?.title ?? l10n.musicNotPlaying;
    final subtitle =
        track == null
            ? l10n.portalDockMusic
            : '${track!.artistName} / ${track!.albumTitle}';
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 820 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: (27 * scale).clamp(23.0, 34.0),
                height: 1.10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 7 * scale),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: (16 * scale).clamp(14.0, 19.0),
                height: 1.16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
