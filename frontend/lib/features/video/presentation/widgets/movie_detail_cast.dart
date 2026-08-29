import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

class CastCrewSection extends StatelessWidget {
  const CastCrewSection({
    required this.cast,
    required this.crew,
    this.width,
    super.key,
  });

  final List<MovieCastMember> cast;
  final List<MovieCrewMember> crew;
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) {
      return SizedBox.shrink();
    }
    final w = width ?? MediaQuery.sizeOf(context).width;
    final titleSize = ms(w, 17);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).videoCast,
          style: TextStyle(
            color: context.videoColors.onSurface,
            fontSize: titleSize,
            height: 24 / 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: cast.length,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              separatorBuilder: (_, _) => const SizedBox(width: 24),
              itemBuilder: (context, index) => _CastCard(member: cast[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.member});

  final MovieCastMember member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          _CastAvatar(name: member.name, profilePath: member.profilePath),
          SizedBox(height: 10),
          Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.videoColors.onSurface,
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (member.character != null && member.character!.isNotEmpty) ...[
            SizedBox(height: 3),
            Text(
              member.character!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant.withValues(
                  alpha: 0.72,
                ),
                fontSize: 11,
                height: 14 / 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CastAvatar extends StatelessWidget {
  const _CastAvatar({required this.name, this.profilePath});

  final String name;
  final String? profilePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: context.videoColors.surfaceContainerHighest,
      ),
      child:
          profilePath != null && profilePath!.isNotEmpty
              ? CachedNetworkImage(
                imageUrl: profilePath!,
                fit: BoxFit.cover,
                memCacheWidth: 100,
                errorWidget: (_, _, _) => _InitialsAvatar(name: name),
              )
              : _InitialsAvatar(name: name),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: context.videoColors.onSurface,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
