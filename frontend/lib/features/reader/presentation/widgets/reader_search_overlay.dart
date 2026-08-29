import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/reader_colors.dart';

/// 搜索弹窗覆盖层 — 屏幕中间展开的搜索卡片
class ReaderSearchOverlay extends StatefulWidget {
  const ReaderSearchOverlay({
    required this.controller,
    required this.colors,
    required this.onSearch,
    super.key,
  });

  final TextEditingController controller;
  final ReaderColors colors;
  final ValueChanged<String> onSearch;

  @override
  State<ReaderSearchOverlay> createState() => _ReaderSearchOverlayState();
}

class _ReaderSearchOverlayState extends State<ReaderSearchOverlay> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      decoration: BoxDecoration(
        color: widget.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.colors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.readerSearch,
                  style: TextStyle(
                    color: widget.colors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.coreClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: widget.colors.onSurfaceVariant,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            autofocus: true,
            style: TextStyle(color: widget.colors.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: l10n.readerSearchHint,
              hintStyle: TextStyle(color: widget.colors.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: widget.colors.onSurfaceVariant,
              ),
              filled: true,
              fillColor: widget.colors.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.colors.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
            onSubmitted: widget.onSearch,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onSearch(widget.controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: widget.colors.primaryContainer,
                foregroundColor: widget.colors.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n.readerSearch),
            ),
          ),
        ],
      ),
    );
  }
}
