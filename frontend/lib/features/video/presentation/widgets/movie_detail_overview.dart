import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

class MovieDetailOverview extends StatefulWidget {
  const MovieDetailOverview({required this.overview, this.width, super.key});

  final String? overview;
  final double? width;

  @override
  State<MovieDetailOverview> createState() => _MovieDetailOverviewState();
}

class _MovieDetailOverviewState extends State<MovieDetailOverview> {
  bool _expanded = false;
  bool _hasOverflow = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.overview;
    if (text == null || text.isEmpty) {
      return SizedBox.shrink();
    }
    final w = widget.width ?? MediaQuery.sizeOf(context).width;
    final titleSize = ms(w, 17);
    final bodySize = ms(w, 14);
    final btnSize = ms(w, 13);
    final textStyle = TextStyle(
      color: context.videoColors.onSurfaceVariant,
      fontSize: bodySize,
      height: 22 / 14,
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).videoOverview,
          style: TextStyle(
            color: context.videoColors.onSurface,
            fontSize: titleSize,
            height: 24 / 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        if (_expanded)
          Text(text, style: textStyle)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final span = TextSpan(text: text, style: textStyle);
              final tp = TextPainter(
                text: span,
                maxLines: 3,
                textDirection: TextDirection.ltr,
              );
              tp.layout(maxWidth: constraints.maxWidth);
              final hasOverflow = tp.didExceedMaxLines;
              if (hasOverflow != _hasOverflow) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _hasOverflow = hasOverflow);
                });
              }
              return Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              );
            },
          ),
        if (_hasOverflow) ...[
          SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? AppLocalizations.of(context).videoCollapse
                  : AppLocalizations.of(context).videoExpandAll,
              style: TextStyle(
                color: context.videoColors.primary,
                fontSize: btnSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
