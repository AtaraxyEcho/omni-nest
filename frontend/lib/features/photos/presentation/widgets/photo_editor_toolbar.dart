import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/core/widgets/app_slider.dart';

/// 编辑操作类型
enum EditTool { crop, rotate, brightness, contrast, saturation, filter }

/// 滤镜预设
enum FilterPreset { original, grayscale, sepia }

/// 照片编辑底部工具栏
class PhotoEditorToolbar extends StatelessWidget {
  const PhotoEditorToolbar({
    required this.selectedTool,
    required this.onToolSelected,
    required this.onRotate,
    required this.onCrop,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.selectedFilter,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onSaturationChanged,
    required this.onFilterSelected,
    super.key,
  });

  final EditTool? selectedTool;
  final ValueChanged<EditTool?> onToolSelected;
  final VoidCallback onRotate;
  final VoidCallback onCrop;
  final double brightness;
  final double contrast;
  final double saturation;
  final FilterPreset selectedFilter;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<FilterPreset> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.photosColors.surfaceContainer.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: context.photosColors.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 滑块区域
          if (selectedTool == EditTool.brightness)
            _SliderRow(
              label: AppLocalizations.of(context).photosBrightness,
              value: brightness,
              min: -1,
              max: 1,
              onChanged: onBrightnessChanged,
            ),
          if (selectedTool == EditTool.contrast)
            _SliderRow(
              label: AppLocalizations.of(context).photosContrast,
              value: contrast,
              min: 0,
              max: 2,
              onChanged: onContrastChanged,
            ),
          if (selectedTool == EditTool.saturation)
            _SliderRow(
              label: AppLocalizations.of(context).photosSaturation,
              value: saturation,
              min: -1,
              max: 1,
              onChanged: onSaturationChanged,
            ),
          if (selectedTool == EditTool.filter)
            _FilterChips(
              selected: selectedFilter,
              onSelected: onFilterSelected,
            ),
          // 工具按钮行
          SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: _ToolButton(
                    icon: Icons.crop_rounded,
                    label: AppLocalizations.of(context).photosCrop,
                    selected: selectedTool == EditTool.crop,
                    onTap: onCrop,
                  ),
                ),
                Expanded(
                  child: _ToolButton(
                    icon: Icons.rotate_right_rounded,
                    label: AppLocalizations.of(context).photosRotate,
                    selected: selectedTool == EditTool.rotate,
                    onTap: onRotate,
                  ),
                ),
                Expanded(
                  child: _ToolButton(
                    icon: Icons.brightness_6_rounded,
                    label: AppLocalizations.of(context).photosBrightness,
                    selected: selectedTool == EditTool.brightness,
                    onTap:
                        () => onToolSelected(
                          selectedTool == EditTool.brightness
                              ? null
                              : EditTool.brightness,
                        ),
                  ),
                ),
                Expanded(
                  child: _ToolButton(
                    icon: Icons.contrast_rounded,
                    label: AppLocalizations.of(context).photosContrast,
                    selected: selectedTool == EditTool.contrast,
                    onTap:
                        () => onToolSelected(
                          selectedTool == EditTool.contrast
                              ? null
                              : EditTool.contrast,
                        ),
                  ),
                ),
                Expanded(
                  child: _ToolButton(
                    icon: Icons.auto_awesome_rounded,
                    label: AppLocalizations.of(context).photosFilter,
                    selected: selectedTool == EditTool.filter,
                    onTap:
                        () => onToolSelected(
                          selectedTool == EditTool.filter
                              ? null
                              : EditTool.filter,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  selected
                      ? context.photosColors.primaryContainer
                      : context.photosColors.onSurfaceVariant,
              size: 22,
            ),
            SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    selected
                        ? context.photosColors.primaryContainer
                        : context.photosColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.photosColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: AppSlider(
              value: value,
              min: min,
              max: max,
              semanticLabel: label,
              activeColor: context.photosColors.primaryContainer,
              inactiveColor: context.photosColors.outlineVariant.withValues(
                alpha: 0.3,
              ),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: context.photosColors.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final FilterPreset selected;
  final ValueChanged<FilterPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = {
      FilterPreset.original: l10n.photosFilterOriginal,
      FilterPreset.grayscale: l10n.photosFilterGrayscale,
      FilterPreset.sepia: l10n.photosFilterSepia,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children:
            filters.entries.map((entry) {
              final isSelected = selected == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (_) => onSelected(entry.key),
                  selectedColor: context.photosColors.primaryContainer
                      .withValues(alpha: 0.2),
                  side: BorderSide(
                    color:
                        isSelected
                            ? context.photosColors.primaryContainer
                            : context.photosColors.outlineVariant.withValues(
                              alpha: 0.32,
                            ),
                  ),
                  labelStyle: TextStyle(
                    color:
                        isSelected
                            ? context.photosColors.primaryContainer
                            : context.photosColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
