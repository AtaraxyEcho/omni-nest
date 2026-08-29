import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';

/// 响应式搜索框：最大宽度 [maxWidth]，窄屏时自动缩小。
class ResponsiveSearchField extends StatelessWidget {
  const ResponsiveSearchField({
    required this.onChanged,
    this.hintText,
    this.maxWidth = 320,
    this.style,
    this.decoration,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String? hintText;
  final double maxWidth;
  final TextStyle? style;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: TextField(
        onChanged: onChanged,
        style: style,
        decoration:
            decoration ??
            InputDecoration(
              isDense: true,
              filled: true,
              hintText: hintText ?? l10n.coreSearchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
      ),
    );
  }
}
